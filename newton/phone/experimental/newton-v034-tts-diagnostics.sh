#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.4: diagnose the model-output-to-Android-TTS handoff.
# Does NOT alter recording, Whisper, wake detector, model or native Android app.
# Install with Newton stopped. Original file is backed up.
set -euo pipefail

TARGET="$HOME/newton/newton-vad-turn.sh"
[[ -f "$TARGET" ]] || { echo "Missing $TARGET; nothing modified." >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "Python 3 missing: pkg install python" >&2; exit 1; }
command -v timeout >/dev/null 2>&1 || { echo "Coreutils timeout missing: pkg install coreutils" >&2; exit 1; }
if command -v pgrep >/dev/null 2>&1 &&
   pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
  echo "Stop Newton in the app before applying the patch; no changes made." >&2
  exit 1
fi

python3 - "$TARGET" <<'PYTHON_PATCH'
from pathlib import Path
from datetime import datetime
import os, shutil, subprocess, sys

target=Path(sys.argv[1])
source=target.read_text()
if "# NEWTON_TTS_DIAGNOSTICS_V034" in source:
    print("Newton v0.3.4 diagnostics already installed.")
    raise SystemExit(0)
if "# NEWTON_MODEL_STABILITY_V033" not in source:
    sys.exit("v0.3.3 model patch not found. Refusing to modify unknown code.")

old_parse = '''reply="$(jq -r '.choices[0].message.content // empty' <<<"$response" 2>/dev/null || true)"'''
new_parse = '''# NEWTON_TTS_DIAGNOSTICS_V034
echo 'Newton: MODEL_PARSE_STARTED'
reply="$(jq -r '.choices[0].message.content // empty' <<<"$response" 2>/dev/null || true)"
echo "Newton: MODEL_PARSE_FINISHED chars=\${#reply}"'''
old_speech = '''echo "Newton: $reply"
if termux-tts-speak -s MUSIC -l en -n GB "$reply"; then
  echo 'Newton: TTS_SUBMITTED'
else
  echo 'Newton: TTS_FAILED' >&2
fi
sleep 1.5'''
new_speech = '''# Do not print the actual answer in diagnostics: only non-sensitive stage markers.
echo "Newton: TTS_START chars=\${#reply}"
tts_start="$(date +%s)"
if timeout 20 termux-tts-speak -s MUSIC -l en -n GB "$reply" >/dev/null 2>"$TMP/tts-error"; then
  echo "Newton: TTS_SUBMITTED elapsed_seconds=$(($(date +%s)-tts_start))"
else
  tts_rc=$?
  echo "Newton: TTS_FAILED exit_code=$tts_rc elapsed_seconds=$(($(date +%s)-tts_start))" >&2
fi
sleep 1.5'''

for label, needle in (("parse", old_parse), ("speech", old_speech)):
    if source.count(needle)!=1:
        sys.exit(f"Unexpected {label} code. No change made; please share relevant script section.")
updated=source.replace(old_parse,new_parse,1).replace(old_speech,new_speech,1)
backup=target.with_name(target.name+'.backup-v034-'+datetime.now().strftime('%Y%m%d-%H%M%S'))
temp=target.with_name('.'+target.name+'.v034.tmp')
shutil.copy2(target,backup)
try:
    temp.write_text(updated)
    os.chmod(temp,target.stat().st_mode & 0o777)
    subprocess.run(['bash','-n',str(temp)],check=True)
    os.replace(temp,target)
except BaseException:
    temp.unlink(missing_ok=True)
    raise
print("Newton v0.3.4 installed: model parse and TTS markers, 20s TTS timeout.")
print("Backup:",backup)
print("No changes to native app, AI models, wake word or recording.")
PYTHON_PATCH
