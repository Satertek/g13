#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# g13 SteamOS support: build step
#
# Compiles g13d with the Homebrew toolchain. Does NOT require root.
# Usage: steamos/build.sh [--clean]
#
# Why the unusual flags?
#   SteamOS ships no /usr/include, so libc headers come from Homebrew's keg-only
#   glibc. Adding them with -I / -isystem / C_INCLUDE_PATH puts them *before*
#   libstdc++'s directories, which breaks the `#include_next <stdlib.h>` chain in
#   <cstdlib> and friends. -idirafter appends them *after* GCC's own system dirs,
#   preserving the search order.
#   Binaries are linked against Homebrew's glibc, so they must also use
#   Homebrew's dynamic loader (--dynamic-linker), otherwise the host ld.so loads
#   a mismatched libc and fails with GLIBC_PRIVATE symbol errors.
# -----------------------------------------------------------------------------
set -euo pipefail

STEAMOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=steamos/common.sh
source "${STEAMOS_DIR}/common.sh"

CLEAN=0
[[ "${1:-}" == "--clean" ]] && CLEAN=1

load_brew_env
ensure_brew_deps
SRC_DIR="$(resolve_source_dir)"
BUILD_DIR="${SRC_DIR}/build"

GLIBC_DIR="${BREW_PREFIX}/opt/glibc"
INCLUDE_FLAGS="-idirafter ${BREW_PREFIX}/include -idirafter ${GLIBC_DIR}/include"
LINKER_FLAGS="-L${BREW_PREFIX}/lib -L${GLIBC_DIR}/lib"
LINKER_FLAGS+=" -Wl,-rpath,${BREW_PREFIX}/lib -Wl,-rpath,${GLIBC_DIR}/lib"
LINKER_FLAGS+=" -Wl,--dynamic-linker=${BREW_PREFIX}/lib/ld.so"

if (( CLEAN )); then
    log "Removing ${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
fi

log "Configuring CMake in ${BUILD_DIR}"
# The project's CMakeLists.txt overwrites CMAKE_CXX_FLAGS, so the include flags
# are also passed through the per-config (Release) flags, which it leaves alone.
cmake -B "${BUILD_DIR}" -S "${SRC_DIR}" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER="${BREW_PREFIX}/bin/gcc" \
    -DCMAKE_CXX_COMPILER="${BREW_PREFIX}/bin/g++" \
    -DCMAKE_C_FLAGS="${INCLUDE_FLAGS}" \
    -DCMAKE_CXX_FLAGS="${INCLUDE_FLAGS}" \
    -DCMAKE_C_FLAGS_RELEASE="-O2 ${INCLUDE_FLAGS}" \
    -DCMAKE_CXX_FLAGS_RELEASE="-O2 ${INCLUDE_FLAGS}" \
    -DCMAKE_EXE_LINKER_FLAGS="${LINKER_FLAGS}"

log "Compiling"
make -C "${BUILD_DIR}" -j"$(nproc)" g13d pbm2lpbm

log "Build complete: ${BUILD_DIR}/g13d"
