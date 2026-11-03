#!/bin/sh
# Builds the ScottFree the Scott Adams format stories (.dat) are played
# with: ScottFree 1.14 by the Swansea University Computer Society, as
# updated in 2007 by Sam Trenholme for Desert Adventure (asciiverse/scottfree,
# unchanged from his desert-scott.zip on the IF Archive), plus
# asciiverse/scottfree-fixes.patch. GPL-2.0-or-later.
# Linux: run inside alpine:3.22 for a static binary; macOS: run on the runner
# with CC_ARCH set, linking only the system's ncurses. Leaves build/scottfree.
set -eu
here=$(cd "$(dirname "$0")" && pwd)
if [ -f /etc/alpine-release ]; then
  apk add --no-cache build-base ncurses-dev ncurses-static patch >/dev/null
fi
rm -rf build/scottfree-src build/scottfree && mkdir -p build/scottfree-src
cp "$here"/scottfree/* build/scottfree-src/
(cd build/scottfree-src && sed '/^#/d' "$here/scottfree-fixes.patch" | patch -s -p3)
if [ -f /etc/alpine-release ]; then
  cc -O2 -std=gnu89 -static -o build/scottfree build/scottfree-src/ScottCurses.c -lncursesw
else
  cc -arch "$CC_ARCH" -O2 -std=gnu89 -o build/scottfree build/scottfree-src/ScottCurses.c -lncurses
fi
strip build/scottfree
cp "$here/scottfree/COPYING" build/COPYING.scottfree
