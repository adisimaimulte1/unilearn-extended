package ro.contras.apollospeech;

import android.Manifest;
import android.content.pm.PackageManager;
import android.os.Handler;
import android.os.Looper;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;

import java.util.Arrays;
import java.util.HashSet;
import java.util.Set;

public class ApolloSpeech extends GodotPlugin {
    private static final int RECORD_AUDIO_REQUEST_CODE = 1001;

    private ApolloSpeechLoop speechLoop;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    public ApolloSpeech(Godot godot) {
        super(godot);
    }


    @Override
    public String getPluginName() {
        return "ApolloSpeech";
    }

    @Override
    public Set<SignalInfo> getPluginSignals() {
        return new HashSet<>(Arrays.asList(
                new SignalInfo("wake_detected", String.class),
                new SignalInfo("sleep_detected", String.class),
                new SignalInfo("command_result", String.class),
                new SignalInfo("partial_result", String.class),
                new SignalInfo("state_changed", String.class),
                new SignalInfo("error", String.class)
        ));
    }


    @UsedByGodot
    public boolean isAvailable() {
        return getActivity() != null && ApolloSpeechLoop.isAvailable(getActivity());
    }

    @UsedByGodot
    public boolean isRunning() {
        return speechLoop != null && speechLoop.isRunning();
    }

    @UsedByGodot
    public boolean isActive() {
        return speechLoop != null && speechLoop.isActive();
    }


    @UsedByGodot
    public boolean hasRecordAudioPermission() {
        return getActivity() != null
                && getActivity().checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED;
    }


    @UsedByGodot
    public void setWakeName(String name) {
        runOnUi(() -> getLoop().setWakeName(name));
    }

    @UsedByGodot
    public void setAssistantName(String name) {
        runOnUi(() -> getLoop().setWakeName(name));
    }

    @UsedByGodot
    public void setActiveCooldownMs(int ms) {
        runOnUi(() -> getLoop().setActiveCooldownMs(ms));
    }


    @UsedByGodot
    public void startWakeLoop() {
        runOnUi(() -> {
            if (getActivity() == null) {
                emitError("Activity is null.");
                return;
            }

            if (hasRecordAudioPermission()) {
                getLoop().start();
                return;
            }

            emitState("requesting_permission");

            getActivity().requestPermissions(
                    new String[]{Manifest.permission.RECORD_AUDIO},
                    RECORD_AUDIO_REQUEST_CODE
            );
        });
    }

    @UsedByGodot
    public void stopWakeLoop() {
        runOnUi(() -> {
            if (speechLoop != null) {
                speechLoop.stop();
            }
        });
    }


    @UsedByGodot
    public void forceActivate() {
        runOnUi(() -> getLoop().forceActivate());
    }

    @UsedByGodot
    public void startActiveTimeout() {
        runOnUi(() -> getLoop().startActiveTimeout());
    }


    @Override
    public void onMainRequestPermissionsResult(
            int requestCode,
            String[] permissions,
            int[] grantResults
    ) {
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults);

        if (requestCode != RECORD_AUDIO_REQUEST_CODE) {
            return;
        }

        mainHandler.post(() -> {
            boolean granted = grantResults != null
                    && grantResults.length > 0
                    && grantResults[0] == PackageManager.PERMISSION_GRANTED;

            if (!granted) {
                emitState("permission_denied_required");
                emitError("Microphone permission denied.");
                return;
            }

            /*
             * Important:
             * Do NOT start SpeechRecognizer in the same app session
             * immediately after the first runtime mic permission grant.
             *
             * Godot/Android SpeechRecognizer can return flat RMS / no match
             * until the app is restarted. Godot frontend should show a popup
             * asking the user to fully close and reopen the app.
             */
            emitState("permission_granted_restart_required");
        });
    }


    private void runOnUi(Runnable runnable) {
        if (getActivity() == null) {
            emitError("Activity is null.");
            return;
        }

        getActivity().runOnUiThread(runnable);
    }

    private ApolloSpeechLoop getLoop() {
        if (speechLoop == null) {
            speechLoop = new ApolloSpeechLoop(
                    getActivity(),
                    this::emitWake,
                    this::emitSleep,
                    this::emitCommand,
                    this::emitPartial,
                    this::emitState,
                    this::emitError
            );
        }

        return speechLoop;
    }


    private void emitWake(String text) {
        emitSignal("wake_detected", text);
    }

    private void emitSleep(String text) {
        emitSignal("sleep_detected", text);
    }

    private void emitCommand(String json) {
        emitSignal("command_result", json);
    }

    private void emitPartial(String text) {
        emitSignal("partial_result", text);
    }

    private void emitState(String state) {
        emitSignal("state_changed", state);
    }

    private void emitError(String error) {
        emitSignal("error", error);
    }
}