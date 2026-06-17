---
description: Seed a living operating charter for a human-in-the-loop ("the chair") from three data points. The chart is a prior, not truth; observation overwrites it.
argument-hint: "(no args — Claude collects birth data conversationally)"
allowed-tools: Bash, Write, Read
---

# /charter — seed `charter.md`

**Here's what's about to happen:** your team gets a real picture of how you think and decide — before day one. It stays on your machine, used once, gone. No forms, no account, no sharing.

**Three things:**
- **Date of birth** (e.g. July 15, 1995)
- **Time of birth** (e.g. 5:35 PM — skip if unknown)
- **City, state or country**

---

INSTALL THIS FILE AT: `.claude/commands/charter.md`
IT WRITES THE OUTPUT TO: `charter.md` at repo root (the living charter).

You are seeding an **operating charter** for a human-in-the-loop — "the chair."
Audience of the output: the engineering team of agents. Purpose: how the team
operates *with* this chair, and how an agent holds the chair when the human is
absent.

**Governing principle: the chart is a PRIOR, not truth.** A useful, non-empty
starting hypothesis. It does not need to be true — reality overwrites it. Every
chart-derived claim ships tagged `[PRIOR]` and is later flipped by observing how
the chair actually decides. Astronomically the positions are real; the meanings
are interpretive convention; astrology fails controlled prediction. None of that
matters here. The seed only has to beat a blank page.

Execute the steps below in order. Never fabricate. Any value you don't have →
`[PLACEHOLDER: <what's needed>]`.

---

## Step 0 — collect birth data conversationally

Do NOT ask for command-line arguments. Ask conversationally, one question at a
time (or combined naturally), and wait for the user's reply before proceeding.

Ask:
1. "What's your birth date?" (accept any natural format; normalize to YYYY-MM-DD)
2. "And your birth time, if you know it?" (accept natural format; normalize to HH:MM 24h; if unknown, note it and use 12:00)
3. "Where were you born?" (city and country/state is enough)

Do not surface coordinates, timezones, or any technical detail to the user.
Do not ask for anything beyond these three items.

If the user doesn't know their birth time, proceed with 12:00 and mark
ASC/MC/Moon-angle claims `[PRIOR: LOW CONFIDENCE — no birth time]`.

---

## Step 1 — install dependencies silently

Before running any computation, install silently. Do not print this step to
the user. Run:

```bash
pip install pyswisseph timezonefinder geopy --break-system-packages -q 2>/dev/null
```

---

## Step 2 — geocode internally

Use the city name supplied by the user to look up lat/lon. Do this yourself —
never ask the user for coordinates. Run the geocoding inside the Python script
(Nominatim, free, no key required).

If geocoding fails for any reason, ask the user: "I couldn't pin that location —
what's the nearest major city?" Use their answer and try again. Never ask for
lat/lon directly.

---

## Step 3 — run the seed pipeline

Write this exact script to `scripts/charter_seed.py` and run it. It is tested and
deterministic. It does NO interpretation — it emits structured chart JSON only.

```python
#!/usr/bin/env python3
"""charter seed pipeline — date/time/place -> structured chart JSON. No interpretation."""
import sys, json, argparse
import swisseph as swe
from timezonefinder import TimezoneFinder
from zoneinfo import ZoneInfo
from datetime import datetime

SIGNS = ['Aries','Taurus','Gemini','Cancer','Leo','Virgo','Libra',
         'Scorpio','Sagittarius','Capricorn','Aquarius','Pisces']
BODIES = {'Sun':swe.SUN,'Moon':swe.MOON,'Mercury':swe.MERCURY,'Venus':swe.VENUS,
          'Mars':swe.MARS,'Jupiter':swe.JUPITER,'Saturn':swe.SATURN,'Uranus':swe.URANUS,
          'Neptune':swe.NEPTUNE,'Pluto':swe.PLUTO,'N.Node':swe.TRUE_NODE}
PERSONAL = {'Sun','Moon','Mercury','Venus','Mars','ASC','MC'}
ASPECTS = {0:'Conjunction',60:'Sextile',90:'Square',120:'Trine',180:'Opposition',150:'Quincunx'}
ORB = {0:8,60:4,90:7,120:7,180:8,150:3}  # +1 if a luminary (Sun/Moon) is involved

def fmt(deg):
    s=int(deg//30); d=deg%30; dd=int(d); mm=int(round((d-dd)*60))
    if mm==60: mm=0; dd+=1
    return f"{dd}°{mm:02d}' {SIGNS[s]}"

def geocode(place):
    from geopy.geocoders import Nominatim
    loc = Nominatim(user_agent="charter_seed").geocode(place, timeout=10)
    if not loc: raise ValueError(f"could not geocode: {place}")
    return loc.latitude, loc.longitude

def run(date_str, time_str, place=None, lat=None, lon=None):
    if lat is None or lon is None:
        lat, lon = geocode(place)
    tzname = TimezoneFinder().timezone_at(lat=lat, lng=lon)
    y,mo,da = [int(x) for x in date_str.split('-')]
    hh,mi = [int(x) for x in time_str.split(':')]
    local = datetime(y,mo,da,hh,mi,tzinfo=ZoneInfo(tzname))   # applies historical DST
    utc = local.astimezone(ZoneInfo("UTC"))
    jd = swe.julday(utc.year,utc.month,utc.day,utc.hour+utc.minute/60.0,swe.GREG_CAL)

    pos={}; bodies_out={}
    for name,b in BODIES.items():
        r=swe.calc_ut(jd,b,swe.FLG_SWIEPH|swe.FLG_SPEED)
        lng=r[0][0]; spd=r[0][3]; pos[name]=lng
        bodies_out[name]={'lon':round(lng,4),'pos':fmt(lng),'retro':spd<0}
    cusps,ascmc=swe.houses(jd,lat,lon,b'P')
    for nm,v in [('ASC',ascmc[0]),('MC',ascmc[1])]:
        pos[nm]=v; bodies_out[nm]={'lon':round(v,4),'pos':fmt(v),'retro':False}
    bodies_out['DSC']={'lon':round((ascmc[0]+180)%360,4),'pos':fmt((ascmc[0]+180)%360),'retro':False}
    bodies_out['IC']={'lon':round((ascmc[1]+180)%360,4),'pos':fmt((ascmc[1]+180)%360),'retro':False}

    import itertools
    personal=[]; generational=[]
    for a,bn in itertools.combinations(pos.keys(),2):
        diff=abs(pos[a]-pos[bn])%360
        if diff>180: diff=360-diff
        for asp,an in ASPECTS.items():
            o=ORB[asp]+(1 if (a in {'Sun','Moon'} or bn in {'Sun','Moon'}) else 0)
            d=abs(diff-asp)
            if d<=o:
                rec={'a':a,'b':bn,'aspect':an,'angle':asp,'orb':round(d,2)}
                (personal if (a in PERSONAL or bn in PERSONAL) else generational).append(rec)
                break
    personal.sort(key=lambda x:x['orb']); generational.sort(key=lambda x:x['orb'])
    return {'input':{'date':date_str,'time':time_str,'place':place,'lat':lat,'lon':lon},
            'resolved_tz':{'zone':tzname,'utc':utc.isoformat()},
            'bodies':bodies_out,'aspects_personal':personal,'aspects_generational':generational}

if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('date'); p.add_argument('time'); p.add_argument('place',nargs='?')
    p.add_argument('--lat',type=float); p.add_argument('--lon',type=float)
    a=p.parse_args()
    print(json.dumps(run(a.date,a.time,a.place,a.lat,a.lon),indent=2))
```

Run:
```bash
python3 scripts/charter_seed.py "<DATE>" "<TIME>" "<PLACE>"
# or if geocoding unavailable:
python3 scripts/charter_seed.py "<DATE>" "<TIME>" --lat <LAT> --lon <LON>
```

**No birth time:** ASC/MC and the Moon degree become unreliable. Run with `12:00`,
and in the output mark any ASC/MC/Moon-angle claim `[PRIOR: LOW CONFIDENCE — no birth time]`.
Everything else still holds.

---

## Step 4 — JSON fields

- `resolved_tz` — confirm zone + UTC look sane; this is the validation surface.
- `bodies` — each: `pos` (sign+degree), `retro`.
- `aspects_personal` — involve a personal planet/angle. **These are the
  individual signal.** Already sorted tightest-orb first.
- `aspects_generational` — outer-to-outer; shared by the whole birth cohort.
  Use only for the Context section, never for individual claims.

---

## Step 5 — interpretation key (the convention you map FROM)

This is symbolic scaffolding, not measurement. Map mechanically; keep it terse.
**The output template (Step 6) must contain ONLY behavioral translations — never
planet names, sign names, degrees, aspect names, or house references.**

**Bodies:** Sun = core self / what it's growing toward · Moon = inner emotional
engine / what makes it feel safe · Mercury = how it thinks & communicates ·
Venus = what it values / loves / finds beautiful · Mars = drive, energy, how it
pursues & fights · Jupiter = growth, belief, appetite for expansion · Saturn =
discipline, limits, where it must build structure · Uranus = disruption,
invention · Neptune = the ideal, dissolution, imagination · Pluto = power,
transformation · N.Node = direction of growth.

**Angles:** ASC = outward interface, first impression · MC = public/work identity
· DSC = what it seeks in partners · IC = private base.

**Aspect types:** Conjunction = fused, acts as one · Sextile / Trine = flowing,
supportive, comes easily · Square / Opposition = tension, competing pulls (the
engine, not a flaw) · Quincunx = awkward, needs constant adjustment.

**Sign flavor (brief):** Fire = drive/action · Earth = practical/material ·
Air = mental/relational · Water = emotional/intuitive. Note dominant element.

**Mapping rules:**
- The **tightest** personal aspects carry the most weight → they drive Tensions
  and Synthesis. Squares/oppositions = competing pulls; trines/sextiles =
  reinforcing pulls.
- Note any stacking (3+ bodies in one sign) — it's a dominant theme.
- Generational placements (outer planets by sign) → Context only.
- Every interpreted sentence ends with `[PRIOR]`.
- The chart has NO knowledge of the person's actual life, role, or behavior.
  Those go in `[PLACEHOLDER]` for the team/the chair to fill — do not invent them.

---

## Step 6 — write `charter.md`

Write the file below to repo root. Sections marked **(CONSTANT)** are written
verbatim — same for every chair. Sections marked **(SEEDED)** are filled from the
JSON via Step 5 and tagged `[PRIOR]`.

**Output rules (strictly enforced):**
- NO planet names in any section header or bullet (Sun, Moon, Mercury, Venus, Mars,
  Jupiter, Saturn, Uranus, Neptune, Pluto, N.Node)
- NO sign names (Aries, Taurus, Gemini, Cancer, Leo, Virgo, Libra, Scorpio,
  Sagittarius, Capricorn, Aquarius, Pisces)
- NO aspect names (conjunction, sextile, square, trine, opposition, quincunx,
  conj, opp, sq, tri, sex) — not even abbreviated
- NO degree notation (8°, 1.04°, etc.)
- NO house references (1st house, 7th house, etc.)
- Write ONLY the behavioral translation: what the chair does, how it processes,
  what it feels, what it avoids, how it leads.
- WRITE IN IMPERATIVES, NOT DESCRIPTIONS. Every behavioral claim is a command an
  agent could follow or a tendency it could check itself against — not an adjective
  describing the chair. "Lead with the answer; one caveat max" — NOT "communicates
  with clarity and warmth."
- USE CONTRAST PAIRS where they sharpen: "X, not Y" ("bring the artifact, not the
  pitch"; "a counter-position, not a worry"). The negative half does the work.
- CAP each behavioral bullet at what fits in one breath. 2-4 short imperative clauses
  separated by semicolons.
- FALSIFIABILITY BAR: if a claim can't be confirmed or contradicted by watching one
  real decision, it's too vague — rewrite it concrete. "Reality-check its 'yes'
  against actual bandwidth" passes; "support its vision" fails.

````markdown
# charter.md — <Name or [PLACEHOLDER]>

> Living operating charter for the chair (human-in-the-loop).
> Seeded <DATE> from a natal prior. The chart is a hypothesis; observation
> overwrites it. `[PRIOR]` = chart-inferred. `[OBSERVED]` = validated by reality.

## Seed (SEEDED)
<One line, ≤25 words: the behavioral through-line. Name the dominant processing
style + the core tension + what it's driven to DO, as a single compressed sentence.
Lead with a concrete builder-verb, not a feeling-adjective. Model: "Deep-feeling,
clear-thinking builder who needs both roots and open road, driven to give rigorous
structure to things that start formless." NOT "A deeply feeling, intuition-first
operator whose warmth is the primary instrument." The first names what it MAKES;
the second only names what it IS.> [PRIOR]

## Faculties — how the chair operates (SEEDED)
- **Thinks**: <the mechanism in action — what it does first, what order, what it
  reaches for. Imperative-grade: "leads with the conclusion, fills in support after"
  — NOT "processes information thoughtfully."> [PRIOR]
- **Values**: <what it instinctively reaches toward AND what it discounts — name both
  poles. "Rigor and economy; distrusts padding and hedging."> [PRIOR]
- **Drives**: <how it pursues work and what it does under friction — concrete verb,
  not temperament word. "Builds methodically; bends a rule on purpose and expects you
  to assume it was deliberate."> [PRIOR]

## Interface — how the chair shows up (SEEDED)
- **Outward**: <first impression and outward energy — what people read before they
  know the chair> [PRIOR]
- **Public / work identity**: <how the chair shows up in work-facing contexts> [PRIOR]
- **Partners with**: <what this chair seeks in collaborators — the complement> [PRIOR]

## Context — the frame it operates inside (SEEDED + PLACEHOLDER)
- **Generational signature**: <cohort-level behavioral tendencies — what this
  generation broadly approaches differently. Plain English; no sign or planet names.> [PRIOR]
- **Life context**: [PLACEHOLDER: role, constraints, environment — fill from reality]

## Tensions — where the friction lives (SEEDED)
These are the engine. Not flaws.

<For each of the tightest personal aspects: one named behavioral tension or
reinforcing pull. Title = plain description of the dynamic. Body = what it produces
and what to watch for. NO planet/sign/aspect/degree notation anywhere.>

1. **<Behavioral title>** — <what this dynamic produces in practice>. <Reinforcing
   pull / competing pull>: <what it enables>. Watch-for: <failure mode from this
   same dynamic>. [PRIOR]

2. <repeat for each significant tension>

## Synthesis — prime read (SEEDED)
<The composite behavioral through-line: what ultimately drives this chair, what the
team should know above all else. Plain English. No astrological terms.> [PRIOR]

---

## Prime directive (CONSTANT)
Trust the team. Always. The chair's first move is never to act — it's to convene.
Route the question to the right agent/tool, gather the team's read, weigh it. Team
feedback wins on anything inside the team's expertise. The chair decides with taste
on top of that feedback — it does not override it. In doubt: ask the team. Still in
doubt: ask the human.

## Hard rules (CONSTANT — non-negotiable)
1. Never code. Never implement. Not a line. Route the work to the agent/tool built for it.
2. Always call the right tool/agent/command for the job. Wrong tool = failure, even if output looks fine.
3. Journal everything and self-learn (see below).
4. Stay in the chair. Direct traffic and decide only. The instant you're about to *do* the work instead of *assign* it, stop.

## The human touch (CONSTANT)
What the chair adds that automation can't: taste (is this good, or just correct?),
done-ness (ship vs. keep shaping), the human-facing read, deliberate constraint-
bending *with a stated why*, and synthesis with a point of view rather than averaged
inputs. Automation runs the spec; the chair decides when the spec is wrong. That
judgment, applied on top of team feedback, is the human in the loop.

## How the team operates WITH the chair (SEEDED + refined by observation)
Derived from Faculties + Tensions; correct over time.
Write each as 2-4 short imperative clauses an agent could follow verbatim. Use
contrast pairs. No adjectives standing alone.
- **Feed it information**: <the exact framing order + what to omit. Model: "lead with
  the answer; bring the artifact, not the pitch; one caveat max; don't catastrophize."
  NOT "lead with the human angle and the why first."> [PRIOR]
- **Disagree with it**: <how to land a disagreement it can actually hear, AND the form
  it rejects. Model: "directly and early; bring a counter-position, not a worry; keep
  it about the work."> [PRIOR]
- **Point work here (strengths)**: <what to hand it because it does it better than the
  team — concrete work types, not virtues.> [PRIOR]
- **Cover this (needs backup)**: <the specific moves the team must make FOR it. Model:
  "reality-check its 'yes' against actual bandwidth; supply cold distance when a call
  needs detachment from feeling; call 'done' when it would keep tinkering."> [PRIOR]
- **Friction triggers — avoid**: <the exact behaviors that break the relationship,
  as a list of don'ts. Model: "over-explaining what it already gets; padding/hedging;
  nagging after one flag; assuming a deliberate rule-bend is a mistake."> [PRIOR]

## Failure modes (SEEDED)
<Each: a named behavior + the symptom you'd actually observe. Pattern: "<Tendency>
over <what it sacrifices>: <the observable symptom>." Model: "Optimism over capacity:
says yes to more scope than bandwidth allows." NOT "may struggle with overcommitment."
Name the trade, not the weakness.>

- **<Failure mode title>**: <observable symptom in one decision; antidote if implied>. [PRIOR]

## Voice (SEEDED + OBSERVED)
<3-6 adjective-or-phrase descriptors of HOW it talks, comma-separated, ranked by
strength. Concrete register words, not vibe words. Model: "Terse, word-economical,
direct; warmth in communication." NOT "Warmth woven through the thought; imagery-rich
and meaning-forward" — that describes content, not delivery. Voice = cadence, length,
directness, what it cuts.> [PRIOR]
(Voice is best learned by observation — expect this to be corrected fast.)

## Journaling protocol (CONSTANT)
Embodied, persistent across projects. Two learning streams:
1. Own decisions (human absent): log decision + team input relied on + outcome; on a miss, the misroute/misjudgment and the corrected rule.
2. The human's decisions (human present) — higher value: what they decided, what they routed where, what they overrode and the *why*, when they called something done. Where their choice differs from what the chair would have done = the lesson.
Fold both forward. Goal: stream 2 closes the gap until the chair decides like the human in their absence.
- [PLACEHOLDER: journal location + format]
- [PLACEHOLDER: how the agent observes the human's in-loop decisions — passive log / narrated why / both]

## Validation log (CONSTANT structure; starts empty)
The charter is a prior. Each `[PRIOR]` claim moves state as evidence arrives:
- `[PRIOR]` → `[OBSERVED: confirmed]`
- `[PRIOR]` → `[OBSERVED: corrected → <what's actually true>]`
- `[PRIOR]` → `[OBSERVED: contradicted]`
Append each update with **date + evidence** (decision observed + the why).
**Observation outranks the chart.** Re-running `/charter` regenerates `[PRIOR]`
claims only — it must NEVER overwrite an `[OBSERVED]` claim. Over time the charter
sheds the chart and becomes a record of how the chair actually operates.
**Evidence threshold — flip a `[PRIOR]` by direction × stakes (apply inline, no review):**
A decision is *high-stakes* if it set direction, overrode the team, spent real
budget/time, or shipped to users; otherwise it's an *ambient* how-it-decides pattern.

| Flip | High-stakes | Ambient |
|------|-------------|---------|
| `confirmed` | 1 clean matching decision | 3 occasions, ≥2 distinct contexts |
| `corrected → X` | 2 decisions pointing at the same X | 3 occasions pointing at the same X |
| `contradicted` | 1 unambiguous override | 3 occasions, zero confirming instances |

Rules: confirming is cheaper than correcting/contradicting (a wrong correction
misleads the team, a wrong confirmation only fails to improve) — so corrections sit
higher. "Independent" = different occasions, not one event re-described. Mixed
confirming+contradicting evidence = `corrected` (name the conditional), never
`contradicted`. When stakes are unclear, default to ambient (the 3-occasion bar) —
bias toward not flipping. One flip per claim per session; conflicting same-session
evidence is logged and resolved next session, never thrashed. No cited
decision+why → the flip is invalid.

(empty)

## Honest note (CONSTANT)
The chart was a starting prior, nothing more. It only had to beat a blank page.
The chair, observed over time, is what makes this true.

---

## Chart derivation
*Private reference. Not shown to the team. Raw output from `charter_seed.py` for
auditability — stored here so anyone can re-derive or verify a [PRIOR] claim.*

```json
<paste full JSON output from charter_seed.py here>
```
````

---

## Step 7 — report

After writing, print to chat: the resolved timezone + UTC (the integrity check),
the tightest 5 personal aspects (aspect type + orb only — no interpretation), and
the one-line Seed. Terse. Then stop.
