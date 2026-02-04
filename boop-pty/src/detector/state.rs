#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionState {
    Working,
    AwaitingApproval,
    Completed,
    Error,
}

impl SessionState {
    pub fn as_str(&self) -> &'static str {
        match self {
            SessionState::Working => "WORKING",
            SessionState::AwaitingApproval => "AWAITING_APPROVAL",
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
