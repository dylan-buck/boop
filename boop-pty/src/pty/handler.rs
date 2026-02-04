use crate::detector::{SessionState, StateDetector};
use crate::error::{BoopError, Result};
use crate::ipc::{IpcClient, Message};
use crate::pty::resize::{get_terminal_size, set_terminal_size};
use mio::unix::SourceFd;
use mio::{Events, Interest, Poll, Token};
use portable_pty::{native_pty_system, CommandBuilder, PtySize};
use signal_hook::consts::signal::SIGWINCH;
use signal_hook::iterator::Signals;
use std::io::{Read, Write};
use std::os::fd::AsRawFd;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

const STDIN_TOKEN: Token = Token(0);

pub struct PtyHandler {
    session_id: String,
    tool: String,
    project_name: String,
    ipc: IpcClient,
    detector: StateDetector,
}

impl PtyHandler {
    pub fn new(session_id: String, tool: String, project_name: String) -> Self {
        Self {
            session_id,
            tool,
            project_name,
            ipc: IpcClient::new(),
            detector: StateDetector::new(),
        }
    }

    pub fn run(&mut self, args: &[String]) -> Result<i32> {
        // Get initial terminal size
        let (cols, rows) = get_terminal_size().unwrap_or((80, 24));

        // Create PTY
        let pty_system = native_pty_system();
        let pair = pty_system
            .openpty(PtySize {
                rows,
                cols,
                pixel_width: 0,
                pixel_height: 0,
            })
            .map_err(|e| BoopError::Pty(e.to_string()))?;

        // Build command
        let mut cmd = CommandBuilder::new(&self.tool);
        cmd.args(args);

        // Set up environment
        if let Ok(term) = std::env::var("TERM") {
            cmd.env("TERM", term);
        } else {
            cmd.env("TERM", "xterm-256color");
        }

        // Spawn child process
        let mut child = pair
            .slave
            .spawn_command(cmd)
            .map_err(|e| BoopError::Pty(e.to_string()))?;

        // Drop slave - we only need master now
        drop(pair.slave);

        // Get master reader/writer
        let mut master_reader = pair.master.try_clone_reader()
            .map_err(|e| BoopError::Pty(e.to_string()))?;
        let mut master_writer = pair.master.take_writer()
            .map_err(|e| BoopError::Pty(e.to_string()))?;

        // Send START message
        let pid = std::process::id();
        let start_msg = Message::start(&self.session_id, &self.tool, &self.project_name, pid);
        let _ = self.ipc.send(&start_msg);

        // Send initial WORKING state
        let state_msg = Message::state(&self.session_id, SessionState::Working, "Starting...");
        let _ = self.ipc.send(&state_msg);

        // Set up termination flag
        let running = Arc::new(AtomicBool::new(true));
        let running_clone = running.clone();

        // Set up SIGWINCH handler for terminal resize
        let master_fd_opt = pair.master.as_raw_fd();
        let running_sigwinch = running.clone();
        thread::spawn(move || {
            if let Ok(mut signals) = Signals::new([SIGWINCH]) {
                for _ in signals.forever() {
                    if !running_sigwinch.load(Ordering::Relaxed) {
                        break;
                    }
                    if let Ok((cols, rows)) = get_terminal_size() {
                        if let Some(fd) = master_fd_opt {
                            let _ = set_terminal_size(fd, cols, rows);
                        }
                    }
                }
            }
        });

        // Set stdin to raw mode (restoration handled globally by signal/panic handlers)
        let stdin = std::io::stdin();
        crate::terminal::set_raw_mode();

        // Thread to read from stdin and write to PTY using poll for non-blocking
        let running_stdin = running.clone();
        let stdin_handle = thread::spawn(move || {
            let stdin_fd = std::io::stdin().as_raw_fd();

            // Create poll instance
            let mut poll = match Poll::new() {
                Ok(p) => p,
                Err(_) => return,
            };

            let mut events = Events::with_capacity(1);

            // Register stdin for reading
            let mut source_fd = SourceFd(&stdin_fd);
            if poll.registry().register(&mut source_fd, STDIN_TOKEN, Interest::READABLE).is_err() {
                return;
            }

            let mut stdin = stdin.lock();
            let mut buf = [0u8; 1024];

            while running_stdin.load(Ordering::Relaxed) {
                // Poll with 100ms timeout to allow checking running flag
                if poll.poll(&mut events, Some(Duration::from_millis(100))).is_err() {
                    break;
                }

                for event in events.iter() {
                    if event.token() == STDIN_TOKEN {
                        match stdin.read(&mut buf) {
                            Ok(0) => return, // EOF
                            Ok(n) => {
                                if master_writer.write_all(&buf[..n]).is_err() {
                                    return;
                                }
                                let _ = master_writer.flush();
                            }
                            Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                                continue;
                            }
                            Err(_) => return,
                        }
                    }
                }
            }

            // Deregister on exit
            let _ = poll.registry().deregister(&mut source_fd);
        });

        // Main thread: read from PTY and write to stdout, detect state
        let stdout = std::io::stdout();
        let mut stdout = stdout.lock();
        let mut buf = [0u8; 4096];
        let mut last_state = SessionState::Working;

        loop {
            match master_reader.read(&mut buf) {
                Ok(0) => break, // EOF
                Ok(n) => {
                    // Write to stdout
                    if stdout.write_all(&buf[..n]).is_err() {
                        break;
                    }
                    let _ = stdout.flush();

                    // Process for state detection
                    if let Some((new_state, working_duration_secs)) = self.detector.process_output(&buf[..n]) {
                        if new_state != last_state {
                            let details = self.detector.get_details();
                            let state_msg = Message::state_with_duration(
                                &self.session_id,
                                new_state,
                                &details,
                                working_duration_secs,
                            );
                            let _ = self.ipc.send(&state_msg);
                            last_state = new_state;
                        }
                    }
                }
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    thread::sleep(Duration::from_millis(10));
                }
                Err(_) => break,
            }
        }

        // Stop stdin thread
        running_clone.store(false, Ordering::Relaxed);

        // Wait for child to exit
        let exit_status = child.wait().map_err(|e| BoopError::Pty(e.to_string()))?;
        let exit_code = exit_status
            .exit_code()
            .try_into()
            .unwrap_or(-1);

        // Send END message
        let end_msg = Message::end(&self.session_id, exit_code);
        let _ = self.ipc.send(&end_msg);

        // Wait for stdin thread (with timeout since poll allows it to exit)
        let _ = stdin_handle.join();

        Ok(exit_code)
    }
}
