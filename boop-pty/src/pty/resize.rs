use nix::libc::{ioctl, winsize, TIOCGWINSZ, TIOCSWINSZ};
use std::io;
use std::os::fd::RawFd;

pub fn get_terminal_size() -> io::Result<(u16, u16)> {
    let mut ws = winsize {
        ws_row: 0,
        ws_col: 0,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };

    let result = unsafe { ioctl(libc::STDOUT_FILENO, TIOCGWINSZ, &mut ws) };

    if result == -1 {
        return Err(io::Error::last_os_error());
    }

    Ok((ws.ws_col, ws.ws_row))
}

pub fn set_terminal_size(fd: RawFd, cols: u16, rows: u16) -> io::Result<()> {
    let ws = winsize {
        ws_row: rows,
        ws_col: cols,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };

    let result = unsafe { ioctl(fd, TIOCSWINSZ, &ws) };

    if result == -1 {
        return Err(io::Error::last_os_error());
    }

    Ok(())
}
