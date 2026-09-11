# re-shell

A mise-based reverse engineering environment designed for use with [Claude Code](https://docs.anthropic.com/en/docs/claude-code). Drop in a binary, capture, or archive and ask Claude to analyze it -- the right tools and context activate automatically.

## Quick start

```sh
# One-time: installs mise if you don't have it (https://mise.jdx.dev)
curl https://mise.run | sh

# One-time: activate mise in your interactive shell (already done on this machine)
eval "$(mise activate bash)"

# Enter the environment
cd re-shell            # tools auto-install on first enter

# First run only: approve this repo's mise.toml
mise trust

# Bootstrap project-local resources (venv, pico-sdk, wordlists)
mise run setup

# Then start Claude Code
cp ~/Downloads/suspicious.exe .
claude

# And just ask:
#   "Reverse engineer suspicious.exe"
#   "Decompile this APK and find hardcoded API keys"
#   "Analyze this HAR file for undocumented API endpoints"
```

## How it works

The environment bundles a full reverse engineering toolchain (Ghidra, radare2, Frida, mitmproxy, YARA, and more) into a single [mise](https://mise.jdx.dev) config (`mise.toml` + `mise.lock`). Tools are pinned, checksummed, and reproducible. Claude Code is configured via `CLAUDE.md` with discipline-specific **skills** that auto-activate based on file type and context:

| Skill | Activates on | Example files |
|-------|-------------|---------------|
| Windows RE | PE binaries, .NET assemblies, drivers | `.exe`, `.dll`, `.sys` |
| Android RE | Android packages, DEX bytecode | `.apk`, `.xapk` |
| Web RE | HTTP captures, API traffic, protobufs | `.har`, `.proto` |

When Claude detects relevant context, the matching skill loads specialized tool documentation and workflows -- no manual configuration needed.

## Tool tiers

- **mise-managed** (everything in `mise.toml`): runtimes, GitHub/aqua/pipx/npm release tools. Install with `mise install` (this repo's `[tool_config] locked` enforces the lockfile locally; `--locked` is for CI/clean checkouts). Update with `mise up`.
- **Project-local state** (gitignored): `.venv/`, `.mise/sources/` (pico-sdk, SecLists, rockyou), `wordlists/`, `tmp/`.
- **OS tier** (optional, never auto-installed): system daemons, hardware/GPU tools, and GUI binaries without portable releases. `mise run check-system` reports what's missing. See `MISE-MIGRATION.md` for the full tier table.

## Adding tools

The environment is self-modifying. If an analysis needs something that isn't installed:

- **mise tools:** edit `mise.toml` (tools/aliases) or `mise use <name>`, then `mise install`; commit `mise.toml` + `mise.lock` together.
- **Python packages:** `uv add <pkg>` then `mise run setup-deps`
- **Node packages:** `npm install <pkg>` (project-local; see `package.json` if added back)

**Never** run `mise use -g` / `mise set -g` in this repo -- it would pollute your global config.

## Output directories

- **`tmp/`** -- Intermediate work products (gitignored)
- **`artifacts/`** -- Final deliverables like reports and analysis notes (gitignored)
