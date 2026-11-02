# Keep the directory name expected by upstream Rust build scripts.
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE static)
set(VCPKG_CMAKE_SYSTEM_NAME iOS)
set(VCPKG_OSX_SYSROOT iphonesimulator)
set(VCPKG_OSX_DEPLOYMENT_TARGET "$ENV{RUSTDESK_DEPLOYMENT_TARGET}")
set(VCPKG_BUILD_TYPE release)
# Autotools must distinguish this Simulator target from the arm64 macOS host.
set(VCPKG_MAKE_BUILD_TRIPLET "--host=aarch64-apple-ios;--build=aarch64-apple-darwin")
