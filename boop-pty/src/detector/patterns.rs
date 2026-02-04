use regex::Regex;
use std::sync::LazyLock;

static APPROVAL_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        // Claude Code CLI patterns
        Regex::new(r"(?i)do you want to proceed").unwrap(),
        Regex::new(r"(?i)allow this action").unwrap(),
        Regex::new(r"(?i)press enter to continue").unwrap(),
        Regex::new(r"\[Y/n\]").unwrap(),
        Regex::new(r"\[y/N\]").unwrap(),
        Regex::new(r"(?i)waiting for approval").unwrap(),
        Regex::new(r"(?i)requires? your permission").unwrap(),
        Regex::new(r"(?i)approve\?").unwrap(),
        Regex::new(r"(?i)confirm\?").unwrap(),
        // Additional approval indicators
        Regex::new(r"(?i)do you want to allow").unwrap(),
        Regex::new(r"(?i)proceed\s*\?").unwrap(),
        Regex::new(r"(?i)continue\s*\?").unwrap(),
        Regex::new(r"(?i)accept\s*\?").unwrap(),
        Regex::new(r"(?i)yes/no").unwrap(),
        // Plan mode patterns
        Regex::new(r"(?i)review.*plan").unwrap(),
        Regex::new(r"(?i)approve.*plan").unwrap(),
    ]
});

static COMPLETION_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        Regex::new(r"(?i)task completed").unwrap(),
        Regex::new(r"(?i)successfully completed").unwrap(),
        Regex::new(r"(?i)finished successfully").unwrap(),
        Regex::new(r"(?i)done\!").unwrap(),
    ]
});

// Patterns for detecting when Claude Code is idle and waiting for input
static IDLE_PROMPT_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        // Claude Code input prompt - line starting with > followed by space or end
        Regex::new(r"^>\s*$").unwrap(),
    ]
});

static ERROR_PATTERNS: LazyLock<Vec<Regex>> = LazyLock::new(|| {
    vec![
        Regex::new(r"(?i)error:").unwrap(),
        Regex::new(r"(?i)fatal error").unwrap(),
        Regex::new(r"(?i)failed:").unwrap(),
        Regex::new(r"(?i)exception:").unwrap(),
        Regex::new(r"(?i)panic:").unwrap(),
    ]
});

pub struct PatternMatcher;

impl PatternMatcher {
    pub fn is_approval_needed(text: &str) -> bool {
        APPROVAL_PATTERNS.iter().any(|pattern| pattern.is_match(text))
    }

    pub fn is_completed(text: &str) -> bool {
        COMPLETION_PATTERNS.iter().any(|pattern| pattern.is_match(text))
    }

    pub fn is_error(text: &str) -> bool {
        ERROR_PATTERNS.iter().any(|pattern| pattern.is_match(text))
    }

    pub fn get_approval_match(text: &str) -> Option<&str> {
        for pattern in APPROVAL_PATTERNS.iter() {
            if let Some(m) = pattern.find(text) {
                return Some(m.as_str());
            }
        }
        None
    }

    /// Check if the last non-empty line is the idle prompt (> at start of line)
    pub fn is_idle_prompt(text: &str) -> bool {
        text.lines()
            .rev()
            .find(|line| !line.trim().is_empty())
            .map(|line| IDLE_PROMPT_PATTERNS.iter().any(|p| p.is_match(line)))
            .unwrap_or(false)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_approval_patterns() {
        assert!(PatternMatcher::is_approval_needed("Do you want to proceed?"));
        assert!(PatternMatcher::is_approval_needed("Allow this action? [Y/n]"));
        assert!(PatternMatcher::is_approval_needed("This requires your permission"));
        assert!(PatternMatcher::is_approval_needed("approve?"));
        assert!(!PatternMatcher::is_approval_needed("Working on task..."));
    }

    #[test]
    fn test_completion_patterns() {
        assert!(PatternMatcher::is_completed("Task completed successfully"));
        assert!(PatternMatcher::is_completed("Done!"));
        assert!(!PatternMatcher::is_completed("Still working..."));
    }

    #[test]
    fn test_error_patterns() {
        assert!(PatternMatcher::is_error("Error: something went wrong"));
        assert!(PatternMatcher::is_error("Fatal error occurred"));
        assert!(!PatternMatcher::is_error("Everything is fine"));
    }

    #[test]
    fn test_idle_prompt_patterns() {
        // Simple prompt
        assert!(PatternMatcher::is_idle_prompt(">"));
        assert!(PatternMatcher::is_idle_prompt("> "));
        assert!(PatternMatcher::is_idle_prompt(">\n"));

        // Prompt after output
        assert!(PatternMatcher::is_idle_prompt("Some output\n>"));
        assert!(PatternMatcher::is_idle_prompt("Some output\n> "));
        assert!(PatternMatcher::is_idle_prompt("Line 1\nLine 2\n>"));

        // Prompt with trailing whitespace/newlines
        assert!(PatternMatcher::is_idle_prompt("Output\n>\n"));
        assert!(PatternMatcher::is_idle_prompt("Output\n> \n\n"));

        // Should NOT match
        assert!(!PatternMatcher::is_idle_prompt("> ls")); // Command being typed
        assert!(!PatternMatcher::is_idle_prompt(">command")); // No space
        assert!(!PatternMatcher::is_idle_prompt("still working...")); // No prompt
        assert!(!PatternMatcher::is_idle_prompt("")); // Empty
        assert!(!PatternMatcher::is_idle_prompt("  >  ")); // Indented prompt (not at start of line)
    }
}
