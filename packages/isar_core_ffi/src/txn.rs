use crate::dart::{dart_post_int, DartPort};
use crate::error::DartErrCode;
use isar_core::error::{IsarError, Result};
use isar_core::instance::IsarInstance;
use isar_core::txn::IsarTxn;
use once_cell::sync::Lazy;
use std::borrow::BorrowMut;
use std::sync::mpsc;
use std::sync::mpsc::{Receiver, Sender};
use std::sync::Arc;
use std::sync::Mutex;
use threadpool::{Builder, ThreadPool};

static THREAD_POOL: Lazy<Mutex<ThreadPool>> =
    Lazy::new(|| Mutex::new(Builder::new().thread_name("isarworker".to_string()).build()));

pub fn run_async<F: FnOnce() + Send + 'static>(job: F) {
    THREAD_POOL.lock().unwrap().execute(job);
}

type AsyncJob = (Box<dyn FnOnce() + Send + 'static>, bool);

#[no_mangle]
pub unsafe extern "C" fn isar_txn_begin(
    isar: &'static IsarInstance,
    txn: *mut *const CIsarTxn,
    sync: bool,
    write: bool,
    silent: bool,
    port: DartPort,
) -> i64 {
    isar_try! {
        let new_txn = if sync {
            CIsarTxn::begin_sync(isar, write, silent)?
        } else {
            CIsarTxn::begin_async(isar, write, silent, port)
        };
        let txn_ptr = Box::into_raw(Box::new(new_txn));
        txn.write(txn_ptr);
    }
}

#[no_mangle]
pub unsafe extern "C" fn isar_txn_finish(txn: *mut CIsarTxn, commit: bool) -> i64 {
    let txn = Box::from_raw(txn);
    isar_try! {
        txn.finish(commit)?;
    }
}

/// Frees a transaction that was never finished. Used as the NativeFinalizer of async
/// transactions, so a transaction whose isolate shuts down mid-way is rolled back.
#[no_mangle]
pub unsafe extern "C" fn isar_txn_free(txn: *mut CIsarTxn) {
    if !txn.is_null() {
        drop(Box::from_raw(txn));
    }
}

pub struct IsarTxnSend(IsarTxn<'static>);

unsafe impl Send for IsarTxnSend {}

pub enum CIsarTxn {
    Sync {
        txn: Option<IsarTxn<'static>>,
    },
    Async {
        tx: Sender<AsyncJob>,
        port: DartPort,
        txn: Arc<Mutex<Option<IsarTxnSend>>>,
    },
}

impl CIsarTxn {
    fn begin_sync(isar: &'static IsarInstance, write: bool, silent: bool) -> Result<CIsarTxn> {
        let sync_txn = CIsarTxn::Sync {
            txn: Some(isar.begin_txn(write, silent)?),
        };
        Ok(sync_txn)
    }

    fn begin_async(
        isar: &'static IsarInstance,
        write: bool,
        silent: bool,
        port: DartPort,
    ) -> CIsarTxn {
        let (tx, rx): (Sender<AsyncJob>, Receiver<AsyncJob>) = mpsc::channel();
        let txn = Arc::new(Mutex::new(None));
        let txn_clone = txn.clone();
        // `isar` comes from `Arc::into_raw` in `isar_instance_create`. Take an owned
        // reference for as long as this worker can touch the instance: otherwise the
        // instance's NativeFinalizer (`isar_instance_close`, run when the owning isolate
        // shuts down) can free it while a job is still running here.
        let instance = unsafe {
            let ptr = isar as *const IsarInstance;
            Arc::increment_strong_count(ptr);
            Arc::from_raw(ptr)
        };
        run_async(move || {
            let new_txn = isar.begin_txn(write, silent);
            match new_txn {
                Ok(new_txn) => {
                    txn_clone.lock().unwrap().replace(IsarTxnSend(new_txn));
                    dart_post_int(port, 0);
                    // The sender is dropped without a final job when the Dart side goes
                    // away mid-transaction (see `isar_txn_free`).
                    while let Ok((job, stop)) = rx.recv() {
                        job();
                        if stop {
                            break;
                        }
                    }
                    // Roll back a transaction that was never finished, releasing the
                    // write lock, before the instance reference goes away.
                    txn_clone.lock().unwrap().take();
                }
                Err(e) => {
                    dart_post_int(port, Err(e).into_dart_result_code());
                }
            }
            drop(instance);
        });

        CIsarTxn::Async { tx, port, txn }
    }

    pub fn exec_async_internal<F: FnOnce() -> Result<()> + Send + 'static>(
        job: F,
        port: DartPort,
        tx: Sender<AsyncJob>,
        stop: bool,
    ) {
        let handle_response_job = move || {
            let result = job().into_dart_result_code();
            dart_post_int(port, result as i64);
        };
        tx.send((Box::new(handle_response_job), stop)).unwrap();
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
            CIsarTxn::Async { txn, tx, port } => {
                let txn = txn.clone();
                let job = move || -> Result<()> {
                    let mut lock = txn.lock().unwrap();
                    if let Some(ref mut txn) = *lock {
                        job(&mut txn.0)
                    } else {
                        Err(IsarError::TransactionClosed {})
                    }
                };
                CIsarTxn::exec_async_internal(job, *port, tx.clone(), false);
                Ok(())
            }
        }
    }

    pub fn finish(self, commit: bool) -> Result<()> {
        match self {
            CIsarTxn::Sync { mut txn } => {
                if let Some(txn) = txn.take() {
                    if commit {
                        txn.commit()
                    } else {
                        txn.abort();
                        Ok(())
                    }
                } else {
                    Err(IsarError::TransactionClosed {})
                }
            }
            CIsarTxn::Async { txn, tx, port } => {
                let txn = txn.clone();
                let job = move || -> Result<()> {
                    let mut lock = txn.lock().unwrap();
                    if let Some(txn) = (*lock).take() {
                        if commit {
                            txn.0.commit()
                        } else {
                            txn.0.abort();
                            Ok(())
                        }
                    } else {
                        Err(IsarError::TransactionClosed {})
                    }
                };
                CIsarTxn::exec_async_internal(job, port, tx.clone(), true);
                Ok(())
            }
        }
    }
}
