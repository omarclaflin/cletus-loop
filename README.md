# cletus-loop

A Claude Code plugin that runs iterative agent loops with fresh context per iteration. Ralph Wiggum, meet the even simpler Cletus Spuckler.

Basically, a bash loop inside Claude Code.

<p align="center">
  <img src="cletus_spuckler.png" width="600" />
</p>

## Problem

Existing loop approaches in Claude Code have context problems:

| Approach | Issue |
|----------|-------|
| Ralph loop (stop hook) | Same session reused. History accumulates. Agent loses focus after many iterations. |
| Subagent loop (Task/Agent tool) | Child results leak into parent context. Parent contaminates subsequent child prompts (via prompt generation contaminated by history). |
| LLM Orchestrator + Task tool with verbatim prompt | The orchestrator is an LLM, not a pipe. As conversation history grows, prompt pass-through becomes increasingly nondeterministic — it paraphrases, summarizes, or injects its own context instead of forwarding verbatim. |
| External bash loop | This works too -- clean isolation, but a plugin gives us agency options inside CC. |

Basically, I wanted to setup loops with proper firewalls/without context accumulation, but realized I had to keep restarting /ralph or just externally looping claude code. Why? Because of context accumulation and information leaking.

To make this clear, briefly, consider a meta-loop with a 'diagnostic & improvement' agent who _should_ only see the outputs of an independent automated unit test, but instead the inner workings of that test is 'leaked' to it (via chat summaries between agents or chat history) allowing it to cheat/lazily hack around it.

I thought I was hallucinating issues until I saw [claude-code#14118](https://github.com/anthropics/claude-code/issues/14118).

<p align="center">
  <img src="cletus_spuckler_2.png" width="300" />
</p>


## Solution

Cletus-loop spawns a new `claude` process per iteration. Each iteration:
1. Starts with zero conversation history
2. Reads a prompt file
3. Reads tracker files on disk to know what's done
4. Does one unit of work
5. Updates the tracker
6. Exits

No parent agent. No accumulated history. Files are the only state.

Packaged as a CC plugin so agents inside CC can call it dynamically.

## Install

```bash
# Local testing
claude --plugin-dir ./cletus-loop

# Or install from a marketplace
/plugin install cletus-loop@your-marketplace
```

## Usage

### Basic loop with a prompt file [--file]
```
/cletus-loop:cletus-loop --file PROMPT.md --max-iterations 10 --completion-string "ALL DONE"
```

### Loop with a prompt string
```
/cletus-loop:cletus-loop "Read TASKS.md, pick one undone task, do it, mark it done. If all done output ALL DONE." --max-iterations 10
```

### Kill agent after each unit of work rather than allowing it to stop on its own [--iteration-string]
(to prevent agent from creatively spiralling; sometimes with sloppy prompts, it 'infers' its own task list within a loop; also, be careful not to include terms it would use in its task work so it doesn't end prematurely like "CHECK TASK LIST")
```
/cletus-loop:cletus-loop --file PROMPT.md --iteration-string "TASK FINISHED" --completion-string "ALL DONE" --max-iterations 20
```

### Named loop [-name]
(so you can cancel it if running multiple loops)
```
/cletus-loop:cletus-loop --file PROMPT.md --name proofreader --iteration-string "TASK FINISHED" --completion-string "ALL DONE"
```

### Cancel a running loop
```
/cletus-loop:cancel proofreader
```

### Show help
```
/cletus-loop:help
```

### From another agent/skill
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/cletus-loop.sh" --file PROMPT.md --max-iterations 10 --completion-string "ALL DONE"
```

## Pattern for writing prompt files

Your prompt file should follow the one-item-per-iteration pattern:

```markdown
Read TRACKER.md to see what's done.
If everything is done, output "ALL DONE".
Pick ONE item from SOURCE.md not in TRACKER.md.
Do the work. Write output to output_files/.
Append to TRACKER.md.
Output "TASK DONE".
```

## Why not just…

**Ralph loop (stop hook, same session)?** Context accumulates. By iteration 15, the agent is dragging around the full history of iterations 1–14. Wasted tokens on finished work, and the model starts anchoring to earlier mistakes.

**Subagent loop (Task tool)?** The parent agent's context leaks into child agents. Children aren't truly independent — they're influenced by what the parent has seen and done. See [claude-code#14118](https://github.com/anthropics/claude-code/issues/14118).

**Plain bash loop outside Claude Code?** Clean isolation, but you lose agency. Other agents and skills inside CC can't call it. It's just a cron job at that point.

**Cletus loop** gets you fresh-process isolation (like bash) while staying callable from inside CC (like subagents). The tradeoff is that all inter-iteration state lives in files on disk — which is the point.


## Summary

Children of **LLM orchestrators** are affected by the parent's history and knowledge.

**Ralph** is a single child who never leaves home with a room accumulating with context junk.

**Cletus** children are parentless so they never inherit anything.

<p align="center">
  <img src="CletusLoop.png" width="300" />
</p>


I know its really dumb (basically a for loop for Claude Code). But maybe it'll be helpful to you, goodluck and godspeed
--Omar Claflin

## License

MIT

<p align="center">
  <img src="vicePrezCletus.png" width="300" />
</p>
