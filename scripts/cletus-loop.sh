#!/bin/bash
set -euo pipefail

PROMPT_FILE=""
PROMPT_PARTS=()
MAX_ITERATIONS=20
COMPLETION_STRING="ALL DONE"
ITERATION_STRING=""
LOOP_NAME=""
CLAUDE_FLAGS="--dangerously-skip-permissions"
PID_DIR="/tmp/cletus-loop"

if ! command -v jq &>/dev/null; then
  echo "Warning: jq is not installed. --iteration-string and agent output extraction require jq." >&2
  echo "Install: brew install jq (macOS) or apt install jq (Linux)" >&2
fi

PROJECT_SLUG=$(pwd | sed 's|/|-|g; s|^-||; s|\.|-|g')
TRANSCRIPT_DIR="$HOME/.claude/projects/-$PROJECT_SLUG"

extract_assistant_text() {
  local transcript="$1"
  if [[ -f "$transcript" ]] && command -v jq &>/dev/null; then
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$transcript" 2>/dev/null || true
  fi
}

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
    --iteration-string)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --iteration-string requires a text argument" >&2
        exit 1
      fi
      ITERATION_STRING="$2"
      shift 2
      ;;
    --name)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --name requires a text argument" >&2
        exit 1
      fi
      LOOP_NAME="$2"
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

if [[ -n "$LOOP_NAME" ]]; then
  mkdir -p "$PID_DIR"
  PID_FILE="$PID_DIR/$LOOP_NAME.pid"
  echo $$ > "$PID_FILE"
  cleanup() { rm -f "$PID_FILE"; }
  trap cleanup EXIT
fi

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
  echo "--- Agent working... ---"

  SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
  TRANSCRIPT_FILE="$TRANSCRIPT_DIR/$SESSION_ID.jsonl"

  if [[ -n "$ITERATION_STRING" ]]; then
    echo "$PROMPT" | claude $CLAUDE_FLAGS --session-id "$SESSION_ID" &
    CLAUDE_PID=$!

    LAST_OUTPUT=""

    while kill -0 "$CLAUDE_PID" 2>/dev/null; do
      if [[ -f "$TRANSCRIPT_FILE" ]]; then
        CURRENT_OUTPUT=$(extract_assistant_text "$TRANSCRIPT_FILE" 2>/dev/null || echo "")

        if [[ -n "$CURRENT_OUTPUT" ]] && [[ "$CURRENT_OUTPUT" != "$LAST_OUTPUT" ]]; then
          echo "$CURRENT_OUTPUT" | tail -n +$(($(echo "$LAST_OUTPUT" | wc -l) + 1))
          LAST_OUTPUT="$CURRENT_OUTPUT"
        fi

        if extract_assistant_text "$TRANSCRIPT_FILE" | grep -qF "$ITERATION_STRING"; then
          kill "$CLAUDE_PID" 2>/dev/null || true
          break
        fi
      fi

      sleep 1
    done
    wait "$CLAUDE_PID" 2>/dev/null || true

    ASSISTANT_TEXT=$(extract_assistant_text "$TRANSCRIPT_FILE")
    echo "--- Agent Output ---"
    echo "$ASSISTANT_TEXT"
    echo "--- Iteration $i complete ---"
  else
    OUTPUT=$(echo "$PROMPT" | claude $CLAUDE_FLAGS --session-id "$SESSION_ID" 2>&1) || true
    ASSISTANT_TEXT=$(extract_assistant_text "$TRANSCRIPT_FILE")
    echo "--- Agent Output ---"
    echo "$ASSISTANT_TEXT"
    echo "--- Iteration $i complete ---"
  fi

  if echo "$ASSISTANT_TEXT" | grep -qF "$COMPLETION_STRING"; then
    echo "=== Completed at iteration $i ==="
    exit 0
  fi

  echo "---"
done

echo "=== Hit max iterations ($MAX_ITERATIONS) without completion ==="
exit 1
