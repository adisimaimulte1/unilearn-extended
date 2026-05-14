package ro.contras.apollospeech;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class ApolloSleepWordDetector {
    private static final float SLEEP_THRESHOLD = 0.68f;
    private static final int MAX_GAP_BETWEEN_PATTERN_WORDS = 5;
    private static final int NEGATION_LOOKBACK_WORDS = 4;

    private String assistantName = "apollo";

    private final List<List<String>> sleepPatterns = new ArrayList<>();

    public ApolloSleepWordDetector() {
        addDefaultPatterns();
    }


    public String getAssistantName() {
        return assistantName;
    }


    public void setAssistantName(String name) {
        if (name != null && !name.trim().isEmpty()) {
            assistantName = ApolloSpeechTextUtils.normalize(name);
        }
    }


    public void addSleepPattern(String... words) {
        if (words == null || words.length == 0) return;

        List<String> pattern = new ArrayList<>();

        for (String word : words) {
            if (word == null) continue;

            String normalized = ApolloSpeechTextUtils.normalize(word);

            if (!normalized.isEmpty()) {
                pattern.add(normalized);
            }
        }

        if (!isSafePattern(pattern)) {
            return;
        }

        sleepPatterns.add(pattern);
    }

    private void addDefaultPatterns() {
        addSleepPattern("stop", "listening");
        addSleepPattern("stop", "hearing");
        addSleepPattern("stop", "recording");

        addSleepPattern("go", "sleep");
        addSleepPattern("go", "to", "sleep");

        addSleepPattern("shut", "down");
        addSleepPattern("shut", "yourself", "down");

        addSleepPattern("turn", "off");
        addSleepPattern("turn", "yourself", "off");

        // Common STT mistake: "off" can become "of".
        addSleepPattern("turn", "of");
        addSleepPattern("turn", "yourself", "of");

        addSleepPattern("switch", "off");
        addSleepPattern("switch", "yourself", "off");

        addSleepPattern("cancel", "listening");
        addSleepPattern("cancel", "recording");

        addSleepPattern("never", "mind");
        addSleepPattern("that", "all");
        addSleepPattern("that", "is", "all");

        addSleepPattern("be", "quiet");
        addSleepPattern("stay", "quiet");

        addSleepPattern("disable", "microphone");
        addSleepPattern("deactivate", "microphone");

        addSleepPattern("mute", "yourself");
        addSleepPattern("mute", "microphone");

        addSleepPattern("stop", assistantName);
        addSleepPattern("sleep", assistantName);
        addSleepPattern("quiet", assistantName);
    }


    public boolean containsSleepPhrase(String text) {
        String normalized = ApolloSpeechTextUtils.normalize(text);
        if (normalized.isEmpty()) return false;

        List<String> tokens = tokenize(normalized);
        if (tokens.isEmpty()) return false;

        MatchResult best = bestSleepMatch(tokens);
        return best.matched && best.score >= SLEEP_THRESHOLD;
    }

    private boolean containsNegation(List<String> tokens) {
        if (tokens.isEmpty()) {
            return false;
        }

        for (String token : tokens) {
            if (
                    token.equals("dont")
                            || token.equals("don't")
                            || token.equals("never")
                            || token.equals("no")
                            || token.equals("without")
                            || token.equals("cannot")
                            || token.equals("cant")
                            || token.equals("can't")
            ) {
                return true;
            }
        }

        for (int i = 0; i < tokens.size() - 1; i++) {
            String current = tokens.get(i);
            String next = tokens.get(i + 1);

            if (current.equals("do") && next.equals("not")) return true;
            if (current.equals("should") && next.equals("not")) return true;
            if (current.equals("must") && next.equals("not")) return true;
            if (current.equals("can") && next.equals("not")) return true;
            if (current.equals("will") && next.equals("not")) return true;
            if (current.equals("would") && next.equals("not")) return true;
        }

        return false;
    }

    private boolean hasNegationBeforeMatch(List<String> tokens, int matchStartIndex) {
        int start = Math.max(0, matchStartIndex - NEGATION_LOOKBACK_WORDS);
        int end = matchStartIndex - 1;

        if (end < start) {
            return false;
        }

        List<String> window = new ArrayList<>();

        for (int i = start; i <= end; i++) {
            String token = tokens.get(i);

            if (!isFillerWord(token)) {
                window.add(token);
            }
        }

        return containsNegation(window);
    }


    private MatchResult bestSleepMatch(List<String> tokens) {
        MatchResult best = MatchResult.failed();

        for (List<String> pattern : sleepPatterns) {
            MatchResult result = findScoredOrderedPattern(tokens, pattern);

            if (!result.matched) {
                continue;
            }

            if (hasNegationBeforeMatch(tokens, result.startIndex)) {
                continue;
            }

            if (result.score > best.score) {
                best = result;
            }
        }

        return best;
    }

    private MatchResult findScoredOrderedPattern(List<String> tokens, List<String> pattern) {
        if (!isSafePattern(pattern)) return MatchResult.failed();

        MatchResult best = MatchResult.failed();

        for (int start = 0; start < tokens.size(); start++) {
            MatchResult candidate = tryMatchFrom(tokens, pattern, start);

            if (candidate.score > best.score) {
                best = candidate;
            }
        }

        return best;
    }

    private MatchResult tryMatchFrom(List<String> tokens, List<String> pattern, int startIndex) {
        int patternIndex = 0;
        int firstMatchedIndex = -1;
        int lastMatchedIndex = -1;
        int totalGap = 0;

        for (int i = startIndex; i < tokens.size(); i++) {
            String token = tokens.get(i);

            String expected = pattern.get(patternIndex);

            if (token.equals(assistantName) && !expected.equals(assistantName)) {
                continue;
            }

            if (isFillerWord(token)) {
                continue;
            }

            if (token.equals(expected)) {
                if (firstMatchedIndex == -1) {
                    firstMatchedIndex = i;
                }

                if (lastMatchedIndex != -1) {
                    int gap = countUsefulWordsBetween(tokens, lastMatchedIndex + 1, i - 1);

                    if (gap > MAX_GAP_BETWEEN_PATTERN_WORDS) {
                        return MatchResult.failed();
                    }

                    totalGap += gap;
                }

                lastMatchedIndex = i;
                patternIndex++;

                if (patternIndex >= pattern.size()) {
                    float score = calculateScore(
                            tokens,
                            pattern,
                            firstMatchedIndex,
                            lastMatchedIndex,
                            totalGap
                    );

                    return new MatchResult(true, firstMatchedIndex, lastMatchedIndex, score);
                }
            }
        }

        return MatchResult.failed();
    }


    private float calculateScore(
            List<String> tokens,
            List<String> pattern,
            int startIndex,
            int endIndex,
            int totalGap
    ) {
        int span = endIndex - startIndex + 1;
        int usefulSpan = countUsefulWordsBetween(tokens, startIndex, endIndex);

        float score = 1.0f;

        score -= totalGap * 0.08f;
        score -= Math.max(0, usefulSpan - pattern.size()) * 0.05f;

        // Sleep commands can appear naturally after some words, so this penalty is weaker
        // than wake detection.
        int usefulWordsBefore = countUsefulWordsBetween(tokens, 0, startIndex - 1);
        score -= Math.min(0.15f, usefulWordsBefore * 0.025f);

        if (span > 10) {
            score -= 0.12f;
        }

        return clamp01(score);
    }


    private List<String> tokenize(String text) {
        if (text == null || text.trim().isEmpty()) {
            return new ArrayList<>();
        }

        String[] rawTokens = text.trim().split("\\s+");
        return new ArrayList<>(Arrays.asList(rawTokens));
    }

    private int countUsefulWordsBetween(List<String> tokens, int start, int end) {
        if (start > end) return 0;

        int count = 0;

        for (int i = Math.max(0, start); i <= Math.min(tokens.size() - 1, end); i++) {
            String token = tokens.get(i);

            if (!token.equals(assistantName) && !isFillerWord(token)) {
                count++;
            }
        }

        return count;
    }


    private boolean isSafePattern(List<String> pattern) {
        if (pattern == null || pattern.size() < 2) {
            return false;
        }

        Set<String> uniqueWords = new HashSet<>(pattern);
        return uniqueWords.size() >= 2;
    }

    private boolean isFillerWord(String token) {
        return token.equals("please")
                || token.equals("the")
                || token.equals("a")
                || token.equals("an")
                || token.equals("there")
                || token.equals("now")
                || token.equals("can")
                || token.equals("you")
                || token.equals("could")
                || token.equals("would")
                || token.equals("just")
                || token.equals("like")
                || token.equals("um")
                || token.equals("uh")
                || token.equals("back")
                || token.equals("for")
                || token.equals("me");
    }


    private float clamp01(float value) {
        return Math.max(0.0f, Math.min(1.0f, value));
    }


    private static class MatchResult {
        final boolean matched;
        final int startIndex;
        final int endIndex;
        final float score;

        MatchResult(boolean matched, int startIndex, int endIndex, float score) {
            this.matched = matched;
            this.startIndex = startIndex;
            this.endIndex = endIndex;
            this.score = score;
        }

        static MatchResult failed() {
            return new MatchResult(false, -1, -1, 0.0f);
        }
    }
}