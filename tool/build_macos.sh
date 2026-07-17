#!/bin/bash

# Definir a toolchain específica para macOS
RUST_TOOLCHAIN="1.88.0-x86_64-apple-darwin"

# Instalar a toolchain se não existir
rustup toolchain install $RUST_TOOLCHAIN

echo "Building for macOS"
rustup run $RUST_TOOLCHAIN rustc --version
rustup run $RUST_TOOLCHAIN cargo --version
rustup target add aarch64-apple-darwin x86_64-apple-darwin --toolchain $RUST_TOOLCHAIN
rustup run $RUST_TOOLCHAIN cargo build --target aarch64-apple-darwin --release
rustup run $RUST_TOOLCHAIN cargo build --target x86_64-apple-darwin --release
lipo "target/aarch64-apple-darwin/release/libisar.dylib" "target/x86_64-apple-darwin/release/libisar.dylib" -output "libisar_macos.dylib" -create
install_name_tool -id @rpath/libisar.dylib libisar_macos.dylib

# Place CocoaPods dylib and SPM xcframework under the plugin package.
macos_dir="packages/isar_community_flutter_libs/macos"
macos_spm_dir="$macos_dir/isar_community_flutter_libs"
mkdir -p "$macos_spm_dir"
cp libisar_macos.dylib "$macos_dir/libisar.dylib"
rm -rf "$macos_spm_dir/isar.xcframework"
cp libisar_macos.dylib /tmp/libisar.dylib
xcodebuild -create-xcframework \
  -library /tmp/libisar.dylib \
  -output "$macos_spm_dir/isar.xcframework"
rm -f /tmp/libisar.dylib
