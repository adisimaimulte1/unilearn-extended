package ro.contras.apollospeech;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class ApolloIntentRegistry {
    private final List<ApolloIntent> intents = new ArrayList<>();

    public ApolloIntentRegistry() {
        add("navigate/home",
                words("open", "go to", "enter", "show", "launch", "access", "navigate to", "go back to"),
                words("home", "main screen", "solar system", "universe")
        );

        add("navigate/menu",
                words("open", "go to", "enter", "show", "launch", "access", "navigate to", "go back to"),
                words("menu", "main menu", "selection screen")
        );

        add("navigate/planets",
                words("open", "go to", "enter", "show", "launch", "access", "navigate to", "check"),
                words("planets", "planet list", "solar system", "planet screen")
        );

        add("navigate/quiz",
                words("open", "go to", "start", "begin", "launch", "show"),
                words("quiz", "test", "questions", "challenge")
        );

        add("navigate/sandbox",
                words("open", "go to", "start", "begin", "launch", "show"),
                words("sandbox", "simulation", "orbit simulator", "planet creator")
        );

        add("action/generate_planet",
                words("create", "generate", "make", "build"),
                words("planet", "new planet", "custom planet")
        );

        add("action/explain_planet",
                words("explain", "describe", "tell me about", "what is", "teach me about"),
                words("planet", "this planet", "selected planet")
        );

        add("action/start_quiz",
                words("start", "begin", "launch", "run"),
                words("quiz", "test", "challenge")
        );

        add("action/compare_planets",
                words("compare", "difference between", "which is bigger", "which is smaller"),
                words("planet", "planets", "mars", "earth", "venus", "jupiter")
        );

        add("setting/toggle_voice",
                words("turn on", "turn off", "enable", "disable", "stop", "start"),
                words("voice", "assistant", "apollo")
        );

        add("setting/toggle_wake_word",
                words("turn on", "turn off", "enable", "disable", "stop", "start"),
                words("wake word", "hey apollo", "activation phrase", "voice activation")
        );

        add("just_talk/joke",
                words("tell", "say", "come up with"),
                words("joke", "another joke", "space joke")
        );
    }

    public String folderFor(String input) {
        String normalized = ApolloSpeechTextUtils.normalize(input);

        for (ApolloIntent intent : intents) {
            if (intent.matches(normalized)) {
                return intent.folder;
            }
        }

        return "";
    }

    private void add(String folder, List<String> triggers, List<String> targets) {
        intents.add(new ApolloIntent(folder, triggers, targets));
    }

    private List<String> words(String... values) {
        return Arrays.asList(values);
    }

    private static class ApolloIntent {
        final String folder;
        final List<String> triggers;
        final List<String> targets;

        ApolloIntent(String folder, List<String> triggers, List<String> targets) {
            this.folder = folder;
            this.triggers = triggers;
            this.targets = targets;
        }

        boolean matches(String input) {
            for (String trigger : triggers) {
                if (!input.contains(ApolloSpeechTextUtils.normalize(trigger))) {
                    continue;
                }

                for (String target : targets) {
                    if (input.contains(ApolloSpeechTextUtils.normalize(target))) {
                        return true;
                    }
                }
            }

            return false;
        }
    }
}