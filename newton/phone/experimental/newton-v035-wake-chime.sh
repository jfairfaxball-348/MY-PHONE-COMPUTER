#!/data/data/com.termux/files/usr/bin/bash
# Newton v0.3.5 — offline two-tone wake acknowledgement.
# Patches the existing v02c wake listener only after a syntax check and backup.
set -euo pipefail
WAKE="$HOME/newton/newton-wake-v02c.sh"
[[ -f "$WAKE" ]] || { echo "Missing $WAKE; no changes made." >&2; exit 1; }
command -v python3 >/dev/null || { echo 'Python 3 required (pkg install python)' >&2; exit 1; }
command -v termux-media-player >/dev/null || { echo 'Termux API media-player command is missing (pkg install termux-api)' >&2; exit 1; }
command -v timeout >/dev/null || { echo 'timeout is missing (pkg install coreutils)' >&2; exit 1; }
if command -v pgrep >/dev/null 2>&1 && \
   pgrep -f 'newton-(wake(-v02c|-v02)?|vad-turn)[.]sh' >/dev/null 2>&1; then
    echo 'Stop Newton from the Android app before installing. No changes made.' >&2
    exit 1
fi
python3 - "$WAKE" <<'PY'
from pathlib import Path
from datetime import datetime
import math, os, re, shutil, struct, subprocess, sys, tempfile, wave

wake=Path(sys.argv[1]); app=wake.parent/'app'; sounds=app/'sounds'
original=wake.read_text()
marker='# NEWTON_WAKE_CHIME_V035'
if marker in original:
    print('Wake chime already installed; no changes made.')
    raise SystemExit(0)
lines=original.splitlines(keepends=True)
matches=[]
for i, line in enumerate(lines):
    if line.lstrip().startswith('#') or 'termux-tts-speak' not in line:
        continue
    cmd=line
    j=i
    while cmd.rstrip().endswith('\\') and j+1 < len(lines) and j < i+7:
        j+=1
        cmd+=lines[j]
    if re.search(r'\byes\b', cmd, re.IGNORECASE):
        matches.append(i)
if len(matches)!=1:
    print("Could not safely find exactly one wake-word 'Yes' speech command.")
    print('Nothing changed. Please show:')
    print("grep -nE 'Yes|yes|termux-tts-speak' ~/newton/newton-wake-v02c.sh")
    raise SystemExit(2)
idx=matches[0]
# preserve shell control-flow alignment and only add a chime just before the reply
indent=re.match(r'\s*',lines[idx]).group(0)
lines.insert(idx, indent+'bash "$HOME/newton/app/wake-chime.sh" || true '+marker+'\n')
updated=''.join(lines)

# Build a two-note friendly chime locally; no downloaded audio assets.
rate=24000; duration=0.49
def tone(t, start, length, frequency):
    x=t-start
    if x<0 or x>=length: return 0.0
    attack=min(1.0,x/0.015)
    release=min(1.0,(length-x)/0.1)
    v=attack*release*math.exp(-2*x)
    return v*(math.sin(2*math.pi*frequency*x)+0.12*math.sin(4*math.pi*frequency*x))
frames=bytearray()
for k in range(int(rate*duration)):
    t=k/rate
    v=.5*tone(t,0,.24,523.25)+.5*tone(t,.16,.31,659.25)
    frames+=struct.pack('<h',max(-32768,min(32767,round(13000*v))))
helper='''#!/data/data/com.termux/files/usr/bin/bash
# Chime acknowledgment. Short timeout: never block conversation if Android audio fails.
if command -v termux-media-player >/dev/null 2>&1; then
  timeout 3 termux-media-player play "$HOME/newton/app/sounds/wake-chime.wav" >/dev/null 2>&1 || true
  sleep 0.52
fi
'''
# Check the patched listener and helper before replacing anything.
with tempfile.TemporaryDirectory(prefix='.newton-chime-', dir=wake.parent) as tmp:
    tmp=Path(tmp)
    candidate=tmp/'newton-wake-v02c.sh'
    candidate.write_text(updated)
    subprocess.run(['bash','-n',str(candidate)],check=True)
    candidatehelper=tmp/'wake-chime.sh'
    candidatehelper.write_text(helper)
    subprocess.run(['bash','-n',str(candidatehelper)],check=True)
    candidatewav=tmp/'wake-chime.wav'
    with wave.open(str(candidatewav),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes(bytes(frames))
    app.mkdir(parents=True,exist_ok=True)
    sounds.mkdir(parents=True,exist_ok=True)
    backup=wake.with_name(wake.name+'.backup-v035-'+datetime.now().strftime('%Y%m%d-%H%M%S'))
    shutil.copy2(wake,backup)
    stage=wake.with_name('.'+wake.name+'.v035.new')
    try:
        shutil.copy2(candidate,stage)
        os.chmod(stage,wake.stat().st_mode&0o777)
        os.replace(candidatewav,sounds/'wake-chime.wav')
        shutil.copy2(candidatehelper,app/'wake-chime.sh')
        os.chmod(app/'wake-chime.sh',0o700)
        os.replace(stage,wake)
    finally:
        stage.unlink(missing_ok=True)
print('Newton wake chime installed successfully.')
print('Backup:',backup)
print('Preview: termux-media-player play ~/newton/app/sounds/wake-chime.wav')
print('Start Newton from your Android app as before.')
PY
