#!/bin/sh
# Builds the glulxe that Glulx stories are played with: Andrew Plotkin's
# glulxe 0.6.1 against his GlkTerm, wide-character edition, both from
# upstream's own repositories at pinned commits, plus the four GlkTerm fixes
# of theasciiverse/glulxe (its PATCHES.md), applied below. Same build as
# that repo's asciiverse/build.sh. Self-contained: copy it anywhere.
# Linux: run inside alpine:3.22 for a fully static binary; macOS: run on
# the runner with CC_ARCH set (x86_64 or arm64), linking only the system's
# ncurses. Leaves build/glulxe, build/LICENSE.glulxe and
# build/LICENSE-glkterm. (Copied from theasciiverse/glulxe, with the
# build folder shared with the other interpreters.)
#   docker run --rm -v "$PWD":/src -w /src alpine:3.22 sh build-glulxe.sh
set -eu
GLULXE_TAG=glulxe-0.6.1
GLULXE_COMMIT=5c4644f4463acc5e63cf4ef778f774c2f72d900d
GLKTERM_COMMIT=32fefd01fb759cd538a91d14c7f9320c1b476669   # branch widechar
if [ -f /etc/alpine-release ]; then
  apk add --no-cache build-base ncurses-dev ncurses-static git >/dev/null
  cc="cc"; os="-DOS_UNIX -DUNIX_RAND_GETRANDOM"; ld="-static"; curses="-lncursesw"
else
  cc="cc -arch $CC_ARCH"; os="-DOS_MAC"; ld=""; curses="-lncurses"
fi
# -fno-strict-aliasing: glulxe's float.c type-puns floats through pointers.
opt="-O2 -fno-strict-aliasing"

rm -rf build/glulxe-src build/glulxe && mkdir -p build
git clone -q --depth 1 --branch "$GLULXE_TAG" https://github.com/erkyrath/glulxe.git build/glulxe-src
[ "$(git -C build/glulxe-src rev-parse HEAD)" = "$GLULXE_COMMIT" ] || { echo "glulxe $GLULXE_TAG is not $GLULXE_COMMIT" >&2; exit 1; }
git init -q build/glulxe-src/glkterm
git -C build/glulxe-src/glkterm fetch -q --depth 1 https://github.com/erkyrath/glkterm.git "$GLKTERM_COMMIT"
git -C build/glulxe-src/glkterm checkout -q FETCH_HEAD
[ "$(git -C build/glulxe-src/glkterm rev-parse HEAD)" = "$GLKTERM_COMMIT" ] || { echo "glkterm is not $GLKTERM_COMMIT" >&2; exit 1; }

# The four GlkTerm fixes of theasciiverse/glulxe, one commit each there
# (PATCHES.md):
# 1. include <curses.h>: Alpine and macOS have no <ncursesw/ncurses.h>.
# 2. look for a typed file name's dot suffix in the string whose length
#    was taken, not past the end of the typed name.
# 3. never page a text window to line -1 (read lines[-1]; glulxe crashed
#    when the terminal was made narrower).
# 4. keep text marked as read when a window is re-wrapped to a new width
#    (the first key typed after a resize was lost).
git -C build/glulxe-src/glkterm apply <<'PATCH'
diff --git a/gtfref.c b/gtfref.c
index 49ea725..56e1e71 100644
--- a/gtfref.c
+++ b/gtfref.c
@@ -348,8 +348,8 @@ frefid_t glk_fileref_create_by_prompt(glui32 usage, glui32 fmode,
     /* If there is no dot-suffix, add a standard one. */
     val = strlen(newbuf);
     gotdot = FALSE;
-    while (val && (buf[val-1] != '/')) {
-        if (buf[val-1] == '.') {
+    while (val && (newbuf[val-1] != '/')) {
+        if (newbuf[val-1] == '.') {
             gotdot = TRUE;
             break;
         }
diff --git a/gtncursesw.c b/gtncursesw.c
index 2509a29..a5c61f4 100644
--- a/gtncursesw.c
+++ b/gtncursesw.c
@@ -92,7 +92,7 @@ int local_mvaddnwstr(int y, int x, const wchar_t *wstr, int n)
 #else /* LOCAL_NCURSESW */
 
 #define _XOPEN_SOURCE_EXTENDED /* ncursesw *wch* and *wstr* functions */
-#include <ncursesw/ncurses.h>
+#include <curses.h>
 
 int local_get_wch (wint_t *ch)
 {
diff --git a/gtw_buf.c b/gtw_buf.c
index c92e649..b6b19fb 100644
--- a/gtw_buf.c
+++ b/gtw_buf.c
@@ -88,6 +88,7 @@ window_textbuffer_t *win_textbuffer_create(window_t *win)
     dwin->scrollline = 0;
     dwin->scrollpos = 0;
     dwin->lastseenline = 0;
+    dwin->seenpos = -1;
     dwin->drawall = TRUE;
     
     dwin->width = -1;
@@ -159,6 +160,19 @@ void win_textbuffer_rearrange(window_t *win, grect_t *box)
     dwin->height = box->bottom - box->top;
     
     if (oldwid != dwin->width) {
+        /* All the text is about to be re-wrapped, and replace_lines() will
+            then count every line as unseen (lastseenline goes back to 0):
+            the window would page from its first line and swallow the next
+            key. Remember how far the player had read, as a character
+            position, for updatetext() to restore after the re-wrap. */
+        if (dwin->seenpos == -1) {
+            if (dwin->lastseenline < dwin->numlines)
+                dwin->seenpos = dwin->lines[dwin->lastseenline].pos;
+            else
+                dwin->seenpos = dwin->numchars;
+            if (dwin->dirtybeg != -1 && dwin->dirtybeg < dwin->seenpos)
+                dwin->seenpos = dwin->dirtybeg;
+        }
         /* Set dirty region to the whole (or visible?), and
             delta should indicate that the whole old region is changed. */
         if (dwin->dirtybeg == -1) {
@@ -573,6 +587,13 @@ static void updatetext(window_textbuffer_t *dwin)
         
         replace_lines(dwin, lnbeg, lnend, numtmplines);
         lndelta = numtmplines - (lnend-lnbeg);
+
+        if (dwin->seenpos != -1) {
+            /* Re-wrapped to a new width; see win_textbuffer_rearrange(). */
+            long lx = find_line_by_pos(dwin, dwin->seenpos);
+            dwin->lastseenline = (lx < 0) ? 0 : lx;
+            dwin->seenpos = -1;
+        }
         
         drawbeg = lnbeg;
         if (lndelta == 0) {
@@ -775,6 +796,7 @@ void win_textbuffer_clear(window_t *win)
     dwin->scrollline = 0;
     dwin->scrollpos = 0;
     dwin->lastseenline = 0;
+    dwin->seenpos = -1;
     dwin->drawall = TRUE;
 }
 
@@ -951,6 +973,8 @@ void win_textbuffer_set_paging(window_t *win, int forcetoend)
         && dwin->lastseenline - 0 < dwin->numlines - dwin->height) {
         /* scroll lastseenline to top, stick there */
         val = dwin->lastseenline - 1;
+        if (val < 0)
+            val = 0;
     }
     else {
         /* scroll to bottom, set lastseenline to end. */
diff --git a/gtw_buf.h b/gtw_buf.h
index 8573475..08b6196 100644
--- a/gtw_buf.h
+++ b/gtw_buf.h
@@ -79,6 +79,8 @@ typedef struct window_textbuffer_struct {
     long scrollline;
     long scrollpos;
     long lastseenline;
+    long seenpos; /* While a re-wrap is pending: the text before this
+        character position had been seen. Otherwise -1. */
     
     /* The following are meaningful only for the current line input request. */
     void *inbuf; /* char* or glui32*, depending on inunicode. */
PATCH

cd build/glulxe-src
make -C glkterm CC="$cc" OPTIONS="$opt" LIBS="$curses"
make CC="$cc" OPTIONS="$opt -Wall -Wno-unused $os $ld" \
  GLKINCLUDEDIR=glkterm GLKLIBDIR=glkterm GLKMAKEFILE=Make.glktermw glulxe
if [ ! -f /etc/alpine-release ]; then
  otool -L glulxe
  if otool -L glulxe | tail -n +2 | grep -v -E "^\s*/(usr/lib|System/Library)/"; then
    echo "glulxe links a library outside the system" >&2; exit 1
  fi
fi
strip glulxe
cp glulxe ../
cp LICENSE ../LICENSE.glulxe
cp glkterm/LICENSE ../LICENSE-glkterm
