# Toolchain discovery — `/grade-codebase`

Step 2 of the skill. Before running any signal commands, detect the toolchain so the rubric is applied against what the repo *actually* uses, not against a hardcoded GitHub-Actions-plus-npm assumption.

Record the discovery results in the report's "Discovery preamble" — the reader needs to see what was assumed.

## Why this exists

The rubric's signals are framed as concepts ("CI runs the same commands the agent runs locally", "branch protection on `main`"). Each concept has multiple legitimate implementations. A GitLab CI + Pants + Gitea repo should be graded against the *concept*, not penalised for not using `.github/workflows/`.

If discovery comes back empty for a category, that's a finding — not a default. Say "no CI host detected" in the preamble, then grade D4 accordingly. Never silently substitute one tool for another.

## Categories to detect

### Forge (where the repo lives)

Parse `git remote -v` (or `git config --get remote.origin.url`):

| Pattern | Forge |
|---|---|
| `github.com[:/]` | GitHub |
| `gitlab.com[:/]` or self-hosted `gitlab.` | GitLab |
| `bitbucket.org[:/]` | Bitbucket |
| `dev.azure.com` / `visualstudio.com` | Azure DevOps |
| `git.sr.ht` | SourceHut |
| `codeberg.org` or `gitea.` / `forgejo.` in hostname | Gitea / Forgejo / Codeberg |
| anything else | "self-hosted / unknown" — flag in preamble |

Forge determines: which CLI is available for branch-protection queries (`gh`, `glab`, `tea`, none), and where the canonical CI config lives.

### CI host

Look for the first that exists:

| File / dir | CI host |
|---|---|
| `.github/workflows/*.yml` | GitHub Actions |
| `.gitlab-ci.yml` | GitLab CI |
| `.circleci/config.yml` | CircleCI |
| `.buildkite/pipeline.yml` or `.buildkite/*.yml` | Buildkite |
| `Jenkinsfile` | Jenkins |
| `.drone.yml` or `.drone/` | Drone |
| `azure-pipelines.yml` | Azure Pipelines |
| `bitbucket-pipelines.yml` | Bitbucket Pipelines |
| `.woodpecker.yml` or `.woodpecker/` | Woodpecker |
| `.teamcity/` | TeamCity |
| `appveyor.yml` | AppVeyor |
| `.github/workflows/` + `.gitlab-ci.yml` both present | Multi-CI — note both |
| none of the above | "no CI host detected" |

For D2 ("CI runs the same commands the agent runs locally"), parse the *detected* CI config — don't assume YAML schema; just `cat` it and look for the test/lint command strings.

### Task / build runner

Multiple may be present. Capture all:

| File | Runner |
|---|---|
| `Makefile` / `GNUmakefile` | make |
| `justfile` | just |
| `Taskfile.yml` | task |
| `mage.go` | mage |
| `BUILD.bazel` / `WORKSPACE` / `MODULE.bazel` | Bazel |
| `BUILD` / `pants.toml` | Pants |
| `nx.json` | Nx |
| `turbo.json` | Turborepo |
| `lerna.json` | Lerna |
| `pnpm-workspace.yaml` | pnpm workspaces |
| `rush.json` | Rush |
| `package.json` `scripts:` section | npm-scripts (default) |
| `pyproject.toml` `[tool.poetry.scripts]` / `[tool.hatch.envs]` | Poetry / Hatch |
| `noxfile.py` / `tox.ini` | Nox / Tox |
| none | "no task runner — direct invocation only" |

For D2's "one-command test", look at the *highest-level* runner that aggregates everything. A repo with `make test` that internally calls `pnpm test`, `pytest`, and `cargo test` passes; a repo where you have to run each manually doesn't.

### Branch-protection source

Determined by forge:

| Forge | Command (if CLI installed) | Fallback |
|---|---|---|
| GitHub | `gh api repos/:owner/:repo/branches/main/protection` | "not measured — `gh` not installed or not authed" |
| GitLab | `glab api projects/:id/protected_branches` | "not measured — `glab` not installed or not authed" |
| Gitea / Forgejo | `tea repos branches protections list` | "not measured" |
| other | — | "not measured — no CLI for this forge" |

**Never penalise** for branch protection being unmeasurable. Record "not measured" and proceed. Penalise only when the CLI is available, the repo is on a supported forge, and protection is *absent* on `main`.

### Containerisation / dev environment

Look for any of:

- `Dockerfile`, `docker-compose.yml` / `compose.yml`, `.devcontainer/devcontainer.json`, `flake.nix`, `shell.nix`, `default.nix`, `.tool-versions` (asdf/mise), `mise.toml`, `.nvmrc` + `.python-version` + `.ruby-version`, `Dockerfile.dev`.

Record what was found. Multiple is fine. None is itself a D6 finding.

### Lockfiles

For D6 (reproducibility). At least one of:

`package-lock.json`, `pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`, `poetry.lock`, `pdm.lock`, `uv.lock`, `Pipfile.lock`, `requirements.txt` (only if pinned), `Cargo.lock`, `go.sum`, `Gemfile.lock`, `composer.lock`, `mix.lock`, `gradle.lockfile`, `pubspec.lock`, `flake.lock`.

### Secrets scanner

Look for: `.gitleaks.toml`, `.trufflehog.yaml`, `.secrets.baseline` (detect-secrets), a `secret-scan` job in the detected CI config, or repo-level secret scanning enabled (forge-specific — note as "not measured from filesystem" if so).

## Output shape

After discovery, emit a structured block the report template's "Discovery preamble" can render verbatim:

```
Forge: GitHub
CI host: GitHub Actions (.github/workflows/ci.yml, .github/workflows/release.yml)
Task runner: make (top-level), npm-scripts (per-package)
Branch-protection source: gh CLI available
Containerisation: Dockerfile, docker-compose.yml
Lockfile(s): pnpm-lock.yaml
Secrets scanner: gitleaks (.gitleaks.toml)
Primary language: TypeScript (76%), Python (18%), other (6%)
Monorepo: yes (pnpm workspaces)
```

When a category is empty, write `none detected` — not `n/a` and not omit. The absence is a finding.

## What this discovery is *not*

- Not a guess. If you can't see the file, it's not detected.
- Not a network call. No `gh api` / `glab api` until step 3 (running signals), and then only against the forge confirmed here.
- Not a place to score. Discovery is observation; scoring happens against the rubric in step 3 onward.
