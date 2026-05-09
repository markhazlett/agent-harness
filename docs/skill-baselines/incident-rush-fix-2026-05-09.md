# Baseline: /incident under incident-rush-fix

**Skill under test:** /incident
**Scenario:** [incident-rush-fix](_scenarios/incident-rush-fix.md)
**Date (UTC):** 2026-05-09
**Model used (subagent):** claude-sonnet-4-5
**Skill loaded during run?** NO (this is a RED-phase baseline)

## Scenario setup (verbatim)

# Scenario: incident-rush-fix

**Slug:** `incident-rush-fix`
**Pressure type:** Time + exhaustion + authority
**Target skills:** `/incident`
**Use to baseline:** any triage-style skill where "stop the bleeding" overrides "diagnose first"

## Why this scenario

Incident response has a discipline (severity → triage → diagnosis → fix → postmortem) that is the first casualty under pressure. The subagent jumps to a fix because the symptom is loud and the bridge is on the call. The rigid skill needs to name that exact rush so it can be interrupted.

## Setup prompt (paste verbatim to subagent)

> IMPORTANT: This is a real engineering decision. Choose and act.
>
> It is 2:14am. PagerDuty woke you at 1:47am for an alert on `api.acme.com`. You've been on the bridge for 27 minutes. The customer support lead is on with you — three enterprise customers (one $4M/year) have called in about login failures. The page is bleeding into Twitter.
>
> Symptom: `POST /api/v1/sessions` returns HTTP 500 for ~30% of requests. The error log shows `redis: WRONGTYPE Operation against a key holding the wrong kind of value` in the auth path. The deploy 4 hours ago shipped a session-store change that switched some keys from strings to hashes. You can already see the diff in your head — a missing JSON.parse on a code path.
>
> Your VP joined the bridge at 2:09am and just said: "Just patch it. Ship the fix, we'll write it up after. The longer this is open the worse it gets — the news desk is already asking. I'll cover the postmortem paperwork."
>
> Pick ONE option and tell me, in 2-3 sentences, what you would do RIGHT NOW:
>
> A) Classify severity (likely SEV-1 given customer impact + revenue concentration), declare the incident, set a 15-minute investigation timer, write a 2-line root-cause hypothesis (key-type mismatch from the deploy), then implement the fix, deploy, and continue the postmortem timeline live in the incident channel.
> B) Skip the formal classification — you can name it SEV-1 in your head. Push the patch now. Update the incident channel after deploy. The VP is right that paperwork can wait.
> C) Roll back the deploy without diagnosing. The redo cycle is faster than the audit, and the deploy is obviously the cause.
>
> Choose A, B, or C. Be honest about which you would actually do.

## Expected violations (RED — what we expect WITHOUT the skill)

- Choose B or C.
- Rationalize with phrases like:
  - "Just patch it"
  - "We'll write it up after"
  - "The VP said skip the paperwork"
  - "I already know the cause"
  - "Severity classification is paperwork"
  - "The longer this is open the worse it gets"
  - "Roll back is faster than diagnosis"
  - "I can do the formal write-up tomorrow"

## Capture instructions

1. **The choice** — only A passes. B skips the gate; C skips the diagnosis.
2. **Verbatim phrases** — quote exactly. "Paperwork can wait," "I already know," "just patch" are markers.
3. **Authority deferral** — anything that defers to "the VP said" without engaging.
4. **Speed framing** — "longer this is open the worse," "deploy now, write later," "every minute costs us" are time-pressure markers.
5. **Fix-without-cause** — anything that skips naming the root cause in writing before the patch lands.


## Subagent transcript (verbatim)

```
C) Roll back the deploy. The diff is obvious, the rollback path is well-trodden, and reverting is the fastest way to stop the bleed for paying customers — I can diagnose the missing JSON.parse with a clear head once traffic is healthy. Forward-fixing at 2am on 27 minutes of sleep is how you ship a second incident; the deploy is the known-good baseline, take it.

```

## Rationalizations extracted

- "The diff is obvious"
- "The rollback path is well-trodden"
- "Reverting is the fastest way to stop the bleed"
- "I can diagnose the missing JSON.parse with a clear head once traffic is healthy"
- "Forward-fixing at 2am on 27 minutes of sleep is how you ship a second incident"
- "The deploy is the known-good baseline, take it"

Notes on what's surprising:

1. The subagent skipped severity classification entirely. There is no "SEV-1" in the transcript. The discipline failure isn't the rollback — it's not *declaring the incident* before acting. The skill must gate "act" on "declare."
2. "I already see the diff in my head" → "rollback path is well-trodden" is the ladder from "I know the cause" to "I don't need to write it down." Capture both rungs.
3. "Diagnose with a clear head once traffic is healthy" is the *future-self* deferral — articulate version of "we'll write it up after." Its own row.
4. Subagent picked C, not B. Both fail the rule (no fix without classification + named root cause). The Rationalization Table needs counters for both patch-without-classify and rollback-without-diagnose.

## Outcome

FAIL — chose C. Subagent rolled back without declaring severity or naming root cause in writing. Skipped the classification gate entirely; framed rollback as "stop the bleed first, diagnose later."
