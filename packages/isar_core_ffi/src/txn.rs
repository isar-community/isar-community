use crate::dart::{dart_post_int, DartPort};
use crate::error::DartErrCode;
use crossbeam_channel::{select, unbounded, Receiver, RecvTimeoutError, Sender};
use isar_core::error::{IsarError, Result};
use isar_core::instance::IsarInstance;
use isar_core::txn::IsarTxn;
use once_cell::sync::Lazy;
use std::borrow::BorrowMut;
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::sync::Mutex;
use std::sync::Weak;
use std::time::Duration;
use threadpool::{Builder, ThreadPool};

static THREAD_POOL: Lazy<Mutex<ThreadPool>> =
    Lazy::new(|| Mutex::new(Builder::new().thread_name("isarworker".to_string()).build()));

pub fn run_async<F: FnOnce() + Send + 'static>(job: F) {
    THREAD_POOL.lock().unwrap().execute(job);
}

/// Keeps an instance open for work that runs on the pool. Dart may close its
/// handle, or its isolate may die, before that work is done.
pub struct InstanceRef(Option<Arc<IsarInstance>>);

impl InstanceRef {
    /// The pointer has to come from isar_instance_create and the handle it was
    /// read from must still be open.
    pub unsafe fn new(isar: *const IsarInstance) -> Self {
        Arc::increment_strong_count(isar);
        InstanceRef(Some(Arc::from_raw(isar)))
    }
}

impl Drop for InstanceRef {
    fn drop(&mut self) {
        if let Some(instance) = self.0.take() {
            instance.release();
        }
    }
}

pub enum AsyncJob {
    // A job returns its answer for Dart. The flag marks the job that ends the
    // transaction.
    Run(Box<dyn FnOnce() -> i64 + Send + 'static>, bool),
    // Dart will never use or free the transaction again. No answer is owed.
    Abandon,
}

// How long an idle transaction is kept once no handle of its instance is open.
// It is counted in short waits, so the time a suspended process spent frozen
// does not pass for idleness.
const ORPHAN_GRACE_WAIT: Duration = Duration::from_millis(100);
const ORPHAN_GRACE_WAITS: u32 = if cfg!(test) { 5 } else { 50 };

#[no_mangle]
pub unsafe extern "C" fn isar_txn_begin(
    isar: *const IsarInstance,
    txn: *mut *const CIsarTxn,
    sync: bool,
    write: bool,
    silent: bool,
    port: DartPort,
) -> i64 {
    isar_try! {
        let new_txn = if sync {
            CIsarTxn::begin_sync(&*isar, write, silent)?
        } else {
            CIsarTxn::begin_async(isar, write, silent, port)
        };
        let txn_ptr = Box::into_raw(Box::new(new_txn));
        txn.write(txn_ptr);
    }
}

#[no_mangle]
pub unsafe extern "C" fn isar_txn_finish(txn: *mut CIsarTxn, commit: bool) -> i64 {
    isar_try! {
        CIsarTxn::finish(txn, commit)?;
    }
}

/// Lets Dart say that it will never use or free an async transaction again:
/// its isolate is gone, or the object that held the transaction was collected.
pub struct CIsarTxnWatch {
    tx: Sender<AsyncJob>,
    closed: Arc<Mutex<bool>>,
    watched: Arc<AtomicBool>,
    instance_ref: Weak<Mutex<Option<InstanceRef>>>,
}

/// Returns null for a sync transaction. Dart attaches a native finalizer that
/// calls isar_txn_abandon to the result and then calls isar_txn_watch_start.
/// In that order no transaction counts as watched without a finalizer.
#[no_mangle]
pub unsafe extern "C" fn isar_txn_watch(txn: &CIsarTxn) -> *mut CIsarTxnWatch {
    match txn {
        CIsarTxn::Sync { .. } => ptr::null_mut(),
        CIsarTxn::Async {
            tx,
            closed,
            watched,
            instance_ref,
            ..
        } => Box::into_raw(Box::new(CIsarTxnWatch {
            tx: tx.clone(),
            closed: closed.clone(),
            watched: watched.clone(),
            instance_ref: Arc::downgrade(instance_ref),
        })),
    }
}

#[no_mangle]
pub unsafe extern "C" fn isar_txn_watch_start(watch: &CIsarTxnWatch) {
    watch.watched.store(true, Ordering::SeqCst);
}

/// Frees the watch. A transaction that is still open is ended and no longer
/// keeps its instance.
#[no_mangle]
pub unsafe extern "C" fn isar_txn_abandon(watch: *mut CIsarTxnWatch) {
    let watch = Box::from_raw(watch);
    let closed = watch.closed.lock().unwrap();
    if !*closed {
        let _ = watch.tx.send(AsyncJob::Abandon);
    } else if let Some(instance_ref) = watch.instance_ref.upgrade() {
        // The worker is gone and the transaction object was never freed.
        instance_ref.lock().unwrap().take();
    }
}

pub struct IsarTxnSend(IsarTxn<'static>);

unsafe impl Send for IsarTxnSend {}

struct CIsarTxnSend(*mut CIsarTxn);

unsafe impl Send for CIsarTxnSend {}

pub enum CIsarTxn {
    Sync {
        txn: Option<IsarTxn<'static>>,
    },
    Async {
        tx: Sender<AsyncJob>,
        port: DartPort,
        write: bool,
        txn: Arc<Mutex<Option<IsarTxnSend>>>,
        // True once the worker takes no more jobs. Jobs are sent with it locked,
        // so none can slip into the queue behind the worker's back.
        closed: Arc<Mutex<bool>>,
        // Dart may go on using the transaction after closing its handle, and
        // what it passes in points into the instance. This is emptied once
        // Dart is known never to free the transaction.
        instance_ref: Arc<Mutex<Option<InstanceRef>>>,
        // Dart abandons the transaction itself when nobody is left to finish
        // it, so the worker does not have to guess.
        watched: Arc<AtomicBool>,
    },
}

impl CIsarTxn {
    fn begin_sync(isar: &'static IsarInstance, write: bool, silent: bool) -> Result<CIsarTxn> {
        let sync_txn = CIsarTxn::Sync {
            txn: Some(isar.begin_txn(write, silent)?),
        };
        Ok(sync_txn)
    }

    unsafe fn begin_async(
        isar: *const IsarInstance,
        write: bool,
        silent: bool,
        port: DartPort,
    ) -> CIsarTxn {
        let (tx, rx): (Sender<AsyncJob>, Receiver<AsyncJob>) = unbounded();
        let txn = Arc::new(Mutex::new(None));
        let txn_clone = txn.clone();
        let closed = Arc::new(Mutex::new(false));
        let closed_clone = closed.clone();
        // Taken before returning, while the caller's handle is open. The
        // worker shares it, so the instance stays for as long as either the
        // worker or the transaction object needs it.
        let txn_instance_ref = Arc::new(Mutex::new(Some(InstanceRef::new(isar))));
        let txn_instance_ref_clone = txn_instance_ref.clone();
        let watched = Arc::new(AtomicBool::new(false));
        let watched_clone = watched.clone();
        let isar: &'static IsarInstance = &*isar;
        let orphaned = isar.orphan_signal();
        run_async(move || {
            // The answer still owed to Dart, and whether Dart will never free
            // the transaction: it does not finish one that failed to begin, a
            // closed port means that its isolate is gone, and it may have
            // abandoned the transaction.
            let (last_answer, never_freed) = match isar.begin_txn(write, silent) {
                Ok(new_txn) => {
                    txn_clone.lock().unwrap().replace(IsarTxnSend(new_txn));
                    if dart_post_int(port, 0) {
                        Self::run_jobs(&rx, &orphaned, &watched_clone, port)
                    } else {
                        (None, true)
                    }
                }
                Err(e) => (Some(Err(e).into_dart_result_code()), true),
            };

            // Held to the end: an answer posted for a refused job must not
            // overtake the answers of the jobs still in the queue.
            let mut closed = closed_clone.lock().unwrap();
            *closed = true;
            drop(txn_clone.lock().unwrap().take());
            if never_freed {
                txn_instance_ref_clone.lock().unwrap().take();
            }
            // The instance is let go before the last answer leaves, so that a
            // close which follows that answer finds it free. The transaction
            // borrowed from the instance and is gone by now.
            let txn_instance_ref_weak = Arc::downgrade(&txn_instance_ref_clone);
            drop(txn_instance_ref_clone);
            if let Some(answer) = last_answer {
                dart_post_int(port, answer);
            }
            // Jobs still in the queue find the transaction gone and say so.
            while let Ok(job) = rx.try_recv() {
                match job {
                    AsyncJob::Run(job, _) => {
                        dart_post_int(port, job());
                    }
                    AsyncJob::Abandon => {
                        // The transaction object outlived a commit that failed.
                        if let Some(instance_ref) = txn_instance_ref_weak.upgrade() {
                            instance_ref.lock().unwrap().take();
                        }
                    }
                }
            }
        });

        CIsarTxn::Async {
            tx,
            port,
            write,
            txn,
            closed,
            instance_ref: txn_instance_ref,
            watched,
        }
    }

    // Runs jobs until one ends the transaction or nobody is left to send it:
    // Dart abandoned the transaction, an answer no longer reaches Dart, or no
    // job comes anymore. Returns the answer of the job that ended the
    // transaction, and whether Dart is known never to free it.
    fn run_jobs(
        jobs: &Receiver<AsyncJob>,
        orphaned: &Receiver<()>,
        watched: &AtomicBool,
        port: DartPort,
    ) -> (Option<i64>, bool) {
        while let Some(job) = Self::next_job(jobs, orphaned, watched) {
            let (job, stop) = match job {
                AsyncJob::Run(job, stop) => (job, stop),
                AsyncJob::Abandon => return (None, true),
            };
            let answer = job();
            if stop {
                return (Some(answer), false);
            }
            if !dart_post_int(port, answer) {
                return (None, true);
            }
        }
        (None, false)
    }

    // Results point into the database, so a transaction cannot be ended while
    // its isolate may still read them. A watched transaction is abandoned by
    // Dart when that is over. For any other one the worker has to guess: once
    // the last handle of the instance is closed, an isolate that is alive sends
    // its next job shortly and a dead one never does, so the wait gives up
    // after a grace period.
    fn next_job(
        jobs: &Receiver<AsyncJob>,
        orphaned: &Receiver<()>,
        watched: &AtomicBool,
    ) -> Option<AsyncJob> {
        if let Ok(job) = jobs.try_recv() {
            return Some(job);
        }
        select! {
            recv(jobs) -> job => return job.ok(),
            recv(orphaned) -> _ => {}
        }
        for _ in 0..ORPHAN_GRACE_WAITS {
            if watched.load(Ordering::SeqCst) {
                return jobs.recv().ok();
            }
            match jobs.recv_timeout(ORPHAN_GRACE_WAIT) {
                Ok(job) => return Some(job),
                Err(RecvTimeoutError::Timeout) => {}
                Err(RecvTimeoutError::Disconnected) => return None,
            }
        }
        None
    }

    // Dart awaits one answer per job, so when the worker is gone the answer is
    // posted from here. Returns whether the worker got the job.
    fn exec_async_internal<F: FnOnce() -> Result<()> + Send + 'static>(
        job: F,
        answer_if_closed: Result<()>,
        port: DartPort,
        tx: &Sender<AsyncJob>,
        closed: &Mutex<bool>,
        stop: bool,
    ) -> bool {
        let handle_response_job = move || job().into_dart_result_code();
        let closed = closed.lock().unwrap();
        if *closed
            || tx
                .send(AsyncJob::Run(Box::new(handle_response_job), stop))
                .is_err()
        {
            dart_post_int(port, answer_if_closed.into_dart_result_code());
            false
        } else {
            true
        }
    }

    pub fn exec(
        &mut self,
        job: Box<dyn FnOnce(&mut IsarTxn) -> Result<()> + Send + 'static>,
    ) -> Result<()> {
        match self.borrow_mut() {
            CIsarTxn::Sync { ref mut txn } => {
                if let Some(ref mut txn) = txn {
                    job(txn)
                } else {
                    Err(IsarError::TransactionClosed {})
                }
            }
            CIsarTxn::Async {
                txn,
                tx,
                port,
                closed,
                ..
            } => {
                let txn = txn.clone();
                let job = move || -> Result<()> {
                    let mut lock = txn.lock().unwrap();
                    if let Some(ref mut txn) = *lock {
                        job(&mut txn.0)
                    } else {
                        Err(IsarError::TransactionClosed {})
                    }
                };
                CIsarTxn::exec_async_internal(
                    job,
                    Err(IsarError::TransactionClosed {}),
                    *port,
                    tx,
                    closed,
                    false,
                );
                Ok(())
            }
        }
    }

    /// Frees the transaction, except on a commit that fails: Dart aborts a
    /// transaction whose commit failed, so it stays valid until its commit went
    /// through or the abort arrives.
    pub unsafe fn finish(this: *mut CIsarTxn, commit: bool) -> Result<()> {
        if commit {
            if let CIsarTxn::Sync { txn } = &mut *this {
                let txn = txn.take().ok_or(IsarError::TransactionClosed {})?;
                txn.commit()?;
                drop(Box::from_raw(this));
                return Ok(());
            }
            if let CIsarTxn::Async {
                txn,
                tx,
                port,
                write,
                closed,
                ..
            } = &*this
            {
                // The worker may free the transaction as soon as it has the
                // job, so nothing is read from it after that.
                let (txn, tx, closed) = (txn.clone(), tx.clone(), closed.clone());
                let (port, write) = (*port, *write);
                // A read transaction that ended early has nothing left to commit.
                let ended_early = move || -> Result<()> {
                    if write {
                        Err(IsarError::TransactionClosed {})
                    } else {
                        Ok(())
                    }
                };
                let this_send = CIsarTxnSend(this);
                let job = move || -> Result<()> {
                    let this_send = this_send;
                    match txn.lock().unwrap().take() {
                        Some(txn) => txn.0.commit()?,
                        None => ended_early()?,
                    }
                    drop(Box::from_raw(this_send.0));
                    Ok(())
                };
                let answer = ended_early();
                let committed_without_worker = answer.is_ok();
                let sent = CIsarTxn::exec_async_internal(job, answer, port, &tx, &closed, true);
                if !sent && committed_without_worker {
                    drop(Box::from_raw(this));
                }
                return Ok(());
            }
        }

        match *Box::from_raw(this) {
            CIsarTxn::Sync { txn } => {
                // Nothing is left to abort after a commit that failed.
                if let Some(txn) = txn {
                    txn.abort();
                }
                Ok(())
            }
            CIsarTxn::Async {
                txn,
                tx,
                port,
                closed,
                ..
            } => {
                let job = move || -> Result<()> {
                    if let Some(txn) = txn.lock().unwrap().take() {
                        txn.0.abort();
                    }
                    Ok(())
                };
                CIsarTxn::exec_async_internal(job, Ok(()), port, &tx, &closed, true);
                Ok(())
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::c_object_set::CObjectSet;
    use crate::dart::testing::{answer, close_port, open_port, received, refused, wait_until};
    use crate::instance::{
        isar_instance_close, isar_instance_close_and_delete, isar_instance_copy_to_file,
        isar_instance_create, isar_instance_create_async,
    };
    use crate::query::{isar_q_find, isar_q_free, isar_qb_build, isar_qb_create};
    use isar_core::object::isar_object::IsarObject;
    use isar_core::query::Query;
    use std::ffi::CString;
    use std::mem::ManuallyDrop;
    use std::ptr;
    use std::sync::mpsc;
    use std::sync::Weak;
    use std::thread;
    use std::time::{Duration, Instant};

    const SCHEMA: &str = r#"[{"name":"col","properties":[{"name":"value","type":"Long"}]}]"#;

    // A handle as Dart holds it.
    #[derive(Clone, Copy)]
    struct Handle(*const IsarInstance);

    unsafe impl Send for Handle {}

    impl Handle {
        fn isar(self) -> &'static IsarInstance {
            unsafe { &*self.0 }
        }

        fn close(self) -> bool {
            unsafe { isar_instance_close(self.0) }
        }
    }

    struct TestDb {
        name: CString,
        dir: CString,
        schema: CString,
        // Counts the references to the instance without being one.
        instance: Mutex<Weak<IsarInstance>>,
    }

    impl TestDb {
        fn new(name: &str) -> Self {
            let dir = std::env::temp_dir().join(format!("isar_ffi_{}_{name}", std::process::id()));
            let _ = std::fs::remove_dir_all(&dir);
            std::fs::create_dir_all(&dir).unwrap();
            TestDb {
                name: CString::new(name).unwrap(),
                dir: CString::new(dir.to_str().unwrap()).unwrap(),
                schema: CString::new(SCHEMA).unwrap(),
                instance: Mutex::new(Weak::new()),
            }
        }

        fn open(&self) -> Handle {
            let mut isar: *const IsarInstance = ptr::null();
            let result = unsafe {
                isar_instance_create(
                    &mut isar,
                    self.name.as_ptr(),
                    self.dir.as_ptr(),
                    self.schema.as_ptr(),
                    64,
                    false,
                    0,
                    0,
                    f64::NAN,
                )
            };
            assert_eq!(result, 0);
            let handle = ManuallyDrop::new(unsafe { Arc::from_raw(isar) });
            *self.instance.lock().unwrap() = Arc::downgrade(&handle);
            Handle(isar)
        }

        fn references(&self) -> usize {
            self.instance.lock().unwrap().strong_count()
        }

        fn is_open(&self) -> bool {
            self.references() > 0
        }

        // INSTANCES holds one reference besides the given ones.
        fn wait_for_references(&self, others: usize) {
            wait_until("the references to the instance", || {
                self.references() == others + 1
            });
        }
    }

    impl Drop for TestDb {
        fn drop(&mut self) {
            let _ = std::fs::remove_dir_all(self.dir.to_str().unwrap());
        }
    }

    // Begins an async transaction and returns it with the answer to the begin.
    fn begin_async_with(
        handle: Handle,
        write: bool,
        silent: bool,
        port: DartPort,
    ) -> (*mut CIsarTxn, i64) {
        let mut txn: *const CIsarTxn = ptr::null();
        let result = unsafe { isar_txn_begin(handle.0, &mut txn, false, write, silent, port) };
        assert_eq!(result, 0);
        (txn as *mut CIsarTxn, answer(port, 0))
    }

    // Begins an async transaction and waits for the worker to have it.
    fn begin_async(handle: Handle, write: bool) -> (*mut CIsarTxn, DartPort) {
        let port = open_port();
        let (txn, begun) = begin_async_with(handle, write, true, port);
        assert_eq!(begun, 0);
        (txn, port)
    }

    fn begin_sync(handle: Handle, write: bool, silent: bool) -> Option<*mut CIsarTxn> {
        let mut txn: *const CIsarTxn = ptr::null();
        let result = unsafe { isar_txn_begin(handle.0, &mut txn, true, write, silent, 0) };
        (result == 0).then_some(txn as *mut CIsarTxn)
    }

    fn exec(txn: *mut CIsarTxn, job: impl FnOnce(&mut IsarTxn) -> Result<()> + Send + 'static) {
        unsafe { (*txn).exec(Box::new(job)).unwrap() };
    }

    fn finish(txn: *mut CIsarTxn, commit: bool) {
        assert_eq!(unsafe { isar_txn_finish(txn, commit) }, 0);
    }

    // Whether the worker of an async transaction has let go of it.
    fn worker_ended(txn: *mut CIsarTxn) -> bool {
        match unsafe { &*txn } {
            CIsarTxn::Async { closed, .. } => *closed.lock().unwrap(),
            CIsarTxn::Sync { .. } => true,
        }
    }

    fn wait_for_worker_end(txn: *mut CIsarTxn) {
        wait_until("the worker to end", || worker_ended(txn));
    }

    // What Dart does right after it began an async transaction. The result
    // is what its finalizer hands to isar_txn_abandon.
    fn watch(txn: *mut CIsarTxn) -> *mut CIsarTxnWatch {
        unsafe {
            let watch = isar_txn_watch(&*txn);
            isar_txn_watch_start(&*watch);
            watch
        }
    }

    fn create(db: &TestDb, schema: &CString) -> (i64, *const IsarInstance) {
        let mut isar: *const IsarInstance = ptr::null();
        let result = unsafe {
            isar_instance_create(
                &mut isar,
                db.name.as_ptr(),
                db.dir.as_ptr(),
                schema.as_ptr(),
                64,
                false,
                0,
                0,
                f64::NAN,
            )
        };
        (result, isar)
    }

    fn other_schema() -> CString {
        CString::new(
            r#"[{"name":"col","properties":[{"name":"value","type":"Long"},{"name":"more","type":"Long"}]}]"#,
        )
        .unwrap()
    }

    // A sync write that notifies watchers blocks for as long as another
    // transaction holds the writer or the watchers.
    fn assert_writer_is_free(handle: Handle) {
        let (done_tx, done_rx) = mpsc::channel();
        thread::spawn(move || {
            let txn = begin_sync(handle, true, false).unwrap();
            finish(txn, true);
            let _ = done_tx.send(());
        });
        done_rx
            .recv_timeout(Duration::from_secs(10))
            .expect("the writer is still held");
    }

    // A job that reads the database once the test lets it go on.
    fn blocked_read(handle: Handle, txn: *mut CIsarTxn) -> mpsc::Sender<()> {
        let (entered_tx, entered_rx) = mpsc::channel();
        let (go_on_tx, go_on_rx) = mpsc::channel::<()>();
        exec(txn, move |txn| {
            entered_tx.send(()).unwrap();
            let _ = go_on_rx.recv();
            handle.isar().verify(txn)
        });
        entered_rx.recv().unwrap();
        go_on_tx
    }

    #[test]
    fn close_right_after_a_commit_closes_the_instance() {
        let db = TestDb::new("commit");
        let handle = db.open();
        let (txn, port) = begin_async(handle, true);

        exec(txn, move |txn| handle.isar().verify(txn));
        assert_eq!(answer(port, 1), 0);
        finish(txn, true);
        assert_eq!(answer(port, 2), 0);

        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn close_right_after_an_abort_closes_the_instance() {
        let db = TestDb::new("abort");
        let handle = db.open();
        let (txn, port) = begin_async(handle, true);

        finish(txn, false);
        assert_eq!(answer(port, 1), 0);

        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn close_right_after_a_copy_closes_the_instance() {
        let db = TestDb::new("copy");
        let handle = db.open();
        let port = open_port();
        let target = format!("{}/target.isar", db.dir.to_str().unwrap());
        let target = CString::new(target).unwrap();

        unsafe { isar_instance_copy_to_file(handle.0, target.as_ptr(), port) };
        assert_eq!(answer(port, 0), 0);

        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn failed_commit_is_followed_by_an_abort() {
        let db = TestDb::new("failed_commit");
        let handle = db.open();
        let (txn, port) = begin_async(handle, true);

        // A failed write leaves the transaction unusable, so its commit fails.
        exec(txn, move |txn| {
            let too_big = vec![0u8; IsarObject::MAX_SIZE as usize + 1];
            let object = IsarObject::from_bytes(&too_big);
            handle.isar().collections[0].put(txn, None, object)?;
            Ok(())
        });
        assert_ne!(answer(port, 1), 0);
        finish(txn, true);
        assert_ne!(answer(port, 2), 0);

        finish(txn, false);
        assert_eq!(answer(port, 3), 0);
        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn close_during_a_job_keeps_the_instance_until_the_transaction_ends() {
        let db = TestDb::new("close_during_job");
        let handle = db.open();
        let (txn, port) = begin_async(handle, false);
        let go_on = blocked_read(handle, txn);

        assert!(!handle.close());
        assert!(db.is_open());

        go_on.send(()).unwrap();
        assert_eq!(answer(port, 1), 0);
        assert!(db.is_open());

        finish(txn, true);
        assert_eq!(answer(port, 2), 0);
        assert!(!db.is_open());
    }

    #[test]
    fn transaction_still_in_use_survives_the_close_of_its_instance() {
        let grace = ORPHAN_GRACE_WAIT * ORPHAN_GRACE_WAITS;
        // A test thread that stalls for a whole grace period proves nothing
        // about the worker, so such an attempt is repeated.
        for attempt in 0.. {
            assert!(attempt < 20, "the test thread never kept up");
            let db = TestDb::new(&format!("in_use_{attempt}"));
            let handle = db.open();
            let (txn, port) = begin_async(handle, false);
            // The worker is idle for less than the time from before one call
            // to after the next.
            let mut before_last_call = Instant::now();
            assert!(!handle.close());

            // Dart keeps coming back before the grace period runs out, for
            // longer than one grace period in all.
            let mut kept_up = true;
            for index in 1..=8 {
                thread::sleep(ORPHAN_GRACE_WAIT);
                let before_call = Instant::now();
                exec(txn, move |txn| handle.isar().verify(txn));
                if before_last_call.elapsed() >= grace {
                    kept_up = false;
                    break;
                }
                assert_eq!(answer(port, index), 0);
                before_last_call = before_call;
            }
            if !kept_up {
                finish(txn, false);
                continue;
            }

            finish(txn, true);
            assert_eq!(answer(port, 9), 0);
            assert!(!db.is_open());
            return;
        }
    }

    #[test]
    fn idle_write_transaction_ends_once_no_handle_is_open() {
        let db = TestDb::new("idle_write");
        let handle = db.open();
        let port = open_port();
        // Not silent, so the transaction also holds the watchers.
        let (txn, begun) = begin_async_with(handle, true, false, port);
        assert_eq!(begun, 0);
        assert!(!handle.close());

        // The transaction object still keeps the instance, so this is the same
        // one, and its writer is free once the grace period is over.
        let handle = db.open();
        assert_writer_is_free(handle);

        // Dart may still use the transaction it was given: every call is
        // answered, and the abort after the failed commit finds it valid.
        exec(txn, move |txn| handle.isar().verify(txn));
        assert_ne!(answer(port, 1), 0);
        finish(txn, true);
        assert_ne!(answer(port, 2), 0);
        finish(txn, false);
        assert_eq!(answer(port, 3), 0);

        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn idle_read_transaction_commits_after_it_was_ended() {
        let db = TestDb::new("idle_read");
        let handle = db.open();
        let (txn, port) = begin_async(handle, false);
        assert!(!handle.close());

        // Only the transaction object is left once the worker gave up.
        wait_for_worker_end(txn);
        db.wait_for_references(1);
        finish(txn, true);
        assert_eq!(answer(port, 1), 0);
        assert!(!db.is_open());
    }

    #[test]
    fn transaction_of_a_dead_isolate_ends_while_another_handle_is_open() {
        let db = TestDb::new("dead_port");
        let handle = db.open();
        let other_handle = db.open();
        let (txn, port) = begin_async(handle, true);

        close_port(port);
        exec(txn, move |txn| handle.isar().verify(txn));

        // Neither the worker nor the transaction object keeps the instance.
        db.wait_for_references(2);
        assert_writer_is_free(other_handle);
        assert_eq!(received(port), vec![0]);

        assert!(!handle.close());
        assert!(other_handle.close());
        assert!(!db.is_open());
        finish(txn, false);
    }

    #[test]
    fn transaction_that_fails_to_begin_does_not_keep_the_instance() {
        let db = TestDb::new("failed_begin");
        let handle = db.open();

        // Read transactions until the environment has no reader left.
        let mut readers = vec![];
        while let Some(txn) = begin_sync(handle, false, true) {
            readers.push(txn);
            assert!(readers.len() < 100_000, "the readers never ran out");
        }
        let port = open_port();
        let (_, begun) = begin_async_with(handle, false, true, port);
        assert_ne!(begun, 0);
        for txn in readers {
            finish(txn, true);
        }

        // Dart never finishes a transaction that did not begin.
        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn async_open_by_a_dead_isolate_leaves_no_handle() {
        let db = TestDb::new("dead_open");
        let handle = db.open();
        let port = open_port();
        close_port(port);

        let slot = Box::leak(Box::new(ptr::null::<IsarInstance>()));
        unsafe {
            isar_instance_create_async(
                slot,
                db.name.as_ptr(),
                db.dir.as_ptr(),
                db.schema.as_ptr(),
                64,
                false,
                0,
                0,
                f64::NAN,
                port,
            )
        };
        wait_until("the answer to the open", || refused(port) == 1);
        db.wait_for_references(1);

        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn reopened_instance_is_not_orphaned_by_the_previous_close() {
        let db = TestDb::new("reopen");
        let handle = db.open();
        let (old_txn, old_port) = begin_async(handle, false);
        assert!(!handle.close());

        let handle = db.open();
        let (txn, port) = begin_async(handle, true);
        // The old worker gives up, the new one does not.
        wait_for_worker_end(old_txn);
        thread::sleep(ORPHAN_GRACE_WAIT * (ORPHAN_GRACE_WAITS + 3));
        assert!(!worker_ended(txn));
        // The handle and both transaction objects are left.
        db.wait_for_references(3);

        exec(txn, move |txn| handle.isar().verify(txn));
        assert_eq!(answer(port, 1), 0);
        finish(txn, true);
        assert_eq!(answer(port, 2), 0);

        finish(old_txn, true);
        assert_eq!(answer(old_port, 1), 0);
        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn handles_are_counted_per_open() {
        let db = TestDb::new("handles");
        let first = db.open();
        let second = db.open();
        let orphaned = first.isar().orphan_signal();

        assert!(!first.close());
        assert!(orphaned.try_recv().unwrap_err().is_empty());
        assert!(second.close());
        assert!(orphaned.try_recv().unwrap_err().is_disconnected());
    }

    #[test]
    fn failed_sync_commit_is_followed_by_an_abort() {
        let db = TestDb::new("failed_sync_commit");
        let handle = db.open();
        let txn = begin_sync(handle, true, true).unwrap();

        // A failed write leaves the transaction unusable, so its commit fails.
        let written = unsafe {
            (*txn).exec(Box::new(move |txn| {
                let too_big = vec![0u8; IsarObject::MAX_SIZE as usize + 1];
                let object = IsarObject::from_bytes(&too_big);
                handle.isar().collections[0].put(txn, None, object)?;
                Ok(())
            }))
        };
        assert!(written.is_err());
        assert_ne!(unsafe { isar_txn_finish(txn, true) }, 0);
        assert_eq!(unsafe { isar_txn_finish(txn, false) }, 0);

        assert_writer_is_free(handle);
        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn delete_asked_by_the_last_handle_happens_once_the_work_is_done() {
        let db = TestDb::new("delete_later");
        let handle = db.open();
        let (txn, port) = begin_async(handle, false);
        let go_on = blocked_read(handle, txn);
        let file = format!("{}/delete_later.isar", db.dir.to_str().unwrap());
        let file = std::path::Path::new(&file);

        assert!(!unsafe { isar_instance_close_and_delete(handle.0) });
        assert!(file.exists());

        go_on.send(()).unwrap();
        assert_eq!(answer(port, 1), 0);
        finish(txn, true);
        assert_eq!(answer(port, 2), 0);
        assert!(!db.is_open());
        assert!(!file.exists());
    }

    #[test]
    fn delete_asked_while_another_handle_is_open_is_not_kept() {
        let db = TestDb::new("delete_not_kept");
        let handle = db.open();
        let other_handle = db.open();
        let file = format!("{}/delete_not_kept.isar", db.dir.to_str().unwrap());

        assert!(!unsafe { isar_instance_close_and_delete(handle.0) });
        assert!(other_handle.close());
        assert!(!db.is_open());
        assert!(std::path::Path::new(&file).exists());
    }

    #[test]
    fn open_with_another_schema_waits_for_the_work_and_migrates() {
        let db = TestDb::new("other_schema");
        let handle = db.open();
        let (txn, port) = begin_async(handle, false);
        let go_on = blocked_read(handle, txn);
        assert!(!handle.close());

        let (opened_tx, opened_rx) = mpsc::channel();
        let name = db.name.clone();
        let dir = db.dir.clone();
        thread::spawn(move || {
            let mut isar: *const IsarInstance = ptr::null();
            let schema = other_schema();
            let result = unsafe {
                isar_instance_create(
                    &mut isar,
                    name.as_ptr(),
                    dir.as_ptr(),
                    schema.as_ptr(),
                    64,
                    false,
                    0,
                    0,
                    f64::NAN,
                )
            };
            let _ = opened_tx.send((result, Handle(isar)));
        });
        // The open does not come back while the work runs.
        assert!(opened_rx.recv_timeout(Duration::from_millis(100)).is_err());

        go_on.send(()).unwrap();
        assert_eq!(answer(port, 1), 0);
        finish(txn, true);
        let (result, migrated) = opened_rx.recv().unwrap();
        assert_eq!(result, 0);
        assert_eq!(migrated.isar().collections[0].properties.len(), 2);
        assert!(migrated.close());
    }

    #[test]
    fn open_with_another_schema_gives_up_on_an_instance_that_stays() {
        let db = TestDb::new("other_schema_stays");
        let handle = db.open();
        // Not watched and never finished: its object keeps the instance.
        let (txn, port) = begin_async(handle, false);
        assert!(!handle.close());

        let (result, _) = create(&db, &other_schema());
        assert_ne!(result, 0);

        // The schema it was opened with is still welcome.
        let handle = db.open();
        finish(txn, true);
        assert_eq!(answer(port, 1), 0);
        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn abandoned_transaction_ends_while_another_handle_is_open() {
        let db = TestDb::new("abandon_other_handle");
        let handle = db.open();
        let other_handle = db.open();
        let port = open_port();
        // Not silent, so the transaction also holds the watchers.
        let (txn, begun) = begin_async_with(handle, true, false, port);
        assert_eq!(begun, 0);
        let watch = watch(txn);

        // What the finalizers of a dying isolate do, in either order.
        assert!(!handle.close());
        unsafe { isar_txn_abandon(watch) };

        // Neither the worker nor the transaction object keeps the instance.
        db.wait_for_references(1);
        assert_writer_is_free(other_handle);
        assert_eq!(received(port), vec![0]);
        assert!(other_handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn abandoned_transaction_does_not_keep_the_instance() {
        let db = TestDb::new("abandon_last_handle");
        let handle = db.open();
        let (txn, _) = begin_async(handle, true);
        let watch = watch(txn);

        unsafe { isar_txn_abandon(watch) };
        wait_for_worker_end(txn);
        assert!(handle.close());
        assert!(!db.is_open());
    }

    #[test]
    fn watched_transaction_outlasts_the_grace_period() {
        let db = TestDb::new("watched");
        let handle = db.open();
        let (txn, port) = begin_async(handle, true);
        let watch = watch(txn);
        assert!(!handle.close());

        // Dart is alive and slow: nothing is taken from it.
        thread::sleep(ORPHAN_GRACE_WAIT * (ORPHAN_GRACE_WAITS + 3));
        assert!(!worker_ended(txn));
        exec(txn, move |txn| handle.isar().verify(txn));
        assert_eq!(answer(port, 1), 0);
        finish(txn, true);
        assert_eq!(answer(port, 2), 0);
        assert!(!db.is_open());

        // The finalizer of the collected object finds the transaction done.
        unsafe { isar_txn_abandon(watch) };
        assert_eq!(received(port), vec![0, 0, 0]);
    }

    #[test]
    fn abandon_after_a_failed_commit_lets_go_of_the_instance() {
        let db = TestDb::new("abandon_failed_commit");
        let handle = db.open();
        let (txn, port) = begin_async(handle, true);
        let watch = watch(txn);

        exec(txn, move |txn| {
            let too_big = vec![0u8; IsarObject::MAX_SIZE as usize + 1];
            let object = IsarObject::from_bytes(&too_big);
            handle.isar().collections[0].put(txn, None, object)?;
            Ok(())
        });
        assert_ne!(answer(port, 1), 0);
        finish(txn, true);
        assert_ne!(answer(port, 2), 0);

        // The isolate dies before the abort Dart owed.
        assert!(!handle.close());
        unsafe { isar_txn_abandon(watch) };
        assert!(!db.is_open());
    }

    #[test]
    fn abandon_queued_behind_a_failed_commit_lets_go_of_the_instance() {
        let db = TestDb::new("abandon_queued");
        let handle = db.open();
        let (txn, port) = begin_async(handle, true);
        let watch = watch(txn);
        let (go_on_tx, go_on_rx) = mpsc::channel::<()>();

        // The worker is held back while the commit and the abandon queue up.
        exec(txn, move |txn| {
            let _ = go_on_rx.recv();
            let too_big = vec![0u8; IsarObject::MAX_SIZE as usize + 1];
            let object = IsarObject::from_bytes(&too_big);
            handle.isar().collections[0].put(txn, None, object)?;
            Ok(())
        });
        finish(txn, true);
        assert!(!handle.close());
        unsafe { isar_txn_abandon(watch) };

        go_on_tx.send(()).unwrap();
        assert_ne!(answer(port, 1), 0);
        assert_ne!(answer(port, 2), 0);
        wait_until("the instance to close", || !db.is_open());
        assert_eq!(received(port).len(), 3);
    }

    #[test]
    fn async_opens_by_a_dead_isolate_that_share_a_slot_leave_no_handle() {
        let first = TestDb::new("dead_open_first");
        let second = TestDb::new("dead_open_second");
        let first_handle = first.open();
        let second_handle = second.open();
        let port = open_port();
        close_port(port);

        // Dart hands the same slot to every open of an isolate.
        let slot: *mut *const IsarInstance = Box::leak(Box::new(ptr::null()));
        for db in [&first, &second] {
            unsafe {
                isar_instance_create_async(
                    slot,
                    db.name.as_ptr(),
                    db.dir.as_ptr(),
                    db.schema.as_ptr(),
                    64,
                    false,
                    0,
                    0,
                    f64::NAN,
                    port,
                )
            };
        }
        wait_until("the answers to the opens", || refused(port) == 2);
        first.wait_for_references(1);
        second.wait_for_references(1);

        assert!(first_handle.close());
        assert!(second_handle.close());
        assert!(!first.is_open());
        assert!(!second.is_open());
    }

    #[test]
    fn queued_job_keeps_its_query_after_the_query_is_freed() {
        let db = TestDb::new("query");
        let handle = db.open();
        let (txn, port) = begin_async(handle, false);
        let go_on = blocked_read(handle, txn);

        let query = unsafe { isar_qb_build(isar_qb_create(&handle.isar().collections[0])) };
        let references = ManuallyDrop::new(unsafe { Arc::from_raw(query as *const Query) });
        let results = Box::leak(Box::new(unsafe { std::mem::zeroed::<CObjectSet>() }));
        assert_eq!(
            unsafe { isar_q_find(query, &mut *txn, results, u32::MAX) },
            0
        );
        assert_eq!(Arc::strong_count(&references), 2);
        // What the finalizer of a dying isolate does.
        unsafe { isar_q_free(query) };
        assert_eq!(Arc::strong_count(&references), 1);

        go_on.send(()).unwrap();
        assert_eq!(answer(port, 1), 0);
        assert_eq!(answer(port, 2), 0);
        finish(txn, true);
        assert_eq!(answer(port, 3), 0);
        assert!(handle.close());
        assert!(!db.is_open());
    }
}
