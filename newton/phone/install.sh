#!/data/data/com.termux/files/usr/bin/bash
# Run inside Termux. Does not change the working start.sh, stop.sh or widgets.
set -euo pipefail
D="$HOME/newton/app"
[[ -f "$D/start.sh" && -f "$D/stop.sh" ]] || {
    echo 'Existing Newton start.sh or stop.sh not found. Nothing changed.' >&2
    exit 1
}
mkdir -p "$HOME/.termux" "$D"
STAMP="$(date +%Y%m%d-%H%M%S)"
for file in status.sh start-safe.sh; do
    if [[ -f "$D/$file" ]]; then
        cp -p "$D/$file" "$D/$file.backup-$STAMP"
    fi
done
# Download both small, inspected companion scripts; do not replace the runtime.
BASE="https://raw.githubusercontent.com/jfairfaxball-348/MY-PHONE-COMPUTER/newton-v03-native/newton/phone"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fsSL "$BASE/status.sh" -o "$TMP/status.sh"
curl -fsSL "$BASE/start-safe.sh" -o "$TMP/start-safe.sh"
bash -n "$TMP/status.sh"
bash -n "$TMP/start-safe.sh"
cp "$TMP/status.sh" "$D/status.sh"
cp "$TMP/start-safe.sh" "$D/start-safe.sh"
chmod 700 "$D/status.sh" "$D/start-safe.sh"
PROPERTIES="$HOME/.termux/termux.properties"
if [[ -f "$PROPERTIES" ]]; then
    cp -p "$PROPERTIES" "$PROPERTIES.backup-$STAMP"
fi
touch "$PROPERTIES"
sed -i -E '/^[[:space:]]*#?[[:space:]]*allow-external-apps[[:space:]]*=/d' "$PROPERTIES"
printf '\nallow-external-apps=true\n' >> "$PROPERTIES"
if command -v termux-reload-settings >/dev/null 2>&1; then
    termux-reload-settings || true
fi
echo 'Newton v0.3 bridge installed. Original runtime and widgets untouched.'
echo 'Status probe result:'
bash "$D/status.sh"
