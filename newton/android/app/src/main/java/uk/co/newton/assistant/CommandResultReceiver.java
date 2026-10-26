package uk.co.newton.assistant;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;

public final class CommandResultReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        String kind = intent.getStringExtra("newton_kind");
        Bundle result = intent.getBundleExtra("result");
        if (result == null) {
            MainActivity.onCommandResult(kind, -1, "", "Termux did not return a result");
            return;
        }
        int error = result.getInt("err", -1);
        int exit = result.getInt("exitCode", -1);
        String stdout = result.getString("stdout", "");
        String stderr = result.getString("stderr", "");
        String errorMessage = result.getString("errmsg", "");
        MainActivity.onCommandResult(kind, error == -1 ? exit : -1, stdout,
                error == -1 ? stderr : errorMessage);
    }
}
