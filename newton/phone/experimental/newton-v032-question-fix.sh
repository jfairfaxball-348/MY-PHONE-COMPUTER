#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.2 experimental continuous-question and local-model handoff fix.
# Modifies only ~/newton/newton-vad-turn.sh after a backup. No APK changes.
set -euo pipefail
TARGET="$HOME/newton/newton-vad-turn.sh"
[[ -f "$TARGET" ]] || { echo "Cannot find $TARGET. Nothing changed." >&2; exit 1; }
if command -v pgrep >/dev/null 2>&1 && \
   pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
  echo 'Newton appears to be running; stop it from the app before patching.' >&2
  exit 1
fi
PYTHON="$(command -v python3 || command -v python || true)"
[[ -n "$PYTHON" ]] || { echo 'Python required. Install in Termux: pkg install python' >&2; exit 1; }
"$PYTHON" - "$TARGET" <<'PYTHON_PATCH'
from pathlib import Path
from datetime import datetime
import os, shutil, subprocess, sys

target = Path(sys.argv[1])
original = target.read_text()
marker = '# NEWTON_CONTINUOUS_QUESTION_V032'
if marker in original:
    print('v0.3.2 question-mode patch is already installed; no change.')
    raise SystemExit(0)

start_marker = "echo 'Newton: Listening for your question...'"
end_marker = '# Test mode: report end detection without asking the model or speaking.'
start = original.find(start_marker)
end = original.find(end_marker)
if start == -1 or end == -1 or end <= start or original.count(start_marker) != 1:
    sys.exit('Expected question recorder not found. Nothing changed. Please share its code for review.')

new_capture = r'''# NEWTON_CONTINUOUS_QUESTION_V032
# MVP test: one uninterrupted audio capture instead of stop/restart every two seconds.
# Fixed duration until proper streaming VAD can be built. Default 10 seconds.
QUESTION_SECONDS="${NEWTON_QUESTION_SECONDS:-10}"
if [[ ! "$QUESTION_SECONDS" =~ ^([5-9]|1[0-9]|2[0-5])$ ]]; then
  echo 'Newton: NEWTON_QUESTION_SECONDS must be between 5 and 25.' >&2
  exit 2
fi
CHUNK="$QUESTION_SECONDS"
echo 'Newton: Listening for your question...'
echo "Newton: QUESTION_CONTINUOUS_START seconds=$QUESTION_SECONDS"
clip="$TMP/continuous-question.m4a"
if ! record_chunk "$clip"; then
  echo 'Newton: QUESTION_MICROPHONE_FAILED' >&2
  exit 0
fi
echo 'Newton: QUESTION_CONTINUOUS_CAPTURE_COMPLETE'
ffmpeg -nostdin -hide_banner -loglevel error -y -i "$clip" \
  -ar 16000 -ac 1 -c:a pcm_s16le "$TMP/question.wav"

'''

# Preserve the downstream transcription and response handling, but make failures visible.
updated = original[:start] + new_capture + original[end:]
old_model = r'''response="$(curl --fail --silent --show-error --max-time 120 \
  -H 'Content-Type: application/json' -d "$payload" \
  http://127.0.0.1:8080/v1/chat/completions)"
reply="$(jq -r '.choices[0].message.content // empty' <<<"$response")"
if [[ -z "$reply" ]]; then
  echo 'Newton: No response from local model.' >&2
  exit 1
fi
echo "Newton: $reply"
termux-tts-speak -s MUSIC -l en -n GB "$reply"
# Leave a little time for Android's asynchronously-spoken last words.
sleep 1.5'''
new_model = r'''# NEWTON_MODEL_HANDOFF_V032
# Readiness check only: do not launch a duplicate model server.
echo 'Newton: MODEL_WAITING_FOR_SERVER'
server_ready=0
for ((attempt=1; attempt<=10; attempt++)); do
  if curl --silent --fail --connect-timeout 2 --max-time 3 \
      http://127.0.0.1:8080/health >/dev/null 2>&1; then
    server_ready=1
    break
  fi
  sleep 1
done
if (( ! server_ready )); then
  echo 'Newton: MODEL_SERVER_UNAVAILABLE' >&2
  termux-tts-speak -s MUSIC -l en -n GB \
    "Sorry, my local AI isn't ready yet. Please try again." >/dev/null 2>&1 || true
  exit 0
fi

echo 'Newton: MODEL_REQUEST_STARTED'
response=''
if ! response="$(curl --silent --show-error --fail \
    --connect-timeout 4 --max-time 60 \
    -H 'Content-Type: application/json' -d "$payload" \
    http://127.0.0.1:8080/v1/chat/completions 2>"$TMP/model-request-error")"; then
  echo 'Newton: MODEL_REQUEST_FAILED' >&2
else
  echo 'Newton: MODEL_RESPONSE_RECEIVED'
fi
reply="$(jq -r '.choices[0].message.content // empty' <<<"$response" 2>/dev/null || true)"
if [[ -z "$reply" ]]; then
  echo 'Newton: MODEL_ANSWER_UNAVAILABLE' >&2
  termux-tts-speak -s MUSIC -l en -n GB \
    "Sorry, I couldn't answer that. Please try again." >/dev/null 2>&1 || true
  exit 0
fi
echo "Newton: $reply"
if termux-tts-speak -s MUSIC -l en -n GB "$reply"; then
  echo 'Newton: TTS_SUBMITTED'
else
  echo 'Newton: TTS_FAILED' >&2
fi
sleep 1.5'''
if updated.count(old_model) != 1:
    sys.exit('Expected model handoff not found; refusing partial modification. Nothing changed.')
updated = updated.replace(old_model, new_model)

backup = target.with_name(target.name + '.backup-v032-' + datetime.now().strftime('%Y%m%d-%H%M%S'))
temp = target.with_name('.' + target.name + '.v032.tmp')
shutil.copy2(target, backup)
try:
    temp.write_text(updated)
    os.chmod(temp, target.stat().st_mode & 0o777)
    subprocess.run(['bash', '-n', str(temp)], check=True)
    os.replace(temp, target)
except BaseException:
    temp.unlink(missing_ok=True)
    raise
print('Newton v0.3.2 experimental question capture + model handoff installed.')
print('Backup:', backup)
print('Start Newton in the existing Android app and ask a question within 10 seconds.')
print('Allow it to finish recording before expecting a response.')
PYTHON_PATCH