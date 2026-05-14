package ro.contras.apollospeech;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

public class ApolloIntentRegistry {
    private final List<ApolloIntent> intents = new ArrayList<>();

    public ApolloIntentRegistry() {
        add("actions/change_settings/sfx_on",
                onWords(),
                words(
                        "sfx",
                        "sound effects",
                        "sounds",
                        "app sounds",
                        "ui sounds",
                        "effects"
                )
        );

        add("actions/change_settings/sfx_off",
                offWords(),
                words(
                        "sfx",
                        "sound effects",
                        "sounds",
                        "app sounds",
                        "ui sounds",
                        "effects"
                )
        );

        add("actions/change_settings/wake_word_detection_on",
                onWords(),
                words(
                        "wake word",
                        "wake word detection",
                        "hey apollo",
                        "activation phrase",
                        "voice activation",
                        "apollo detection",
                        "listening for apollo"
                )
        );

        add("actions/change_settings/wake_word_detection_off",
                offWords(),
                words(
                        "wake word",
                        "wake word detection",
                        "hey apollo",
                        "activation phrase",
                        "voice activation",
                        "apollo detection",
                        "listening for apollo"
                )
        );

        add("actions/change_settings/reduce_motion_on",
                onWords(),
                words(
                        "reduce motion",
                        "reduced motion",
                        "less motion",
                        "motion reduction",
                        "animations",
                        "animation"
                )
        );

        add("actions/change_settings/reduce_motion_off",
                offWords(),
                words(
                        "reduce motion",
                        "reduced motion",
                        "less motion",
                        "motion reduction",
                        "animations",
                        "animation"
                )
        );

        add("actions/change_settings/theme_dark",
                words(
                        "set",
                        "switch",
                        "change",
                        "turn on",
                        "enable",
                        "make",
                        "use"
                ),
                words(
                        "dark mode",
                        "dark theme",
                        "night mode",
                        "black theme",
                        "dark"
                )
        );

        add("actions/change_settings/theme_light",
                words(
                        "set",
                        "switch",
                        "change",
                        "turn on",
                        "enable",
                        "make",
                        "use"
                ),
                words(
                        "light mode",
                        "light theme",
                        "day mode",
                        "white theme",
                        "light"
                )
        );


        add("actions/navigate/go_home",
                words(
                        "go",
                        "go to",
                        "go back to",
                        "return to",
                        "open",
                        "show",
                        "close",
                        "clear",
                        "dismiss",
                        "exit to",
                        "navigate to"
                ),
                words(
                        "home",
                        "home screen",
                        "main screen",
                        "main view",
                        "universe view",
                        "universe",
                        "everything",
                        "all popups"
                )
        );

        add("actions/navigate/enter_menu",
                enterWords(),
                words(
                        "menu",
                        "main menu",
                        "navigation menu",
                        "app menu"
                )
        );

        add("actions/navigate/exit_menu",
                exitWords(),
                words(
                        "menu",
                        "main menu",
                        "navigation menu",
                        "app menu"
                )
        );

        add("actions/navigate/enter_settings",
                enterWords(),
                words(
                        "settings",
                        "setting screen",
                        "settings screen",
                        "options",
                        "preferences"
                )
        );

        add("actions/navigate/exit_settings",
                exitWords(),
                words(
                        "settings",
                        "setting screen",
                        "settings screen",
                        "options",
                        "preferences"
                )
        );

        add("actions/navigate/enter_planet_cards",
                enterWords(),
                words(
                        "planet cards",
                        "cards",
                        "planet library",
                        "card library",
                        "planet card library",
                        "library"
                )
        );

        add("actions/navigate/exit_planet_cards",
                exitWords(),
                words(
                        "planet cards",
                        "cards",
                        "planet library",
                        "card library",
                        "planet card library",
                        "library"
                )
        );


        add("actions/create/galaxy",
                createWords(),
                words(
                        "galaxy",
                        "new galaxy",
                        "galaxy preset",
                        "spiral galaxy",
                        "elliptical galaxy"
                )
        );

        add("actions/create/planet",
                createWords(),
                words(
                        "planet",
                        "new planet",
                        "custom planet",
                        "planet card",
                        "new card",
                        "astral body",
                        "astronomical object",
                        "cosmic object",
                        "space object",
                        "celestial body",
                        "exoplanet",
                        "moon",
                        "satellite",
                        "star",
                        "dwarf planet",
                        "asteroid",
                        "comet"
                )
        );


        add("just_talk/joke",
                words(
                        "tell",
                        "say",
                        "give",
                        "make",
                        "come up with"
                ),
                words(
                        "joke",
                        "another joke",
                        "space joke",
                        "funny joke",
                        "something funny"
                )
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

    private List<String> onWords() {
        return words(
                "turn on",
                "enable",
                "activate",
                "start",
                "switch on",
                "set on"
        );
    }

    private List<String> offWords() {
        return words(
                "turn off",
                "disable",
                "deactivate",
                "stop",
                "switch off",
                "set off",
                "mute"
        );
    }

    private List<String> enterWords() {
        return words(
                "open",
                "enter",
                "show",
                "go to",
                "navigate to",
                "access",
                "bring up",
                "launch"
        );
    }

    private List<String> exitWords() {
        return words(
                "close",
                "exit",
                "leave",
                "go back",
                "back out of",
                "hide",
                "dismiss"
        );
    }

    private List<String> createWords() {
        return words(
                "create",
                "generate",
                "make",
                "build",
                "add",
                "spawn"
        );
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