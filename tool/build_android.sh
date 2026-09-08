#!/bin/bash

# Set the specific toolchain
RUST_TOOLCHAIN="1.88.0-x86_64-unknown-linux-gnu"

if [[ "$(uname -s)" == "Darwin" ]]; then
    export NDK_HOST_TAG="darwin-x86_64"
elif [[ "$(uname -s)" == "Linux" ]]; then
    export NDK_HOST_TAG="linux-x86_64"
else
    echo "Unsupported OS."
    exit
fi

NDK=${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-"$ANDROID_SDK_ROOT/ndk"}}

# Resolve NDK path if it's not a concrete directory (pick latest installed)
if [ ! -d "$NDK" ]; then
  if [ -d "$ANDROID_SDK_ROOT/ndk" ]; then
    NDK=$(ls -d "$ANDROID_SDK_ROOT/ndk"/* 2>/dev/null | sort -V | tail -n1)
  fi
fi

COMPILER_DIR="$NDK/toolchains/llvm/prebuilt/$NDK_HOST_TAG/bin"
export PATH="$COMPILER_DIR:$PATH"

echo "Using NDK at: $NDK"
echo "Compiler dir: $COMPILER_DIR"

# Only export tool-specific CC/AR if the tools actually exist
maybe_set_tool() {
  var_name=$1
  tool_path=$2
  if [ -x "$tool_path" ]; then
    export "$var_name"="$tool_path"
  fi
}

maybe_set_tool CC_i686_linux_android        "$COMPILER_DIR/i686-linux-android21-clang"
maybe_set_tool AR_i686_linux_android        "$COMPILER_DIR/llvm-ar"
maybe_set_tool CARGO_TARGET_I686_LINUX_ANDROID_LINKER "$COMPILER_DIR/i686-linux-android21-clang"
maybe_set_tool CARGO_TARGET_I686_LINUX_ANDROID_AR     "$COMPILER_DIR/llvm-ar"

maybe_set_tool CC_x86_64_linux_android      "$COMPILER_DIR/x86_64-linux-android21-clang"
maybe_set_tool AR_x86_64_linux_android      "$COMPILER_DIR/llvm-ar"
maybe_set_tool CARGO_TARGET_X86_64_LINUX_ANDROID_LINKER "$COMPILER_DIR/x86_64-linux-android21-clang"
maybe_set_tool CARGO_TARGET_X86_64_LINUX_ANDROID_AR     "$COMPILER_DIR/llvm-ar"

maybe_set_tool CC_armv7_linux_androideabi   "$COMPILER_DIR/armv7a-linux-androideabi21-clang"
maybe_set_tool AR_armv7_linux_androideabi   "$COMPILER_DIR/llvm-ar"
maybe_set_tool CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_LINKER "$COMPILER_DIR/armv7a-linux-androideabi21-clang"
maybe_set_tool CARGO_TARGET_ARMV7_LINUX_ANDROIDEABI_AR     "$COMPILER_DIR/llvm-ar"

maybe_set_tool CC_aarch64_linux_android     "$COMPILER_DIR/aarch64-linux-android21-clang"
maybe_set_tool AR_aarch64_linux_android     "$COMPILER_DIR/llvm-ar"
maybe_set_tool CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER "$COMPILER_DIR/aarch64-linux-android21-clang"
maybe_set_tool CARGO_TARGET_AARCH64_LINUX_ANDROID_AR     "$COMPILER_DIR/llvm-ar"

cd packages/isar_core_ffi

if [ "$1" = "x86" ]; then
  echo "Building for x86 architecture"
  rustc --version
  cargo --version
  rustup target add i686-linux-android --toolchain $RUST_TOOLCHAIN
  rustup run $RUST_TOOLCHAIN cargo build --target i686-linux-android --release
  mv "../../target/i686-linux-android/release/libisar.so" "../../libisar_android_x86.so"
elif [ "$1" = "x64" ]; then
  echo "Building for x64 architecture"
  rustc --version
  cargo --version
  rustup target add x86_64-linux-android --toolchain $RUST_TOOLCHAIN
  rustup run $RUST_TOOLCHAIN cargo build --target x86_64-linux-android --release
  mv "../../target/x86_64-linux-android/release/libisar.so" "../../libisar_android_x64.so"
elif [ "$1" = "armv7" ]; then
  echo "Building for armv7 architecture"
  rustc --version
  cargo --version
  rustup target add armv7-linux-androideabi --toolchain $RUST_TOOLCHAIN
  rustup run $RUST_TOOLCHAIN cargo build --target armv7-linux-androideabi --release
  mv "../../target/armv7-linux-androideabi/release/libisar.so" "../../libisar_android_armv7.so"
else
  echo "Building for arm64 architecture"
  rustc --version
  cargo --version
  rustup target add aarch64-linux-android --toolchain $RUST_TOOLCHAIN
  rustup run $RUST_TOOLCHAIN cargo build --target aarch64-linux-android --release
  mv "../../target/aarch64-linux-android/release/libisar.so" "../../libisar_android_arm64.so"
fi