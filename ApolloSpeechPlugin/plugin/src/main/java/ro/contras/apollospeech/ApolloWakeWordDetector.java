package ro.contras.apollospeech;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class ApolloWakeWordDetector {
    private static final float WAKE_THRESHOLD = 0.68f;
    private static final int MAX_GAP_BETWEEN_PATTERN_WORDS = 4;
    private static final int NEGATION_LOOKBACK_WORDS = 4;

    private String wakeName = "apollo";

    private final List<List<String>> wakePatterns = new ArrayList<>();

    public ApolloWakeWordDetector() {
        rebuildWakePatterns();
    }

    public String getWakeName() {
        return wakeName;
    }

    public void setWakeName(String name) {
        if (name != null && !name.trim().isEmpty()) {
            wakeName = ApolloSpeechTextUtils.normalize(name);
            rebuildWakePatterns();
        }
    }

    public boolean containsWakePhrase(String text) {
        String normalized = ApolloSpeechTextUtils.normalize(text);
        if (normalized.isEmpty()) return false;

        List<String> tokens = tokenize(normalized);
        if (tokens.isEmpty()) return false;

        MatchResult best = bestWakeMatch(tokens);
        return best.matched && best.score >= WAKE_THRESHOLD;
    }

    public boolean isOnlyWakePhrase(String text) {
        String normalized = ApolloSpeechTextUtils.normalize(text);
        if (normalized.isEmpty()) return false;

        List<String> tokens = removeFillerWords(tokenize(normalized));
        if (tokens.isEmpty()) return false;

        for (List<String> pattern : wakePatterns) {
            if (tokens.equals(pattern)) {
                return true;
            }
        }

        return false;
    }

    public String removeWakePhrase(String text) {
        String normalized = ApolloSpeechTextUtils.normalize(text);
        if (normalized.isEmpty()) return "";

        List<String> tokens = tokenize(normalized);
        if (tokens.isEmpty()) return "";

        MatchResult best = bestWakeMatch(tokens);

        if (!best.matched || best.score < WAKE_THRESHOLD) {
            return normalized;
        }

        List<String> remaining = new ArrayList<>();

        for (int i = best.endIndex + 1; i < tokens.size(); i++) {
            remaining.add(tokens.get(i));
        }

        return joinTokens(remaining).trim();
    }

    private void rebuildWakePatterns() {
        wakePatterns.clear();

        addWakePattern("ok", wakeName);
        addWakePattern("okay", wakeName);
        addWakePattern("hey", wakeName);
        addWakePattern("hei", wakeName);
        addWakePattern("hi", wakeName);
        addWakePattern("hello", wakeName);
        addWakePattern("yo", wakeName);

        addWakePattern("wake", wakeName);
        addWakePattern("wake", "up", wakeName);
        addWakePattern("listen", wakeName);
        addWakePattern("start", "listening");
        addWakePattern("start", "listening", wakeName);
    }

    public void addWakePattern(String... words) {
        if (words == null || words.length == 0) return;

        List<String> pattern = new ArrayList<>();

        for (String word : words) {
            if (word == null) continue;

            String normalized = ApolloSpeechTextUtils.normalize(word);

            if (!normalized.isEmpty()) {
                pattern.add(normalized);
            }
        }

        if (!isSafePattern(pattern)) return;

        wakePatterns.add(pattern);
    }

    private MatchResult bestWakeMatch(List<String> tokens) {
        MatchResult best = MatchResult.failed();

        for (List<String> pattern : wakePatterns) {
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

            if (isFillerWord(token)) {
                continue;
            }

            String expected = pattern.get(patternIndex);

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
        int usefulWordsBefore = countUsefulWordsBetween(tokens, 0, startIndex - 1);

        float score = 1.0f;

        score -= totalGap * 0.10f;
        score -= Math.max(0, usefulSpan - pattern.size()) * 0.06f;
        score -= Math.min(0.25f, usefulWordsBefore * 0.05f);

        if (span > 8) {
            score -= 0.15f;
        }

        return clamp01(score);
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

    private boolean isSafePattern(List<String> pattern) {
        if (pattern == null || pattern.size() < 2) {
            return false;
        }

        Set<String> uniqueWords = new HashSet<>(pattern);
        return uniqueWords.size() >= 2;
    }

    private List<String> tokenize(String text) {
        if (text == null || text.trim().isEmpty()) {
            return new ArrayList<>();
        }

        String[] rawTokens = text.trim().split("\\s+");
        return new ArrayList<>(Arrays.asList(rawTokens));
    }

    private List<String> removeFillerWords(List<String> tokens) {
        List<String> useful = new ArrayList<>();

        for (String token : tokens) {
            if (!isFillerWord(token)) {
                useful.add(token);
            }
        }

        return useful;
    }

    private int countUsefulWordsBetween(List<String> tokens, int start, int end) {
        if (start > end) return 0;

        int count = 0;

        for (int i = Math.max(0, start); i <= Math.min(tokens.size() - 1, end); i++) {
            if (!isFillerWord(tokens.get(i))) {
                count++;
            }
        }

        return count;
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
                || token.equals("how")
                || token.equals("are");
    }

    private String joinTokens(List<String> tokens) {
        StringBuilder builder = new StringBuilder();

        for (String token : tokens) {
            if (builder.length() > 0) {
                builder.append(" ");
            }

            builder.append(token);
        }

        return builder.toString();
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