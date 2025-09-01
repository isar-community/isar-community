use bindgen::{Formatter, callbacks::{IntKind, ParseCallbacks}};
use std::{env, fs, path::{Path, PathBuf}, process::Command};

const LIBMDBX_REPO: &str = "https://github.com/isar-community/libmdbx.git";
const LIBMDBX_TAG: &str = "v0.13.8";

#[derive(Debug)]
struct Callbacks;

impl ParseCallbacks for Callbacks {
    fn int_macro(&self, name: &str, _value: i64) -> Option<IntKind> {
        match name {
            "MDBX_SUCCESS"
            | "MDBX_KEYEXIST"
            | "MDBX_NOTFOUND"
            | "MDBX_PAGE_NOTFOUND"
            | "MDBX_CORRUPTED"
            | "MDBX_PANIC"
            | "MDBX_VERSION_MISMATCH"
            | "MDBX_INVALID"
            | "MDBX_MAP_FULL"
            | "MDBX_DBS_FULL"
            | "MDBX_READERS_FULL"
            | "MDBX_TLS_FULL"
            | "MDBX_TXN_FULL"
            | "MDBX_CURSOR_FULL"
            | "MDBX_PAGE_FULL"
            | "MDBX_MAP_RESIZED"
            | "MDBX_INCOMPATIBLE"
            | "MDBX_BAD_RSLOT"
            | "MDBX_BAD_TXN"
            | "MDBX_BAD_VALSIZE"
            | "MDBX_BAD_DBI"
            | "MDBX_LOG_DONTCHANGE"
            | "MDBX_DBG_DONTCHANGE"
            | "MDBX_RESULT_TRUE"
            | "MDBX_UNABLE_EXTEND_MAPSIZE"
            | "MDBX_PROBLEM"
            | "MDBX_LAST_LMDB_ERRCODE"
            | "MDBX_BUSY"
            | "MDBX_EMULTIVAL"
            | "MDBX_EBADSIGN"
            | "MDBX_WANNA_RECOVERY"
            | "MDBX_EKEYMISMATCH"
            | "MDBX_TOO_LARGE"
            | "MDBX_THREAD_MISMATCH"
            | "MDBX_TXN_OVERLAPPING"
            | "MDBX_BACKLOG_DEPLETED"
            | "MDBX_DUPLICATED_CLK"
            | "MDBX_DANGLING_DBI"
            | "MDBX_OUSTED"
            | "MDBX_MVCC_RETARDED"
            | "MDBX_LAST_ERRCODE" => Some(IntKind::Int),
            _ => Some(IntKind::UInt),
        }
    }
}

fn ensure_libmdbx(out_dir: &Path) -> PathBuf {
    let libmdbx_dir = out_dir.join("libmdbx");
    if libmdbx_dir.exists() {
        let _ = fs::remove_dir_all(&libmdbx_dir);
    }

    let status = Command::new("git")
        .args([
            "clone",
            "--depth", "1",
            "--branch", LIBMDBX_TAG,
            "--single-branch",
            LIBMDBX_REPO,
            libmdbx_dir.to_string_lossy().as_ref(),
        ])
        .status()
        .expect("failed to spawn git");

    if !status.success() {
        panic!("git clone of libmdbx failed with status: {}", status);
    }

    libmdbx_dir
}

fn parse_semver_from_tag(tag: &str) -> (u32, u32, u32, u32, &'static str) {
    // Expect formats like v0.13.7 or 0.13.7
    let t = tag.trim_start_matches('v');
    let mut parts = t.split('.');
    let major = parts.next().unwrap_or("0").parse().unwrap_or(0);
    let minor = parts.next().unwrap_or("0").parse().unwrap_or(0);
    let patch = parts.next().unwrap_or("0").parse().unwrap_or(0);
    let tweak = 0u32;
    let prerelease: &'static str = ""; // keep empty like Vorot's release builds
    (major, minor, patch, tweak, prerelease)
}

fn generate_version_c(libmdbx_dir: &Path, tag: &str) {
    let src_dir = libmdbx_dir.join("src");
    let in_path = src_dir.join("version.c.in");
    if !in_path.exists() { return; }

    let (maj, min, pat, twk, prerelease) = parse_semver_from_tag(tag);
    let mut content = fs::read_to_string(&in_path)
        .expect("read version.c.in failed");

    // CMake-style substitutions
    content = content.replace("${MDBX_VERSION_MAJOR}", &maj.to_string());
    content = content.replace("${MDBX_VERSION_MINOR}", &min.to_string());
    content = content.replace("${MDBX_VERSION_PATCH}", &pat.to_string());
    content = content.replace("${MDBX_VERSION_TWEAK}", &twk.to_string());

    content = content.replace("@MDBX_VERSION_PRERELEASE@", prerelease);
    // Pure SemVer without metadata; not used at compile time here
    content = content.replace("@MDBX_VERSION_PURE@", "");

    // Git metadata placeholders; safe defaults
    content = content.replace("@MDBX_GIT_TIMESTAMP@", "0");
    content = content.replace("@MDBX_GIT_TREE@", "");
    content = content.replace("@MDBX_GIT_COMMIT@", "");
    content = content.replace("@MDBX_GIT_DESCRIBE@", tag.trim_start_matches('v'));

    let out_path = src_dir.join("version.c");
    fs::write(&out_path, content).expect("write version.c failed");
}

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let libmdbx_dir = ensure_libmdbx(&out_dir);

    // Create src/version.c from template
    generate_version_c(&libmdbx_dir, LIBMDBX_TAG);

    // Generate bindings
    let bindings = bindgen::Builder::default()
        .header(libmdbx_dir.join("mdbx.h").to_string_lossy())
        .allowlist_var("^(MDBX|mdbx)_.*")
        .allowlist_type("^(MDBX|mdbx)_.*")
        .allowlist_function("^(MDBX|mdbx)_.*")
        .size_t_is_usize(true)
        .ctypes_prefix("::libc")
        .parse_callbacks(Box::new(Callbacks))
        .layout_tests(false)
        .prepend_enum_name(false)
        .generate_comments(false)
        .disable_header_comment()
        .formatter(Formatter::None)
        .generate()
        .expect("Unable to generate bindings");

    bindings
        .write_to_file(out_dir.join("bindings.rs"))
        .expect("Couldn't write bindings!");

    // Compile C
    let mut cc_builder = cc::Build::new();
    cc_builder
        .flag_if_supported("-Wall")
        .flag_if_supported("-Werror")
        .flag_if_supported("-ffunction-sections")
        .flag_if_supported("-fvisibility=hidden")
        .flag_if_supported("-Wno-error=attributes");

    let target = env::var("TARGET").unwrap_or_default();
    let target_os = env::var("CARGO_CFG_TARGET_OS").unwrap_or_default();

    if !target.contains("windows") {
        cc_builder.pic(true);
    }

    // Define MDBX_BUILD_FLAGS for parity with Vorot
    let flags = format!(
        "\"-NDEBUG={} {}\"",
        u8::from(!cfg!(debug_assertions)),
        cc_builder
            .get_compiler()
            .cflags_env()
            .to_str()
            .unwrap_or("")
            .trim()
    );

    cc_builder
        .define("MDBX_BUILD_FLAGS", flags.as_str())
        .define("MDBX_TXN_CHECKOWNER", "0");

    // Disable builtin CPU supports probing on musl
    if target.ends_with("-musl") {
        cc_builder.define("MDBX_HAVE_BUILTIN_CPU_SUPPORTS", "0");
    }

    // Android specific tweaks
    if target_os == "android" {
        cc_builder.define("MDBX_HAVE_BUILTIN_CPU_SUPPORTS", "0");
        cc_builder.define("MDBX_ENV_CHECKPID", "0");
    }

    if target.contains("windows") {
        println!(r"cargo:rustc-link-lib=dylib=ntdll");
        println!(r"cargo:rustc-link-lib=dylib=user32");
        println!(r"cargo:rustc-link-lib=dylib=advapi32");
    }

    let amalgamated = libmdbx_dir.join("mdbx.c");
    let src_dir = libmdbx_dir.join("src");
    let alloy = src_dir.join("alloy.c");
    if amalgamated.exists() {
        cc_builder.file(amalgamated);
    } else if alloy.exists() {
        // alloy.c is a self-amalgamated build unit; compile only it
        cc_builder.include(&src_dir);
        cc_builder.file(alloy);
    } else {
        // Fallback: build individual sources (rare)
        let mut files: Vec<PathBuf> = fs::read_dir(&src_dir)
            .expect("list libmdbx/src failed")
            .filter_map(|e| e.ok())
            .map(|e| e.path())
            .filter(|p| p.extension().map(|e| e == "c").unwrap_or(false))
            .collect();
        let is_windows = target.contains("windows");
        files.retain(|p| {
            let fname = p.file_name().unwrap().to_string_lossy();
            if fname == "version.c" || fname == "version.c.in" { return false; }
            if fname == "alloy.c" { return false; }
            if is_windows {
                if fname == "lck-posix.c" { return false; }
            } else {
                if fname == "lck-windows.c" || fname == "windows-import.c" { return false; }
            }
            true
        });
        for f in files { cc_builder.file(f); }
    }

    cc_builder.compile("libmdbx.a");
}


