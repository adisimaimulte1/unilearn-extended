package ro.contras.apollospeech;

import android.speech.SpeechRecognizer;

import java.util.List;
import java.util.Map;

public class ApolloSpeechTextUtils {
    public static String cleanText(String text) {
        if (text == null) return "";
        return text.trim();
    }

    public static String normalize(String text) {
        if (text == null) return "";

        return text
                .toLowerCase()
                .replaceAll("[^a-z0-9ăâîșşțţ% ]", " ")
                .replaceAll("\\s+", " ")
                .trim();
    }



    public static String commandJson(ApolloIntentRegistry.ApolloCommandParse parse) {
        if (parse == null) {
            return emptyCommandJson();
        }

        StringBuilder builder = new StringBuilder();

        builder.append("{");
        builder.append("\"text\":\"").append(escapeJson(parse.text)).append("\",");
        builder.append("\"normalizedText\":\"").append(escapeJson(parse.normalizedText)).append("\",");
        builder.append("\"commandCount\":").append(parse.commands.size()).append(",");
        builder.append("\"commands\":[");

        List<ApolloIntentRegistry.ApolloCommand> commands = parse.commands;

        for (int i = 0; i < commands.size(); i++) {
            ApolloIntentRegistry.ApolloCommand command = commands.get(i);

            if (i > 0) {
                builder.append(",");
            }

            builder.append("{");
            builder.append("\"folder\":\"").append(escapeJson(command.folder)).append("\",");
            builder.append("\"confidence\":").append(command.confidence).append(",");
            builder.append("\"params\":{");

            int paramIndex = 0;

            for (Map.Entry<String, String> entry : command.params.entrySet()) {
                if (paramIndex > 0) {
                    builder.append(",");
                }

                builder.append("\"").append(escapeJson(entry.getKey())).append("\":");
                builder.append("\"").append(escapeJson(entry.getValue())).append("\"");

                paramIndex++;
            }

            builder.append("}");
            builder.append("}");
        }

        builder.append("]");
        builder.append("}");

        return builder.toString();
    }

    private static String emptyCommandJson() {
        return "{"
                + "\"text\":\"" + escapeJson("") + "\","
                + "\"normalizedText\":\"" + escapeJson("") + "\","
                + "\"commandCount\":0,"
                + "\"commands\":[]"
                + "}";
    }

    public static String escapeJson(String value) {
        if (value == null) return "";

        return value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\n", "\\n")
                .replace("\r", "\\r")
                .replace("\t", "\\t");
    }



    public static String speechErrorToText(int errorCode) {
        return switch (errorCode) {
            case SpeechRecognizer.ERROR_AUDIO -> "Audio recording error.";
            case SpeechRecognizer.ERROR_CLIENT -> "Client side error.";
            case SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "Insufficient permissions.";
            case SpeechRecognizer.ERROR_NETWORK -> "Network error.";
            case SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "Network timeout.";
            case SpeechRecognizer.ERROR_NO_MATCH -> "No speech match.";
            case SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "Recognizer busy.";
            case SpeechRecognizer.ERROR_SERVER -> "Server error.";
            case SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "Speech timeout.";
            default -> "Unknown error.";
        };
    }
}