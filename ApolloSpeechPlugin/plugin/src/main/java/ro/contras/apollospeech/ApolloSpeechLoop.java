package ro.contras.apollospeech;

import android.Manifest;
import android.app.Activity;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.speech.RecognitionListener;
import android.speech.RecognizerIntent;
import android.speech.SpeechRecognizer;

import java.util.ArrayList;

public class ApolloSpeechLoop {
    public interface StringEmitter {
        void emit(String value);
    }

    private Runnable activeTimeoutRunnable = null;

    private final Activity activity;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    private final StringEmitter wakeEmitter;
    private final StringEmitter sleepEmitter;
    private final StringEmitter commandEmitter;
    private final StringEmitter partialEmitter;
    private final StringEmitter stateEmitter;
    private final StringEmitter errorEmitter;

    private SpeechRecognizer recognizer;

    private boolean running = false;
    private boolean listening = false;
    private boolean active = false;

    private long activeUntilMs = 0;
    private long lastListenStartMs = 0;

    private int restartDelayMs = 1200;
    private int activeCooldownMs = 120_000;
    private int startGeneration = 0;

    private String lastPartialText = "";

    private final ApolloWakeWordDetector wakeDetector = new ApolloWakeWordDetector();
    private final ApolloSleepWordDetector sleepDetector = new ApolloSleepWordDetector();
    private final ApolloIntentRegistry intentRegistry = new ApolloIntentRegistry();

    public ApolloSpeechLoop(
            Activity activity,
            StringEmitter wakeEmitter,
            StringEmitter sleepEmitter,
            StringEmitter commandEmitter,
            StringEmitter partialEmitter,
            StringEmitter stateEmitter,
            StringEmitter errorEmitter
    ) {
        this.activity = activity;
        this.wakeEmitter = wakeEmitter;
        this.sleepEmitter = sleepEmitter;
        this.commandEmitter = commandEmitter;
        this.partialEmitter = partialEmitter;
        this.stateEmitter = stateEmitter;
        this.errorEmitter = errorEmitter;
    }

    public static boolean isAvailable(Activity activity) {
        return activity != null && SpeechRecognizer.isRecognitionAvailable(activity);
    }

    public boolean isRunning() {
        return running;
    }

    public boolean isActive() {
        return active;
    }

    public void setWakeName(String name) {
        mainHandler.post(() -> {
            wakeDetector.setWakeName(name);
            sleepDetector.setAssistantName(name);
        });
    }

    public void setActiveCooldownMs(int ms) {
        mainHandler.post(() -> activeCooldownMs = Math.max(5_000, ms));
    }

    public void start() {
        mainHandler.post(this::startInternal);
    }

    private void startInternal() {
        if (activity == null) {
            errorEmitter.emit("Activity is null.");
            return;
        }

        if (!SpeechRecognizer.isRecognitionAvailable(activity)) {
            errorEmitter.emit("SpeechRecognizer is not available.");
            return;
        }

        if (!hasPermission()) {
            stateEmitter.emit("permission_missing");
            return;
        }

        running = true;

        if (!active) {
            activeUntilMs = 0;
        }

        startWakeLoopDelayed(800);
    }

    public void stop() {
        mainHandler.post(this::stopInternal);
    }

    private void stopInternal() {
        running = false;
        listening = false;
        active = false;
        activeUntilMs = 0;
        lastPartialText = "";
        ++startGeneration;

        clearActiveTimeout();

        destroyRecognizer();
        stateEmitter.emit("stopped");
    }

    public void forceActivate() {
        mainHandler.post(() -> {
            running = true;
            active = true;
            activeUntilMs = 0;
            lastPartialText = "";

            clearActiveTimeout();

            wakeEmitter.emit(wakeDetector.getWakeName());
            restartListeningSoon(800);
        });
    }

    private boolean hasPermission() {
        return activity != null
                && activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO)
                == PackageManager.PERMISSION_GRANTED;
    }

    private void startWakeLoopDelayed(int delayMs) {
        int generation = ++startGeneration;

        stateEmitter.emit("starting_android_stt");
        cancelRecognizer();

        mainHandler.postDelayed(() -> {
            if (!running || generation != startGeneration) return;
            startWakeLoopInternal();
        }, delayMs);
    }

    private void startWakeLoopInternal() {
        if (!running) return;

        lastPartialText = "";
        startListeningInternal();
    }

    private void startListeningInternal() {
        if (!running || listening) return;

        if (!hasPermission()) {
            running = false;
            active = false;
            stateEmitter.emit("permission_missing");
            return;
        }

        cancelRecognizer();

        lastPartialText = "";
        lastListenStartMs = System.currentTimeMillis();

        ensureRecognizer();

        Intent intent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
        intent.putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
        );
        intent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
        intent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5);
        intent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, activity.getPackageName());

        try {
            recognizer.startListening(intent);
        } catch (Exception e) {
            listening = false;
            errorEmitter.emit(e.getMessage() == null ? "Failed to start listening." : e.getMessage());
            restartListeningSoon(1800);
        }
    }

    private void ensureRecognizer() {
        if (recognizer != null) return;

        recognizer = SpeechRecognizer.createSpeechRecognizer(activity);
        recognizer.setRecognitionListener(createListener());
    }

    private RecognitionListener createListener() {
        return new RecognitionListener() {
            @Override
            public void onReadyForSpeech(Bundle params) {
                listening = true;
                stateEmitter.emit(active ? "active_listening" : "wake_listening");
            }

            @Override
            public void onBeginningOfSpeech() {
                stateEmitter.emit("speech_started");
            }

            @Override
            public void onRmsChanged(float rmsdB) {
                // Keep empty in production. Enable only for debugging:
                // stateEmitter.emit("rms:" + rmsdB);
            }

            @Override
            public void onBufferReceived(byte[] buffer) {
            }

            @Override
            public void onEndOfSpeech() {
                listening = false;
                stateEmitter.emit("speech_ended");
            }

            @Override
            public void onError(int errorCode) {
                listening = false;

                long aliveMs = System.currentTimeMillis() - lastListenStartMs;

                if (errorCode == SpeechRecognizer.ERROR_NO_MATCH && !lastPartialText.isEmpty()) {
                    partialEmitter.emit(lastPartialText);
                    handleText(lastPartialText, false);
                    lastPartialText = "";
                    restartListeningSoon(restartDelayMs);
                    return;
                }

                if (
                        errorCode == SpeechRecognizer.ERROR_NO_MATCH
                                || errorCode == SpeechRecognizer.ERROR_SPEECH_TIMEOUT
                ) {
                    if (aliveMs < 1800) {
                        stateEmitter.emit("stt_fast_restart");
                        restartListeningSoon(1800);
                    } else {
                        errorEmitter.emit(
                                "Speech error "
                                        + errorCode
                                        + ": "
                                        + ApolloSpeechTextUtils.speechErrorToText(errorCode)
                        );
                        restartListeningSoon(restartDelayMs);
                    }

                    return;
                }

                errorEmitter.emit(
                        "Speech error "
                                + errorCode
                                + ": "
                                + ApolloSpeechTextUtils.speechErrorToText(errorCode)
                );

                if (running) {
                    restartListeningSoon(restartDelayMs);
                }
            }

            @Override
            public void onResults(Bundle results) {
                listening = false;

                String text = bestResult(results);

                if (!text.isEmpty()) {
                    lastPartialText = "";
                    partialEmitter.emit(text);
                    handleText(text, false);
                } else if (!lastPartialText.isEmpty()) {
                    handleText(lastPartialText, false);
                    lastPartialText = "";
                }

                restartListeningSoon(restartDelayMs);
            }

            @Override
            public void onPartialResults(Bundle partialResults) {
                String text = bestResult(partialResults);

                if (!text.isEmpty()) {
                    lastPartialText = text;
                    partialEmitter.emit(text);
                    handleText(text, true);
                }
            }

            @Override
            public void onEvent(int eventType, Bundle params) {
            }
        };
    }

    private void handleText(String rawText, boolean partial) {
        String text = ApolloSpeechTextUtils.cleanText(rawText);
        if (text.isEmpty()) return;

        if (!active) {
            if (wakeDetector.containsWakePhrase(text)) {
                active = true;
                activeUntilMs = 0;
                clearActiveTimeout();

                wakeEmitter.emit(rawText);

                String command = wakeDetector.removeWakePhrase(text);

                if (!partial && !command.isEmpty()) {
                    emitCommand(command);
                }
            }

            return;
        }

        if (!partial && sleepDetector.containsSleepPhrase(text)) {
            sleepEmitter.emit(rawText);
            deactivateToWakeListening();
            return;
        }

        if (!partial && !wakeDetector.isOnlyWakePhrase(text)) {
            emitCommand(rawText);
        }
    }

    private void emitCommand(String text) {
        String folder = intentRegistry.folderFor(text);
        String json = ApolloSpeechTextUtils.commandJson(text, folder);
        commandEmitter.emit(json);
    }

    private void deactivateToWakeListening() {
        active = false;
        activeUntilMs = 0;
        lastPartialText = "";

        clearActiveTimeout();

        if (running) {
            restartListeningSoon(250);
        }
    }

    private void clearActiveTimeout() {
        if (activeTimeoutRunnable != null) {
            mainHandler.removeCallbacks(activeTimeoutRunnable);
            activeTimeoutRunnable = null;
        }
    }

    private void restartListeningSoon(int delayMs) {
        if (!running) return;

        int generation = ++startGeneration;

        cancelRecognizer();

        mainHandler.postDelayed(() -> {
            if (!running || generation != startGeneration) return;
            startListeningInternal();
        }, delayMs);
    }

    private void cancelRecognizer() {
        listening = false;

        if (recognizer != null) {
            try {
                recognizer.cancel();
            } catch (Exception ignored) {
            }
        }
    }

    private void destroyRecognizer() {
        listening = false;

        if (recognizer != null) {
            try {
                recognizer.cancel();
            } catch (Exception ignored) {
            }

            try {
                recognizer.destroy();
            } catch (Exception ignored) {
            }

            recognizer = null;
        }
    }

    private String bestResult(Bundle bundle) {
        if (bundle == null) return "";

        ArrayList<String> matches = bundle.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (matches == null || matches.isEmpty()) return "";

        return matches.get(0) == null ? "" : matches.get(0);
    }

    public void startActiveTimeout() {
        mainHandler.post(() -> {
            running = true;
            active = true;
            lastPartialText = "";

            activeUntilMs = System.currentTimeMillis() + activeCooldownMs;

            clearActiveTimeout();

            activeTimeoutRunnable = () -> {
                active = false;
                activeUntilMs = 0;
                activeTimeoutRunnable = null;

                stateEmitter.emit("idle");

                if (running) {
                    restartListeningSoon(250);
                }
            };

            mainHandler.postDelayed(activeTimeoutRunnable, activeCooldownMs);
        });
    }
}