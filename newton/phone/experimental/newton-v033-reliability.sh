#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.3 — bounded Qwen replies and model-request timing for phone diagnostics.
# Safe to run in Termux. Only changes ~/newton/newton-vad-turn.sh after a backup.
set -euo pipefail
TARGET="$HOME/newton/newton-vad-turn.sh"
[[ -f "$TARGET" ]] || { echo "Missing $TARGET — nothing changed." >&2; exit 1; }
if command -v pgrep >/dev/null 2>&1 && \
  pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
  echo 'Please press Stop Newton before applying this patch. Nothing changed.' >&2
  exit 1
fi
PYTHON="$(command -v python3 || command -v python || true)"
[[ -n "$PYTHON" ]] || { echo 'Python is required in Termux (pkg install python).' >&2; exit 1; }
"$PYTHON" - "$TARGET" <<'PYTHON_PATCH'
from pathlib import Path
from datetime import datetime
import os, shutil, subprocess, sys

path = Path(sys.argv[1])
old = path.read_text()
marker = '# NEWTON_MODEL_STABILITY_V033'
if marker in old:
    print('Newton v0.3.3 model patch already installed. No change.')
    raise SystemExit(0)
if '# NEWTON_MODEL_HANDOFF_V032' not in old:
    sys.exit('Expected installed v0.3.2 handoff not found. No changes made.')

old_tokens = 'temperature:0.7,max_tokens:180,stream:false'
old_call = r'''echo 'Newton: MODEL_REQUEST_STARTED'
response=''
if ! response="$(curl --silent --show-error --fail \
    --connect-timeout 4 --max-time 60 \
    -H 'Content-Type: application/json' -d "$payload" \
    http://127.0.0.1:8080/v1/chat/completions 2>"$TMP/model-request-error")"; then
  echo 'Newton: MODEL_REQUEST_FAILED' >&2
else
  echo 'Newton: MODEL_RESPONSE_RECEIVED'
fi'''
new_call = r'''# NEWTON_MODEL_STABILITY_V033
# No streaming yet: respond quickly or surface an explicit failure.
# Logs contain timing and exit code only, never the question or response.
request_start="$(date +%s)"
echo 'Newton: MODEL_REQUEST_STARTED'
response=''
if response="$(curl --silent --show-error --fail \
    --connect-timeout 4 --max-time 45 \
    -H 'Content-Type: application/json' -d "$payload" \
    http://127.0.0.1:8080/v1/chat/completions 2>"$TMP/model-request-error")"; then
  echo "Newton: MODEL_RESPONSE_RECEIVED elapsed_seconds=$(($(date +%s)-request_start))"
else
  model_exit=$?
  echo "Newton: MODEL_REQUEST_FAILED curl_exit=$model_exit elapsed_seconds=$(($(date +%s)-request_start))" >&2
fi'''
for needle in (old_tokens, old_call):
    if old.count(needle) != 1:
        sys.exit('Expected model code differs from this patch: refusing to modify Newton. No change.')
updated = old.replace(old_tokens, 'temperature:0.7,max_tokens:72,stream:false').replace(old_call, new_call)

stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
backup = path.with_name(f'{path.name}.backup-v033-{stamp}')
tmp = path.with_name(f'.{path.name}.v033-tmp')
shutil.copy2(path, backup)
try:
    tmp.write_text(updated)
    os.chmod(tmp, path.stat().st_mode & 0o777)
    subprocess.run(['bash', '-n', str(tmp)], check=True)
    os.replace(tmp, path)
except BaseException:
    tmp.unlink(missing_ok=True)
    raise
print('Newton v0.3.3 installed: shorter replies + model-request timings.')
print('Backup:', backup)
print('Existing Android app, wake word, microphone recording and Stop button unchanged.')
PYTHON_PATCH
