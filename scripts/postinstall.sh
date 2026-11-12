#!/bin/bash

# Run patch-package first
npx patch-package --error-on-fail || exit 1

# Clone OpenCL headers if building llama.rn from source
OPENCL_HEADERS_DIR="node_modules/llama.rn/third_party/OpenCL-Headers"
if [ ! -d "$OPENCL_HEADERS_DIR" ]; then
    echo "Cloning OpenCL headers for llama.rn build from source..."
    mkdir -p "node_modules/llama.rn/third_party"
    git clone --depth 1 https://github.com/KhronosGroup/OpenCL-Headers.git "$OPENCL_HEADERS_DIR"
    echo "OpenCL headers cloned successfully."
else
    echo "OpenCL headers already present."
fi

# The Android NDK ships Vulkan's C headers but not Khronos Vulkan-Hpp. The
# llama.cpp Vulkan backend includes <vulkan/vulkan.hpp>, so restore the Khronos
# headers for Android source builds.
VULKAN_HEADERS_VERSION="v1.4.368"
VULKAN_HEADERS_DIR="node_modules/llama.rn/third_party/Vulkan-Headers"
if [ ! -f "$VULKAN_HEADERS_DIR/include/vulkan/vulkan.hpp" ]; then
    echo "Restoring Vulkan-Headers for llama.rn build from source..."
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    git -C "$TEMP_DIR" init --quiet
    git -C "$TEMP_DIR" remote add origin https://github.com/KhronosGroup/Vulkan-Headers.git
    git -C "$TEMP_DIR" sparse-checkout init --cone
    git -C "$TEMP_DIR" sparse-checkout set include
    git -C "$TEMP_DIR" fetch --quiet --depth 1 --filter=blob:none origin "$VULKAN_HEADERS_VERSION"
    git -C "$TEMP_DIR" checkout --quiet FETCH_HEAD
    mkdir -p "$VULKAN_HEADERS_DIR"
    cp -R "$TEMP_DIR/include" "$VULKAN_HEADERS_DIR/"
    test -f "$VULKAN_HEADERS_DIR/include/vulkan/vulkan.hpp"
    rm -rf "$TEMP_DIR"
    trap - EXIT
    echo "Vulkan-Headers restored."
else
    echo "Vulkan-Headers already present."
fi

# SPIRV-Headers are installed on the CI host, but their host include directory
# is not searched by the Android cross-compiler. Keep a local header copy for
# the Vulkan target to consume.
SPIRV_HEADERS_VERSION="v1.202610.0"
SPIRV_HEADERS_DIR="node_modules/llama.rn/third_party/SPIRV-Headers"
if [ ! -f "$SPIRV_HEADERS_DIR/include/spirv/unified1/spirv.hpp" ]; then
    echo "Restoring SPIRV-Headers for llama.rn build from source..."
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    git -C "$TEMP_DIR" init --quiet
    git -C "$TEMP_DIR" remote add origin https://github.com/KhronosGroup/SPIRV-Headers.git
    git -C "$TEMP_DIR" sparse-checkout init --cone
    git -C "$TEMP_DIR" sparse-checkout set include
    git -C "$TEMP_DIR" fetch --quiet --depth 1 --filter=blob:none origin "$SPIRV_HEADERS_VERSION"
    git -C "$TEMP_DIR" checkout --quiet FETCH_HEAD
    mkdir -p "$SPIRV_HEADERS_DIR"
    cp -R "$TEMP_DIR/include" "$SPIRV_HEADERS_DIR/"
    test -f "$SPIRV_HEADERS_DIR/include/spirv/unified1/spirv.hpp"
    rm -rf "$TEMP_DIR"
    trap - EXIT
    echo "SPIRV-Headers restored."
else
    echo "SPIRV-Headers already present."
fi

# llama.rn's npm package explicitly excludes ggml-vulkan even though its Android
# source-build patch enables that backend. Restore the exact llama.cpp tree that
# this llama.rn release vendors so the CMake source and headers stay in sync.
LLAMA_CPP_COMMIT="8642541b255bfb5dc39cd351a178be09013a55d6"
LLAMA_RN_DIR="node_modules/llama.rn"
VULKAN_SOURCE_DIR="$LLAMA_RN_DIR/vendor/llama.cpp/ggml/src/ggml-vulkan"
if [ ! -f "$VULKAN_SOURCE_DIR/CMakeLists.txt" ]; then
    echo "Restoring ggml-vulkan sources for llama.rn..."
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    git -C "$TEMP_DIR" init --quiet
    git -C "$TEMP_DIR" remote add origin https://github.com/ggml-org/llama.cpp.git
    git -C "$TEMP_DIR" sparse-checkout init --cone
    git -C "$TEMP_DIR" sparse-checkout set ggml/src/ggml-vulkan
    git -C "$TEMP_DIR" fetch --quiet --depth 1 --filter=blob:none origin "$LLAMA_CPP_COMMIT"
    git -C "$TEMP_DIR" checkout --quiet FETCH_HEAD
    mkdir -p "$(dirname "$VULKAN_SOURCE_DIR")"
    cp -R "$TEMP_DIR/ggml/src/ggml-vulkan" "$VULKAN_SOURCE_DIR"
    test -f "$VULKAN_SOURCE_DIR/CMakeLists.txt"
    rm -rf "$TEMP_DIR"
    trap - EXIT
    echo "ggml-vulkan sources restored."
else
    echo "ggml-vulkan sources already present."
fi
