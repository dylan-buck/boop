#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionState {
    Working,
    AwaitingApproval,
    Idle,       // Claude is at prompt, ready for input
    Completed,  // Process exited successfully
    Error,      // Process exited with error
}

impl SessionState {
    pub fn as_str(&self) -> &'static str {
        match self {
            SessionState::Working => "WORKING",
            SessionState::AwaitingApproval => "AWAITING_APPROVAL",
            SessionState::Idle => "IDLE",
            SessionState::Completed => "COMPLETED",
            SessionState::Error => "ERROR",
        }
    }
}

impl std::fmt::Display for SessionState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", self.as_str())
    }
}
