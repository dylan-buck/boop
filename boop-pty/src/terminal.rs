use nix::sys::termios::{tcgetattr, tcsetattr, SetArg, Termios};
use std::os::fd::{AsRawFd, BorrowedFd};
use std::sync::Mutex;

static ORIGINAL_TERMIOS: Mutex<Option<Termios>> = Mutex::new(None);

pub fn save_terminal_settings() {
    let fd = std::io::stdin().as_raw_fd();
    let borrowed = unsafe { BorrowedFd::borrow_raw(fd) };
    if let Ok(termios) = tcgetattr(borrowed) {
        if let Ok(mut guard) = ORIGINAL_TERMIOS.lock() {
            *guard = Some(termios);
        }
    }
}

pub fn restore_terminal_settings() {
    if let Ok(guard) = ORIGINAL_TERMIOS.lock() {
        if let Some(ref original) = *guard {
            let fd = std::io::stdin().as_raw_fd();
            let borrowed = unsafe { BorrowedFd::borrow_raw(fd) };
            let _ = tcsetattr(borrowed, SetArg::TCSANOW, original);
        }
    }
}

pub fn set_raw_mode() {
    use nix::sys::termios::{InputFlags, LocalFlags};

    if let Ok(guard) = ORIGINAL_TERMIOS.lock() {
        if let Some(ref original) = *guard {
            let mut raw = original.clone();
            raw.local_flags.remove(LocalFlags::ICANON);
            raw.local_flags.remove(LocalFlags::ECHO);
            raw.local_flags.remove(LocalFlags::ISIG);
            raw.input_flags.remove(InputFlags::IXON);
            raw.input_flags.remove(InputFlags::ICRNL);

            let fd = std::io::stdin().as_raw_fd();
            let borrowed = unsafe { BorrowedFd::borrow_raw(fd) };
            let _ = tcsetattr(borrowed, SetArg::TCSANOW, &raw);
        }
    }
}
