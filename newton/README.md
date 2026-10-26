# Newton v0.3 — native Android controller

This is an **Android application**, not a WebView or a terminal theme. Its Start and Stop buttons use Termux's documented RUN_COMMAND service to reuse the owner's existing offline wake-word and AI pipeline.

## What is and is not implemented

- Native app launcher, dedicated icon, designed Start/Stop UI.
- Permission-based commands directed only to known Termux scripts.
- Read-only process/health status via callback (Termux >= 0.109).
- No model files, audio, or conversations leave the phone.
- Existing Termux widgets and app/start.sh, app/stop.sh remain intact.
- No custom Android microphone recorder or foreground service in v0.3.
- Wake/voice accuracy, all-day/screen-lock microphone reliability and 'speaking' detection are **not certified**.

## Phone setup

**First**, keep your current Newton scripts unchanged and confirm widgets still work. The only phone modifications from the v0.3 helper are additional scripts and the Termux allow-external-apps property. Backups are kept for any touched file.

Open **Termux** once and install the two new companion scripts:

\`\`\`bash
curl -fL https://raw.githubusercontent.com/jfairfaxball-348/MY-PHONE-COMPUTER/newton-v03-native/newton/phone/install.sh -o ~/newton-v03-install.sh
\`\`\`

Inspect the installer with \`cat ~/newton-v03-install.sh\` if desired, then run:

\`\`\`bash
bash ~/newton-v03-install.sh
\`\`\`

You may need to restart Termux once to apply the new property.

**Second**, from the Actions tab on this development branch open **Newton v0.3 Android APK**, the latest green build, then download the \`newton-v03-installable-apk\` artifact ZIP. Extract \`app-debug.apk\` on your Galaxy S24 and tap it to install. Allow installing apps from that source if Android asks.

**Third**, on the phone open Android Settings → Apps → Newton → Permissions → Additional permissions → **Run commands in Termux environment** → Allow. Alternatively, use the in-app "Allow Termux access" button if Android offers the permission dialog.

Open Newton, tap **Start Newton**, and watch for the state to change to **Listening**. Say "Hey Newton" and ask a simple question. Tap **Stop Newton** and verify the status returns to Stopped. Termux logs remain in \`~/newton/app/logs/newton.log\`.

## Building on a computer

Android Studio can open the \`newton/android\` folder. This repository's CI build uses JDK 17, Gradle 8.10.2, Android Gradle Plugin 8.7.3, and Android SDK 35. Because the Android Gradle wrapper JAR is not checked in, install Gradle 8.10.2 locally or generate a Gradle wrapper using that version. Run \`gradle :app:assembleDebug\` in \`newton/android\`. The resulting APK is \`app/build/outputs/apk/debug/app-debug.apk\`.

**Security/limitations**: The RUN_COMMAND grant is powerful: only install APKs you trust. The app requests no Internet or microphone permission and transmits no data. Termux's existing Qwen server remains on localhost. Status is a heuristic process probe, not a guarantee the microphone is recording or the full conversation works. Android 16 and Samsung power-saving rules can interrupt the Termux process when the app is backgrounded. App builds use ephemeral debug signing keys and are for testing, not an upgradeable release track. Keep the original widget as a fallback.


## v0.3.1 stability patch (experimental)

Known user-reported issues: wake activation can be fiddly, the VAD question stage can stall without a spoken reply, and the original Stop action sometimes leaves listening active. The actual phone logs are not yet available, so this patch **does not claim to have corrected the VAD or wake issue**.

The native Stop action now invokes `stop-safe.sh`, which asks Termux to stop recording, executes the original `stop.sh` with a timeout, terminates only recognizable Newton wake/VAD process trees and the Qwen3 server, then checks for stragglers. All old widget files remain untouched. `diagnostics.sh` extracts counts and stage names from the local log without collecting or returning any transcript, answer or audio. The app's **Copy diagnostics** button copies this summary locally, making the next debugging session evidence-based.

Phone setup requires copying the three updated scripts plus the new `stop-safe.sh` to `~/newton/app` using the versioned installer, with backups first. Keep the original widgets available as a fallback.

**Install caveat:** GitHub Actions debug APKs use an ephemeral signing certificate per run. If Android reports a signing or update conflict, uninstall **only Newton** (not Termux or Termux:API) before installing 0.3.1; then re-grant the RUN_COMMAND permission. A persistent signing strategy belongs in a future release build.
