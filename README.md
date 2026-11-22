# claude-plugins

A Claude Code plugin marketplace.

## Install

In Claude Code, run once per machine:

```
/plugin marketplace add pcbender/claude-plugins
/plugin install quiet-output@pcbender-plugins
```

Pick **user scope** when asked, so it applies in every project. Restart the
session (or run `/hooks` to check) for the hook to load.

## Updates

In Claude Code, run once per machine:

Run these commands in your shell (omitting the marketplace name updates all registered marketplaces):

```
claude plugin marketplace update pcbender/claude-plugins
claude plugin update quiet-output@pcbender-plugins
```

### Inside an Active Claude Code Session

You can also do this interactively without leaving Claude Code:

- Via Slash Commands:
  1. Run /plugin marketplace update pcbender/claude-plugins
  2. Run /plugin → go to the Installed tab → press Enter on your plugin and select Update now.   
  3. Run /reload-plugins when prompted.   
- Enable Auto-Updates (Recommended for Custom Repos): Custom GitHub/repo marketplaces have auto-update turned off by default. To have Claude Code pull updates automatically at session start:   
  1. Run /plugin and switch to the Marketplaces tab.
  2. Select the pcbender/claude-plugins repository marketplace and toggle Auto-update on.

## Plugins

### quiet-output

Long install/build/test output gets added to Claude's context in full and is
re-sent on every later turn. This plugin adds a `PreToolUse` hook that sends
plain install/build/test commands through `quiet-run.sh`. The wrapper saves
the full output to a log file and prints only:

```
FAIL  exit=3  12s  303 lines of output
cmd:     npm run build
version: my-app@1.4.0 (package.json)
--- errors (2 unique, showing up to 30) ---
src/a.ts(3,5): error TS2304: Cannot find name 'foo'
Build failed
--- last 15 lines ---
...
full log: /tmp/quiet-run/20261119-100605-331.log
```

The command's real exit code is kept.

**Commands that get wrapped** (only when written plainly, with no pipes, `;`,
`&&`, redirects or `$`): npm, yarn, pnpm, pip, `python -m pip`, uv, poetry,
cargo, go, make, `cmake --build`, mvn, gradle, `./gradlew`, pytest,
`docker build`, tsc, `next build`, `vite build`.

**Bypass:** set `CLAUDE_QUIET_OFF=1`, or prefix the command with `env `.

**Tunables:** `QUIET_RUN_MAX_ERRORS` (default 30), `QUIET_RUN_TAIL`
(default 15), `QUIET_RUN_LOG_DIR` (default `${TMPDIR:-/tmp}/quiet-run`).

**Requires:** `bash` and `jq`. Without jq the hook prints a warning and lets commands run unfiltered.

**Limits:** errors are found by keyword, so a failure message without words
like "error" or "failed" only shows in the last lines. Version detection is
pattern-based and prints `UNKNOWN` when nothing matches.

Based on the `filter-test-output.sh` example in the Claude Code docs:
https://code.claude.com/docs/en/costs#offload-processing-to-hooks-and-skills
