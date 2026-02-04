use thiserror::Error;

#[derive(Error, Debug)]
pub enum BoopError {
    #[error("PTY error: {0}")]
    Pty(String),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("IPC error: {0}")]
    Ipc(String),

    #[error("Invalid arguments: {0}")]
    InvalidArgs(String),

    #[error("Signal error: {0}")]
    Signal(String),
}

pub type Result<T> = std::result::Result<T, BoopError>;
