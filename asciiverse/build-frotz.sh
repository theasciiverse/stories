#!/bin/sh
# Builds the Frotz the stories are played with: Frotz 2.55 from upstream's
# own repository at a pinned commit, curses interface, no sound, plus
# frotz-blorb-name.patch. Same build as theasciiverse/frotz
# (asciiverse/build.sh there) and theasciiverse/zork. Linux: run inside alpine:3.22 for a
# static binary; macOS: run on the runner with CC_ARCH set, linking only the
# system's ncurses. Leaves build/frotz.
set -eu
FROTZ_TAG=2.55
FROTZ_COMMIT=acf205585a9472d27c07c0fe62da4b8bc89d1ec7
here=$(cd "$(dirname "$0")" && pwd)
if [ -f /etc/alpine-release ]; then
  apk add --no-cache build-base ncurses-dev ncurses-static pkgconf git >/dev/null
fi
rm -rf build/frotz-src build/frotz && mkdir -p build
git clone -q --depth 1 --branch "$FROTZ_TAG" https://gitlab.com/DavidGriffith/frotz.git build/frotz-src
[ "$(git -C build/frotz-src rev-parse HEAD)" = "$FROTZ_COMMIT" ] || { echo "frotz $FROTZ_TAG is not $FROTZ_COMMIT" >&2; exit 1; }
cd build/frotz-src
# theasciiverse/frotz's one code fix: a heap overread when Frotz guesses the
# Blorb file name, which crashed the static build under long install paths
git apply "$here/frotz-blorb-name.patch"
if [ -f /etc/alpine-release ]; then
  make SOUND_TYPE=none LDFLAGS=-static frotz
else
  make SOUND_TYPE=none CC="cc -arch $CC_ARCH" HOMEBREW_PREFIX=/nonexistent \
    CURSES_CONFIG="$here/macos-curses-config" frotz
  if otool -L frotz | tail -n +2 | grep -v -E "^\s*/(usr/lib|System/Library)/"; then
    echo "frotz links a library outside the system" >&2; exit 1
  fi
fi
strip frotz
cp frotz COPYING ../
