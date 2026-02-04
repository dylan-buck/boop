mod buffer;
mod patterns;
mod state;

pub use buffer::OutputBuffer;
pub use patterns::PatternMatcher;
pub use state::SessionState;

use std::time::{Duration, Instant};

const STATE_DEBOUNCE_MS: u64 = 500;
const MIN_WORKING_DURATION_SECS: u64 = 30;

pub struct StateDetector {
    current_state: SessionState,
    buffer: OutputBuffer,
    last_state_change: Instant,
    pending_state: Option<SessionState>,
    working_started: Option<Instant>,  // Track when work began for notification threshold
}

impl StateDetector {
    pub fn new() -> Self {
        Self {
            current_state: SessionState::Working,
            buffer: OutputBuffer::new(),
            last_state_change: Instant::now(),
            pending_state: None,
            working_started: Some(Instant::now()),  // Session starts in working state
        }
    }

    /// Returns (new_state, working_duration_secs) if state changed
    pub fn process_output(&mut self, data: &[u8]) -> Option<(SessionState, Option<u64>)> {
        self.buffer.append(data);

        let text = self.buffer.get_recent_text();
        let detected_state = self.detect_state(&text);

        // Debounce state changes
        if detected_state != self.current_state {
            let now = Instant::now();

            if self.pending_state == Some(detected_state) {
                // Same pending state, check if debounce period passed
                if now.duration_since(self.last_state_change) >= Duration::from_millis(STATE_DEBOUNCE_MS) {
                    let previous_state = self.current_state;
                    self.current_state = detected_state;
                    self.pending_state = None;
                    self.last_state_change = now;

                    // Calculate working duration if transitioning FROM working
                    let working_duration_secs = if previous_state == SessionState::Working {
                        self.working_started.map(|start| now.duration_since(start).as_secs())
                    } else {
                        None
                    };

                    // Track working duration transitions
                    if detected_state == SessionState::Working && previous_state != SessionState::Working {
                        // Started working
                        self.working_started = Some(now);
                    } else if previous_state == SessionState::Working && detected_state != SessionState::Working {
                        // Stopped working - clear the timer
                        self.working_started = None;
                    }

                    return Some((detected_state, working_duration_secs));
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

        // Check for idle prompt (Claude waiting for input)
        if PatternMatcher::is_idle_prompt(text) {
            return SessionState::Idle;
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
        self.working_started = Some(Instant::now());
    }

    /// Returns the duration Claude has been in the Working state, if currently working
    pub fn working_duration(&self) -> Option<Duration> {
        self.working_started.map(|start| Instant::now().duration_since(start))
    }

    /// Returns true if Claude has been working long enough to warrant a notification
    pub fn worked_long_enough_for_notification(&self) -> bool {
        self.working_started
            .map(|start| Instant::now().duration_since(start) >= Duration::from_secs(MIN_WORKING_DURATION_SECS))
            .unwrap_or(false)
    }
}

impl Default for StateDetector {
    fn default() -> Self {
        Self::new()
    }
}
