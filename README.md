# Content

1. [Overview](#overview)
2. [Features](#features)
3. [Pre-requisites](#pre-requisites)
4. [Installation](#installation)

# Overview
This Docker environment simplifies Rust embedded MCU programming setup. It integrates essential development tools within a Rust-centric ecosystem, allowing project creation based on customizable MCU-specific configuration files or pre-built configurations. These projects define cargo make rules for compiling, flashing, debugging, and more, supporting both single-core and dual-core MCU projects

# Features
- **Rust Environment**: Comes with Rust 1.78, including `cargo-generate`, `cargo-flash`, `cargo-embed`, and `cargo-binutils` for comprehensive Rust development and MCU programming.
- **Embedded Tools**: Includes `openocd` for on-chip debugging and programming, along with utilities like `gdb-multiarch` for cross-platform debugging.
- **Project creation**: A CLI tool that allows creating projects based on configuration files

# Pre-requisites
Before you begin, ensure you have the following installed on your machine:

- **Docker**: [Install Docker](https://docs.docker.com/get-docker/) for your operating system to run the Docker containers.


# Installation
Follow these steps to set up the Docker environment:
1. **Clone the Repository** 
   ```bash
      git clone https://github.com/RandomGenericUsername/rust-embedded-environment
      cd rust-embedded-environment
   ```
