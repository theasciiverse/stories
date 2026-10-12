#!/bin/sh
# Builds frob, the FrobTADS interpreter for TADS 2 and TADS 3 stories:
# FrobTADS 2.0 from upstream's own repository at a pinned commit, plus the
# two fixes listed in theasciiverse/frobtads PATCHES.md (carried here as
# diffs, so this script needs nothing but itself). Curses interface; no
# TADS networking (so no libcurl) and no compilers.
#
# Linux: run inside alpine:3.22 for a fully static binary with ncurses
# linked in. macOS: run on the runner with CC_ARCH set to x86_64 or arm64;
# it links only the system's own ncurses and fails if otool shows any other
# library.
#   docker run --rm -v "$PWD":/src -w /src alpine:3.22 sh build-frobtads.sh
#
# Leaves build/frob, the licences (build/COPYING.frobtads, build/LICENSE.TADS2,
# build/LICENSE.TADS3) and build/NOTICE.frobtads (who made this build and where its
# source is; the TADS licence asks ports to carry contact details).
set -eu
FROBTADS_TAG=v2.0
FROBTADS_COMMIT=934b0e4900d9a3a1ab291aa711919f209276c421

if [ -f /etc/alpine-release ]; then
  apk add --no-cache build-base cmake ncurses-dev ncurses-static git >/dev/null
fi
rm -rf build/frobtads-src build/obj build/frob && mkdir -p build
src=$PWD/build/frobtads-src
git clone -q --branch "$FROBTADS_TAG" https://github.com/realnc/frobtads.git "$src"
[ "$(git -C "$src" rev-parse HEAD)" = "$FROBTADS_COMMIT" ] \
  || { echo "frobtads $FROBTADS_TAG is not $FROBTADS_COMMIT" >&2; exit 1; }
# 1. Build without libcurl when networking is off
git -C "$src" apply <<'EOF'
diff --git a/tads3/unix/osnetunix.h b/tads3/unix/osnetunix.h
index 2abfca1..3fafb0c 100644
--- a/tads3/unix/osnetunix.h
+++ b/tads3/unix/osnetunix.h
@@ -43,9 +43,6 @@ Modified
 /* infinite timeout value */
 #define OS_FOREVER  ((ulong)-1)

-/* libcurl headers */
-#include <curl/curl.h>
-
 /* OS X spinlocks */
 #ifdef __APPLE__
 #include <libkern/OSAtomic.h>
EOF
# 2. Keep TADS 3 files in the current directory with --no-chdir
git -C "$src" apply <<'EOF'
diff --git a/src/frobtadsapp.cc b/src/frobtadsapp.cc
index 34b59e0..f5030fa 100644
--- a/src/frobtadsapp.cc
+++ b/src/frobtadsapp.cc
@@ -127,6 +127,14 @@ FrobTadsApplication::fRunTads3( char* filename, int argc, const char* const* arg
     params.saved_state = savedState;
     params.netconfig = netconfig;

+    // The T3VM resolves file names (saved games included) against the
+    // game's directory unless told otherwise, so --no-chdir alone would
+    // still save next to the game. Use the current directory instead, for
+    // file names and the file safety sandbox alike.
+    if (not this->options.changeDir) {
+        params.file_dir = ".";
+    }
+
     // Invoke the VM to run the program.
     int vmRet = vm_run_image(&params);

EOF
obj=$PWD/build/obj
set -- -DCMAKE_BUILD_TYPE=Release -DENABLE_TADSNET=OFF \
  -DENABLE_T2_COMPILER=OFF -DENABLE_T3_COMPILER=OFF
if [ -f /etc/alpine-release ]; then
  # only static libraries, so ncurses (and its terminfo reader) is linked in
  cmake -S "$src" -B "$obj" "$@" -DCMAKE_FIND_LIBRARY_SUFFIXES=.a \
    -DCMAKE_EXE_LINKER_FLAGS=-static >/dev/null
  cmake --build "$obj" --target frob -j "$(nproc)"
else
  # the SDK's ncurses, never Homebrew's (pkg-config and Homebrew's prefixes
  # are kept out of the search)
  sdk=$(xcrun --show-sdk-path)
  PKG_CONFIG_LIBDIR=/nonexistent PKG_CONFIG_PATH= \
  cmake -S "$src" -B "$obj" "$@" -DCMAKE_OSX_ARCHITECTURES="$CC_ARCH" \
    -DCMAKE_IGNORE_PREFIX_PATH="/opt/homebrew;/usr/local" \
    -DCURSES_INCLUDE_PATH="$sdk/usr/include" \
    -DCURSES_LIBRARY="$sdk/usr/lib/libncurses.tbd" >/dev/null
  cmake --build "$obj" --target frob -j "$(sysctl -n hw.ncpu)"
  otool -L "$obj/frob"
  if otool -L "$obj/frob" | tail -n +2 | grep -v -E "^\s*/(usr/lib|System/Library)/"; then
    echo "frob links a library outside the system" >&2; exit 1
  fi
  lipo -archs "$obj/frob" | grep -qx "$CC_ARCH" \
    || { echo "frob is not built for $CC_ARCH" >&2; exit 1; }
fi
strip "$obj/frob"
cp "$obj/frob" build/frob
cp "$src/doc/COPYING" build/COPYING.frobtads
cp "$src/tads2/LICENSE.TXT" build/LICENSE.TADS2
cp "$src/tads3/LICENSE.TXT" build/LICENSE.TADS3
cat > build/NOTICE.frobtads <<'EOF'
frob, the FrobTADS 2.0 interpreter for TADS 2 and TADS 3 stories.

FrobTADS: Nikos Chantziaras, https://github.com/realnc/frobtads
TADS: Michael J. Roberts, https://www.tads.org
Free software under the TADS 2 and TADS 3 Freeware Source Code Licenses
(LICENSE.TADS2, LICENSE.TADS3, COPYING): it may be copied and given away,
never sold or bundled with anything that is sold.

This build: Asciiverse, for Unix terminals (static Linux, macOS), with
two small fixes over upstream's 2.0. Complete source, the changes and how
it is built: https://github.com/theasciiverse/frobtads (PATCHES.md).
Questions about this build: packages@asciiverse.sh or an issue there.
EOF
ls -l build/frob
