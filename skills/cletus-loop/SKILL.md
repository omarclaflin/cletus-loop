---
name: cletus-loop
description: Run an iterative agent loop with fresh context per iteration. Use when a task requires many sequential iterations (plan writing, proofreading, test writing, code implementation) and context accumulation would degrade quality. Each iteration spawns a new Claude process with no conversation history. State persists only through files on disk.
---

# Cletus Loop Skill

You have access to a cletus-loop script that runs iterative agent loops with clean context.

## When to use

- A task needs many iterations of the same prompt
- Each iteration should not see previous iterations' conversation history
- State between iterations is tracked in files (trackers, checklists, etc.)

## How to use

Run the bash script directly:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" --file PROMPT.md --max-iterations 20 --completion-string "ALL DONE"
```

Parameters:
- **--file**: Markdown file with instructions for each iteration
- **--prompt**: Inline prompt string (alternative to --file)
- **--max-iterations**: Safety cap (default 20)
- **--completion-string**: The agent outputs this when all work is done (default "ALL DONE"); shared across all subprompts
- **--iteration-string**: Kill the agent the moment it outputs this string (single-prompt mode)
- **--triplecheck N**: Require N consecutive completion confirmations before stopping
- **--name**: Name the loop so it can be cancelled
- **--subprompt**: Start a new subprompt group (see multi-prompt below)

## Prompt file pattern

A good prompt file follows this structure:
1. Read tracker file to see what's already done
2. Pick ONE item not yet done
3. Do the work for that item
4. Update the tracker
5. If everything is done, output the completion string

## Single-prompt example

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" --file PROMPT.md --max-iterations 20 --completion-string "PLAN COMPLETE"
```

## Multi-prompt example

Use `--subprompt` to define a sequence of prompts that cycle in order (A, B, C, A, B, C, ...). Each subprompt can have its own `--file`, `--prompt`, and `--iteration-string`. `--completion-string` is shared and can be output by any subprompt to stop the loop.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" \
  --subprompt --file STEP_A.md \
  --subprompt --file STEP_B.md --iteration-string "B DONE" \
  --subprompt --file STEP_C.md --iteration-string "C DONE" \
  --completion-string "ALL DONE" \
  --max-iterations 30
```

- Subprompt A has no `--iteration-string`: runs to natural completion each time
- Subprompts B and C are killed the moment they output their iteration strings
- Any subprompt outputting "ALL DONE" stops the entire loop

## Architecture notes

- Each iteration is a completely independent Claude process
- No parent agent exists — no context contamination between iterations
- Files on disk are the only communication channel between iterations
- Callable by other agents/skills inside Claude Code, preserving agency
- Unlike ralph-loop: no accumulated conversation history
- Unlike subagent loops: no parent context leakage (anthropics/claude-code#14118)
