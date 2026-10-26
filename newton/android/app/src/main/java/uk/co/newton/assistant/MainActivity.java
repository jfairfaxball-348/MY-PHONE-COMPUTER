package uk.co.newton.assistant;

import android.Manifest;
import android.app.Activity;
import android.app.PendingIntent;
import android.content.ClipData;
import android.content.ClipboardManager;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.Insets;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;
import java.lang.ref.WeakReference;
import java.util.Locale;
import java.util.concurrent.atomic.AtomicInteger;

public final class MainActivity extends Activity {
    private static final String PERMISSION = "com.termux.permission.RUN_COMMAND";
    private static final String HOME = "/data/data/com.termux/files/home";
    private static final String BASH = "/data/data/com.termux/files/usr/bin/bash";
    private static final int BG = 0xFF101827;
    private static final int CARD = 0xFF1A2739;
    private static final int MUTED = 0xFFA8B8CA;
    private static final int MINT = 0xFF5FE0C0;
    private static final AtomicInteger IDS = new AtomicInteger(1100);
    private static WeakReference<MainActivity> open = new WeakReference<>(null);

    private final Handler handler = new Handler(Looper.getMainLooper());
    private TextView stateText, detailsText;
    private Button startButton, stopButton, accessButton, diagnosticsButton;
    private boolean visible = false;
    private boolean statusPending = false;
    private long statusSentAt = 0;
    private long commandAt = 0;
    private String deferred = "";
    private final Runnable poll = new Runnable() {
        @Override public void run() {
            if (!visible) return;
            if (hasPermission() && SystemClock.uptimeMillis() - commandAt > 2000) {
                if (!statusPending || SystemClock.uptimeMillis() - statusSentAt > 8000) {
                    statusPending = true;
                    statusSentAt = SystemClock.uptimeMillis();
                    issue("status", "status.sh");
                }
            }
            handler.postDelayed(this, 4000);
        }
    };

    private static int dp(Activity activity, float value) {
        return Math.round(value * activity.getResources().getDisplayMetrics().density);
    }
    private GradientDrawable rounded(int color, int radius) {
        GradientDrawable result = new GradientDrawable();
        result.setColor(color);
        result.setCornerRadius(dp(this, radius));
        return result;
    }
    private TextView text(String content, int sp, int color, boolean heavy) {
        TextView t = new TextView(this);
        t.setText(content);
        t.setTextColor(color);
        t.setTextSize(sp);
        if (heavy) t.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        return t;
    }
    private void add(LinearLayout layout, View view, int topSpace) {
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(this, topSpace);
        layout.addView(view, lp);
    }
    private Button button(String label, int color, int textColor) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextColor(textColor);
        b.setTextSize(16);
        b.setAllCaps(false);
        b.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        b.setMinHeight(dp(this, 58));
        b.setBackground(rounded(color, 18));
        return b;
    }
    @Override public void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setBackgroundColor(BG);
        scroll.setOnApplyWindowInsetsListener((v, insets) -> {
            Insets x = insets.getInsets(WindowInsets.Type.systemBars());
            scroll.setPadding(0, x.top, 0, x.bottom);
            return insets;
        });
        LinearLayout page = new LinearLayout(this);
        page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(this, 26), dp(this, 32), dp(this, 26), dp(this, 32));
        scroll.addView(page);

        TextView emblem = text("N", 46, MINT, true);
        emblem.setGravity(Gravity.CENTER);
        emblem.setBackground(rounded(CARD, 24));
        LinearLayout.LayoutParams emblemLp = new LinearLayout.LayoutParams(dp(this, 88), dp(this, 88));
        page.addView(emblem, emblemLp);

        add(page, text("NEWTON", 35, Color.WHITE, true), 28);
        add(page, text("Your offline voice assistant", 16, MUTED, false), 6);
        TextView privateText = text("●  PRIVATE BY DESIGN   •   ON-DEVICE AI", 11, MINT, true);
        privateText.setLetterSpacing(0.06f);
        add(page, privateText, 22);

        LinearLayout statusCard = new LinearLayout(this);
        statusCard.setOrientation(LinearLayout.VERTICAL);
        statusCard.setPadding(dp(this, 22), dp(this, 22), dp(this, 22), dp(this, 24));
        statusCard.setBackground(rounded(CARD, 22));
        add(page, statusCard, 37);
        statusCard.addView(text("CURRENT STATUS", 12, MUTED, true));
        stateText = text("Checking Newton…", 25, Color.WHITE, true);
        add(statusCard, stateText, 15);
        detailsText = text("Connecting to your local runtime", 14, MUTED, false);
        add(statusCard, detailsText, 7);

        startButton = button("Start Newton", MINT, BG);
        add(page, startButton, 27);
        startButton.setOnClickListener(v -> runUserCommand("start"));
        stopButton = button("Stop Newton", CARD, Color.WHITE);
        add(page, stopButton, 12);
        stopButton.setOnClickListener(v -> runUserCommand("stop"));

        diagnosticsButton = button("Copy diagnostics", 0xFF30465C, Color.WHITE);
        add(page, diagnosticsButton, 16);
        diagnosticsButton.setOnClickListener(v -> {
            if (!hasPermission()) {
                requestAccess("diagnostics");
                return;
            }
            show("Reading diagnostics…", "Gathering a private, text-free fault summary");
            issue("diagnostics", "diagnostics.sh");
        });
        accessButton = button("Allow Termux access", 0xFF30465C, Color.WHITE);
        add(page, accessButton, 21);
        accessButton.setOnClickListener(v -> requestAccess("status"));

        TextView note = text(
            "If a conversation stalls, tap Copy diagnostics and paste the summary into chat. Your existing Termux AI stays on this phone. " +
            "Background and screen-locked listening have not yet been verified.", 13, MUTED, false);
        note.setLineSpacing(dp(this, 4), 1f);
        add(page, note, 34);
        add(page, text("NEWTON  /  VERSION 0.3", 11, MUTED, true), 22);
        setContentView(scroll);
        show("Checking…", "Verifying access to Termux");
    }
    private boolean hasPermission() {
        return Build.VERSION.SDK_INT < 23 ||
               checkSelfPermission(PERMISSION) == PackageManager.PERMISSION_GRANTED;
    }
    private void show(String state, String message) {
        if (stateText != null) stateText.setText(state);
        if (detailsText != null) detailsText.setText(message);
        if (accessButton != null) accessButton.setVisibility(hasPermission() ? View.GONE : View.VISIBLE);
    }
    @Override protected void onResume() {
        super.onResume();
        open = new WeakReference<>(this);
        visible = true;
        if (!hasPermission()) show("Setup needed", "Grant permission to run commands in Termux");
        handler.removeCallbacks(poll);
        handler.post(poll);
    }
    @Override protected void onPause() {
        visible = false;
        handler.removeCallbacks(poll);
        super.onPause();
    }
    private void runUserCommand(String command) {
        if (!hasPermission()) {
            requestAccess(command);
            return;
        }
        commandAt = SystemClock.uptimeMillis();
        if ("start".equals(command)) {
            startButton.setEnabled(false);
            handler.postDelayed(() -> startButton.setEnabled(true), 4500);
            show("Starting…", "Sending launch request to Termux");
            issue("start", "start-safe.sh");
        } else {
            stopButton.setEnabled(false);
            handler.postDelayed(() -> stopButton.setEnabled(true), 4500);
            show("Stopping…", "Asking Newton to stop cleanly");
            issue("stop", "stop-safe.sh");
        }
    }
    private void requestAccess(String action) {
        deferred = action;
        if (Build.VERSION.SDK_INT >= 23) {
            requestPermissions(new String[]{PERMISSION}, 102);
        }
    }
    @Override public void onRequestPermissionsResult(int request, String[] names, int[] grants) {
        super.onRequestPermissionsResult(request, names, grants);
        if (request != 102) return;
        if (hasPermission()) {
            String action = deferred;
            deferred = "";
            if ("start".equals(action) || "stop".equals(action)) runUserCommand(action);
            else if ("diagnostics".equals(action)) issue("diagnostics", "diagnostics.sh");
            else {
                show("Checking…", "Access granted. Reading Newton status");
                issue("status", "status.sh");
            }
        } else {
            show("Permission required", "In Android Settings → Apps → Newton → Permissions → Additional permissions, allow Run commands in Termux environment.");
        }
    }
    private void issue(String kind, String script) {
        try {
            Intent command = new Intent("com.termux.RUN_COMMAND");
            command.setClassName("com.termux", "com.termux.app.RunCommandService");
            command.putExtra("com.termux.RUN_COMMAND_PATH", BASH);
            command.putExtra("com.termux.RUN_COMMAND_ARGUMENTS",
                    new String[]{HOME + "/newton/app/" + script});
            command.putExtra("com.termux.RUN_COMMAND_WORKDIR", HOME);
            command.putExtra("com.termux.RUN_COMMAND_BACKGROUND", true);
            command.putExtra("com.termux.RUN_COMMAND_COMMAND_LABEL", "Newton " + kind);
            Intent callback = new Intent(this, CommandResultReceiver.class);
            callback.putExtra("newton_kind", kind);
            int flags = PendingIntent.FLAG_ONE_SHOT | PendingIntent.FLAG_UPDATE_CURRENT;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) flags |= PendingIntent.FLAG_MUTABLE;
            PendingIntent response = PendingIntent.getBroadcast(this, IDS.incrementAndGet(), callback, flags);
            command.putExtra("com.termux.RUN_COMMAND_PENDING_INTENT", response);
            startService(command);
        } catch (Exception ex) {
            if ("status".equals(kind)) statusPending = false;
            show("Cannot reach Termux", ex.getClass().getSimpleName() + ": " + ex.getMessage());
        }
    }
    public static void onCommandResult(String kind, int exit, String stdout, String stderr) {
        MainActivity a = open.get();
        if (a == null || !a.visible) return;
        a.onResult(kind, exit, stdout == null ? "" : stdout.trim(),
                stderr == null ? "" : stderr.trim());
    }
    private void onResult(String kind, int exit, String stdout, String stderr) {
        if ("status".equals(kind)) statusPending = false;
        if ("diagnostics".equals(kind) && exit == 0) {
            ClipboardManager clipboard = (ClipboardManager) getSystemService(Context.CLIPBOARD_SERVICE);
            if (clipboard != null) {
                clipboard.setPrimaryClip(ClipData.newPlainText("Newton diagnostics", stdout));
            }
            show("Diagnostics copied", "Paste the summary into our chat. No speech or answer text included.");
            Toast.makeText(this, "Diagnostic summary copied", Toast.LENGTH_LONG).show();
            return;
        }
        if (exit != 0) {
            if (!"status".equals(kind)) show("Command failed", stderr.isEmpty() ?
                    "Check ~/newton/app/logs in Termux" : stderr.substring(0, Math.min(200, stderr.length())));
            else if (SystemClock.uptimeMillis() - commandAt > 2500)
                show("Status unavailable", "Install the v0.3 Termux bridge on this phone");
            return;
        }
        if ("start".equals(kind) || "stop".equals(kind)) {
            if ("start".equals(kind)) show("Starting…", "Waiting for the local listener");
            else show("Stopping…", "Checking that the runtime has stopped");
            statusPending = false;
            handler.postDelayed(() -> {
                if (visible && hasPermission()) issue("status", "status.sh");
            }, 900);
            return;
        }
        if (SystemClock.uptimeMillis() - commandAt < 2300) return;
        switch (stdout) {
            case "LISTENING":
                show("Listening", "Wake word detector active · Say “Hey Newton”");
                break;
            case "PROCESSING":
                show("In conversation", "Newton is handling a voice turn");
                break;
            case "SERVER_ONLY":
                show("Server only", "Qwen is running; wake listener not detected");
                break;
            case "STARTING":
                show("Starting…", "Waiting for Qwen and the wake listener");
                break;
            case "STOPPING":
                show("Stopping…", "Finishing microphone and worker shutdown");
                break;
            case "STOPPED":
                show("Stopped", "Newton is not currently running");
                break;
            default:
                show("Status unknown", "Termux returned: " +
                    stdout.substring(0, Math.min(stdout.length(), 70)));
        }
    }
}
