#![no_std]
#![no_main]

// Some panic handler needs to be included. This one halts the processor on panic.
extern crate panic_halt;
extern crate cortex_m_rt;
// use panic_semihosting as _; // logs messages to the host stderr; requires a debugger

#[cortex_m_rt::entry]
fn main() -> ! {

    loop {
        // your code goes here
    }
}
