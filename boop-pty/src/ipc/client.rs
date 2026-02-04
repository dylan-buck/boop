use crate::error::{BoopError, Result};
use crate::ipc::protocol::Message;
use std::io::Write;
use std::os::unix::net::UnixStream;
use std::path::PathBuf;
use std::time::Duration;

pub struct IpcClient {
    socket_path: PathBuf,
}

impl IpcClient {
    pub fn new() -> Self {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".to_string());
        let socket_path = PathBuf::from(home).join(".boop").join("sock");
        Self { socket_path }
    }

    pub fn with_path(socket_path: PathBuf) -> Self {
        Self { socket_path }
    }

    pub fn send(&self, message: &Message) -> Result<()> {
        // Try to connect with timeout
        let stream = match UnixStream::connect(&self.socket_path) {
            Ok(s) => s,
            Err(e) => {
                // Socket not available - app might not be running, silently ignore
                if e.kind() == std::io::ErrorKind::NotFound
                    || e.kind() == std::io::ErrorKind::ConnectionRefused
                {
                    return Ok(());
                }
                return Err(BoopError::Ipc(format!(
                    "Failed to connect to socket: {}",
                    e
                )));
            }
        };

        stream.set_write_timeout(Some(Duration::from_secs(1)))?;

        let mut stream = stream;
        let data = message.serialize();
        stream.write_all(data.as_bytes()).map_err(|e| {
            BoopError::Ipc(format!("Failed to send message: {}", e))
        })?;

        Ok(())
    }

    pub fn is_available(&self) -> bool {
        self.socket_path.exists()
    }
}

impl Default for IpcClient {
    fn default() -> Self {
        Self::new()
    }
}
