# scratch: config file support

Add config file support to `bin/scratch` so settings (primarily `SCRATCH_DIR`)
can persist across invocations and reboots, following the config pattern from
`snippets/template_functional-script.sh`.

* **Status**: Accepted
* **Context**: `bin/scratch`, personal scripts repo, 2026-07-03. Primary use
  case: a consistent scratch dir that survives reboots, plus aliases like
  `alias notes="scratch -d ~/Documents/notes"` or
  `alias notes="scratch --config-file ~/.notes.conf"`.
* **Rationale**: "sometimes i want a consistent dir that survives reboots, and
  it'd be lovely to be able to do something like
  `alias notes="scratch --some-param ~/Documents/notes/"`". Config style chosen:
  "the config setup from ~/code/sh/snippets/template_functional-script.sh".
  Scope: config only — style modernization deferred to a later pass. The known
  bug fixes (duplicate `-e`/`-u` flags, `--no-exec` stray brace, `chmod 600` on
  a directory, duplicated mkdir block) were initially deferred, then fixed the
  same day at the user's request: `--exec` rebound from `-e` to `-x` (`-e`
  stays `--editor`), unimplemented `-u / --user-dirs` removed from help (`-u`
  stays `--unique`; per-user dirs are already the default behavior), stray
  brace removed, and the duplicated mkdir blocks collapsed into one with
  `chmod 700` on the directory.

## Design

**Loading** (top of `parse-args`, before defaults): pre-scan args for
`--config-file`, defaulting to `~/.$(basename "${0}").conf` (i.e.
`~/.scratch.conf`), then `source` it if it exists — verbatim template pattern.
A `--config-file) shift ;;` no-op case in the main option loop keeps the flag
from being swallowed as a filename.

**Defaults become config-respecting** via `${VAR:-default}`:

```bash
SCRATCH_DIR="${SCRATCH_DIR:-${TMP_DIR}/scratch-$(id -u)}"
SUMMARY_LENGTH="${SUMMARY_LENGTH:-50}"
```

`EDITOR`/`PAGER` already follow this pattern.

**Precedence**: CLI flags > config file > environment > built-in defaults.
Template quirk: the config is sourced over the environment, so config beats
env; a config line written as `SCRATCH_DIR="${SCRATCH_DIR:-...}"` restores
env-wins for that var.

**Documented config vars**: `SCRATCH_DIR`, `EDITOR`, `PAGER`,
`SUMMARY_LENGTH` — listed in `--help` along with the `--config-file` option.
