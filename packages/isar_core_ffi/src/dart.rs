use once_cell::sync::OnceCell;

static DART_POST_C_OBJECT: OnceCell<DartPostCObjectFnType> = OnceCell::new();

/// Returns false when the port is closed, which is the case once its isolate
/// is gone.
pub fn dart_post_int(port: DartPort, value: i64) -> bool {
    let dart_post = DART_POST_C_OBJECT.get().unwrap();
    dart_post(port, &mut DartCObject::new(value)) != 0
}

pub type DartPort = i64;

pub type DartPostCObjectFnType = extern "C" fn(port_id: DartPort, message: *mut DartCObject) -> i8;

#[repr(C)]
pub struct DartCObject {
    ty: i32,
    value: DartCObjectValue,
}

impl DartCObject {
    fn new(value: i64) -> Self {
        DartCObject {
            ty: 3,
            value: DartCObjectValue { value },
        }
    }
}

#[repr(C)]
union DartCObjectValue {
    pub value: i64,
    _union_align: [u64; 5usize],
}

#[no_mangle]
pub unsafe extern "C" fn isar_connect_dart_api(ptr: DartPostCObjectFnType) {
    let _ = DART_POST_C_OBJECT.set(ptr);
}

/// Stands in for the Dart side in tests: remembers what every port received and
/// lets a test close a port, as the death of its isolate would.
#[cfg(test)]
pub mod testing {
    use super::*;
    use once_cell::sync::Lazy;
    use std::collections::{HashMap, HashSet};
    use std::sync::atomic::{AtomicI64, Ordering};
    use std::sync::Mutex;
    use std::thread::sleep;
    use std::time::{Duration, Instant};

    static NEXT_PORT: AtomicI64 = AtomicI64::new(1);
    static RECEIVED: Lazy<Mutex<HashMap<DartPort, Vec<i64>>>> =
        Lazy::new(|| Mutex::new(HashMap::new()));
    static CLOSED: Lazy<Mutex<HashSet<DartPort>>> = Lazy::new(|| Mutex::new(HashSet::new()));
    static REFUSED: Lazy<Mutex<HashMap<DartPort, usize>>> =
        Lazy::new(|| Mutex::new(HashMap::new()));

    extern "C" fn post(port: DartPort, message: *mut DartCObject) -> i8 {
        if CLOSED.lock().unwrap().contains(&port) {
            *REFUSED.lock().unwrap().entry(port).or_default() += 1;
            return 0;
        }
        let value = unsafe { (*message).value.value };
        RECEIVED
            .lock()
            .unwrap()
            .entry(port)
            .or_default()
            .push(value);
        1
    }

    pub fn open_port() -> DartPort {
        unsafe { isar_connect_dart_api(post) };
        NEXT_PORT.fetch_add(1, Ordering::SeqCst)
    }

    pub fn close_port(port: DartPort) {
        CLOSED.lock().unwrap().insert(port);
    }

    /// How many messages a closed port turned away.
    pub fn refused(port: DartPort) -> usize {
        REFUSED.lock().unwrap().get(&port).copied().unwrap_or(0)
    }

    pub fn received(port: DartPort) -> Vec<i64> {
        RECEIVED
            .lock()
            .unwrap()
            .get(&port)
            .cloned()
            .unwrap_or_default()
    }

    pub fn wait_until(what: &str, condition: impl Fn() -> bool) {
        let start = Instant::now();
        while !condition() {
            assert!(
                start.elapsed() < Duration::from_secs(10),
                "timed out: {what}"
            );
            sleep(Duration::from_millis(2));
        }
    }

    /// The next answer a port gets after the ones already taken.
    pub fn answer(port: DartPort, index: usize) -> i64 {
        wait_until("an answer on the port", || received(port).len() > index);
        received(port)[index]
    }
}
