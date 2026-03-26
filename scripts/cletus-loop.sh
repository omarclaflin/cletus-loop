#!/bin/bash
set -euo pipefail

PROMPT_FILE=""
PROMPT_PARTS=()
MAX_ITERATIONS=20
COMPLETION_STRING="ALL DONE"
ITERATION_STRING=""
LOOP_NAME=""
TRIPLECHECK=1
CLAUDE_FLAGS="--dangerously-skip-permissions"
PID_DIR="/tmp/cletus-loop"
VAR_KEYS=()
VAR_VALUES=()
unset CLAUDECODE

# Multi-prompt state
SUBPROMPT_MODE=false
SUBPROMPT_PROMPTS=()
SUBPROMPT_ITER_STRINGS=()
IN_SUBPROMPT=false
CURRENT_SP_FILE=""
CURRENT_SP_PARTS=()
CURRENT_SP_ITER_STRING=""

PROJECT_SLUG=$(pwd | sed 's|/|-|g; s|^-||; s|\.|-|g')
TRANSCRIPT_DIR="$HOME/.claude/projects/-$PROJECT_SLUG"

extract_assistant_text() {
  local transcript="$1"
  if [[ -f "$transcript" ]] && command -v jq &>/dev/null; then
    jq -r 'select(.type == "assistant") | .message.content[]? | select(.type == "text") | .text' "$transcript" 2>/dev/null || true
  fi
}

push_current_subprompt() {
  if [[ -n "$CURRENT_SP_FILE" ]]; then
    if [[ ! -f "$CURRENT_SP_FILE" ]]; then
      echo "Error: file '$CURRENT_SP_FILE' not found" >&2
      exit 1
    fi
    SUBPROMPT_PROMPTS+=("$(cat "$CURRENT_SP_FILE")")
  elif [[ ${#CURRENT_SP_PARTS[@]} -gt 0 ]]; then
    SUBPROMPT_PROMPTS+=("${CURRENT_SP_PARTS[*]}")
  else
    echo "Error: --subprompt declared with no --file or --prompt" >&2
    exit 1
  fi
  SUBPROMPT_ITER_STRINGS+=("$CURRENT_SP_ITER_STRING")
  CURRENT_SP_FILE=""
  CURRENT_SP_PARTS=()
  CURRENT_SP_ITER_STRING=""
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --subprompt)
      if [[ "$IN_SUBPROMPT" == true ]]; then
        push_current_subprompt
      fi
      SUBPROMPT_MODE=true
      IN_SUBPROMPT=true
      shift
      ;;
    --file|-f)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --file requires a path argument" >&2
        exit 1
      fi
      if [[ "$SUBPROMPT_MODE" == true ]]; then
        CURRENT_SP_FILE="$2"
      else
        PROMPT_FILE="$2"
      fi
      shift 2
      ;;
    --prompt)
      if [[ -z "${2:-}" ]]; then
        echo "Error: --prompt requires a text argument" >&2
        exit 1
      fi
      if [[ "$SUBPROMPT_MODE" == true ]]; then
        CURRENT_SP_PARTS+=("$2")
      else
        PROMPT_PARTS+=("$2")
      fi
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
      if [[ "$SUBPROMPT_MODE" == true ]]; then
        CURRENT_SP_ITER_STRING="$2"
      else
        ITERATION_STRING="$2"
      fi
      shift 2
      ;;
    --triplecheck)
      if [[ -z "${2:-}" ]] || ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: --triplecheck requires a positive integer" >&2
        exit 1
      fi
      TRIPLECHECK="$2"
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
    --var)
      if [[ -z "${2:-}" ]] || [[ "$2" != *=* ]]; then
        echo "Error: --var requires KEY=VALUE format" >&2
        exit 1
      fi
      VAR_KEYS+=("${2%%=*}")
      VAR_VALUES+=("${2#*=}")
      shift 2
      ;;
    *)
      if [[ "$SUBPROMPT_MODE" == true ]]; then
        CURRENT_SP_PARTS+=("$1")
      else
        PROMPT_PARTS+=("$1")
      fi
      shift
      ;;
  esac
done

# Finalize the last subprompt group
if [[ "$SUBPROMPT_MODE" == true ]]; then
  if [[ "$IN_SUBPROMPT" == true ]]; then
    push_current_subprompt
  fi
  NUM_SUBPROMPTS=${#SUBPROMPT_PROMPTS[@]}
  if [[ $NUM_SUBPROMPTS -eq 0 ]]; then
    echo "Error: --subprompt used but no prompts defined" >&2
    exit 1
  fi
fi

# Check jq/uuidgen if any iteration-string is in use
NEEDS_ITER_TOOLS=false
if [[ -n "$ITERATION_STRING" ]]; then
  NEEDS_ITER_TOOLS=true
fi
if [[ "$SUBPROMPT_MODE" == true ]]; then
  for s in "${SUBPROMPT_ITER_STRINGS[@]}"; do
    if [[ -n "$s" ]]; then
      NEEDS_ITER_TOOLS=true
      break
    fi
  done
fi

if [[ "$NEEDS_ITER_TOOLS" == true ]]; then
  if ! command -v jq &>/dev/null; then
    echo "Error: --iteration-string requires jq. Install: brew install jq (macOS) or apt install jq (Linux)" >&2
    exit 1
  fi
  if ! command -v uuidgen &>/dev/null; then
    echo "Error: --iteration-string requires uuidgen." >&2
    exit 1
  fi
fi

if [[ -n "$LOOP_NAME" ]]; then
  mkdir -p "$PID_DIR"
  PID_FILE="$PID_DIR/$LOOP_NAME.pid"
  echo $$ > "$PID_FILE"
  cleanup() { rm -f "$PID_FILE"; }
  trap cleanup EXIT
fi

# Resolve single-prompt mode
if [[ "$SUBPROMPT_MODE" == false ]]; then
  if [[ -n "$PROMPT_FILE" ]]; then
    if [[ ! -f "$PROMPT_FILE" ]]; then
      echo "Error: file '$PROMPT_FILE' not found" >&2
      exit 1
    fi
    PROMPT=$(cat "$PROMPT_FILE")
  elif [[ ${#PROMPT_PARTS[@]} -gt 0 ]]; then
    PROMPT="${PROMPT_PARTS[*]}"
  else
    echo "Error: no prompt provided. Use --subprompt --file <path>, --file <path>, --prompt <text>, or pass a prompt string." >&2
    exit 1
  fi
fi

COMPLETION_COUNT=0

for i in $(seq 1 "$MAX_ITERATIONS"); do
  if [[ "$SUBPROMPT_MODE" == true ]]; then
    idx=$(( (i - 1) % NUM_SUBPROMPTS ))
    ITER_PROMPT="${SUBPROMPT_PROMPTS[$idx]}"
    ITER_STRING="${SUBPROMPT_ITER_STRINGS[$idx]}"
    echo "=== Iteration $i / $MAX_ITERATIONS (subprompt $((idx + 1)) / $NUM_SUBPROMPTS) ==="
  else
    ITER_PROMPT="$PROMPT"
    ITER_STRING="$ITERATION_STRING"
    echo "=== Iteration $i / $MAX_ITERATIONS ==="
  fi
  for _v in "${!VAR_KEYS[@]}"; do
    ITER_PROMPT="${ITER_PROMPT//\{\{${VAR_KEYS[$_v]}\}\}/${VAR_VALUES[$_v]}}"
  done
  echo "--- Agent working... ---"

  if [[ -n "$ITER_STRING" ]]; then
    SESSION_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    TRANSCRIPT_FILE="$TRANSCRIPT_DIR/$SESSION_ID.jsonl"

    echo "$ITER_PROMPT" | claude $CLAUDE_FLAGS --session-id "$SESSION_ID" &
    CLAUDE_PID=$!

    LAST_OUTPUT=""

    while kill -0 "$CLAUDE_PID" 2>/dev/null; do
      if [[ -f "$TRANSCRIPT_FILE" ]]; then
        CURRENT_OUTPUT=$(extract_assistant_text "$TRANSCRIPT_FILE" 2>/dev/null || echo "")

        if [[ -n "$CURRENT_OUTPUT" ]] && [[ "$CURRENT_OUTPUT" != "$LAST_OUTPUT" ]]; then
          echo "$CURRENT_OUTPUT" | tail -n +$(($(echo "$LAST_OUTPUT" | wc -l) + 1))
          LAST_OUTPUT="$CURRENT_OUTPUT"
        fi

        if extract_assistant_text "$TRANSCRIPT_FILE" | grep -qF "$ITER_STRING"; then
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
    OUTPUT=$(echo "$ITER_PROMPT" | claude $CLAUDE_FLAGS 2>&1) || true
    echo "$OUTPUT" | tail -5
    ASSISTANT_TEXT="$OUTPUT"
  fi

  if echo "$ASSISTANT_TEXT" | grep -qF "$COMPLETION_STRING"; then
    COMPLETION_COUNT=$((COMPLETION_COUNT + 1))
    if [[ $COMPLETION_COUNT -ge $TRIPLECHECK ]]; then
      echo "=== Completed at iteration $i ($COMPLETION_COUNT/$TRIPLECHECK confirmations) ==="
      exit 0
    else
      echo "=== Completion detected ($COMPLETION_COUNT/$TRIPLECHECK), continuing to verify... ==="
    fi
  fi

  echo "---"
done

echo "=== Hit max iterations ($MAX_ITERATIONS) without completion ==="
exit 1
