Run a cletus-loop: an iterative agent loop where each iteration spawns a brand new Claude process with zero conversation history.

Usage:
  /cletus-loop:cletus-loop --file <prompt_file> [--max-iterations N] [--completion-string TEXT]
  /cletus-loop:cletus-loop <prompt string> [--max-iterations N] [--completion-string TEXT]

Examples:
  /cletus-loop:cletus-loop --file PROMPT.md --max-iterations 10 --completion-string "PLAN COMPLETE"
  /cletus-loop:cletus-loop Fix the auth bug --max-iterations 10 --completion-string "FIXED"

Execute the loop by running the script:

```bash
chmod +x "${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh"
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" $ARGUMENTS
```
