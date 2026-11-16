#!/usr/bin/env python3
"""Records asciiverse/<story>.cast for the real-time Z-machine games, which
read single keys against the clock instead of typed commands: the catalog
preview at 100x30 (hub/RECORDING.md), through the same start script av runs
(stage/<story>, see stage.sh), with a throwaway HOME. Each step is a pause
in seconds, then a key. Usage: python3 asciiverse/record-preview-realtime.py zracer-c40"""
import fcntl, json, os, pty, select, shutil, struct, sys, tempfile, termios, time

ESC = "\x1b"

def zracer():
    # the title with its moving block, level 1 (Arena), then three laps:
    # speed up to 40 out of the start, ease off through the hairpins, and
    # out through the pause menu (Esc), Quit, yes
    steps = [(3.5, " "), (2.0, " "), (0.6, " "), (0.6, " "), (0.6, " ")]
    for _ in range(6):
        steps += [(3.5, "b"), (1.5, " ")]
    steps += [(4.0, ESC), (2.0, "q"), (0.6, "y"), (1.5, " ")]
    return steps

def mad_bomber():
    # the title, then a bomb every 0.7 s or so until the plane crashes
    # (bombing stops when the game asks for a high scorer's name; a city
    # levelled only brings the next one); then the name and Q at the title
    steps = [(2.5, " ")]
    for i in range(90):
        steps.append((0.75 if i % 3 else 0.55, " ", "Enter your name"))
    steps += [(1.5, "A"), (0.3, "c"), (0.3, "e"), (0.4, "\r"), (2.5, "q"), (1.5, " ")]
    return steps

GAMES = {"zracer-c40": zracer, "mad-bomber": mad_bomber}

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
story = sys.argv[1]
steps = GAMES[story]()
cast = f"{root}/asciiverse/{story}.cast"
home = tempfile.mkdtemp()
env = dict(os.environ, HOME=home, TERM="xterm-256color", COLORTERM="truecolor", LANG="C.UTF-8")
env.pop("XDG_DATA_HOME", None)

pid, fd = pty.fork()
if pid == 0:
    os.execvpe("asciinema", ["asciinema", "rec", "--overwrite", "-q", "-i", "2",
        "--capture-env", "TERM,COLORTERM,LANG", "-c", f"{root}/stage/{story}/{story}",
        cast], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))

seen = b""

def pump(t):
    global seen
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.03)
        if r:
            try: seen = (seen + os.read(fd, 65536))[-4096:]
            except OSError: return

# a step is (pause, key) or (pause, key, text): with a text, the step
# (pause and key) is skipped once that text has appeared on screen
for step in steps:
    if len(step) > 2 and step[2].encode() in seen:
        continue
    pump(step[0])
    if len(step) > 2 and step[2].encode() in seen:
        continue
    try: os.write(fd, step[1].encode())
    except OSError: break
pump(1.0)
for _ in range(50):
    if os.waitpid(pid, os.WNOHANG)[0]: break
    time.sleep(0.2)
shutil.rmtree(home, ignore_errors=True)

# asciinema writes the command it ran into the cast's header, with a path
# on the recording machine; players never use it, so it is taken out
with open(cast) as f:
    lines = f.read().split("\n")
head = json.loads(lines[0])
head.pop("command", None)
lines[0] = json.dumps(head, separators=(",", ":"))
with open(cast, "w") as f:
    f.write("\n".join(lines))
print(cast, os.path.getsize(cast), "bytes")
