#!/usr/bin/env python3
"""Records asciiverse/<story>.cast, a story's catalog preview, at 100x30
(hub/RECORDING.md): the opening, then a few moves typed at a human pace,
through the same start script av runs (stage/<story>, see stage.sh), with a
throwaway HOME. Usage: python3 asciiverse/record-preview.py lost-pig"""
import os, pty, shutil, struct, fcntl, select, sys, tempfile, termios, time

# Per story: keys pressed to get past title pages and menus, then the moves.
STORIES = {
    "tristam-island": ([], ["northeast", "examine boulder", "north", "look", "south", "southwest"]),
    "all-things-devours": ([], ["examine desk", "push first", "up", "look", "down", "south"]),
    "fate": ([" "], ["examine crystal ball", "inventory", "open pouch", "look in pouch", "examine tapestries", "south"]),
    "changes": ([" "], ["look", "stand up", "look", "inventory", "north", "look"]),
    "spider-and-web": ([], ["examine door", "examine plate", "touch plate", "south", "look", "north"]),
    "so-far": ([], ["look at stage", "listen", "stand up", "west", "look", "north"]),
    "curses": ([" "], ["inventory", "read paper", "turn on torch", "north", "look", "south"]),
    "shade": ([], ["examine hyacinth", "stand up", "look in mirror", "examine desk", "examine stereo", "look"]),
    "lost-pig": ([], ["listen", "east", "look", "west", "examine wall", "inventory"]),
    "savoir-faire": ([" ", " "], ["inventory", "examine sundial", "look in well", "examine roses", "southeast", "look"]),
    "book-and-volume": (["B", " "], ["turn on light", "look", "read pager", "examine stars", "inventory", "out"]),
    "risorgimento-represso": ([], ["examine notebook", "examine professor", "stand up", "sit down", "examine students", "look"]),
    "hoosegow": ([" ", " "], ["examine bars", "inventory", "talk to muddy", "examine stool", "examine window", "read paper"]),
    "blue-chairs": ([], ["yes", "examine chairs", "look", "examine bulb", "inventory", "down"]),
    # Glulx: GlkTerm pages long openings, and the first key only turns the page
    "counterfeit-monkey": ([], ["yes", "no", "Andra", "look", "x r-remover", "north", "east"]),
    "kerkerkruip": (["n", " ", " ", " "], ["take blindfold", "inventory", "examine buckler", "look", "north"]),
    "rovers-day-out": ([" ", " "], ["look", "inventory", "wake up", "look", "examine arm", "inventory"]),
    "andromeda-apocalypse": ([" "], ["look", "examine uncle oren", "talk to oren", "examine ocean", "inventory", "south"]),
    "doctor-m": ([" "], ["examine signpost", "read signpost", "inventory", "north", "look"]),
    # Scott Adams format (ScottFree): two-word commands, the room drawn above
    "desert-adventure": ([], ["look", "go north", "get flower", "enter pool", "get tube", "inventory", "go up"]),
}
root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
story = sys.argv[1]
keys, moves = STORIES[story]
home = tempfile.mkdtemp()
env = dict(os.environ, HOME=home, TERM="xterm-256color", COLORTERM="truecolor", LANG="C.UTF-8")

pid, fd = pty.fork()
if pid == 0:
    os.execvpe("asciinema", ["asciinema", "rec", "--overwrite", "-q", "-i", "2",
        "--capture-env", "TERM,COLORTERM,LANG", "-c", f"{root}/stage/{story}/{story}",
        f"{root}/asciiverse/{story}.cast"], env)
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 30, 100, 0, 0))

def pump(t):
    end = time.time() + t
    while time.time() < end:
        r, _, _ = select.select([fd], [], [], 0.03)
        if r:
            try: os.read(fd, 65536)
            except OSError: return

def type_line(line, after=2.4):
    for c in line:
        os.write(fd, c.encode()); pump(0.09)
    os.write(fd, b"\r"); pump(after)

pump(3.5)
for k in keys:
    os.write(fd, k.encode()); pump(2.5)
for move in moves:
    type_line(move)
if any(n.endswith(".dat") for n in os.listdir(f"{root}/{story}")):
    type_line("quit game", 1.5)            # ScottFree: QUIT alone only explains this
else:
    type_line("quit", 1.0)
    type_line("y", 1.0)
os.write(fd, b" "); pump(0.5)              # Frotz: "[Hit any key to exit.]"
for _ in range(50):
    if os.waitpid(pid, os.WNOHANG)[0]: break
    time.sleep(0.2)
shutil.rmtree(home, ignore_errors=True)

# asciinema writes the command it ran into the cast's header, with a path
# on the recording machine; players never use it, so it is taken out
cast = f"{root}/asciiverse/{story}.cast"
with open(cast) as f:
    lines = f.read().split("\n")
import json
head = json.loads(lines[0])
head.pop("command", None)
lines[0] = json.dumps(head, separators=(",", ":"))
with open(cast, "w") as f:
    f.write("\n".join(lines))
