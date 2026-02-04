mod buffer;
mod patterns;
mod state;

pub use buffer::OutputBuffer;
pub use patterns::PatternMatcher;
pub use state::SessionState;

use std::time::{Duration, Instant};

const STATE_DEBOUNCE_MS: u64 = 500;

pub struct StateDetector {
    current_state: SessionState,
    buffer: OutputBuffer,
    last_state_change: Instant,
    pending_state: Option<SessionState>,
}

impl StateDetector {
    pub fn new() -> Self {
        Self {
            current_state: SessionState::Working,
            buffer: OutputBuffer::new(),
            last_state_change: Instant::now(),
            pending_state: None,
        }
    }

    pub fn process_output(&mut self, data: &[u8]) -> Option<SessionState> {
        self.buffer.append(data);

        let text = self.buffer.get_recent_text();
        let detected_state = self.detect_state(&text);

        // Debounce state changes
        if detected_state != self.current_state {
            let now = Instant::now();

            if self.pending_state == Some(detected_state) {
                // Same pending state, check if debounce period passed
                if now.duration_since(self.last_state_change) >= Duration::from_millis(STATE_DEBOUNCE_MS) {
                    self.current_state = detected_state;
                    self.pending_state = None;
                    self.last_state_change = now;
                    return Some(detected_state);
                }
            } else {
                // New pending state, start debounce timer
                self.pending_state = Some(detected_state);
                self.last_state_change = now;
            }
        } else {
            // State matches current, clear pending
            self.pending_state = None;
        }

        None
    }

    fn detect_state(&self, text: &str) -> SessionState {
        if PatternMatcher::is_approval_needed(text) {
            return SessionState::AwaitingApproval;
        }

        if PatternMatcher::is_error(text) {
            return SessionState::Error;
        }

        if PatternMatcher::is_completed(text) {
            return SessionState::Completed;
        }

        SessionState::Working
    }

    pub fn current_state(&self) -> SessionState {
        self.current_state
    }

    pub fn get_details(&self) -> String {
        if let Some(line) = self.buffer.get_last_line() {
            // Truncate if too long
            if line.len() > 100 {
                format!("{}...", &line[..97])
            } else {
                line.to_string()
            }
        } else {
            String::new()
        }
    }

    pub fn reset(&mut self) {
        self.current_state = SessionState::Working;
        self.buffer.clear();
        self.pending_state = None;
    }
}

impl Default for StateDetector {
    fn default() -> Self {
        Self::new()
    }
}
