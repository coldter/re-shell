# Migrating re-shell from Nix to mise

> **Status:** implemented **·** Date: 2026-08-27 **·** Validated with: mise 2026.8.14 on Linux x64

This is the implementation plan for replacing `flake.nix`/`flake.lock` with a mise-first environment. Mise owns development tools and project tasks; the operating system owns hardware integration, daemons, drivers, and libraries that do not have a useful portable release artifact.

## 1. Re-evaluation result

The first draft had four issues:

1. **Activation:** mise's current documentation says that using direnv with mise is deprecated and unsupported. Use one normal `eval "$(mise activate bash)"` installation in the user's interactive shell. `.envrc` is removed unless it is needed for unrelated, non-mise variables.
2. **Dependency setup:** `sources` by itself does not make a task up-to-date. The dependency task must declare both `sources` and `outputs`. `mise deps` can do this too, but it is currently experimental; the stable task form is the project default.
3. **Node CLIs:** `apk-mitm` and `asar` are tools, not project libraries. Install them with mise's native `npm:` backend; do not retain `package.json`, `package-lock.json`, `node_modules`, or a PATH hack solely for those CLIs.
4. **Backend coverage:** "no aqua entry" does not mean "OS-only." mise also has native GitHub, pipx, npm, cargo, go, HTTP, and vfox backends. Every tool gets an explicit backend review before being assigned to pacman/AUR.

The result remains Linux/Arch-oriented for hardware and GUI portions of the toolchain, while portable tools are mise-managed and lockable where their backend supports lock URLs/checksums.

## 2. Mise policy

* `mise.toml` is the sole project configuration. Do not use `mise use -g`, `mise set -g`, or `mise tool-alias set` for this project.
* The user's global mise install/cache (`~/.local/share/mise`, `~/.cache/mise`) remains shared. This project does not write global tool selections.
* Keep the project minimum at the oldest mise release supporting the committed syntax. The migration baseline is 2026.8.14; do not pin a particular mise executable in the repository.
* Enable the project lockfile and scope strict locking to this config root. `mise.lock` is generated, never hand-edited, and committed with `mise.toml`.
* Keep version intent readable in `mise.toml` (`24`, `3.13`, or `latest` where appropriate) and let `mise.lock` pin exact versions, URLs, and checksums. Update with `mise lock`/`mise up`, review the diff, and commit both files.
* Do not put secrets, credentials, or host-specific absolute paths in project config.

See the current [configuration](https://mise.jdx.dev/configuration.html), [lockfile](https://mise.jdx.dev/dev-tools/mise-lock.html), [backend](https://mise.jdx.dev/dev-tools/backends/), and [GitHub asset](https://mise.jdx.dev/dev-tools/backends/github.html) documentation.

## 3. Activation

Activate mise once in the interactive shell, after other PATH modifications:

```sh
eval "$(mise activate bash)"
```

This is a user bootstrap, not a project-global tool selection. It lets mise add and remove this project's PATH and environment as the user changes directories. For CI, scripts, and IDE terminals, use `mise exec -- ...` or shims instead of relying on a prompt hook.

The existing `.envrc` is a nix-direnv loader and will be deleted. Do not replace it with `eval "$(mise activate bash)"`; mise's current guidance explicitly discourages using direnv to manage the same PATH. If direnv is retained for an unrelated variable, it must not manage mise's PATH.

## 4. `mise.toml` to implement

This is the intended shape. Release asset filters and executable names must be confirmed by `mise install` on the target platform before the lockfile is committed.

```toml
min_version = { hard = "2026.8.0" }

[settings]
lockfile = true

# Project-root policy; unlike [settings].locked, this does not pull global
# tools into this project's lock policy.
[tool_config]
locked = true

[tool_alias]
# GitHub release assets
ghidra = "github:NationalSecurityAgency/ghidra"
jadx = "github:skylot/jadx"
dex2jar = "github:pxb1988/dex2jar"
pe-bear = "github:hasherezade/pe-bear"
floss = "github:mandiant/flare-floss"
payload-dumper-go = "github:ssut/payload-dumper-go"
curl-impersonate = "github:lexiforest/curl-impersonate"
yr = "github:VirusTotal/yara-x"
rizin = "github:rizinorg/rizin"
scrcpy = "github:Genymobile/scrcpy"

# PyPI applications (pipx uses uvx automatically when uv is installed)
frida-tools = "pipx:frida-tools"
apkid = "pipx:apkid"
apksigcopier = "pipx:apksigcopier"
jnitrace = "pipx:jnitrace"
trueseeing = "pipx:trueseeing"
quark-engine = "pipx:quark-engine"
koodousfinder = "pipx:koodousfinder"
volatility3 = "pipx:volatility3"
httpie = "pipx:httpie"
hid-tools = "pipx:hid-tools"

# Standalone npm applications
apk-mitm = "npm:apk-mitm"
asar = "npm:asar"

# Aqua entries without a useful short name
grpcui = "aqua:fullstorydev/grpcui"
pup = "aqua:ericchiang/pup"

[tools]
# Node 24 is the current LTS line; Ghidra 12.1 requires JDK 21.
# Python 3.13: 3.14 is blocked by missing cp314 wheels for yara-python and
# yara-python-dex (apkid dep); revisit when upstream ships cp314.
python = "3.13"
node = "24"
java = "temurin-21"
uv = "latest"

# Portable binary releases / registry tools
ghidra = "latest"
jadx = "latest"
dex2jar = "latest"
pe-bear = { version = "latest", matching = "qt6.4.2_x64_linux" }
floss = { version = "latest", matching = "linux" }
payload-dumper-go = "latest"
curl-impersonate = { version = "latest", matching_regex = "^curl-impersonate-v", prerelease = true }
yr = { version = "latest", matching = "linux" }
rizin = { version = "latest", matching = "-static-x86_64" }
scrcpy = "latest"
grpcui = "latest"
pup = "latest"
protoc = "latest"
grpcurl = "latest"
websocat = "latest"
upx = "latest"
cmake = "latest"
gcc-arm-none-eabi = "latest"
jq = "latest"

# Python CLI applications. `depends` controls install order only.
frida-tools = { version = "latest", depends = ["uv", "python"] }
apkid = { version = "latest", depends = ["uv", "python"] }
apksigcopier = { version = "latest", depends = ["uv", "python"] }
jnitrace = { version = "latest", depends = ["uv", "python"] }
trueseeing = { version = "latest", depends = ["uv", "python"] }
quark-engine = { version = "latest", depends = ["uv", "python"] }
koodousfinder = { version = "latest", depends = ["uv", "python"] }
volatility3 = { version = "latest", depends = ["uv", "python"] }
httpie = { version = "latest", depends = ["uv", "python"] }
hid-tools = { version = "latest", depends = ["uv", "python"] }
mitmproxy = { version = "latest", depends = ["uv", "python"] }

# The npm backend gives each CLI its own mise-managed install.
apk-mitm = { version = "latest", depends = ["node"] }
asar = { version = "latest", depends = ["node"] }

[env]
_.path = ["{{ config_root }}/.venv/bin"]
PYTHONPATH = false
VIRTUAL_ENV = "{{ config_root }}/.venv"
GHIDRA_INSTALL_DIR = { value = "{{ tools.ghidra.path }}", tools = true }
GHIDRA_JAVA_HOME = { value = "{{ env.JAVA_HOME }}", tools = true }
PICO_SDK_PATH = "{{ config_root }}/.mise/sources/pico-sdk"

[tasks.setup]
description = "Prepare Python, Pico SDK, wordlists, and local links"
depends = ["setup-deps", "setup-pico", "setup-wordlists", "setup-local"]

[tasks.setup-deps]
description = "Sync locked Python project dependencies"
sources = ["pyproject.toml", "uv.lock"]
outputs = [".venv/.mise-synced"]
run = "uv sync --locked && touch .venv/.mise-synced"

[tasks.setup-pico]
description = "Fetch the pinned Pico SDK into project-local state"
sources = ["mise.toml", "sources.lock"]
outputs = [".mise/sources/.pico-sdk-ready"]
run = '''
set -e
src=".mise/sources/pico-sdk"
ref="$(awk '$1 == "pico-sdk" { print $2 }' sources.lock)"
commit="$(awk '$1 == "pico-sdk" { print $3 }' sources.lock)"
if [ ! -f .mise/sources/.pico-sdk-ready ]; then
  if [ ! -f "$src/pico_sdk_init.cmake" ]; then
    mkdir -p .mise/sources
    git clone --quiet --depth 1 --branch "$ref" https://github.com/raspberrypi/pico-sdk "$src"
  fi
  git -C "$src" checkout --quiet --detach "$commit"
  test "$(git -C "$src" rev-parse HEAD)" = "$commit"
  touch .mise/sources/.pico-sdk-ready
fi
'''

[tasks.setup-wordlists]
description = "Fetch sparse SecLists and extract rockyou"
sources = ["mise.toml", "sources.lock"]
outputs = [".mise/sources/.wordlists-ready"]
run = '''
set -e
if [ ! -f .mise/sources/.wordlists-ready ]; then
  ref="$(awk '$1 == "SecLists" { print $2 }' sources.lock)"
  commit="$(awk '$1 == "SecLists" { print $3 }' sources.lock)"
  mkdir -p .mise/sources
  if [ ! -d .mise/sources/SecLists/.git ]; then
    git clone --quiet --depth 1 --filter=blob:none --sparse --branch "$ref" \
      https://github.com/danielmiessler/SecLists .mise/sources/SecLists
  fi
  git -C .mise/sources/SecLists checkout --quiet --detach "$commit"
  test "$(git -C .mise/sources/SecLists rev-parse HEAD)" = "$commit"
  git -C .mise/sources/SecLists sparse-checkout set Passwords Discovery Fuzzing
  if [ ! -f .mise/sources/rockyou.txt ]; then
    tar -xzf .mise/sources/SecLists/Passwords/Leaked-Databases/rockyou.txt.tar.gz \
      -C .mise/sources rockyou.txt
  fi
  touch .mise/sources/.wordlists-ready
fi
'''

[tasks.setup-local]
description = "Create scratch space and wordlist links"
run = '''
set -e
mkdir -p tmp/jtmp wordlists
ln -sfn "$PWD/.mise/sources/SecLists" wordlists/seclists
ln -sfn "$PWD/.mise/sources/rockyou.txt" wordlists/rockyou.txt
for pair in \
  "/usr/share/hashcat/rules:hashcat-rules" \
  "/usr/share/john/rules:john-rules" \
  "/usr/share/john/rules/best64.rule:best64.rule" \
  "/usr/share/john/password.lst:john-password.lst"; do
  src="${pair%%:*}"; name="${pair##*:}"
  [ -e "$src" ] && ln -sfn "$src" "wordlists/$name"
done
'''

[tasks.check-system]
description = "Report optional OS, hardware, GUI, and daemon tools (never install)"
run = "scripts/check-system.sh"
```

The `setup-*` tasks explicitly download mutable source/data trees. They do not run as an enter/install hook. This keeps `cd` and `mise install` predictable; run `mise run setup` when project-local resources are wanted.

`sources.lock` is a small committed text lock for the two Git checkouts. It is created during migration with the resolved commit IDs (replace the placeholders before running setup):

```
# name ref-or-branch full-commit-sha
pico-sdk 2.3.0 98a542c1a62fb549ffb5d66a3e5892b06276b670
SecLists master 830924cd2b522d82b870b37fd761a06c0f6b2bc8
```

The setup tasks detach at those commits and verify `git rev-parse HEAD`; `mise.lock` cannot lock arbitrary source trees.

The dependency task has both `sources` and `outputs`. A `sources` list alone only informs `mise watch`; it does not skip a fresh task. The inline task body is also automatically considered a source, so changing a pinned ref or sparse path invalidates the task.

## 5. Tool backend matrix (resolved)

Executable names below were verified by installing each tool and resolving its binaries:

### Managed by mise

| Tools | Backend | Notes |
|---|---|---|
| Python 3.13, Node 24, Java 21, uv | core / aqua | Python 3.13 pinned (see §9); Node 24 LTS; Java temurin-21 for Ghidra 12.1 |
| Ghidra | `github:` | exe `ghidraRun`; tag `Ghidra_12.1.3_build`; checksum locked |
| JADX, dex2jar | `github:` | exe `jadx`; dex2jar v2.4 is the unified **`dex-tools`** CLI (no `d2j-*` scripts) |
| PE-bear | `github:` | `matching = qt6.4.2_x64_linux`; exe `bin/PE-bear` (GUI) |
| FLOSS | `github:` | exe `floss` |
| payload-dumper-go | `github:` | exe `payload-dumper-go` |
| curl-impersonate | `github:` | `prerelease = true`; exes `curl_chrome*` / `curl_firefox*` |
| YARA-X | `github:VirusTotal/yara-x` | **exe is `yr`**, not `yara` (verified in the v1.20.0 tarball); classic `yara` is a separate optional system tool |
| rizin | `github:rizinorg/rizin` | `matching = -static-x86_64`; static tarball exposes `bin/rizin` + `rz-*` |
| scrcpy | `github:Genymobile/scrcpy` | aqua registry entry stops at v2/v3; v4.1 linux asset `scrcpy-linux-x86_64-v4.1.tar.gz` |
| grpcui, pup, protoc, grpcurl, websocat, upx, cmake, jq | `aqua:` | verified assets: grpcui 1.5.2, pup 0.4.0, protoc 36.0, grpcurl 1.9.3, websocat 1.14.1, upx 5.2.0, cmake 4.4.3, jq 1.8.2 |
| gcc-arm-none-eabi | vfox registry | installed 13.3.Rel1; exe `arm-none-eabi-gcc` |
| Frida tools, apkid, apksigcopier, jnitrace, trueseeing, quark-engine, koodousfinder, volatility3, httpie, hid-tools, mitmproxy | `pipx:` | uvx-backed; console scripts verified (volatility3 = **`vol`**, quark-engine = `quark`/`freshquark`, hid-tools = `hid-decode`…) |
| apk-mitm, asar | `npm:` | standalone CLIs confirmed; removed `package.json`/`package-lock.json`/`.npmrc` |

### OS/system tier (intentional)

Keep these out of `mise.toml` unless a verified portable artifact is found:

* **Hardware/privileged/daemon integration:** `ddcutil`, `i2c-tools`, `usbutils`, `v4l-utils`/`edid-decode`, `libusb`, `hidapi`, `avahi`, and device permissions.
* **Network/system utilities:** `wireshark-cli`/`tshark`, `nmap`, and tools depending on system interfaces or capabilities.
* **GPU/cracking stack:** `hashcat` and `john`, including GPU drivers and OpenCL/CUDA/ROCm libraries.
* **OS/runtime integration:** Wine, winetricks, cabextract, msitools, Android `adb`/`fastboot`, Android SDK build-tools (`aapt2`, `apksigner`), ImHex, and Bytecode Viewer.
* **Libraries/base utilities:** `openssl`, `sqlite`, `file`, `binutils`, `curl`, `unzip`, `p7zip`, `xxd`, and `exiftool`; system installation preserves ABI/toolchain integration.
* **Source/build-heavy FPGA tools:** `yosys`, prjtrellis/`trellis`, and HAL until a maintained, verifiable release backend exists.

Individual backend checks were resolved as follows (formerly "require an individual backend check"; see §9 for evidence):

* **rizin** — added to mise via the `github:` static x86_64 release asset (see above).
* **binwalk** — not mise-managed: ReFirmLabs/binwalk retagged `v3.1.0` onto the Rust rewrite (no Python packaging remains in-repo; PyPI has a stale 2.1.0). Use the OS/AUR `binwalk` package until the Rust v4 ships installable binaries.
* **apktool, simg2img, sdat2img, imgpatchtools, osslsigncode, detect-it-easy, picotool, protoscope, hal-hardware-analyzer, radare2** — no installable Linux binaries on GitHub, no matching aqua/pipx/cargo/go/vfox artifact; documented as optional pacman/AUR/source tools. `check-system.sh` reports them; nothing is silently dropped.

## 6. Environment and state boundaries

Project-managed state:

```
.venv/                       # uv sync --locked
.mise/sources/pico-sdk/      # pinned git checkout
.mise/sources/SecLists/      # sparse git checkout
.mise/sources/rockyou.txt    # extracted data
sources.lock                 # committed Git source commit IDs
wordlists/                   # gitignored symlinks
tmp/jtmp/                    # project scratch space
mise.toml                    # committed source of truth
mise.lock                    # committed resolved artifacts
```

Environment evaluation only declares values and PATH entries. It must not clone repositories, install packages, create links, or emit startup text. `setup-local` performs side effects explicitly. Ghidra may still create its upstream-required settings directory at `~/.ghidra`; that is outside mise's control.

Remove the Nix-only `LIBUSB1_SO`, `UV_NO_SYNC`, `UV_PYTHON`, and `UV_PYTHON_DOWNLOADS` variables. `PYTHONPATH = false` replaces `unset PYTHONPATH`; `linkNodeModulesHook` is removed; the Nix-store link farm becomes project-local setup tasks.

## 7. Files changed by implementation

| File | Change |
|---|---|
| `mise.toml` | Added (see §4). |
| `mise.lock` | Generated with `mise lock` for supported platforms; committed. |
| `sources.lock` | Records exact Pico SDK and SecLists commit IDs; committed. |
| `flake.nix`, `flake.lock` | Deleted after mise smoke tests pass. |
| `.envrc` | Deleted (nix-direnv loader). Activation is the one `~/.bashrc` line in §3. |
| `.gitignore` | Ignores `.venv`, `.mise`, `wordlists`, `tmp`, and analysis outputs; never ignores `mise.toml`/`mise.lock`. |
| `package.json`, `package-lock.json`, `.npmrc` | Deleted after `npm:` backend smoke tests passed (`apk-mitm`, `asar` both run). |
| `README.md`, `CLAUDE.md`, `.claude/skills/**` | Replace Nix/direnv workflows and references with mise and system-tier policy. |
| `scripts/check-system.sh` | Informational checker; exits 0 and never invokes pacman/AUR helpers. |

Implementation status: **complete.** Configuration, lockfile, tool installs, project state, shell activation, deletions (`flake.*`, `.npmrc`, package files), and doc rewrites (README/CLAUDE/skills) are all done; final smoke pass (see audit below) succeeded.

Audit notes:
- `mise install --locked` in this directory also iterates the user's **global** config tools (`codex`, `bun`, `pnpm`, …), which have no entries in this project's lock and therefore fail under `--locked`. Local installs use plain `mise install` (the project's `[tool_config] locked = true` already enforces the lockfile for repo tools); reserve `--locked` for clean checkouts/CI. Global tools are unaffected and remain installed as before.
- The user's global `~/.local/share/mise/shims` dir is on PATH : project shims (e.g. `ghidraRun`) are *visible* outside this repo but inert — mise refuses to run them without a matching config (`No version is set for shim: …`).

## 8. Migration and verification sequence

1. Confirm current mise and activate it in the interactive shell. Ensure baseline system prerequisites (`git`, `tar`, compiler/linker, and any desktop/USB/GPU dependencies needed for an analysis) exist.
2. Add `mise.toml`; run `mise fmt` and `mise config ls`. Check that the project config is loaded without accidentally selecting a global tool as a project tool.
3. Resolve and inspect artifacts with `mise lock`. For Linux x64, ensure lockable tools have URLs/checksums. Never hand-edit the result.
4. Run `mise install --locked`. For a clean checkout, lockable tools must not require live GitHub/aqua resolution. Backends such as pipx and vfox may use their own package/plugin mechanisms, as documented by mise.
5. Run `mise run setup`. This performs `uv sync --locked`, fetches the pinned Pico SDK and sparse wordlists, and creates local links. It is safe to repeat.
6. Run `mise run check-system` and install missing OS packages separately, only when needed.
7. Smoke-test actual executable names and integration points:

   ```sh
   python -c 'import pyghidra, frida, lief'
   node --version                         # 24.x
   uv --version
   apk-mitm --help
   asar --version
   yr --help                              # YARA-X; classic yara is separate
   frida-ps --help
   protoc --version
   ghidraRun --help || true
   test -f "$PICO_SDK_PATH/pico_sdk_init.cmake"
   test -L wordlists/rockyou.txt
   ```

8. Outside the repository, verify project tools and variables are absent. Verify no global config was modified. Only then update documentation and delete Nix files; commit `mise.toml` and `mise.lock` together.

Routine commands:

```sh
mise install --locked
mise run setup
mise run check-system
mise outdated
mise up                 # review; then mise lock if needed
mise fmt
mise doctor
```

## 9. Open checks → resolved (2026-08-27)

* **GitHub aliases / Linux x64 assets + executable names — resolved.** Installed and verified on Linux x64: `ghidraRun` (Ghidra_12.1.3_build), `jadx` (bin/jadx), `dex-tools` (dex2jar 2.4 unified CLI — the old `d2j-*` scripts no longer exist), `floss`, `payload-dumper-go`, `PE-bear`, `curl_chrome*`/`curl_firefox*`, `rz-*`+`rizin` (from the static-x86_64 tarball), `scrcpy` (pending final lock pass), `yr`.
* **YARA-X binary — confirmed `yr`.** The v1.20.0 linux tarball contains a single `yr` executable (no `yara` shim). Classic `yara` is documented as an optional system tool.
* **pipx console scripts — resolved.** All pipx tools install; specifically: volatility3 exposes **`vol`** (not `vol.py`), quark-engine exposes `quark`/`freshquark`/`quark-agent`, hid-tools exposes `hid-decode`/`hid-recorder`/`hid-replay`, mitmproxy exposes `mitmproxy`/`mitmweb`/`mitmdump`. All support Python 3.13 (the console-script envs are uvx-managed).
* **Python 3.14 → blocked, 3.13 chosen.** `yara-python` (4.5.4) and `yara-python-dex` (1.0.7, required by apkid) publish no cp314 wheels; apkid's sdist build breaks on 3.14 (`yara-python/README.rst` FileNotFoundError in the build env). `uv sync --locked` succeeds on 3.13.15 with wheels only. Revisit when upstream ships cp314.
* **gcc-arm-none-eabi vfox artifact — resolved.** Installed `13.3.Rel1~amd64`; commands present as `arm-none-eabi-{gcc,g++,objcopy,gdb,...}`. Note vfox gcc toolchains don't record lockfile URLs (plugin mechanism), so they are exempt from strict-lock URL resolution — installs use the pinned plugin version.
* **Individual backend checks — resolved** (results in §5). radare2: no Linux release binary (only deb pkg for Debian + windows zips + source); rizin: NOW mise-managed via static-x86_64; binwalk: upstream moved to Rust (PyPI has only 2.1.0) → system/AUR; apktool (jar-only release), picotool (source-only), osslsigncode (mac/win binaries only), detect-it-easy (linux only as a `.deb`, not an extractable archive for mise), simg2img / sdat2img / imgpatchtools (no releases; sdat2img/imgpatchtools have AUR git builds), protoscope (no releases), hal-hardware-analyzer (source-only).
* **Python-wheel compatibility — resolved.** All pyproject dependencies resolve to wheels on 3.13 (`uv sync --locked` clean); the import smoke test passes (`frida, capstone, lief, yara, dnfile, pefile, pyghidra, unicorn, grpc, haralyzer, pyaxmlparser, hermes_dec, bs4, scipy, numpy, PIL, cryptography`).

## 10. Post-migration: upstream sync (2026-09-11)

Ported schlarpc/re-shell upstream `main` (11 commits, through `fd9d858`) into the mise environment:

* **New tools.** `esptool` (`pipx:`) provides `esptool`, `espsecure`, and `espefuse`; `apkeep` (`github:EFForg/apkeep`) downloads APKs/XAPKs by package name -- Linux/Windows only, because the 1.0.0 release ships no macOS asset; `xtensa-esp-elf` (`github:espressif/crosstool-NG`) provides the ESP32 Xtensa toolchain (objdump, gcc, g++).
* **All-targets objdump adaptation.** Upstream switched to `binutils-unwrapped-all-targets`. No portable all-targets binutils exists for mise and Arch's `binutils` is host-only (x86 + BPF), so Xtensa disassembly comes from the Espressif toolchain instead. RISC-V, MIPS, and AVR remain cross-binutils/system tier; see the ESP32 section of `CLAUDE.md`.
* **Python dependencies.** `bleak>=3.0.2`, `pyserial>=3.5`, and `hidapi>=0.15.0` were added to `pyproject.toml`/`uv.lock`; cp313 wheels exist for all three.
* **Darwin gating.** `os = ["linux"]` on `pe-bear`, `hid-tools`, and `rizin`; `apkeep` and `upx` are `os = ["linux", "windows"]` (no macOS artifact in their backends). `floss` and `yr` dropped `matching = "linux"` so GitHub autodetection can select macOS assets without changing the Linux artifacts. The remaining GitHub/pipx tools either ship macOS assets (Ghidra, JADX, dex2jar, scrcpy, payload-dumper-go, curl-impersonate, YARA-X, FLOSS) or are covered by the vfox `gcc-arm-none-eabi` plugin, which supports darwin.
* **Docs.** `CLAUDE.md` gains the ESP32 section, the USB class-driver guidance, and the Python library rows; the Android skill gains the APK-acquisition section; the README documents the mise prerequisites.
