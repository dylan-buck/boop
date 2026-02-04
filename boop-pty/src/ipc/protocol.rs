use serde::{Deserialize, Serialize};

use crate::detector::SessionState;

#[derive(Debug, Clone)]
pub enum Message {
    Start {
        session_id: String,
        tool: String,
        project_name: String,
        pid: u32,
    },
    State {
        session_id: String,
        state: SessionState,
        details: String,
        working_duration_secs: Option<u64>,  // Duration spent in working state before this state change
    },
    End {
        session_id: String,
        exit_code: i32,
    },
}

#[derive(Serialize, Deserialize)]
struct JsonMessage {
    #[serde(rename = "type")]
    msg_type: String,
    session_id: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    tool: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    project_name: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pid: Option<u32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    state: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    details: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    exit_code: Option<i32>,
    #[serde(skip_serializing_if = "Option::is_none")]
    working_duration_secs: Option<u64>,  // Duration spent in working state before this state change
}

impl Message {
    pub fn start(session_id: &str, tool: &str, project_name: &str, pid: u32) -> Self {
        Self::Start {
            session_id: session_id.to_string(),
            tool: tool.to_string(),
            project_name: project_name.to_string(),
            pid,
        }
    }

    pub fn state(session_id: &str, state: SessionState, details: &str) -> Self {
        Self::State {
            session_id: session_id.to_string(),
            state,
            details: details.to_string(),
            working_duration_secs: None,
        }
    }

    pub fn state_with_duration(session_id: &str, state: SessionState, details: &str, working_duration_secs: Option<u64>) -> Self {
        Self::State {
            session_id: session_id.to_string(),
            state,
            details: details.to_string(),
            working_duration_secs,
        }
    }

    pub fn end(session_id: &str, exit_code: i32) -> Self {
        Self::End {
            session_id: session_id.to_string(),
            exit_code,
        }
    }

    pub fn serialize(&self) -> String {
        let json = match self {
            Message::Start {
                session_id,
                tool,
                project_name,
                pid,
            } => JsonMessage {
                msg_type: "START".to_string(),
                session_id: session_id.clone(),
                tool: Some(tool.clone()),
                project_name: Some(project_name.clone()),
                pid: Some(*pid),
                state: None,
                details: None,
                exit_code: None,
                working_duration_secs: None,
            },
            Message::State {
                session_id,
                state,
                details,
                working_duration_secs,
            } => JsonMessage {
                msg_type: "STATE".to_string(),
                session_id: session_id.clone(),
                tool: None,
                project_name: None,
                pid: None,
                state: Some(state.as_str().to_string()),
                details: Some(details.clone()),
                exit_code: None,
                working_duration_secs: *working_duration_secs,
            },
            Message::End {
                session_id,
                exit_code,
            } => JsonMessage {
                msg_type: "END".to_string(),
                session_id: session_id.clone(),
                tool: None,
                project_name: None,
                pid: None,
                state: None,
                details: None,
                exit_code: Some(*exit_code),
                working_duration_secs: None,
            },
        };
        format!("{}\n", serde_json::to_string(&json).unwrap())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_start_message() {
        let msg = Message::start("abc123", "claude", "my-project", 12345);
        let serialized = msg.serialize();
        assert!(serialized.contains("\"type\":\"START\""));
        assert!(serialized.contains("\"session_id\":\"abc123\""));
        assert!(serialized.contains("\"tool\":\"claude\""));
        assert!(serialized.contains("\"project_name\":\"my-project\""));
        assert!(serialized.contains("\"pid\":12345"));
    }

    #[test]
    fn test_state_message() {
        let msg = Message::state("abc123", SessionState::AwaitingApproval, "Waiting for input");
        let serialized = msg.serialize();
        assert!(serialized.contains("\"type\":\"STATE\""));
        assert!(serialized.contains("\"session_id\":\"abc123\""));
        assert!(serialized.contains("\"state\":\"AWAITING_APPROVAL\""));
        assert!(serialized.contains("\"details\":\"Waiting for input\""));
    }

    #[test]
    fn test_end_message() {
        let msg = Message::end("abc123", 0);
        let serialized = msg.serialize();
        assert!(serialized.contains("\"type\":\"END\""));
        assert!(serialized.contains("\"session_id\":\"abc123\""));
        assert!(serialized.contains("\"exit_code\":0"));
    }

    #[test]
    fn test_special_characters_in_details() {
        // JSON handles special chars including pipe, quotes, newlines
        let msg = Message::state("abc123", SessionState::Working, "Line with | pipe and \"quotes\"");
        let serialized = msg.serialize();
        // Should be properly escaped
        assert!(serialized.contains("\\\"quotes\\\""));
    }

    #[test]
    fn test_valid_json_output() {
        let msg = Message::start("test", "claude", "project", 1234);
        let serialized = msg.serialize().trim().to_string();
        // Should parse as valid JSON
        let parsed: serde_json::Value = serde_json::from_str(&serialized).unwrap();
        assert_eq!(parsed["type"], "START");
        assert_eq!(parsed["session_id"], "test");
    }
}
