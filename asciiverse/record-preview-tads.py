#!/usr/bin/env python3
"""Records asciiverse/i-am-prey.cast at 100x30: I Am Prey's opening at a
human pace, through the same start script av runs (stage/i-am-prey, see
stage.sh), with a throwaway HOME. FrobTADS pages long text with [More], so
this watches the screen through pyte (pip install pyte), types only at a
prompt, and pages at reading pace. From theasciiverse/frobtads's recorder.
Usage: python3 asciiverse/record-preview-tads.py"""
import os, pty, shutil, struct, fcntl, select, sys, tempfile, termios, time
import pyte

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
story = "i-am-prey"
work = tempfile.mkdtemp()
env = dict(os.environ, HOME=work, TERM="xterm-256color", COLORTERM="truecolor", LANG="C.UTF-8")
pid, fd = pty.fork()
if pid == 0:
    os.chdir(work)
    fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
    os.execvpe("asciinema", ["asciinema", "rec", "--overwrite", "-q", "-i", "2",
        "--capture-env", "TERM,COLORTERM,LANG",
        "-c", f"{root}/stage/{story}/{story}", f"{root}/asciiverse/{story}.cast"], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))
screen = pyte.Screen(100, 30)
stream = pyte.ByteStream(screen)

def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.03)
        if r:
            try:
                stream.feed(os.read(fd, 65536))
            except OSError:
                return

def cur():
    """the bottom row, where frob shows [More] and the prompt"""
    return screen.display[-1]

def more():
    return any("[More]" in row for row in screen.display)

def settle(read=3.2):
    """Page through [More] until a prompt shows."""
    for _ in range(40):
        pump(0.6)
        if more():
            pump(read)
            os.write(fd, b" ")
        elif cur().rstrip() in (">", "Type in your choice here:"):
            pump(0.8)
            return

def typ(s, read=3.4, wait=True):
    if wait:
        settle()
    for c in s:
        os.write(fd, c.encode()); pump(0.11)
    pump(0.3); os.write(fd, b"\r"); pump(read)

pump(2.5)
typ("n", 1.0, False)                      # not using a screen reader
for _ in range(20):                 # warnings and notes, up to the menu
    pump(0.6)
    if not more():
        break
    pump(2.2); os.write(fd, b" ")
typ("4", 1.0)                       # medium mode, then the prologue
for move in ["take uniform", "open door", "east"]:
    typ(move)
typ("quit", 1.2)
typ("y", 1.8)
os.write(fd, b" "); pump(0.5)       # [Hit any key to exit.]
for _ in range(50):
    if os.waitpid(pid, os.WNOHANG)[0]:
        break
    time.sleep(0.2)
else:
    print("frob did not exit; last screen:", file=sys.stderr)
    for l in screen.display:
        print("|" + l.rstrip(), file=sys.stderr)
    os.kill(pid, 15)
shutil.rmtree(work, ignore_errors=True)
