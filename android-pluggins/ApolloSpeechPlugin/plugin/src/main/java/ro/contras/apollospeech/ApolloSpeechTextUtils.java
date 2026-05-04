package ro.contras.apollospeech;

import android.speech.SpeechRecognizer;

import java.util.Locale;

public class ApolloSpeechTextUtils {
    public static String cleanText(String text) {
        if (text == null) return "";
        return text.trim();
    }

    public static String normalize(String text) {
        if (text == null) return "";

        return text
                .toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9ăâîșşțţ ]", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }

    public static String commandJson(String text, String folder) {
        return "{"
                + "\"text\":\"" + escapeJson(text) + "\","
                + "\"folder\":\"" + escapeJson(folder) + "\""
                + "}";
    }

    private static String escapeJson(String value) {
        if (value == null) return "";

        return value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }

    public static String speechErrorToText(int errorCode) {
        switch (errorCode) {
            case SpeechRecognizer.ERROR_AUDIO:
                return "Audio recording error.";
            case SpeechRecognizer.ERROR_CLIENT:
                return "Client side error.";
            case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS:
                return "Insufficient permissions.";
            case SpeechRecognizer.ERROR_NETWORK:
                return "Network error.";
            case SpeechRecognizer.ERROR_NETWORK_TIMEOUT:
                return "Network timeout.";
            case SpeechRecognizer.ERROR_NO_MATCH:
                return "No speech match.";
            case SpeechRecognizer.ERROR_RECOGNIZER_BUSY:
                return "Recognizer busy.";
            case SpeechRecognizer.ERROR_SERVER:
                return "Server error.";
            case SpeechRecognizer.ERROR_SPEECH_TIMEOUT:
                return "Speech timeout.";
            default:
                return "Unknown error.";
        }
    }
}