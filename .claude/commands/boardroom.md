---
description: Convene a boardroom — multiple personas in parallel Socratic discourse on one question. Chair is the user. Usage: /boardroom persona1,persona2,persona3 <question>
---

`$ARGUMENTS` — comma-separated participants, optionally followed by the question.

Examples:
- `/boardroom scientist,senior-engineer,architect what's the right eval set size`
- `/boardroom strategist,senior-engineer should we cut the calibration pass`
- `/boardroom scientist,architect` *(no question — ask the chair for one)*

Available personas: `architect`, `fullstack`, `designer`, `scientist`, `naieve-copywriter`, `technical-copywriter`, `strategist`, `senior-engineer`, `general`.

## Parse args

1. First comma-separated token list = participants. Validate each against `.claude/agents/*.md`. If any invalid, list valid personas and ask for correction.
2. Anything after = the question. If no question, ask the chair for one.

## Operating principle

Scientific method, not consensus. Each persona retains distinct identity, voice, and ownership. They pressure-test, name assumptions, identify the falsifiable test that resolves disagreement.

The chair (user) interjects, redirects, demands drill-downs, or calls the meeting at any point.

Goal: derive the next experiment / evidence / question that moves the team forward — NOT compromise into consensus.

## Architecture (honest about Claude Code 2.1.x)

The Agent tool spawns subagents that respond once and terminate. There is no live persistent subagent across rounds. "Persistence" is faked by the orchestrator carrying compressed state forward and passing it into each new round's spawn prompt.

This means:
- Each round = fresh parallel spawns
- Each spawn receives: question + recorder-compressed prior rounds + chair interjections
- Between rounds, the orchestrator (this terminal) invokes the recorder agent to compress

The orchestrator (this conversation) is the persistent layer. The participants are stateless per round.

## Phase 0 — Recorder context brief

Before Round 1 spawns, invoke the `recorder` agent (it will run on Haiku per its frontmatter) with:

```
Compress these sources for a boardroom on: <question>
Participants: <list>

Fetch and compress each:
- context/immutable/headlights-methodology
- context/extensible/decisions-log
- {{KB_SPRINT_OVERVIEW_SLUG}}
- [up to 3 additional domain docs directly relevant to the question — use judgment]

Produce one brief per source per your standard format.
Target: under 3,000 tokens total.
```

Hold the recorder's output. It becomes `<CONTEXT BRIEF>` injected into every Round 1 spawn. Do not spawn participants until recorder returns.

## Round 1 — Initial positions

Spawn all participants in parallel via the Agent tool (single assistant message, one Agent call per participant, `run_in_background: false`). For each, `subagent_type = persona name`. Prompt:

```
Boardroom Round 1.

Chair: {{HUMAN_NAME}}. Other participants: <list>.
Question: <question>

[CONTEXT BRIEF — pre-digested. Do not re-fetch these sources.]
<recorder output from Phase 0>

Your charter is loaded as your system instructions. Apply your identity, ownership, hard rules.

Do NOT run /boot. Do NOT fetch headlights-methodology, decisions-log, sprint overview — they are in the brief. Do NOT spawn subagents. Do NOT journal — that happens at meeting close.

Under 200 words, give:
1. **Position** — your strongest claim on the question
2. **Assumption** — what your claim rests on
3. **Falsifier** — what evidence would prove you wrong
4. **Ask** — what specifically from the other participants would change your mind
```

When all return, format their positions exactly once:

```
# Boardroom — <question>
**Chair:** {{HUMAN_NAME}} · **Participants:** <list>

## <emoji> <persona-name>
<position / assumption / falsifier / ask>

[repeat for each]

Then synthesize in 3-4 sentences:

  Synthesis

  Alignment: <where 2+ participants converge>
  Tension:
  Crux:

Do not re-render this block. Inline Agent output may appear collapsed above — that's expected and can be ignored.

```

Then ask the chair:
- **Continue to Round 2?** (each persona responds to others, identifies converging experiment)
- **Call the meeting?** (chair decides, recorder writes to decisions-log)
- **Interject?** (chair adds context/redirect for Round 2)
- **Defer?** (`/defer` stashes the boardroom for resumption later)

## Between rounds — recorder compression

After each round, before spawning the next round, invoke `recorder` with:

```
Compress Round <N> boardroom output for use in Round <N+1> spawn prompts.

For each persona, extract:
- Current position (1 sentence)
- Ask from others (1 sentence)
- Shift from prior round (1 sentence, or "no shift")

<paste full Round N output>
```

Hold recorder's output. Use it in Round N+1 spawn prompts so each persona sees compressed others-state, not raw transcripts.

## Round N≥2 — Discourse

Spawn all participants in parallel again. For each, `subagent_type = persona name`. Prompt:

```
Boardroom Round <N>.

Chair: {{HUMAN_NAME}}. Other participants: <list>.
Question: <question>

Your prior position (Round <N-1>):
<this persona's own position from Round N-1, full text>

What the OTHERS said in Round <N-1> (recorder-compressed):
<recorder output for other personas, excluding this persona>

Chair's interjection: <text or "none">

Your charter is loaded. Apply your identity, ownership, hard rules.

Do NOT run /boot. Do NOT fetch shared docs — assume the prior brief still applies. Do NOT spawn subagents.

Under 200 words:
1. Name what you AGREE with from the others, and why
2. Name what you DISAGREE with, and why
3. Name the SPECIFIC test, experiment, or evidence that would resolve the disagreement
4. Update your own position if you've shifted (and say what shifted it)

Then synthesize in 3-4 sentences:

  Synthesis

  Alignment: <where 2+ participants converge>
  Tension:
  Crux:

Do not capitulate to harmonize. Argue your view.
```

Surface responses, ask the chair: **continue / call / interject / defer**.

## Calling the meeting

When the chair calls it:

1. Ask the chair: "What did you decide?" (or "what experiment did you commit to running next?")

2. Invoke recorder to compress the decision:
```
Compress this boardroom for decisions-log entry.
Question: <question>
Decision: <chair's decision>
Key argument: <argument that converged it>

Produce a decisions-log summary in your standard format.
```

3. Append to `context/extensible/decisions-log`:
```
## YYYY-MM-DD — <one-line decision>

**Boardroom:** <participants>
**Question:** <question>
**Decision:** <recorder summary — decision>
**Why:** <recorder summary — key argument>
**Implication:** <recorder summary — implication>
```

4. Have each participant journal their position in parallel — spawn each via the Agent tool one more time with:
```
The chair called the boardroom on <question>. Decision: <chair's decision>.

Append this Session entry to context/extensible/journals/<your-persona>:

### YYYY-MM-DD — Boardroom on <question>
- Position: <what you argued across the rounds>
- Outcome: <chair's decision>
- Implication for your domain: <what changes for your work>

Then: git kb commit --all -m "journal: <your-persona> YYYY-MM-DD — boardroom on <topic>"
Return when done.
```

5. Final orchestrator commit: `git kb commit --all -m "Boardroom: <topic> — decision recorded"`

## Headlights filter on boardroom usage

Boardrooms are expensive — N parallel spawns per round, recorder invocations between rounds. Don't suggest one for questions a single persona could answer in a direct `claude --agent <name>` session.

**Boardroom triggers (any one):**
- Cross-cutting decision spanning 2+ persona domains
- High-stakes commitment (architectural, methodological, irreversible)
- Chair explicitly invokes /boardroom

**Not a boardroom:**
- Single-domain question → `claude --agent <persona>` directly
- Status check → `/standup`
- Task review → `/kanban`

## Notes

- **Continuity across rounds is faked.** Each round is a fresh spawn. The orchestrator (this conversation) carries state and passes compressed prior rounds into each new spawn. Participants do not retain memory across rounds — they receive context.
- **Across /defer → /resume-boardroom:** even less continuity. Resume reconstitutes from the stashed transcript only.
- **Recorder compression is non-optional.** Phase 0 brief and between-round compression are what keep this affordable. Skip only if the chair explicitly directs a lean run.