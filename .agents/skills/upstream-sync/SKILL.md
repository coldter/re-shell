---
name: upstream-sync
user-invocable: false
description: >
  Port new upstream commits from the original Nix-based schlarpc/re-shell flake into this
  repo's mise environment. Use when asked to fetch/check out upstream, see what changed
  upstream, bring upstream commits over, sync the mise port against upstream, or audit
  whether the fork is behind. Covers fork-point reconnaissance, per-change Nix-to-mise
  translation (tool backends, env vars, Python deps, platform gating), subagent
  orchestration for docs and independent verification, mise.lock/uv.lock hygiene, smoke
  tests, and the commit/definition-of-done.
---

# Upstream Sync: Nix flake -> mise port

Process for pulling `schlarpc/re-shell` changes into this mise fork. The goal is to port
*intent*, not files: upstream edits `flake.nix`, we own `mise.toml` + `mise.lock` +
`pyproject.toml`/`uv.lock` + docs.

## TL;DR run order

0. Recon the **net** diff and count commits.
1. Classify every net change; map each to a mise mechanism.
2. Resolve real design forks with the user (large downloads, platform scope).
3. Main agent edits config + lockfiles. Background subagent ports docs. Separate
   read-only subagent verifies.
4. Lock, install, smoke test.
5. Verify, then one commit.

## Repo invariants

- `origin` is `github.com/coldter/re-shell`; the working branch is `mise-migrate`.
- `main` is the untouched Nix fork; `mise-migrate` = `main` + the mise migration commit.
- `upstream` is `github.com/schlarpc/re-shell`. Add if missing:
  `git remote add upstream https://github.com/schlarpc/re-shell.git`
- **NEVER** `git merge upstream/main` into `mise-migrate`. It reintroduces `flake.nix`,
  `flake.lock`, `package.json`, `.npmrc`, `.envrc`, and other files the migration deleted.
  Port the semantic changes as a new commit instead.
- `mise.toml` + `mise.lock` are the source of truth for tools; `pyproject.toml` + `uv.lock`
  own Python libraries. Ghidra env vars live in `mise.toml [env]`.
- `.agents/` is gitignored (local agent state). Do not try to commit it.

## Phase 0 - Reconnaissance

```sh
git fetch upstream main --tags
base=$(git merge-base main upstream/main)
git log --oneline --reverse "$base"..upstream/main          # count and order
git log --oneline "$base"..upstream/main | wc -l
git diff --stat "$base" upstream/main                        # net file changes
git diff "$base" upstream/main -- <non-nix files>            # docs/deps to port
git diff "$base" upstream/main -- flake.nix                  # tools/env to translate
```

Rules:

- Analyze the **net diff** `main..upstream/main`, never individual merge commits. Upstream
  regularly merges contributor branches (e.g. mxr's `document` and `darwin-support`); those
  merge commits repeat content and will double-count changes.
- The fork point may not be `main`'s tip if `mise-migrate` is not checked out. Record the
  upstream tip hash; it goes in the commit message.
- Read the whole `flake.nix` diff, because package-list moves and `lib.optionals` gates are
  easy to miss in the `--stat` view.

## Phase 1 - Classify and map

Build a table of every semantic change before touching files:

| Category | Upstream form | Action |
|---|---|---|
| New/removed CLI tool | `pkgs.foo` | Find a mise backend (see table below) |
| Runtime pin | `pkgs.python313` | `[tools]` version intent, keep readable (`python = "3.13"`) |
| Python library | `pyproject.toml` + `uv.lock` | Apply upstream's diff, then `uv sync --locked` |
| Env var | `env = { FOO = ... }` | `[env] FOO = ...`; use `tools = true` if it references `tools.X.path` |
| Output/API surface | `devShells`/`packages`/`lib` | Document mise's equivalent (`mise install`/`mise exec`) |
| Platform gate | `lib.optionals isLinux [...]` | `os = [...]` on the tool |
| Setup workflow | `shellHook`, README | `[tasks.*]`, README quick start |
| Nix-only workaround | buildEnv collision fix | Usually not needed in mise; verify before porting |

### Nix -> mise mapping table

| Nix construct | mise port |
|---|---|
| `pkgs.<cli>` | `mise registry <name>`; if absent, explicit backend (`github:`/`aqua:`/...) |
| GitHub binary releases | `github:owner/repo` with `matching`, `matching_regex`, `asset_pattern`, `bin`, `rename_exe`, `strip_components`, `prerelease` |
| PyPI CLI | `pipx:<pkg>` in `[tool_alias]`; `[tools]` entry with `depends = ["uv", "python"]` |
| npm CLI | `npm:<pkg>` with `depends = ["node"]` |
| Rust CLI | `cargo:<crate>` (slow, version-locked only) or a GitHub release if one exists |
| Python library | `pyproject.toml` + `uv.lock` only, never pipx |
| `pkgs.python3` -> `python313` | `python = "3.13"`; **coupled to `uv.lock`** - bump both together |
| `env = {...}` | `[env]`; tool-derived values use `{ value = "{{ tools.X.path }}", tools = true }` |
| `lib.optionals stdenv.isLinux` | `os = ["linux"]` (also `"macos"`/`"darwin"`, `"windows"`, and `"macos/arm64"` forms) |
| `binutils-unwrapped-all-targets` | No portable equivalent exists. Use a vendor cross toolchain (e.g. Espressif `xtensa-esp-elf`) or OS tier, and document the gap |
| `packages.re-tools`, `lib.envVars` | `mise.toml` itself; `mise install` + `mise exec` covers both. Document, don't rebuild |
| `flake.lock` / nixpkgs pin | `mise.lock`; only `python` pin is coupled to `uv.lock` |

### Backend selection order

1. Core registry / short name (`mise registry <name>`).
2. `aqua:owner/repo` (widest coverage; check the aqua registry even if mise's registry is empty).
3. `github:owner/repo` (check actual assets with `gh release view`).
4. `pipx:` for Python CLIs, `npm:` for Node CLIs.
5. `cargo:` / `vfox:` when no binary release exists.
6. OS/system tier (`scripts/check-system.sh`, `MISE-MIGRATION.md` §5/§6) as the last resort.

"Not in mise's registry" does **not** mean OS-only. Every tool gets an explicit backend
review, and any new backend is smoke-installed in a scratch project first.

### Scratch-project backend test

```sh
mkdir -p /tmp/opencode/probe && cd /tmp/opencode/probe
cat > mise.toml <<'EOF'
[tools]
"github:EFForg/apkeep" = { version = "latest", matching = "x86_64-unknown-linux-gnu" }
EOF
export GITHUB_TOKEN=$(gh auth token)
mise install
ls ~/.local/share/mise/installs/          # find the install dir
~/.local/share/mise/installs/<dir>/latest/<bin> --version
```

Installations land in the shared mise store, so the real project install afterwards is
fast. `gh release view --repo owner/repo --json assets --jq '.assets[].name'` shows the
exact per-platform asset names (including whether a macOS/Windows artifact exists at all).

## Phase 2 - Resolve real forks with the user

Ask (question tool) only when a decision is genuinely the user's:

- Adding large toolchains (state download and installed sizes, e.g. Espressif
  `xtensa-esp-elf` is ~84 MB download / ~563 MB installed).
- Whether to port platform-support work (e.g. aarch64-darwin gating) or stay Linux-only.
- Any upstream capability with no clean mise equivalent.

Do not ask about things with an obvious best answer; make the small calls and document them.

## Phase 3 - Parallel execution with subagents

Division of labor that works:

- **Main agent (owns state):** `mise.toml`, `mise.lock`, `pyproject.toml`, `uv.lock`,
  `scripts/*`. Lock regeneration/dev installs are stateful; keep them in one place.
- **Subagent A - docs port (background, `general`):** one writer for `CLAUDE.md`, discipline
  skill files, `README.md`, `MISE-MIGRATION.md`. Fresh context, so the prompt must contain:
  - repo path and that `upstream` is already fetched;
  - the exact files to edit and the exact files to **never** touch (all config/locks);
  - the mapping from each upstream doc hunk to mise wording;
  - that it must run `git diff main upstream/main -- <files>` itself and adapt, not apply;
  - a required final report (`git diff --stat` + per-file summary).
- **Subagent B - verification (background, `general`, READ-ONLY):** runs after edits.
  Forbid all writes and all `mise install/lock/up`, `uv sync/add`, and commits. Require a
  per-item PASS/FAIL/GAP report with command evidence. Checklist in Phase 6.
- Never two writers on one file; never let a subagent regenerate lockfiles or commit.

Subagent prompts must state the definition of "correct" (the mapping table), the constraints,
and what evidence to return. Vague prompts produce duplicate or contradictory work.

## Phase 4 - Config, deps, lockfiles

```sh
export GITHUB_TOKEN=$(gh auth token)     # REQUIRED: gh stores its token in the keyring and
                                         # mise cannot read it; without this, GitHub API
                                         # rate limits break lock/install
mise fmt --check                          # config must already be clean
mise lock                                 # additive; preserves existing pins
git diff --stat mise.lock                 # must add only the new/changed tools
grep '^\[\[tools\.' mise.lock | sort | uniq -d   # must print nothing
mise install                              # project install; [tool_config] locked = true
```

Lockfile gotchas (all seen in practice):

- **Stale option-scoped sections.** Same tool, changed options (removing `matching`, adding
  `os`, ...) => `mise lock` appends a second `[[tools.X]]` section and leaves the old one.
  Repair: delete the stale block(s), re-run `mise lock`. Never hand-edit anything else.
- **Cross-platform wrong picks.** The lock resolves *all* platforms, including ones you do
  not use. A too-broad `matching_regex` can resolve a Windows entry to the wrong asset
  (e.g. Espressif `esp8266-multilib` because no standard Windows `.tar.xz` exists). Inspect
  every platform entry of every new tool and tighten the regex; it is fine for a platform
  with no matching asset to have no entry when the tool is gated away there anyway.
- **Never `--bump`** during a port. It re-resolves every `latest` selector and buries the
  port in unrelated upgrades.
- Do not run `mise install --locked` locally: it also tries to lock *global* config tools
  that have no project lock entry. `[tool_config] locked = true` already enforces the
  project lock; `--locked` is for clean checkouts/CI.

Python deps: when the fork point matches, upstream's `pyproject.toml`/`uv.lock` diff applies
directly:
```sh
git diff main upstream/main -- pyproject.toml uv.lock | git apply --check
git diff main upstream/main -- pyproject.toml uv.lock | git apply
mise run setup-deps
mise exec -- python -c 'import <newlibs>'
```

## Phase 5 - Documentation port

Upstream's docs are written for Nix; translate them, never copy them verbatim.

- `CLAUDE.md`: tool tables, Python library table, workflow notes (e.g. `uv.lock` <->
  `python` pin coupling), platform caveats, and any "why this tool is here" explanation.
- Discipline skill: `.claude/skills/<discipline>/SKILL.md` gets discipline-specific tools
  (e.g. apkeep under Android).
- `README.md`: only prerequisites change; mise quick start already exists.
- `MISE-MIGRATION.md`: **append** a new final section, never rewrite history:

  ```markdown
  ## N. Post-migration: upstream sync (YYYY-MM-DD)

  Ported schlarpc/re-shell upstream `main` (<count> commits, through `<tip>`) into the mise environment:

  * **New tools.** ...
  * **Adaptations.** (e.g. all-targets binutils -> vendor toolchain)
  * **Python dependencies.** ...
  * **Platform gating.** ...
  * **Docs.** ...
  ```

- `scripts/check-system.sh`: update OS-tier expectations; keep the non-Linux guard at the
  top (the pacman/ldconfig checks are Linux-only).
- Audit for reintroduced Nix wording:
  `git grep -n -iE 'flake|nixpkgs|/nix/store|nix develop|direnv' -- '*.md' '*.toml' '*.sh'`.
  Only historical references inside `MISE-MIGRATION.md` are acceptable.
- Verify every documented command exists:
  `mise exec -- sh -c 'command -v <tool1> <tool2>'`, and run it once.

## Phase 6 - Independent verification and commit

Verifier must prove, with evidence:

- **A. Coverage:** every semantic change in `git diff main upstream/main` appears in the
  port or is documented as not applicable.
- **B. Config:** `mise config ls`, `mise fmt --check`, `mise ls --current` succeed.
- **C. Lock:** no duplicate `[[tools.*]]`; new entries resolve to the intended assets;
  no unrelated existing version/url/checksum changed.
- **D. Python:** `git diff 0800320 -- pyproject.toml uv.lock` equals upstream's diff
  (`git diff main upstream/main -- pyproject.toml uv.lock`).
- **E. Docs:** no Nix wording; documented commands exist; anchors work.
- **F. Scripts:** `bash -n scripts/check-system.sh` and running it exits 0.
- **G. Scope:** `git status --short` shows only expected files, nothing untracked.
- **H. Platform claims:** every tool is either `os`-gated or known to publish assets for the
  platforms claimed in docs.

Then smoke test and commit once:

```sh
mise install
mise exec -- <new-tool> --version
git add mise.toml mise.lock pyproject.toml uv.lock CLAUDE.md README.md \
        MISE-MIGRATION.md .claude/skills/<discipline>/SKILL.md scripts/check-system.sh
git commit -m "Port upstream <tip>: <one-line summary>"
```

Commit body: upstream commit range, tools/deps added, adaptations, platform gating.

## Worked example - sync of 2026-09-11

11 upstream commits from fork point `0800320` through `fd9d858`:

| Upstream | Meaning | Port |
|---|---|---|
| `08b0e96` | esptool, apkeep, all-targets binutils | `pipx:esptool`, `github:EFForg/apkeep`, Espressif `xtensa-esp-elf` |
| `9b5b553` | pin `python313` | already `python = "3.13"`; docs note |
| `1db03b7` | uv.lock/nixpkgs coupling | CLAUDE.md `uv.lock` <-> python pin note |
| `0882b13` | bleak, pyserial, hidapi | pyproject + uv.lock; USB/library docs |
| `4fa830d` + `70bdbc5` | flake tools/envVars/re-tools outputs | CLAUDE.md "mise.toml is single source" paragraph |
| `dfe2c06` | README prerequisites | mise install + `mise trust` lines |
| `2109541` + merges | aarch64-darwin gating | `os = [...]` on pe-bear/hid-tools/rizin/apkeep; dropped `matching = "linux"` from floss/yr; check-system guard |

Lessons specific to this sync: apkeep 1.0.0 has no macOS asset; `floss`/`yr` had
Linux-only `matching` that would break macOS autodetection; Espressif's release needs
`matching = "xtensa-esp-elf"` plus `matching_regex = "(x86_64|aarch64)-(linux-gnu|apple-darwin)\\.tar\\.xz$"`
to avoid riscv32/debug-sections/esp8266-multilib/i586 assets; mise's GitHub backend installs
bare binaries fine (apkeep) and auto-strips the OS/arch suffix.

## Definition of done

- [ ] Net upstream diff fully classified; no semantic change unaccounted for.
- [ ] Every new tool has a tested backend, a version entry, and (if needed) `os` gating.
- [ ] `mise fmt --check` clean; `mise.lock` has no duplicates and no unrelated changes.
- [ ] `mise install` succeeds; every new binary smoke-tested.
- [ ] Python deps applied and import-tested.
- [ ] Docs translated, `MISE-MIGRATION.md` appended, no Nix wording reintroduced.
- [ ] Read-only verification subagent PASS (or gaps fixed).
- [ ] One commit on `mise-migrate` with upstream range in the message.
