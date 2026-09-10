#!/bin/bash

# Set the specific toolchain
RUST_TOOLCHAIN="1.88.0-x86_64-unknown-linux-gnu"

if [ "$1" = "x64" ]; then
  echo "Building for Linux x64 with fixed Rust 1.88.0"
  rustup target add x86_64-unknown-linux-gnu --toolchain $RUST_TOOLCHAIN
  rustup run $RUST_TOOLCHAIN rustc --version
  rustup run $RUST_TOOLCHAIN cargo --version
  rustup run $RUST_TOOLCHAIN cargo build --target x86_64-unknown-linux-gnu --release
  mv "target/x86_64-unknown-linux-gnu/release/libisar.so" "libisar_linux_x64.so"
else
  echo "Building for Linux arm64 with fixed Rust 1.88.0"
  rustup target add aarch64-unknown-linux-gnu --toolchain $RUST_TOOLCHAIN
  rustup run $RUST_TOOLCHAIN rustc --version
  rustup run $RUST_TOOLCHAIN cargo --version
  rustup run $RUST_TOOLCHAIN cargo build --target aarch64-unknown-linux-gnu --release
  mv "target/aarch64-unknown-linux-gnu/release/libisar.so" "libisar_linux_arm64.so"
fi