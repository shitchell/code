# parseargs presets: DRY the functional-template boilerplate

Condense the ~60 template-based scripts in `bin/` by moving their copy-pasted
boilerplate (option parsing, help generation, config file loading, color
setup, silent mode) into `lib/parseargs.sh` and friends. Flagship refactor
target: `bin/srt-format` (characterization suite:
`bin/bats/srt-format.bats`, 19 tests).

* **Status**: Accepted
* **Context**: `lib/parseargs.sh`, `lib/colors.sh`, `lib/shell.sh`,
  `lib/exit-codes.sh`, the ~60 `help-full`+`parse-args` template scripts in
  `bin/`, 2026-07-03.
* **Rationale**: "in general, i'd like to see how much i can condense my
  scripts using existing or new lib stuffs." ... "that template, as much as i
  like it, copies a ton of boilerplate that could stand to be removed. DRY
  and all that". Characterization testing first because refactors must keep
  behavior: "mind finding a script ... suited for bats testing so that we can
  ensure any changes we make are 1:1 identical?", later relaxed to "behavior
  should remain the same. i'm fine if some slight changes happen around the
  help output or args/params so long as they're minimal".

## Decisions

### Generated help via parseargs (accepted)

Scripts stop hand-writing `help-full`; `parseargs-show-help` generates
usage/description/options/positionals/epilog. Rationale: "i'd prefer if
parseargs generated help text automatically with optional pre/post-text ...
i understand that this might change some of the help output for some of the
commands ... i find this acceptable for standardization and consistency -- a
benefit even".

### Explicit presets: `parseargs-include colors config` (accepted)

Presets register standard options + behavior. Import-driven activation
(auto-enabling when colors.sh is loaded) was considered and **rejected**:
`debug.sh`, `echo.sh`, and `net.sh` all `include-source colors.sh`
transitively, so nearly every script would grow a `-c/--color` flag
involuntarily; imports are implementation details, CLI flags are interface.
User: "i still favor explicit over implicit"; on the import-driven variant:
"what are your thoughts? too implicit?" -> agreed too implicit.

- `colors` preset: registers `-c/--color <auto|always|never>` (store:
  `COLOR`); at parse time resolves `DO_COLOR` from the mode + `[[ -t 1 ]]`
  and calls `setup-colors`/`unset-colors`. The fd check works from inside the
  sourced lib because sourcing shares the script's process/fds -- verified
  by experiment; caveats: must not run inside `$( )` and must run before any
  `silence-output` exec redirection.
- `config` preset: registers `--config-file <file>` (default
  `~/.$(prog).conf`); at parse time pre-scans argv for `--config-file`,
  sources the file, then applies option defaults as
  CLI > config/env var named by the option's store > `--default`.
  Config vars are plain bash (`FORMAT=...`), matching the sourced-conf
  standard from `snippets/template_functional-script.sh`. Env consultation
  happens ONLY when the config preset is active (implicit env leakage
  otherwise).

### Standard-but-unprotected `-s`/`-v`; protected `-h` (accepted)

`-s/--silent` and `-v/--verbose` (counted) are built-ins present by default.
"if the user sets their own -s or -v option, then the user defined
short-option wins. -h/--help will be the only fully protected,
non-overwritable parseargs option." Collision rule: a user option claiming
EITHER name of a built-in drops that built-in entirely (no half-orphaned
`--silent` with a stolen short). Built-ins register lazily at parse/help
time so user definitions naturally win and `parseargs-init` state stays
empty. `-s` triggers `silence-output` at the end of parsing; `-v` counts
into `VERBOSE`.

### `parseargs-parse-or-exit "${@}"`

Wrapper: exits 0 on `E_HELP_DISPLAYED`, exits with the granular `E_*` code
on parse errors, applies built-in silent/color/config behavior. Granular
exit codes (1 -> 15/16/...) accepted as part of standardization.

### shell.sh gains public `silence-output` / `restore-output`

Today these exist only as template copy-paste and `__restore_output`
internals. Public functions + an EXIT-trap restore.

### exit-codes.sh reservation scheme (accepted)

Codes are 8-bit (0-255): "i didn't realize exit codes are only 8-bit and cap
out at 255 :p ... i can still put *most* codes in there and perhaps reserve
some subset for script-specific codes?" The range organization already
exists (0-3 general, 10-18 argparse, 20-39 types, 46-52 fs, 60s git, 80s
commands, 90-92 flow control); add a documented reservation scheme:

- 0-99: standard lib codes
- 100-125: reserved for script-specific codes
- 126-165, 255: off-limits (shell-reserved: 126 non-executable, 127 not
  found, 128+N signals, 255 wrap)
- 166-254: unassigned spillover

### Misc parseargs fixes

- `parseargs-show-help` marks positionals with `*` even when
  `required=false` (`${required:+*}` is true for the string "false").
- Help lists options in hash order; switch to declaration order.
- `include-source` takes ONE lib per call (`include-source 'lib' [args...]`);
  the pattern uses one line per lib.

## Process

TDD (red/green) into `lib/tests/parseargs-presets.bats` +
`lib/tests/shell-output.bats`; existing `lib/tests/parseargs.bats` must stay
green. Then refactor `bin/srt-format` against its characterization suite,
updating the accepted-delta tests (exit codes, error wording, KNOWN BUG
fixes) deliberately.
