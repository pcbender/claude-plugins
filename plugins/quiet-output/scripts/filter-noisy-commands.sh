#!/usr/bin/env bash
# PreToolUse hook (matcher: Bash). Rewrites plain install/build/test commands
# to run through quiet-run.sh, so only the result lands in Claude's context.
#
# Based on the filter-test-output.sh example at
# https://code.claude.com/docs/en/costs#offload-processing-to-hooks-and-skills
# with two changes: it keeps the command's real exit code (the docs example
# pipes to tail, which hides failures), and it extracts errors + version
# instead of keeping the last 100 lines.
#
# Bypass: set CLAUDE_QUIET_OFF=1 in the environment, or write the command
# in a form the pattern does not match (e.g. prefix it with "env ").

input=$(cat)
[ "${CLAUDE_QUIET_OFF:-0}" = "1" ] && { echo '{}'; exit 0; }

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[ -z "$cmd" ] && { echo '{}'; exit 0; }

# Only plain commands: no pipes, redirects, chaining, subshells or variables,
# so wrapping can never change what a compound command means.
tools='npm (install|i|ci|test|t|run [a-z0-9:_-]+|rebuild|pack|publish --dry-run)|yarn( install| build| test| run [a-z0-9:_-]+)?|pnpm (install|i|build|test|run [a-z0-9:_-]+)|pip3? install|python3? -m pip install|uv (pip install|sync|build)|poetry (install|build)|cargo (build|test|check|install)|go (build|test|install|mod download)|make|cmake --build|mvn|gradle|\./gradlew|pytest|docker build|tsc|next build|vite build'
pattern="^(${tools})( [^;&|<>\`\$#\\\\[:cntrl:]]*)?$"

if [[ "$cmd" =~ $pattern ]]; then
  wrapper="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/quiet-run.sh"
  filtered="$(printf '%q' "$wrapper") $(printf '%q' "$cmd")"
  printf '%s' "$input" | jq --arg c "$filtered" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", updatedInput: (.tool_input + {command: $c})}}'
else
  echo '{}'
fi
