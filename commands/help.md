Show help for the cletus-loop plugin.

Do NOT run any commands. Just print the following help text exactly:

# cletus-loop

An iterative agent loop where each iteration spawns a brand new Claude process with zero conversation history. State persists only through files on disk.

## Commands

- `/cletus-loop:cletus-loop` — Run a loop
- `/cletus-loop:cancel <name>` — Kill a running loop by name
- `/cletus-loop:help` — Show this help

## Usage

With a prompt file:
```
/cletus-loop:cletus-loop --file PROMPT.md --name my-task --max-iterations 10 --completion-string "ALL DONE"
```

With a prompt string:
```
/cletus-loop:cletus-loop Fix the auth bug --name auth-fix --max-iterations 10 --completion-string "FIXED"
```

With an iteration string (kills the agent after one unit of work):
```
/cletus-loop:cletus-loop --file PROMPT.md --name proofreader --iteration-string "TASK FINISHED" --completion-string "ALL DONE" --max-iterations 20
```

Cancel a running loop:
```
/cletus-loop:cancel proofreader
```

## Flags

| Flag | Default | Description |
|------|---------|-------------|
| --file, -f | (none) | Path to a markdown prompt file. Errors if file doesn't exist. |
| --name | (none) | Name for this loop. Required to use /cletus-loop:cancel. PID stored at /tmp/cletus-loop/<name>.pid |
| --max-iterations | 20 | Safety cap on number of iterations |
| --completion-string | "ALL DONE" | String that stops the entire loop when detected in output |
| --iteration-string | (none) | String that kills the current iteration's agent when detected. Use this to prevent the agent from doing more than one unit of work per iteration. |
| --claude-flags | --dangerously-skip-permissions | Flags passed to the claude CLI |

If --file is not used, all non-flag arguments are joined as the prompt string.

## Completion string vs iteration string

- **--completion-string**: "All tasks are done, stop the loop entirely."
- **--iteration-string**: "One task is done, kill this iteration's process and move to the next."

Your prompt should tell the agent to output the iteration string after completing one item, or the completion string if there are no items left.

## Prompt file pattern

Your prompt file should follow the one-item-per-iteration pattern:

1. Read a tracker file to see what's already done
2. Pick ONE item not yet done
3. Do the work
4. Update the tracker
5. If everything is done, output the completion string. Otherwise, output the iteration string.

---
By Omar Claflin — https://github.com/omarclaflin/cletus-loop
