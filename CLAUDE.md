# Stories (Asciiverse packaging)

Text adventures for the Asciiverse Text adventures category, one folder
per story, each story file unchanged and packaged with its interpreter.
Catalog ids are the folder names (kind `adventure`); the manifests are in
hub/catalog/<id>.toml and .md. Zork I to III live in their own repo,
theasciiverse/zork.

- No code of ours in the stories. Provenance and checksums are in each
  folder's README.md, the exact licence wording and its source in LICENSE;
  never replace a story file without updating both. Fate's GPL needs its
  source, so Fate-source.zip ships with it.
- Each av archive: `<story>` (the start script, asciiverse/play, which picks
  the interpreter by the story file's extension), `lib/<interpreter>`, the
  story folder's files. Saves go to ~/.local/share/<story>.
- Interpreters: asciiverse/build-*.sh, each self-contained and pinned.
  Frotz carries asciiverse/frotz-blorb-name.patch (a heap overread that
  crashed the static build under long install paths).
- No sex content in the catalog (asciiverse/CLAUDE.md); check new stories.
- Release: tag `v1-av.<n>` and push it.
- Previews: build the interpreters, `sh asciiverse/stage.sh <story>`, then
  `python3 asciiverse/record-preview.py <story>` (moves listed in it); I Am
  Prey pages with [More], so it has its own, asciiverse/record-preview-tads.py.
- Held back, not in the repo: Blue Lacuna (its opening asks "make art, or
  make love?" in bed; the no-sex rule, David to decide).
