use std::time::{Duration, Instant};
use strip_ansi_escapes::strip;

const MAX_BUFFER_SIZE: usize = 8192;
const LINE_BUFFER_SIZE: usize = 10;
const LINE_TTL: Duration = Duration::from_secs(2);

pub struct OutputBuffer {
    buffer: Vec<u8>,
    recent_lines: Vec<(String, Instant)>,
}

impl OutputBuffer {
    pub fn new() -> Self {
        Self {
            buffer: Vec::with_capacity(MAX_BUFFER_SIZE),
            recent_lines: Vec::with_capacity(LINE_BUFFER_SIZE),
        }
    }

    pub fn append(&mut self, data: &[u8]) {
        // Strip ANSI escape codes
        let stripped = strip(data);

        // Add to buffer
        self.buffer.extend_from_slice(&stripped);

        // Trim buffer if too large (keep last half)
        if self.buffer.len() > MAX_BUFFER_SIZE {
            let start = self.buffer.len() - MAX_BUFFER_SIZE / 2;
            self.buffer = self.buffer[start..].to_vec();
        }

        // Extract new lines
        self.extract_lines();
    }

    fn extract_lines(&mut self) {
        let now = Instant::now();

        // Remove expired lines first
        self.recent_lines
            .retain(|(_, timestamp)| now.duration_since(*timestamp) < LINE_TTL);

        // Find the position of the last complete line (last newline)
        if let Some(last_newline) = self.buffer.iter().rposition(|&b| b == b'\n') {
            // Process all complete lines
            let complete_text = String::from_utf8_lossy(&self.buffer[..=last_newline]);
            let mut new_lines = Vec::new();
            for line in complete_text.lines() {
                if !line.trim().is_empty() {
                    new_lines.push(line.to_string());
                }
            }

            // Add new lines with current timestamp (don't update existing - only add truly new)
            for line_str in new_lines.into_iter().rev().take(LINE_BUFFER_SIZE) {
                if !self.recent_lines.iter().any(|(l, _)| l == &line_str) {
                    self.recent_lines.insert(0, (line_str, now));
                }
            }

            // Keep only the incomplete portion in the buffer (after last newline)
            self.buffer = self.buffer[last_newline + 1..].to_vec();

            // Trim to max size
            while self.recent_lines.len() > LINE_BUFFER_SIZE {
                self.recent_lines.pop();
            }
        }
    }

    pub fn get_recent_text(&self) -> String {
        let now = Instant::now();
        self.recent_lines
            .iter()
            .filter(|(_, ts)| now.duration_since(*ts) < LINE_TTL)
            .map(|(line, _)| line.clone())
            .collect::<Vec<_>>()
            .join("\n")
    }

    pub fn get_last_line(&self) -> Option<&str> {
        let now = Instant::now();
        self.recent_lines
            .iter()
            .find(|(_, ts)| now.duration_since(*ts) < LINE_TTL)
            .map(|(line, _)| line.as_str())
    }
}

impl Default for OutputBuffer {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::thread;

    #[test]
    fn test_buffer_append() {
        let mut buffer = OutputBuffer::new();
        buffer.append(b"Hello, World!\n");
        assert_eq!(buffer.get_last_line(), Some("Hello, World!"));
    }

    #[test]
    fn test_ansi_stripping() {
        let mut buffer = OutputBuffer::new();
        buffer.append(b"\x1b[32mColored text\x1b[0m\n");
        assert_eq!(buffer.get_last_line(), Some("Colored text"));
    }

    #[test]
    fn test_multiple_lines() {
        let mut buffer = OutputBuffer::new();
        buffer.append(b"Line 1\nLine 2\nLine 3\n");
        let text = buffer.get_recent_text();
        assert!(text.contains("Line 1"));
        assert!(text.contains("Line 2"));
        assert!(text.contains("Line 3"));
    }

    #[test]
    fn test_line_ttl_expiration() {
        let mut buffer = OutputBuffer::new();
        buffer.append(b"Old line\n");
        assert_eq!(buffer.get_last_line(), Some("Old line"));

        // Wait for TTL to expire (2 seconds + margin)
        thread::sleep(Duration::from_millis(2100));

        // Old line should be expired now
        assert_eq!(buffer.get_last_line(), None);
        assert!(buffer.get_recent_text().is_empty());

        // New line should work
        buffer.append(b"New line\n");
        assert_eq!(buffer.get_last_line(), Some("New line"));
    }
}
