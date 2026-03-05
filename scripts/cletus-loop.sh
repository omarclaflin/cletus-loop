#!/bin/bash
set -euo pipefail

PROMPT_FILE=""
PROMPT_PARTS=()
MAX_ITERATIONS=20
COMPLETION_STRING="ALL DONE"
CLAUDE_FLAGS="--dangerously-skip-permissions"

while [[ $# -gt 0 ]]; do
  case $1 in
    --file|-f)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --file requires a path argument" >&2
        exit 1
      fi
      PROMPT_FILE="$2"
      shift 2
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --max-iterations requires a positive integer" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-string)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --completion-string requires a text argument" >&2
        exit 1
      fi
      COMPLETION_STRING="$2"
      shift 2
      ;;
    --claude-flags)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --claude-flags requires an argument" >&2
        exit 1
      fi
      CLAUDE_FLAGS="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

if [[ -n "$PROMPT_FILE" ]]; then
  if [[ ! -f "$PROMPT_FILE" ]]; then
    echo "Error: file '$PROMPT_FILE' not found" >&2
    exit 1
  fi
  PROMPT=$(cat "$PROMPT_FILE")
elif [[ ${#PROMPT_PARTS[@]} -gt 0 ]]; then
  PROMPT="${PROMPT_PARTS[*]}"
else
  echo "Error: no prompt provided. Use --file <path> or pass a prompt string." >&2
  exit 1
fi

for i in $(seq 1 "$MAX_ITERATIONS"); do
  echo "=== Iteration $i / $MAX_ITERATIONS ==="

  OUTPUT=$(echo "$PROMPT" | claude $CLAUDE_FLAGS 2>&1) || true

  echo "$OUTPUT" | tail -5

  if echo "$OUTPUT" | grep -qF "$COMPLETION_STRING"; then
    echo "=== Completed at iteration $i ==="
    exit 0
  fi

  echo "---"
done

echo "=== Hit max iterations ($MAX_ITERATIONS) without completion ==="
exit 1
