#!/usr/bin/env bash
# Informational checklist of OS/AUR-tier tools. Exits 0; never installs anything.
set -u

# The OS tier below is pacman/ldconfig-specific. On macOS the portable toolchain
# comes from mise; see the darwin notes in CLAUDE.md.
if [ "$(uname -s)" != "Linux" ]; then
  echo "check-system: non-Linux host, skipping pacman/ldconfig checks (see CLAUDE.md for darwin notes)."
  exit 0
fi

missing=()
note() { printf '%-28s <- %s\n' "$1" "$2"; }

check() { # check <command> <package/notes>
  if ! command -v "$1" >/dev/null 2>&1; then missing+=("$1 ($2)"); fi
}

# --- pacman (official repos) -------------------------------------------------
for c in "radare2:radare2" "rizin:rizin" "jq:jq" "nmap:nmap" "tshark:wireshark-cli" \
  "avahi-browse:avahi" "ddcutil:ddcutil" "i2cdetect:i2c-tools" "lsusb:usbutils" \
  "v4l2-ctl:v4l-utils" "edid-decode:v4l-utils/edid-decode" "hashcat:hashcat" \
  "john:john the ripper" "yosys:yosys" "yara:yara (classic; mise brings yara-x as 'yr')" \
  "binwalk:binwalk (AUR; Python v3 upstream moved to Rust v4)" \
  "exiftool:perl-image-exiftool" "wine:wine" "winetricks:winetricks" "cabextract:cabextract" \
  "msiinfo:msitools" "msiextract:msitools" "adb:android-tools" "fastboot:android-tools" \
  "openssl:openssl" "sqlite3:sqlite" "file:file" \
  "objdump:binutils (host-only x86+BPF; xtensa via mise xtensa-esp-elf-objdump)" \
  "xxd:vim-common" \
  "unzip:unzip" "7z:p7zip" "curl:curl" "ecputil:trellis (AUR prjtrellis-git)"; do
  check "${c%%:*}" "${c#*:}"
done

# libs (no CLI)
for dep in libusb-1.0.so.0 hidapi.so.0; do
  if ! ldconfig -p 2>/dev/null | grep -q "$dep"; then missing+=("$dep (libusb/hidapi)"); fi
done

# --- AUR (helper opt-in) -----------------------------------------------------
for c in "apktool:android-apktool-bin" "aapt2:android-sdk-build-tools" "apksigner:android-sdk-build-tools" \
  "imhex:imhex-bin" "diec:detect-it-easy-bin" "osslsigncode:osslsigncode" "picotool:picotool-bin" \
  "ecpunpack:prjtrellis-git" "sdat2img:sdat2img-git" "imgpatchtools:imgpatchtools-git" \
  "bytecodeviewer:bytecode-viewer" "apkeditor:apkeditor-bin" "avaloniailspy:avaloniailspy"; do
  check "${c%%:*}" "${c#*:}"
done

# --- source-built / optional -------------------------------------------------
check r2 "radare2 (pacman radare2)" # no Linux release binary exists upstream

if [ "${#missing[@]}" -gt 0 ]; then
  echo "Optional system-tier tools not found (install only if needed):"
  printf '  MISSING  %s\n' "${missing[@]}"
  echo "See MISE-MIGRATION.md §6 for the system tier table."
else
  echo "All known system-tier tools present."
fi
