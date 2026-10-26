#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.6 — experimental 2-second wake listening window, with timing markers.
# Back up the existing wake script, touch no question/AI/TTS implementation.
set -euo pipefail
WAKE="$HOME/newton/newton-wake-v02c.sh"
[[ -f "$WAKE" ]] || { echo "Wake script not found: $WAKE. No changes." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Python 3 is required: pkg install python" >&2; exit 1; }
if command -v pgrep >/dev/null 2>&1 && pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
  echo "Please Stop Newton in the app before applying this patch. No changes." >&2
  exit 1
fi
python3 - "$WAKE" <<'PY_PATCH'
from pathlib import Path
from datetime import datetime
import os, shutil, subprocess, sys
wake = Path(sys.argv[1])
old = wake.read_text()
if "# NEWTON_WAKE_SPEED_V036" in old:
    print("Wake-speed experiment already installed. No changes.")
    raise SystemExit(0)
original_setting = 'WAKE_SECONDS="${NEWTON_WAKE_SECONDS:-3}"'
capture = 'output="$(termux-microphone-record -f "$TMP/wake.m4a" -e aac -l "$WAKE_SECONDS" 2>&1)"'
chime = 'bash "$HOME/newton/app/wake-chime.sh" || true # NEWTON_WAKE_CHIME_V035'
expected = [original_setting, capture, chime]
if any(old.count(x) != 1 for x in expected):
    sys.exit("Unexpected wake-script structure; refusing to modify it. No changes.")
updated = old.replace(original_setting, 'WAKE_SECONDS="${NEWTON_WAKE_SECONDS:-2}" # NEWTON_WAKE_SPEED_V036', 1)
updated = updated.replace(
    capture,
    'echo "Newton: WAKE_CAPTURE_START epoch_ms=$(date +%s%3N)"\n  ' + capture, 1)
updated = updated.replace(
    chime,
    'echo "Newton: WAKE_RECOGNIZED epoch_ms=$(date +%s%3N)"\n    ' + chime, 1)
backup = wake.with_name(wake.name + ".backup-v036-" + datetime.now().strftime("%Y%m%d-%H%M%S"))
staging = wake.with_name("." + wake.name + ".v036.tmp")
shutil.copy2(wake, backup)
try:
    staging.write_text(updated)
    os.chmod(staging, wake.stat().st_mode & 0o777)
    subprocess.run(["bash", "-n", str(staging)], check=True)
    os.replace(staging, wake)
except BaseException:
    staging.unlink(missing_ok=True)
    raise
print("Newton v0.3.6 wake-speed experiment installed.")
print("Wake listening window: 3 seconds -> 2 seconds (default).")
print("New timing markers: WAKE_CAPTURE_START / WAKE_RECOGNIZED.")
print("No changes to the existing chime or 10-second question recording.")
print("Backup:", backup)
print("If 'Hey Newton' becomes less reliable, restore from this backup.")
PY_PATCH