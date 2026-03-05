Show help for the cletus-loop plugin.

Do NOT run any commands. Just print the following help text exactly:

# cletus-loop

An iterative agent loop where each iteration spawns a brand new Claude process with zero conversation history. State persists only through files on disk.

## Commands

- `/cletus-loop:cletus-loop` — Run a loop
- `/cletus-loop:help` — Show this help

## Usage

With a prompt file:
```
/cletus-loop:cletus-loop --file PROMPT.md --max-iterations 10 --completion-string "ALL DONE"
```

With a prompt string:
```
/cletus-loop:cletus-loop Fix the auth bug --max-iterations 10 --completion-string "FIXED"
```

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| --file, -f | (none) | Path to a markdown prompt file. Errors if file doesn't exist. |
| --max-iterations | 20 | Safety cap on number of iterations |
| --completion-string | "ALL DONE" | String the agent outputs when all work is done |
| --claude-flags | --dangerously-skip-permissions | Flags passed to the claude CLI |

If --file is not used, all non-flag arguments are joined as the prompt string.

## Prompt file pattern

Your prompt file should follow the one-item-per-iteration pattern:

1. Read a tracker file to see what's already done
2. Pick ONE item not yet done
3. Do the work
4. Update the tracker
5. If everything is done, output the completion string
