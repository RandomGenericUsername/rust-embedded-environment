#![no_std]
#![no_main]

// Some panic handler needs to be included. This one halts the processor on panic.
extern crate panic_halt;
// use panic_abort as _; // requires nightly
// use panic_itm as _; // logs messages over ITM; requires ITM support
// use panic_semihosting as _; // logs messages to the host stderr; requires a debugger
extern crate cortex_m;
use cortex_m::asm;
extern crate cortex_m_rt as rt;
use rt::entry;

#[entry]
fn main() -> ! {
    asm::nop(); // To not have main optimize to abort in release mode, remove when you add code

    loop {
        // your code goes here
    }
}
