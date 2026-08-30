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

rm -rf isar.xcframework
rm -f isar_macos.xcframework.zip
cp libisar_macos.dylib libisar.dylib
xcodebuild -create-xcframework -library libisar.dylib -output isar.xcframework
zip -r isar_macos.xcframework.zip isar.xcframework
rm -rf isar.xcframework
rm libisar.dylib
