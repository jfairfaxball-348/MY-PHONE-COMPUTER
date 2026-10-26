#!/data/data/com.termux/files/usr/bin/bash
# v0.3.1: metadata-only diagnostic summary. No speech or answer text.
set -u
D="$HOME/newton/app"
printf 'Newton v0.3.1 diagnostic summary\n'
printf 'Captured: %s\n' "$(date '+%Y-%m-%d %H:%M:%S %Z')"
for spec in 'wake:newton-wake(-v02c|-v02)?[.]sh' 'vad:newton-vad-turn[.]sh' 'model:llama-server.*qwen3[.]gguf'; do
    IFS=: read -r name pattern <<< "$spec"
    if command -v pgrep >/dev/null 2>&1 && pgrep -f "$pattern" >/dev/null 2>&1; then
        printf '%s process: present\n' "$name"
    else
        printf '%s process: absent\n' "$name"
    fi
done
if command -v curl >/dev/null 2>&1 && curl -fsS --max-time 2 http://127.0.0.1:8080/health >/dev/null 2>&1; then
    echo 'Local model API: responding'
else
    echo 'Local model API: unavailable'
fi
if command -v termux-microphone-record >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
        info="$(timeout 3 termux-microphone-record -i 2>/dev/null || true)"
    else
        info="$(termux-microphone-record -i 2>/dev/null || true)"
    fi
    case "$info" in
        *'"isRecording":true'*|*'"isRecording": true'*) echo 'Microphone: recording';;
        *'"isRecording":false'*|*'"isRecording": false'*) echo 'Microphone: idle';;
        *) echo 'Microphone: unknown';;
    esac
fi
LOG="$D/logs/newton.log"
if [[ -f "$LOG" ]]; then
    tail -n 250 "$LOG" | awk '
      /Newton: Listening for your question/ { question++; stage="question-recording" }
      /Listening [0-9][0-9][.][.][.]/ && / speech/ { speech++; stage="speech-detected" }
      /Listening [0-9][0-9][.][.][.]/ && / quiet/ { quiet++; stage="quiet-detected" }
      /End of speech detected/ { ended++; stage="recording-finished" }
      /I didn.t hear a question/ { none++; stage="no-question-detected" }
      /Whisper heard nothing/ { blank++; stage="transcription-empty" }
      /^You: / { transcribed++; stage="transcribed" }
      /^Newton: No response from local model/ { noresponse++; stage="model-no-response" }
      END {
        print "Recent log window: last 250 lines"
        printf "Question captures: %d\nSpeech chunks: %d\nQuiet chunks: %d\n",question,speech,quiet
        printf "Recordings ended: %d\nNo question: %d\nEmpty transcripts: %d\n",ended,none,blank
        printf "Transcriptions: %d\nModel no-response: %d\n",transcribed,noresponse
        printf "Last recognized stage: %s\n",stage==""?"none":stage
      }'
else
    echo 'Newton log: missing'
fi
if [[ -f "$D/logs/native-controller.log" ]]; then
    tail -n 15 "$D/logs/native-controller.log" | awk '
        /Stop requested/ { stopreq++ }
        /Stop completed/ { stopok++ }
        /Stop incomplete/ { stopbad++ }
        END { printf "Recent Stop requests: %d\nCompleted: %d\nIncomplete: %d\n",stopreq,stopok,stopbad }'
fi
