#!/usr/bin/env bash
# quiet-run.sh - run a noisy install/build/test command and print only the result.
#
# Usage:
#   quiet-run.sh '<command string>'
#   quiet-run.sh npm install
#
# Prints: PASS/FAIL, exit code, duration, error lines (on failure),
# the last lines of output (on failure), the detected package version,
# and the path of the full log. Exits with the command's own exit code.
#
# Tunables (environment variables):
#   QUIET_RUN_MAX_ERRORS  max error lines to show   (default 30)
#   QUIET_RUN_TAIL        tail lines on failure     (default 15)
#   QUIET_RUN_LOG_DIR     where full logs are kept  (default ${TMPDIR:-/tmp}/quiet-run)

set -u

if [ $# -eq 0 ]; then
  echo "usage: $0 '<command>'" >&2
  exit 2
fi

# One argument = a full shell command string; several = argv to join.
if [ $# -eq 1 ]; then cmd=$1; else cmd="$*"; fi

max_errors=${QUIET_RUN_MAX_ERRORS:-30}
tail_n=${QUIET_RUN_TAIL:-15}
log_dir=${QUIET_RUN_LOG_DIR:-${TMPDIR:-/tmp}/quiet-run}
mkdir -p "$log_dir"
log="$log_dir/$(date +%Y%m%d-%H%M%S)-$$.log"

start=$(date +%s)
bash -c "$cmd" >"$log" 2>&1
status=$?
secs=$(( $(date +%s) - start ))
lines=$(wc -l <"$log" | tr -d ' ')

# Strip ANSI colour codes for matching.
clean() { sed -E 's/\x1B\[[0-9;?]*[A-Za-z]//g' "$log"; }

# Error-looking lines. Excludes "0 errors" / "no errors" summaries.
errors() {
  clean | grep -E -i \
    '(^|[^a-z])(error|err!|fatal|failed|failure|traceback|exception|panic:|cannot find|not found|undefined reference|segmentation fault)([^a-z]|$)' \
    | grep -v -E -i '(^|[^0-9])0 (errors?|failures?|failed)|no errors|without errors|error(s)?: 0' \
    | awk '!seen[$0]++'
}

# Version: first match wins, scanning known tool output, then project files.
detect_version() {
  local out v
  out=$(clean)
  v=$(printf '%s\n' "$out" | grep -oE 'Successfully installed .*' | tail -1)              # pip
  [ -n "$v" ] && { echo "$v"; return; }
  v=$(printf '%s\n' "$out" | grep -oE 'Successfully built [^ ]+' | tail -1)               # pip / docker
  [ -n "$v" ] && { echo "$v"; return; }
  v=$(printf '%s\n' "$out" | grep -oE '^(\+ |npm notice (package|name): *)?[@a-z0-9._/-]+@[0-9]+\.[0-9]+\.[0-9]+[^ ]*' | tail -1)  # npm/yarn/pnpm
  [ -n "$v" ] && { echo "$v"; return; }
  v=$(printf '%s\n' "$out" | grep -oE '(Compiling|Finished|Packaging|Installed package) [^ ]+ v[0-9][^ ]*' | tail -1)  # cargo
  [ -n "$v" ] && { echo "$v"; return; }
  if [ -f package.json ] && command -v jq >/dev/null; then
    v=$(jq -r 'select(.version) | "\(.name // "package")@\(.version)"' package.json 2>/dev/null)
    [ -n "$v" ] && { echo "$v (package.json)"; return; }
  fi
  for f in pyproject.toml Cargo.toml; do
    if [ -f "$f" ]; then
      v=$(grep -m1 -E '^version *= *"' "$f" | sed -E 's/.*"(.*)".*/\1/')
      [ -n "$v" ] && { echo "$v ($f)"; return; }
    fi
  done
  echo "UNKNOWN"
}

if [ "$status" -eq 0 ]; then
  echo "PASS  exit=0  ${secs}s  ${lines} lines of output suppressed"
  echo "cmd:     $cmd"
  echo "version: $(detect_version)"
  n=$(errors | wc -l | tr -d ' ')
  [ "$n" -gt 0 ] && echo "note:    $n error-like lines in log (command still succeeded)"
else
  echo "FAIL  exit=$status  ${secs}s  ${lines} lines of output"
  echo "cmd:     $cmd"
  echo "version: $(detect_version)"
  errs=$(errors)
  if [ -n "$errs" ]; then
    total=$(printf '%s\n' "$errs" | wc -l | tr -d ' ')
    echo "--- errors (${total} unique, showing up to ${max_errors}) ---"
    printf '%s\n' "$errs" | head -n "$max_errors" | cut -c1-300
  fi
  echo "--- last ${tail_n} lines ---"
  clean | tail -n "$tail_n" | cut -c1-300
fi
echo "full log: $log"
exit "$status"
