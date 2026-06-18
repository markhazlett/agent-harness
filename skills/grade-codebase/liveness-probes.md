# Liveness probes — `/grade-codebase` step 4

The mechanical signals in step 3 detect **configuration** — a doc exists, a lint config is present, a test command runs. Configuration is cheap and fakeable. These probes test whether the configuration is **enforced, current, and honest**. They are the reason this skill exists: running step 3 alone produces a false A on any repo full of present-but-dead artifacts (a stale `CLAUDE.md`, an all-green suite that asserts nothing, a CI lint job set to `continue-on-error`).

**Rule: a dimension with a liveness probe cannot score above C until that probe is *run*.** If you can't run it (no CLI, no clean checkout, no network), record `not verified` and cap the dimension at C. "Unverified" is never "passing." See rubric §4 (present-but-misleading scores below absent) and §5 (the probe table).

## D1 — context accuracy, freshness, feedback loop (the false-A guard)

This is the probe the stale-`.ai/` repo defeated. Do all three:

1. **Follow references.** If `CLAUDE.md`/`AGENTS.md` points at another file or folder (`.ai/`, `docs/agent/`, `.cursor/rules/`), open it. That referenced content *is* the onboarding context — grade it, don't just confirm the pointer resolves.
2. **Verify 3–5 concrete claims.** Pull specific, checkable claims from the doc(s) and test each:
   - a **command** ("run `make test`") → does the target exist? (`make -n test`, `--help`, dry-run — don't execute anything destructive)
   - a **path** ("services live in `packages/`") → `test -e`
   - a **convention / helper** ("all DB access goes through `db.query`") → grep; does the real code agree?

   Record each as pass/fail with the evidence. **If ≥1 of 3 sampled claims is false, the doc is *misleading*** — score D1 **D or F**, not C, and apply the §4 compounding-context cap (overall grade capped at C). A wrong doc is worse than no doc.
3. **Freshness.** Compare the context doc's last-touched date against the churn of the code it describes:
   - `git log -1 --format=%cr -- <context-doc-and-referenced-paths>`
   - `git log --since='6 months ago' --name-only --pretty=format: -- <top source dirs> | sort | uniq -c | sort -rn | head`

   Doc untouched while its subject churned heavily = stale → at most C, and a freshness fail plus any false claim → D/F.
4. **Feedback loop.** Is there a mechanism to keep context current? Look for a learnings dir (`docs/learnings/`, `.ai/learnings/`), dated entries in the doc, a `/learn`-style capture skill, or explicit "update this when X changes" instructions. Absence isn't an automatic fail, but it's the anti-signal that *predicts* the doc will be stale at the next grade — note it and dock toward C if freshness is already borderline.

## D2 — does the suite assert anything?

A fast green is not an A if the green is empty. Grep the test tree for `\.skip|\.todo|xfail|@pytest.mark.skip|t.Skip|it\.only`; sample 3–5 test bodies and confirm they contain real assertions, not `expect(true).toBe(true)` or assertion-free bodies. A suite where a meaningful fraction is skipped/empty → rubric §6 #17 fires.

## D4 — is the gate *required*, not just defined?

A workflow file existing ≠ a gate. Check the *detected* CI config (discovery preamble) for `continue-on-error: true` on lint/typecheck/test jobs, and check branch protection (forge CLI from discovery) for whether those checks are **required status checks** — not merely defined workflows. A gate that doesn't block merge is rubric §6 #16.

## D6 — is the environment actually reproducible?

- **Lockfile in sync:** the package manager's verify/check mode (`npm ci --dry-run`, `pnpm install --frozen-lockfile --dry-run`, `poetry lock --check`, `cargo verify-project`, `uv lock --check`). Drift → §6 #18.
- **`.env.example` complete:** grep the code for env reads (`process.env.X`, `os.environ[...]`, `std::env::var`) and diff the keys against `.env.example`. Missing keys = the agent boots into a broken env.

## D7 / D8 / D10 — used, not just installed

- **D7:** a feature-flag library in deps → grep for actual flag *checks* in code, not just the import. ADR folder → are the ADRs current, or do they describe decisions the code has since reversed? (sample one, check against reality)
- **D8:** the "canonical example" → is it the pattern the *rest* of the code follows, or is it contradicted by the files the agent will actually pattern-match against? Sample 2–3 sibling implementations.
- **D10:** structured-logging library in deps → grep error sites; is it populated with useful keys (`user_id`, `trace_id`), or imported and unused?

## Recording

Every probe result goes in the report with its evidence (command + result, or grep + count). A probe you didn't run is `not verified`, caps its dimension at C, and must be named as such in the report — never silently treated as a pass.
