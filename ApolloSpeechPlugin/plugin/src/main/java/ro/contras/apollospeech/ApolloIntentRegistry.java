package ro.contras.apollospeech;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class ApolloIntentRegistry {
    private final List<ApolloIntent> intents = new ArrayList<>();

    public ApolloIntentRegistry() {
        registerSettingsCommands();
        registerNavigationCommands();
        registerGalaxyCommands();
        registerSimulationCommands();
        registerCreationCommands();
        registerTalkCommands();
    }



    public ApolloCommandParse parse(String input) {
        String raw = input == null ? "" : input.trim();
        String normalized = ApolloSpeechTextUtils.normalize(raw);

        ApolloCommandParse result = new ApolloCommandParse(raw, normalized);

        if (normalized.isEmpty()) {
            return result;
        }

        List<String> segments = splitLinkedCommands(normalized);

        for (String segment : segments) {
            ApolloCommand command = commandForSegment(segment);

            if (command == null || command.folder.isEmpty()) {
                continue;
            }

            result.commands.add(command);
        }

        return result;
    }



    private void registerSettingsCommands() {
        add("actions/change_settings/sfx_on",
                onWords(),
                words("sfx", "sound effects", "sounds", "app sounds", "ui sounds", "effects", "audio effects", "interface sounds", "button sounds")
        );

        add("actions/change_settings/sfx_off",
                offWords(),
                words("sfx", "sound effects", "sounds", "app sounds", "ui sounds", "effects", "audio effects", "interface sounds", "button sounds")
        );

        add("actions/change_settings/music_on",
                onWords(),
                words("music", "background music", "app music", "soundtrack", "ambient music", "theme music", "background soundtrack")
        );

        add("actions/change_settings/music_off",
                offWords(),
                words("music", "background music", "app music", "soundtrack", "ambient music", "theme music", "background soundtrack")
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
                        "listening for apollo",
                        "apollo wake up",
                        "apollo activation",
                        "voice wake up",
                        "voice trigger"
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
                        "listening for apollo",
                        "apollo wake up",
                        "apollo activation",
                        "voice wake up",
                        "voice trigger"
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
                        "animation intensity",
                        "movement effects"
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
                        "animation intensity",
                        "movement effects"
                )
        );

        add("actions/change_settings/theme_dark",
                words("set", "switch", "change", "turn on", "enable", "make", "use"),
                words("dark mode", "dark theme", "night mode", "black theme")
        );

        add("actions/change_settings/theme_light",
                words("set", "switch", "change", "turn on", "enable", "make", "use"),
                words("light mode", "light theme", "day mode", "white theme")
        );
    }

    private void registerNavigationCommands() {
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
                words("menu", "main menu", "navigation menu", "app menu")
        );

        add("actions/navigate/exit_menu",
                exitWords(),
                words("menu", "main menu", "navigation menu", "app menu")
        );

        add("actions/navigate/enter_settings",
                enterWords(),
                words("settings", "setting screen", "settings screen", "options", "preferences")
        );

        add("actions/navigate/exit_settings",
                exitWords(),
                words("settings", "setting screen", "settings screen", "options", "preferences")
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

        add("actions/navigate/enter_galaxy",
                enterWords(),
                words(
                        "galaxy",
                        "galaxy console",
                        "simulation console",
                        "universe console",
                        "playground",
                        "playgrounds",
                        "simulation settings",
                        "orbit settings"
                )
        );

        add("actions/navigate/exit_galaxy",
                exitWords(),
                words(
                        "galaxy",
                        "galaxy console",
                        "simulation console",
                        "universe console",
                        "playground",
                        "playgrounds",
                        "simulation settings",
                        "orbit settings"
                )
        );

        add("actions/navigate/enter_achievements",
                enterWords(),
                words(
                        "achievements",
                        "achievement screen",
                        "achievements screen",
                        "trophies",
                        "medals",
                        "badges",
                        "progress"
                )
        );

        add("actions/navigate/exit_achievements",
                exitWords(),
                words(
                        "achievements",
                        "achievement screen",
                        "achievements screen",
                        "trophies",
                        "medals",
                        "badges",
                        "progress"
                )
        );

        add("actions/navigate/enter_help",
                enterWords(),
                words(
                        "help",
                        "help screen",
                        "tutorial",
                        "guide",
                        "instructions",
                        "how to play",
                        "question mark"
                )
        );

        add("actions/navigate/exit_help",
                exitWords(),
                words(
                        "help",
                        "help screen",
                        "tutorial",
                        "guide",
                        "instructions",
                        "how to play",
                        "question mark"
                )
        );
    }

    private void registerGalaxyCommands() {
        add("actions/galaxy/center_anchor",
                words("center", "focus", "find", "show", "go to"),
                words("anchor", "anchor body", "main body", "center body", "orbit anchor")
        );

        add("actions/galaxy/reset_orbits",
                words("reset", "fix", "rebuild", "recalculate", "restore"),
                words("orbits", "orbit", "paths", "trajectories", "revolutions")
        );

        add("actions/galaxy/clear_trails",
                words("clear", "erase", "remove", "delete", "wipe"),
                words("trails", "trail", "trajectory lines", "orbit trails")
        );

        add("actions/galaxy/reset_camera",
                words("reset", "recenter", "restore", "fix"),
                words("camera", "view", "zoom", "position", "screen view")
        );
    }

    private void registerSimulationCommands() {
        add("actions/simulation/add_body",
                simulationAddWords(),
                words(
                        "screen",
                        "scene",
                        "simulation",
                        "universe",
                        "playground",
                        "space",
                        "system"
                )
        );

        add("actions/simulation/remove_body",
                simulationRemoveWords(),
                words(
                        "screen",
                        "scene",
                        "simulation",
                        "universe",
                        "playground",
                        "space",
                        "system"
                )
        );
    }

    private void registerCreationCommands() {
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
    }

    private void registerTalkCommands() {
        add("just_talk/joke",
                words("tell", "say", "give", "make", "come up with"),
                words("joke", "another joke", "space joke", "funny joke", "something funny")
        );
    }



    private ApolloCommand commandForSegment(String segment) {
        String text = ApolloSpeechTextUtils.normalize(segment);

        if (text.isEmpty()) {
            return null;
        }

        ApolloCommand parameterCommand = matchSimulationParameterCommand(text);
        if (parameterCommand != null) return parameterCommand;

        ApolloCommand toggleCommand = matchGalaxyToggleCommand(text);
        if (toggleCommand != null) return toggleCommand;

        ApolloCommand categoryCommand = matchAchievementCategoryCommand(text);
        if (categoryCommand != null) return categoryCommand;

        return matchRegisteredIntent(text);
    }



    private ApolloCommand matchRegisteredIntent(String normalizedInput) {
        ApolloIntent bestIntent = null;
        int bestScore = 0;

        for (ApolloIntent intent : intents) {
            int score = intent.score(normalizedInput);

            if (score > bestScore) {
                bestScore = score;
                bestIntent = intent;
            }
        }

        if (bestIntent == null) {
            return null;
        }

        ApolloCommand command = new ApolloCommand(bestIntent.folder);
        command.confidence = bestScore;
        return command;
    }

    private ApolloCommand matchSimulationParameterCommand(String text) {
        if (!containsAny(text, words("set", "change", "make", "put", "adjust", "move"))) {
            return null;
        }

        String parameter = detectSimulationParameter(text);

        if (parameter.isEmpty()) {
            return null;
        }

        int percent = extractPercentage(text);

        if (percent < 0) {
            return null;
        }

        ApolloCommand command = new ApolloCommand("actions/galaxy/set_simulation_parameter");
        command.params.put("parameter", parameter);
        command.params.put("percent", String.valueOf(clamp(percent)));
        command.confidence = 100;
        return command;
    }

    private ApolloCommand matchGalaxyToggleCommand(String text) {
        String property = detectGalaxyToggleProperty(text);

        if (property.isEmpty()) {
            return null;
        }

        String value = "";

        if (containsAny(text, onWords())) {
            value = "true";
        } else if (containsAny(text, offWords())) {
            value = "false";
        }

        if (value.isEmpty()) {
            return null;
        }

        ApolloCommand command = new ApolloCommand("actions/galaxy/toggle_setting");
        command.params.put("property", property);
        command.params.put("value", value);
        command.confidence = 100;
        return command;
    }

    private ApolloCommand matchAchievementCategoryCommand(String text) {
        if (!containsAny(text, enterWords())) {
            return null;
        }

        if (!containsAny(text, words("achievement", "achievements", "trophy", "trophies", "badge", "badges"))) {
            return null;
        }

        String category = detectAchievementCategory(text);

        if (category.isEmpty()) {
            return null;
        }

        ApolloCommand command = new ApolloCommand("actions/navigate/enter_achievements");
        command.params.put("category", category);
        command.confidence = 100;
        return command;
    }



    private String detectSimulationParameter(String text) {
        String clean = commandText(text);

        if (containsAny(clean, words(
                "simulation speed",
                "time speed",
                "time multiplier",
                "speed of time",
                "time scale",
                "time dilation",
                "simulation multiplier",
                "sim speed",
                "sim multiplier",
                "game speed",
                "clock speed",
                "time"
        ))) {
            return "simulation_speed";
        }

        if (containsAny(clean, words(
                "orbit speed",
                "orbit speed multiplier",
                "orbital speed",
                "orbital speed multiplier",
                "revolution speed",
                "revolution multiplier",
                "orbit multiplier",
                "orbit velocity",
                "orbital velocity",
                "rotation speed",
                "spin around speed"
        ))) {
            return "orbit_speed_multiplier";
        }

        if (containsAny(clean, words(
                "center pull",
                "centre pull",
                "center pull multiplier",
                "centre pull multiplier",
                "center full multiplier",
                "centre full multiplier",
                "center force",
                "centre force",
                "center attraction",
                "centre attraction",
                "center anchor strength",
                "centre anchor strength",
                "anchor strength",
                "anchor pull",
                "anchor force",
                "center strength",
                "centre strength",
                "pull strength",
                "pull multiplier",
                "gravity pull",
                "gravity strength",
                "gravity multiplier"
        ))) {
            return "center_anchor_strength";
        }

        if (containsAny(clean, words(
                "stable orbit elasticity",
                "orbit elasticity",
                "orbit lock strength",
                "orbit locking strength",
                "lock strength",
                "lock multiplier",
                "orbit correction",
                "orbit correction strength",
                "orbit stabilization",
                "orbit stabilisation",
                "stable orbit strength",
                "stable orbit lock",
                "snap strength",
                "orbit snap",
                "orbit magnet"
        ))) {
            return "orbit_lock_strength";
        }

        if (containsAny(clean, words(
                "stable orbit radius",
                "orbit radius",
                "radius multiplier",
                "stable radius",
                "stable radius multiplier",
                "orbit distance",
                "orbital distance",
                "distance multiplier",
                "orbit spacing",
                "planet spacing",
                "body spacing",
                "system spacing",
                "spacing multiplier"
        ))) {
            return "stable_orbit_radius_multiplier";
        }

        if (containsAny(clean, words(
                "hand throw",
                "hand draw",
                "throw strength",
                "draw strength",
                "throw multiplier",
                "draw multiplier",
                "drag throw",
                "drag draw",
                "drag throw strength",
                "drag draw strength",
                "drag throw multiplier",
                "drag draw multiplier",
                "flick strength",
                "flick multiplier",
                "launch strength",
                "launch multiplier",
                "swipe throw",
                "swipe draw",
                "swipe strength",
                "body throw",
                "body draw"
        ))) {
            return "drag_throw_strength";
        }

        return "";
    }

    private String detectGalaxyToggleProperty(String text) {
        String clean = commandText(text);

        if (containsAny(clean, words(
                "center largest bodies",
                "centre largest bodies",
                "center largest body",
                "centre largest body",
                "largest bodies",
                "largest body",
                "biggest bodies",
                "biggest body",
                "largest object",
                "biggest object",
                "auto center largest",
                "auto centre largest",
                "follow largest",
                "track largest"
        ))) {
            return "center_largest_bodies";
        }

        if (containsAny(clean, words(
                "stable orbit",
                "stable orbits",
                "orbit lock",
                "orbit locks",
                "locked orbits",
                "orbit locking",
                "orbit stabilization",
                "orbit stabilisation",
                "auto orbit correction",
                "orbit correction",
                "orbit assist"
        ))) {
            return "stable_orbits";
        }

        if (containsAny(clean, words(
                "trajectories",
                "trajectory",
                "trails",
                "trail",
                "orbit trails",
                "orbit trail",
                "paths",
                "path lines",
                "trajectory lines",
                "orbit lines",
                "movement trails"
        ))) {
            return "trajectories";
        }

        return "";
    }

    private String detectAchievementCategory(String text) {
        if (containsAny(text, words("added bodies", "body achievements", "added body", "new bodies"))) {
            return "add_body";
        }

        if (containsAny(text, words("planet collisions", "planet collision", "collision achievements"))) {
            return "planet_collision";
        }

        if (containsAny(text, words("star collisions", "star collision", "sun collisions", "sun collision"))) {
            return "sun_collision";
        }

        if (containsAny(text, words("black holes", "black hole", "singularity", "singularities"))) {
            return "black_hole";
        }

        if (containsAny(text, words("stat mastery", "stats", "score achievements", "system score"))) {
            return "stat_mastery";
        }

        if (containsAny(text, words("ai use", "ai commands", "apollo commands", "voice commands", "voice control"))) {
            return "ai_use";
        }

        if (containsAny(text, words("unstable systems", "unstable system", "instability"))) {
            return "instability";
        }

        if (containsAny(text, words("cards", "card achievements", "planet cards", "card collection"))) {
            return "type_amount";
        }

        return "";
    }



    private int extractPercentage(String text) {
        String clean = commandText(text);

        Matcher percentMatcher = Pattern.compile("\\b(100|[0-9]{1,2})\\s*(?:%|percent|percentage|per cent)\\b").matcher(clean);

        if (percentMatcher.find()) {
            return safeInt(percentMatcher.group(1));
        }

        int wordNumber = extractWordPercentage(clean);

        if (wordNumber >= 0) {
            return wordNumber;
        }

        Matcher plainNumberMatcher = Pattern.compile("\\b(100|[0-9]{1,2})\\b").matcher(clean);

        if (plainNumberMatcher.find()) {
            return safeInt(plainNumberMatcher.group(1));
        }

        return -1;
    }

    private int extractWordPercentage(String text) {
        String clean = commandText(text);
        Map<String, Integer> numbers = new LinkedHashMap<>();
        numbers.put("zero", 0);
        numbers.put("ten", 10);
        numbers.put("twenty", 20);
        numbers.put("thirty", 30);
        numbers.put("forty", 40);
        numbers.put("fourty", 40);
        numbers.put("fifty", 50);
        numbers.put("sixty", 60);
        numbers.put("seventy", 70);
        numbers.put("eighty", 80);
        numbers.put("ninety", 90);
        numbers.put("hundred", 100);
        numbers.put("one hundred", 100);

        for (Map.Entry<String, Integer> entry : numbers.entrySet()) {
            String key = entry.getKey();

            if (containsAny(clean, words(key + " percent", key + " percentage", key + " per cent"))) {
                return entry.getValue();
            }
        }

        return -1;
    }

    private List<String> splitLinkedCommands(String normalizedInput) {
        List<String> result = new ArrayList<>();

        String text = normalizedInput == null ? "" : normalizedInput.trim();

        if (text.isEmpty()) {
            return result;
        }

        List<String> afterSplit = splitBySingleConnector(text, " after ");

        if (afterSplit.size() == 2 && commandForSoftCheck(afterSplit.get(0)) && commandForSoftCheck(afterSplit.get(1))) {
            result.add(afterSplit.get(1));
            result.add(afterSplit.get(0));
            return expandSoftAndCommands(result);
        }

        List<String> beforeSplit = splitBySingleConnector(text, " before ");

        if (beforeSplit.size() == 2 && commandForSoftCheck(beforeSplit.get(0)) && commandForSoftCheck(beforeSplit.get(1))) {
            result.add(beforeSplit.get(0));
            result.add(beforeSplit.get(1));
            return expandSoftAndCommands(result);
        }

        String[] hardParts = text.split("\\b(?:and then|then|after that|afterwards|next)\\b");

        for (String part : hardParts) {
            String clean = part.trim();

            if (!clean.isEmpty()) {
                result.add(clean);
            }
        }

        return expandSoftAndCommands(result);
    }

    private List<String> expandSoftAndCommands(List<String> input) {
        List<String> result = new ArrayList<>();

        for (String segment : input) {
            String[] andParts = segment.split("\\band\\b");

            if (andParts.length <= 1) {
                result.add(segment);
                continue;
            }

            boolean allPartsLookLikeCommands = true;
            List<String> cleanParts = new ArrayList<>();

            for (String part : andParts) {
                String clean = part.trim();

                if (clean.isEmpty()) {
                    continue;
                }

                cleanParts.add(clean);

                if (!commandForSoftCheck(clean)) {
                    allPartsLookLikeCommands = false;
                }
            }

            if (allPartsLookLikeCommands && cleanParts.size() > 1) {
                result.addAll(cleanParts);
            } else {
                result.add(segment);
            }
        }

        return result;
    }

    private boolean commandForSoftCheck(String segment) {
        String text = ApolloSpeechTextUtils.normalize(segment);

        if (text.isEmpty()) {
            return false;
        }

        if (matchSimulationParameterCommand(text) != null) return true;
        if (matchGalaxyToggleCommand(text) != null) return true;
        if (matchAchievementCategoryCommand(text) != null) return true;

        for (ApolloIntent intent : intents) {
            if (intent.matches(text)) {
                return true;
            }
        }

        return false;
    }

    private List<String> splitBySingleConnector(String text, String connector) {
        List<String> result = new ArrayList<>();
        int index = text.indexOf(connector);

        if (index < 0) {
            return result;
        }

        String left = text.substring(0, index).trim();
        String right = text.substring(index + connector.length()).trim();

        if (!left.isEmpty() && !right.isEmpty()) {
            result.add(left);
            result.add(right);
        }

        return result;
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
                "build"
        );
    }

    private List<String> simulationAddWords() {
        return words(
                "add",
                "put",
                "place",
                "spawn",
                "insert",
                "bring",
                "show"
        );
    }

    private List<String> simulationRemoveWords() {
        return words(
                "remove",
                "delete",
                "take out",
                "hide",
                "despawn",
                "clear"
        );
    }



    private boolean containsAny(String input, List<String> values) {
        String normalized = commandText(input);

        for (String value : values) {
            String clean = commandText(value);

            if (!clean.isEmpty() && normalized.contains(clean)) {
                return true;
            }
        }

        return false;
    }

    private String commandText(String input) {
        String normalized = ApolloSpeechTextUtils.normalize(input == null ? "" : input);
        normalized = normalized.replace("%", " percent ");
        normalized = normalized.replace("per cent", "percent");
        normalized = normalized.replace("centre", "center");
        // Common STT mistakes. Normalize them before phrase matching so commands like
        // "change center pool multiplier to 50 percent" still hit center pull,
        // and "change hand draw multiplier to 90 percent" still hits hand throw.
        normalized = normalized.replaceAll("\\bpool\\b", "pull");
        normalized = normalized.replaceAll("\\bdraw\\b", "throw");
        normalized = normalized.replaceAll("\\bdrawing\\b", "throwing");
        normalized = normalized.replaceAll("\\bdrawn\\b", "thrown");
        normalized = normalized.replaceAll("\\s+", " ").trim();
        return normalized;
    }



    private int safeInt(String value) {
        try {
            return Integer.parseInt(value);
        } catch (Exception ignored) {
            return -1;
        }
    }

    private int clamp(int value) {
        return Math.max(0, Math.min(100, value));
    }



    public static class ApolloCommandParse {
        public final String text;
        public final String normalizedText;
        public final List<ApolloCommand> commands = new ArrayList<>();

        ApolloCommandParse(String text, String normalizedText) {
            this.text = text == null ? "" : text;
            this.normalizedText = normalizedText == null ? "" : normalizedText;
        }

        public boolean hasCommands() {
            return !commands.isEmpty();
        }
    }

    public static class ApolloCommand {
        public final String folder;
        public final Map<String, String> params = new LinkedHashMap<>();
        public int confidence = 0;

        ApolloCommand(String folder) {
            this.folder = folder == null ? "" : folder;
        }
    }



    private record ApolloIntent(String folder, List<String> triggers, List<String> targets) {

        boolean matches(String input) {
            return score(input) > 0;
        }

        int score(String input) {
            String normalizedInput = ApolloSpeechTextUtils.normalize(input);
            int bestScore = 0;

            for (String trigger : triggers) {
                String cleanTrigger = ApolloSpeechTextUtils.normalize(trigger);

                if (cleanTrigger.isEmpty() || !normalizedInput.contains(cleanTrigger)) {
                    continue;
                }

                for (String target : targets) {
                    String cleanTarget = ApolloSpeechTextUtils.normalize(target);

                    if (cleanTarget.isEmpty() || !normalizedInput.contains(cleanTarget)) {
                        continue;
                    }

                    int score = cleanTrigger.length() + cleanTarget.length();

                    if (score > bestScore) {
                        bestScore = score;
                    }
                }
            }

            return bestScore;
        }
    }
}