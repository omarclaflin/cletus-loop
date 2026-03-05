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
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" <prompt_file> [max_iterations] [completion_string]
```

Parameters:
- **prompt_file**: Markdown file with instructions for each iteration. The prompt should tell the agent to read a tracker file to know what's done, do one unit of work, update the tracker, and exit.
- **max_iterations**: Safety cap (default 20)
- **completion_string**: The agent outputs this when all work is done (default "ALL DONE")

## Prompt file pattern

A good prompt file follows this structure:
1. Read tracker file to see what's already done
2. Pick ONE item not yet done
3. Do the work for that item
4. Update the tracker
5. If everything is done, output the completion string

## Example

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" RALPH_PROMPT.MD 20 "PLAN COMPLETE"
```

## Architecture notes

- Each iteration is a completely independent Claude process
- No parent agent exists — no context contamination between iterations
- Files on disk are the only communication channel between iterations
- Callable by other agents/skills inside Claude Code, preserving agency
- Unlike ralph-loop: no accumulated conversation history
- Unlike subagent loops: no parent context leakage (anthropics/claude-code#14118)
