# Native Linux ARM64 build

Use a native aarch64 Linux host with Rust 1.88.0 (via rustup), Git, a C/C++
compiler and libclang. Flutter desktop builds also need CMake, Ninja,
pkg-config and GTK 3 development libraries.

From the repository root:

```sh
rustup toolchain install 1.88.0 --profile minimal
bash tool/build_linux.sh aarch64
cp libisar_linux_arm64.so packages/isar_community_flutter_libs/linux/libisar.aarch64.so
```

The existing x64 build (`bash tool/build_linux.sh x64`) and bundled filename
`linux/libisar.so` are unchanged. Build outputs are ignored by Git.
