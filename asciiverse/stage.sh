#!/bin/sh
# Lays out one story's av archive in stage/<story>: the start script named
# after the story at the top, the interpreter it needs in lib/ with its
# licence, and everything in the story's folder (the story file, LICENSE,
# README.md and, where the licence asks for it, the source).
#   sh asciiverse/stage.sh lost-pig   (after building the interpreter)
set -eu
story=$1
out=stage/$story
rm -rf "$out" && mkdir -p "$out/lib"
cp asciiverse/play "$out/$story"
chmod 755 "$out/$story"
cp -R "$story"/. "$out/"
case "$(ls "$story")" in
  *.ulx*|*.gblorb*) cp build/glulxe "$out/lib/glulxe"; cp build/LICENSE.glulxe build/LICENSE-glkterm "$out/lib/" ;;
  *.t3*|*.gam*)     cp build/frob "$out/lib/frob"; cp build/COPYING.frobtads build/LICENSE.TADS2 build/LICENSE.TADS3 build/NOTICE.frobtads "$out/lib/" ;;
  *.dat*)           cp build/scottfree "$out/lib/scottfree"; cp build/COPYING.scottfree "$out/lib/" ;;
  *)                cp build/frotz "$out/lib/frotz"; cp build/COPYING "$out/lib/COPYING.frotz" ;;
esac
