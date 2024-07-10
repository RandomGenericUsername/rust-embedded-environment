//! This build script copies the `memory.x` file from the crate root into
//! a directory where the linker can always find it at build time.
//! For many projects this is optional, as the linker always searches the
//! project root directory -- wherever `Cargo.toml` is. However, if you
//! are using a workspace or have a more complicated build setup, this
//! build script becomes required. Additionally, by requesting that
//! Cargo re-run the build script whenever `memory.x` is changed,
//! updating `memory.x` ensures a rebuild of the application with the
//! new memory settings.
//!
//! The build script also sets the linker flags to tell it which link script to use.

extern crate colored;

use std::env;
use std::fs::File;
use std::io::Write;
use std::path::PathBuf;
use std::process::Command;
use colored::*;

fn main() {
    println!("Build script started");
    setup_memory_x();
    setup_linker_arguments();
    //display_size_report();
}

fn setup_memory_x() {
    println!("Setting up memory.x");
    // Put `memory.x` in our output directory and ensure it's on the linker search path.
    let out = &PathBuf::from(env::var_os("OUT_DIR").unwrap());
    File::create(out.join("memory.x"))
        .unwrap()
        .write_all(include_bytes!("memory.x"))
        .unwrap();
    println!("cargo:rustc-link-search={}", out.display());
    println!("cargo:rerun-if-changed=memory.x");
}

fn setup_linker_arguments() {
    println!("Setting up linker arguments");
    // Specify linker arguments.
    println!("cargo:rustc-link-arg=--nmagic");
    println!("cargo:rustc-link-arg=-Tlink.x");
}

fn display_size_report() {
    println!("Displaying size report");
    // Get the path to the binary.
    let target = env::var("CARGO_TARGET_DIR").unwrap_or_else(|_| "target".to_string());
    let binary_path = format!("{}/thumbv7em-none-eabihf/debug/{}", target, env::var("CARGO_PKG_NAME").unwrap());

    // Run `arm-none-eabi-size` and capture the output.
    let output = Command::new("arm-none-eabi-size")
        .arg(&binary_path)
        .output()
        .expect("Failed to execute arm-none-eabi-size");

    // Parse and print the size report.
    parse_and_print_size_report(&output.stdout);
}

fn parse_and_print_size_report(output: &[u8]) {
    let output_str = String::from_utf8_lossy(output);
    let lines: Vec<&str> = output_str.split('\n').collect();
    if lines.len() > 1 {
        let sizes: Vec<&str> = lines[1].split_whitespace().collect();
        if sizes.len() >= 4 {
            let text_size: f64 = sizes[0].parse().unwrap();
            let data_size: f64 = sizes[1].parse().unwrap();
            let bss_size: f64 = sizes[2].parse().unwrap();
            let total_size: f64 = sizes[3].parse().unwrap();

            let text_size_mb = text_size / (1024.0 * 1024.0);
            let data_size_mb = data_size / (1024.0 * 1024.0);
            let bss_size_mb = bss_size / (1024.0 * 1024.0);
            let total_size_mb = total_size / (1024.0 * 1024.0);

            println!("\nBuild Size Report:");
            println!("executable code and read-only data: | {:.3} Mb", text_size_mb);
            println!("{}: | {:.3} Mb", "Initialized data".blue(), data_size_mb);
            println!("{}: | {:.3} Mb", "Uninitialized data".yellow(), bss_size_mb);
            println!("{}: | {:.3} Mb", "The total size of the binary".green(), total_size_mb);
        }
    }
}
