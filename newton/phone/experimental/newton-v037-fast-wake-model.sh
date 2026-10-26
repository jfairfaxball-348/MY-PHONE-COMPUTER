#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.7: experiment with a smaller OFFLINE wake-recognition model.
# No changes to question capture, base.en question transcription, chime, Qwen, or TTS.
set -euo pipefail
D="$HOME/newton"
WAKE="$D/newton-wake-v02c.sh"
MODEL="$D/whisper.cpp/models/ggml-tiny.en-q5_1.bin"
ORIG='MODEL="$D/whisper.cpp/models/ggml-base.en.bin"'
REPL='MODEL="$D/whisper.cpp/models/ggml-tiny.en-q5_1.bin" # NEWTON_WAKE_TINY_V037'
HASH='c77c5766f1cef09b6b7d47f21b546cbddd4157886b3b5d6d4f709e91e66c7c2b'
URL='https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en-q5_1.bin'

[ -f "$WAKE" ] || { echo "Wake listener missing; no changes."; exit 1; }
for c in curl python3 sha256sum bash; do
  command -v "$c" >/dev/null || { echo "Missing $c; no changes."; exit 1; }
done
if command -v pgrep >/dev/null 2>&1 && pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
  echo "Please Stop Newton in the Android app before installing."; exit 1
fi
if grep -Fq '# NEWTON_WAKE_TINY_V037' "$WAKE"; then
  echo "The v0.3.7 wake model is already enabled."; exit 0
fi
if [ "$(grep -Fxc "$ORIG" "$WAKE" || true)" != 1 ]; then
  echo "Unexpected wake-listener model setting. Nothing changed."; exit 1
fi
if [ ! -f "$MODEL" ]; then
  echo "Downloading the official 32 MB tiny English model (installation only)."
  TMPFILE="$(mktemp "$D/whisper.cpp/models/.tiny-download.XXXXXXXX")"
  trap 'rm -f "$TMPFILE"' EXIT
  curl -fL --retry 2 --connect-timeout 20 --max-time 500 -o "$TMPFILE" "$URL"
  echo "$HASH  $TMPFILE" | sha256sum -c - >/dev/null || {
    echo "Model checksum mismatch; existing wake listener untouched."; exit 1;
  }
  mv "$TMPFILE" "$MODEL"
  trap - EXIT
else
  echo "$HASH  $MODEL" | sha256sum -c - >/dev/null || {
    echo "Existing tiny model checksum mismatch. Wake listener untouched."; exit 1;
  }
fi
python3 - "$WAKE" "$ORIG" "$REPL" <<'PY'
from pathlib import Path
from datetime import datetime
import os, shutil, subprocess, sys
wake, orig, repl = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
source = wake.read_text()
if source.count(orig) != 1:
    sys.exit("Wake script changed during download. No modifications.")
updated = source.replace(orig, repl, 1)
backup = wake.with_name(wake.name + '.backup-v037-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
temp = wake.with_name('.' + wake.name + '.v037.tmp')
shutil.copy2(wake, backup)
try:
    temp.write_text(updated)
    os.chmod(temp, wake.stat().st_mode & 0o777)
    subprocess.run(['bash','-n',str(temp)],check=True)
    os.replace(temp, wake)
except BaseException:
    temp.unlink(missing_ok=True)
    raise
print('Newton v0.3.7 faster wake-model experiment installed.')
print('Only wake recognition switched to tiny.en-q5_1. Question transcription still uses base.en.')
print('Backup:', backup)
PY
