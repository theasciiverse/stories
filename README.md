# Stories

Text adventures for the [Asciiverse](https://asciiverse.sh) catalog, each
story file unchanged and packaged with the interpreter that plays it, so
`av install <story>` gives a game that just runs.

Every story has its own folder: the story file, `LICENSE` (the exact terms
and where they were found), `README.md` (author, download source, size and
sha256) and, where the licence asks for it, the source.

| Story | Author | Year | Licence |
|---|---|---|---|
| Tristam Island | Hugo Labrande | 2020 | CC0-1.0 |
| All Things Devours | Toby Ord | 2004 | Public domain |
| Fate | Victor Gijsbers | 2007 | GPL-2.0-or-later |
| Changes | David Given | 2012 | CC BY-ND |
| Spider and Web | Andrew Plotkin | 1998 | Free to distribute (author's terms) |
| So Far | Andrew Plotkin | 1996 | Free to distribute (author's terms) |
| Curses | Graham Nelson | 1993 | Free, non-commercial, unmodified (author's terms) |
| Shade | Andrew Plotkin | 2000 | Free, not sold (author's terms) |
| Lost Pig | Admiral Jota | 2007 | CC BY-NC-ND 3.0 |
| Savoir-Faire | Emily Short | 2002 | CC BY-NC-ND 1.0 |
| Book and Volume | Nick Montfort | 2005 | CC BY-NC-SA 2.5 |
| Risorgimento Represso | Michael J. Coyne | 2003 | CC BY-NC-ND 1.0 |
| Hoosegow | Ben Collins-Sussman and Jack Welch | 2010 | CC BY-NC-SA 3.0 |
| Blue Chairs | Chris Klimas | 2004 | CC BY-NC-SA 3.0 |

Several licences allow only non-commercial distribution. Asciiverse gives
these away free; nothing here is sold.

## Interpreters

- Frotz 2.55 (GPL-2.0-or-later) for Z-machine stories, built by
  `asciiverse/build-frotz.sh` from upstream's tag plus one fix
  (`asciiverse/frotz-blorb-name.patch`, also in theasciiverse/frotz).

## Building

    docker run --rm -v "$PWD":/src -w /src alpine:3.22 sh asciiverse/build-frotz.sh
    sh asciiverse/stage.sh lost-pig     # stage/lost-pig is the av archive
    stage/lost-pig/lost-pig             # play it
