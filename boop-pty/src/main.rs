mod detector;
mod error;
mod ipc;
mod pty;
mod terminal;

use crate::error::{BoopError, Result};
use crate::pty::PtyHandler;
use signal_hook::consts::signal::{SIGHUP, SIGINT, SIGTERM};
use signal_hook::iterator::Signals;
use std::env;
use std::process;

fn print_usage() {
    eprintln!("Usage: boop-pty <session_id> <tool> [args...]");
    eprintln!();
    eprintln!("Arguments:");
    eprintln!("  session_id  Unique identifier for this session");
    eprintln!("  tool        The command to run (e.g., 'claude', 'codex')");
    eprintln!("  args        Additional arguments to pass to the tool");
    eprintln!();
    eprintln!("Environment:");
    eprintln!("  BOOP_PROJECT  Override project name (default: git repo or directory name)");
}

fn get_project_name() -> String {
    // Check environment variable first
    if let Ok(project) = env::var("BOOP_PROJECT") {
        return project;
    }

    // Try to get git repo name
    if let Ok(output) = std::process::Command::new("git")
        .args(["rev-parse", "--show-toplevel"])
        .output()
    {
        if output.status.success() {
            if let Ok(path) = String::from_utf8(output.stdout) {
                if let Some(name) = path.trim().split('/').last() {
                    return name.to_string();
                }
            }
        }
    }

    // Fall back to current directory name
    if let Ok(cwd) = env::current_dir() {
        if let Some(name) = cwd.file_name() {
            return name.to_string_lossy().to_string();
        }
    }

    // Ultimate fallback
    "unknown".to_string()
}

fn run() -> Result<i32> {
    let args: Vec<String> = env::args().collect();

    if args.len() < 3 {
        print_usage();
        return Err(BoopError::InvalidArgs(
            "Missing required arguments".to_string(),
        ));
    }

    // Handle --help
    if args.iter().any(|a| a == "--help" || a == "-h") {
        print_usage();
        return Ok(0);
    }

    let session_id = args[1].clone();
    let tool = args[2].clone();
    let tool_args: Vec<String> = args[3..].to_vec();

    let project_name = get_project_name();

    let mut handler = PtyHandler::new(session_id, tool, project_name);
    handler.run(&tool_args)
}

fn main() {
    // Save original terminal settings FIRST
    terminal::save_terminal_settings();

    // Set up panic hook to restore terminal
    let default_panic = std::panic::take_hook();
    std::panic::set_hook(Box::new(move |info| {
        terminal::restore_terminal_settings();
        default_panic(info);
    }));

    // Set up signal handler thread
    std::thread::spawn(|| {
        if let Ok(mut signals) = Signals::new([SIGTERM, SIGINT, SIGHUP]) {
            for sig in signals.forever() {
                terminal::restore_terminal_settings();
                // Re-raise signal with default handler
                unsafe {
                    libc::signal(sig, libc::SIG_DFL);
                    libc::raise(sig);
                }
            }
        }
    });

    match run() {
        Ok(exit_code) => {
            terminal::restore_terminal_settings();
            process::exit(exit_code)
        }
        Err(e) => {
            terminal::restore_terminal_settings();
            eprintln!("boop-pty error: {}", e);
            process::exit(1);
        }
    }
}
