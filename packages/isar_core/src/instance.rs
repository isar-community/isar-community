use crate::collection::IsarCollection;
use crate::error::*;
use crate::mdbx::env::Env;
use crate::query::Query;
use crate::schema::schema_manager::SchemaManager;
use crate::schema::Schema;
use crate::txn::IsarTxn;
use crate::watch::change_set::ChangeSet;
use crate::watch::isar_watchers::{IsarWatchers, WatcherModifier};
use crate::watch::watcher::WatcherCallback;
use crate::watch::WatchHandle;
use crossbeam_channel::{bounded, unbounded, Receiver, Sender};
use intmap::IntMap;
use once_cell::sync::Lazy;
use std::fs::remove_file;
use std::fs::{self, metadata};
use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, AtomicU64, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex, RwLock, RwLockWriteGuard};
use std::thread::sleep;
use std::time::{Duration, Instant};
use xxhash_rust::xxh3::xxh3_64;

static INSTANCES: Lazy<RwLock<IntMap<Arc<IsarInstance>>>> =
    Lazy::new(|| RwLock::new(IntMap::new()));

// Held by an open from start to end. Opens wait for each other here, so that
// INSTANCES is free while an environment is opened.
static OPENING: Mutex<()> = Mutex::new(());

// How long an open with another schema waits for an instance that only work
// on the pool keeps open. Debug builds, which only tests use, wait less.
const LINGERING_INSTANCE_WAIT: Duration =
    Duration::from_secs(if cfg!(debug_assertions) { 1 } else { 10 });

static WATCHER_ID: AtomicU64 = AtomicU64::new(0);

pub struct CompactCondition {
    pub min_file_size: u64,
    pub min_bytes: u64,
    pub min_ratio: f64,
}

pub struct IsarInstance {
    pub name: String,
    pub dir: String,
    pub collections: Vec<IsarCollection>,
    pub(crate) instance_id: u64,

    env: Env,
    watchers: Mutex<IsarWatchers>,
    watcher_modifier_sender: Sender<WatcherModifier>,

    // Handles returned by open() and not closed yet. Only changes under the
    // INSTANCES lock.
    open_handles: AtomicUsize,
    // Replaced when the last handle is closed, which disconnects every receiver
    // handed out before.
    orphan_signal: Mutex<(Sender<()>, Receiver<()>)>,
    // The last handle asked for the files to be deleted. They go with the last
    // reference, which may be work that outlives the handle.
    delete_on_close: AtomicBool,
    // Name and hash of every collection schema the instance was opened with.
    opened_with: Vec<(String, u64)>,
}

impl IsarInstance {
    pub fn open(
        name: &str,
        dir: Option<&str>,
        schema: Schema,
        max_size_mib: usize,
        relaxed_durability: bool,
        compact_condition: Option<CompactCondition>,
    ) -> Result<Arc<Self>> {
        let _opening = OPENING.lock().unwrap();
        let instance_id = xxh3_64(name.as_bytes());
        let waiting_since = Instant::now();
        loop {
            let lock = INSTANCES.write().unwrap();
            let Some(instance) = lock.get(instance_id) else {
                break;
            };
            // Without a handle, only work on the pool keeps the instance open,
            // with the schema of an earlier open. It closes when that work is
            // done, and the file is then opened and migrated as usual.
            if instance.open_handles.load(Ordering::SeqCst) == 0
                && !instance.was_opened_with(&schema)?
            {
                if waiting_since.elapsed() > LINGERING_INSTANCE_WAIT {
                    return Err(IsarError::SchemaMismatch {});
                }
                drop(lock);
                sleep(Duration::from_millis(10));
                continue;
            }
            instance.open_handles.fetch_add(1, Ordering::SeqCst);
            // The database is in use again.
            instance.delete_on_close.store(false, Ordering::SeqCst);
            return Ok(instance.clone());
        }

        if let Some(dir) = dir {
            let new_instance = Self::open_internal(
                name,
                dir,
                instance_id,
                schema,
                max_size_mib,
                relaxed_durability,
                compact_condition,
            )?;
            let new_instance = Arc::new(new_instance);
            new_instance.open_handles.fetch_add(1, Ordering::SeqCst);
            INSTANCES
                .write()
                .unwrap()
                .insert(instance_id, new_instance.clone());
            Ok(new_instance)
        } else {
            Err(IsarError::IllegalArg {
                message: "Please provide a valid directory.".to_string(),
            })
        }
    }

    fn schema_hashes(schema: &Schema) -> Result<Vec<(String, u64)>> {
        schema
            .collections
            .iter()
            .map(|col| Ok((col.name.clone(), xxh3_64(&col.to_json_bytes()?))))
            .collect()
    }

    // Whether every collection of the schema is one this instance was opened
    // with, unchanged.
    fn was_opened_with(&self, schema: &Schema) -> Result<bool> {
        let requested = Self::schema_hashes(schema)?;
        Ok(requested.iter().all(|col| self.opened_with.contains(col)))
    }

    fn get_isar_path(name: &str, dir: &str) -> String {
        let mut file_name = name.to_string();
        file_name.push_str(".isar");

        let mut path_buf = PathBuf::from(dir);
        path_buf.push(file_name);
        path_buf.as_path().to_str().unwrap().to_string()
    }

    fn move_old_database(name: &str, dir: &str, new_path: &str) {
        let mut old_path_buf = PathBuf::from(dir);
        old_path_buf.push(name);
        old_path_buf.push("mdbx.dat");
        let old_path = old_path_buf.as_path();

        let result = fs::rename(old_path, new_path);

        // Also try to migrate the previous default isar name
        if name == "default" && result.is_err() {
            Self::move_old_database("isar", dir, new_path)
        }
    }

    fn open_internal(
        name: &str,
        dir: &str,
        instance_id: u64,
        mut schema: Schema,
        max_size_mib: usize,
        relaxed_durability: bool,
        compact_condition: Option<CompactCondition>,
    ) -> Result<Self> {
        let isar_file = Self::get_isar_path(name, dir);
        // Before the migration merges what the file holds into the schema.
        let opened_with = Self::schema_hashes(&schema)?;

        Self::move_old_database(name, dir, &isar_file);

        let db_count = schema.count_dbs() as u64 + 3;
        let env = Env::create(
            &isar_file,
            db_count,
            max_size_mib.max(1),
            relaxed_durability,
        )
        .map_err(|e| IsarError::EnvError { error: Box::new(e) })?;

        let txn = env.txn(true)?;
        let mut manager = SchemaManager::create(instance_id, &txn)?;
        txn.commit()?;

        let txn = env.txn(true)?;
        let added_indexes = manager.migrate_schema(&txn, &mut schema)?;
        txn.commit()?;

        let mut collections = vec![];
        for col_schema in &schema.collections {
            let txn = env.txn(true)?;
            let col_id = xxh3_64(col_schema.name.as_bytes());
            let added_indexes = added_indexes
                .get(col_id)
                .map(|v| v.as_slice())
                .unwrap_or_default();
            let col = manager.open_collection(&txn, col_schema, &schema, added_indexes)?;
            collections.push(col);
            txn.commit()?;
        }

        if !manager.schemas.is_empty() {
            let txn = env.txn(true)?;
            manager.delete_unopened_collections(&txn)?;
            txn.commit()?;
        }

        let (tx, rx) = unbounded();

        let instance = IsarInstance {
            env,
            name: name.to_string(),
            dir: dir.to_string(),
            collections,
            instance_id,
            watchers: Mutex::new(IsarWatchers::new(rx)),
            watcher_modifier_sender: tx,
            open_handles: AtomicUsize::new(0),
            orphan_signal: Mutex::new(bounded(0)),
            delete_on_close: AtomicBool::new(false),
            opened_with: opened_with.clone(),
        };

        if let Some(compact_condition) = compact_condition {
            let instance = instance.compact(compact_condition)?;
            if let Some(instance) = instance {
                Ok(instance)
            } else {
                let mut instance = Self::open_internal(
                    name,
                    dir,
                    instance_id,
                    schema,
                    max_size_mib,
                    relaxed_durability,
                    None,
                )?;
                // The schema passed on is the merged one.
                instance.opened_with = opened_with;
                Ok(instance)
            }
        } else {
            Ok(instance)
        }
    }

    fn compact(self, compact_condition: CompactCondition) -> Result<Option<Self>> {
        let mut txn = self.begin_txn(false, true)?;
        let instance_size = self.get_size(&mut txn, true, true)?;
        txn.abort();

        let isar_file = Self::get_isar_path(&self.name, &self.dir);
        let file_size = metadata(&isar_file)
            .map_err(|_| IsarError::PathError {})?
            .len();

        let compact_bytes = file_size.saturating_sub(instance_size);
        let compact_ratio = if instance_size == 0 {
            f64::INFINITY
        } else {
            (file_size as f64) / (instance_size as f64)
        };
        let should_compact = file_size >= compact_condition.min_file_size
            && compact_bytes >= compact_condition.min_bytes
            && compact_ratio >= compact_condition.min_ratio;

        if should_compact {
            let compact_file = format!("{}.compact", &isar_file);
            self.copy_to_file(&compact_file)?;
            drop(self);

            let _ = fs::rename(&compact_file, &isar_file);
            Ok(None)
        } else {
            Ok(Some(self))
        }
    }

    pub fn get_instance(name: &str) -> Option<Arc<Self>> {
        let instance_id = xxh3_64(name.as_bytes());
        INSTANCES.read().unwrap().get(instance_id).cloned()
    }

    pub fn begin_txn(&self, write: bool, silent: bool) -> Result<IsarTxn> {
        let change_set = if write && !silent {
            let mut watchers_lock = self.watchers.lock().unwrap();
            watchers_lock.sync();
            let change_set = ChangeSet::new(watchers_lock);
            Some(change_set)
        } else {
            None
        };

        let txn = self.env.txn(write)?;
        IsarTxn::new(self.instance_id, txn, write, change_set)
    }

    pub fn get_size(
        &self,
        txn: &mut IsarTxn,
        include_indexes: bool,
        include_links: bool,
    ) -> Result<u64> {
        let mut size = 0;

        for col in &self.collections {
            size += col.get_size(txn, include_indexes, include_links)?;
        }

        Ok(size)
    }

    pub fn copy_to_file(&self, path: &str) -> Result<()> {
        self.env.copy(path)
    }

    fn new_watcher(&self, start: WatcherModifier, stop: WatcherModifier) -> WatchHandle {
        self.watcher_modifier_sender.try_send(start).unwrap();

        let sender = self.watcher_modifier_sender.clone();
        WatchHandle::new(Box::new(move || {
            let _ = sender.try_send(stop);
        }))
    }

    pub fn watch_collection(
        &self,
        collection: &IsarCollection,
        callback: WatcherCallback,
    ) -> WatchHandle {
        let watcher_id = WATCHER_ID.fetch_add(1, Ordering::SeqCst);
        let col_id = collection.id;
        self.new_watcher(
            Box::new(move |iw| {
                iw.get_col_watchers(col_id)
                    .add_watcher(watcher_id, callback);
            }),
            Box::new(move |iw| {
                iw.get_col_watchers(col_id).remove_watcher(watcher_id);
            }),
        )
    }

    pub fn watch_object(
        &self,
        collection: &IsarCollection,
        oid: i64,
        callback: WatcherCallback,
    ) -> WatchHandle {
        let watcher_id = WATCHER_ID.fetch_add(1, Ordering::SeqCst);
        let col_id = collection.id;
        self.new_watcher(
            Box::new(move |iw| {
                iw.get_col_watchers(col_id)
                    .add_object_watcher(watcher_id, oid, callback);
            }),
            Box::new(move |iw| {
                iw.get_col_watchers(col_id)
                    .remove_object_watcher(oid, watcher_id);
            }),
        )
    }

    pub fn watch_query(
        &self,
        collection: &IsarCollection,
        query: Query,
        callback: WatcherCallback,
    ) -> WatchHandle {
        let watcher_id = WATCHER_ID.fetch_add(1, Ordering::SeqCst);
        let col_id = collection.id;
        self.new_watcher(
            Box::new(move |iw| {
                iw.get_col_watchers(col_id)
                    .add_query_watcher(watcher_id, query, callback);
            }),
            Box::new(move |iw| {
                iw.get_col_watchers(col_id).remove_query_watcher(watcher_id);
            }),
        )
    }

    /// A channel that disconnects once every handle returned by open() has been
    /// closed. Work that outlives its handle watches it to learn that nobody is
    /// left to finish it.
    pub fn orphan_signal(&self) -> Receiver<()> {
        self.orphan_signal.lock().unwrap().1.clone()
    }

    fn close_internal(self: Arc<Self>, delete_from_disk: bool) -> bool {
        let instances = INSTANCES.write().unwrap();
        let handles_left = self
            .open_handles
            .fetch_update(Ordering::SeqCst, Ordering::SeqCst, |handles| {
                handles.checked_sub(1)
            })
            .map_or(0, |handles| handles - 1);
        if handles_left == 0 {
            *self.orphan_signal.lock().unwrap() = bounded(0);
            // With another handle open the database stays, as its files do.
            if delete_from_disk {
                self.delete_on_close.store(true, Ordering::SeqCst);
            }
        }
        self.drop_reference(instances)
    }

    fn drop_reference(
        self: Arc<Self>,
        mut instances: RwLockWriteGuard<IntMap<Arc<IsarInstance>>>,
    ) -> bool {
        // INSTANCES holds one reference and self is another. The count is read
        // and self is dropped under the lock, so two callers cannot both
        // conclude that the other one keeps the instance open.
        if Arc::strong_count(&self) > 2 {
            drop(self);
            return false;
        }

        instances.remove(self.instance_id);
        let delete_from_disk = self.delete_on_close.load(Ordering::SeqCst);
        let mut path = Self::get_isar_path(&self.name, &self.dir);
        drop(self);
        if delete_from_disk {
            let _ = remove_file(&path);
            path.push_str(".lock");
            let _ = remove_file(&path);
        }
        true
    }

    /// Gives up a reference that kept the instance open without being a handle.
    /// The instance is closed if nothing else holds it.
    pub fn release(self: Arc<Self>) -> bool {
        let instances = INSTANCES.write().unwrap();
        self.drop_reference(instances)
    }

    pub fn close(self: Arc<Self>) -> bool {
        self.close_internal(false)
    }

    pub fn close_and_delete(self: Arc<Self>) -> bool {
        self.close_internal(true)
    }

    pub fn verify(&self, txn: &mut IsarTxn) -> Result<()> {
        let mut db_names = vec![];
        db_names.push("_info".to_string());
        for col in &self.collections {
            db_names.push(col.name.clone());
            for index in &col.indexes {
                db_names.push(format!("_i_{}_{}", col.name, index.name));
            }

            for link in &col.links {
                db_names.push(format!("_l_{}_{}", col.name, link.name));
                db_names.push(format!("_b_{}_{}", col.name, link.name));
            }
        }
        let mut actual_db_names = txn.db_names()?;

        db_names.sort();
        actual_db_names.sort();

        if db_names != actual_db_names {
            Err(IsarError::DbCorrupted {
                message: "Incorrect databases".to_string(),
            })
        } else {
            Ok(())
        }
    }
}
