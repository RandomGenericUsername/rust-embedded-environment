# [ =============== Image for setting up python venv =============== ]
FROM rust:1.78 as venv-base
# Set the working directory
WORKDIR /app
# Copy the requirements file into the image
COPY ./.src/requirements.pip /app/requirements.pip
# Install Python and pip
RUN apt-get update \
    && apt-get install -y python3 python3-venv python3-pip \
    && rm -rf /var/lib/apt/lists/*
# Create a virtual environment and install dependencies
RUN python3 -m venv /app/venv && \
    /app/venv/bin/pip install --upgrade pip && \
    /app/venv/bin/pip install -r requirements.pip && \
    ls -al /app/venv/bin  # Debug: list contents
# Make the scripts executable
RUN chmod +x /app/venv/bin/* && ls -la /app/venv/bin/
# Without this, the shebang in the scripts will not work
RUN sed -i 's|#!.*python|#!/usr/local/python/venv/bin/python|' /app/venv/bin/*
# [ ================================================================= ]


# [ ============ Image for setting up rust base image  ============ ]
FROM rust:1.78 as rust-base
# Install system dependencies
RUN apt-get update && apt-get install -y \
    cmake git curl wget pkg-config unzip \
    zsh build-essential gnupg gdb-multiarch \
    openocd libusb-1.0-0-dev libudev-dev libusb-1.0.0 \
    libusb-dev libreadline-dev libncursesw5 libncurses5-dev \
    libusb-1.0.0-dev usbutils libnewlib-arm-none-eabi \
    libstdc++-arm-none-eabi-newlib expect \
    tree bash-completion vim htop lldb  && \
    rm -rf /var/lib/apt/lists/*
RUN cargo install \
    cargo-generate \
    svd2rust \
    cargo-make \
    cargo-binutils \
    && \
    rustup component add llvm-tools-preview &&\
    rustup component add rustfmt && \
    rustup component add rust-src && \
    rustup component add rust-analyzer
# Install probe-rs tools with detailed debugging
RUN curl --proto '=https' --tlsv1.2 -LsSf https://github.com/probe-rs/probe-rs/releases/latest/download/probe-rs-tools-installer.sh -o /tmp/probe-rs-installer.sh && \
    chmod +x /tmp/probe-rs-installer.sh && \
    sh -x /tmp/probe-rs-installer.sh && \
    rm /tmp/probe-rs-installer.sh

# Create symbolic links for probe-rs tools
RUN ln -s /usr/local/cargo/bin/probe-rs /usr/local/bin/probe-rs && \
    ln -s /usr/local/cargo/bin/cargo-flash /usr/local/bin/cargo-flash && \
    ln -s /usr/local/cargo/bin/cargo-embed /usr/local/bin/cargo-embed
# [ =============================================================== ]


# [ ============ Image for setting up cli tools in the rust base image  ============ ]
FROM rust-base as tools-base
# Create a directory to store binaries
RUN mkdir /opt/tools
# Update the package list and install jq
RUN apt-get update && apt-get install -y jq && \
    cp $(which jq) /opt/tools/jq 
# Install command-line yq
RUN wget https://github.com/mikefarah/yq/releases/download/v4.44.1/yq_linux_amd64 -O /opt/tools/yq && \
    chmod +x /opt/tools/yq
# Install Node.js and npm and pajv -> validator
RUN apt-get update && apt-get install -y npm && \
    npm install -g pajv && \
    npm cache clean --force
# Find where Node.js and pajv are installed and set paths
RUN cp -r \
    $(which node) \
    $(which pajv) \
    /opt/tools/
# Clean up to reduce image size
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# [ =============================================================== ]



# [ ============ Gather all images containing tools deps  ============ ]
FROM tools-base as tools-final
# Copy tools
COPY --from=tools-base /opt/tools /usr/local/bin
# Copy the virtual environment from the base stage
COPY --from=venv-base /app/venv /usr/local/python/venv
# Create symbolic links to Python virtual environment binaries
RUN ln -s /usr/local/python/venv/bin/* /usr/local/bin/
# [ =============================================================== ]


# [ ============ Copy all resoursces  ============ ]
FROM tools-final as resources
# Copy the setup scripts
COPY ./.src/setup-scripts/* /tmp/setup-scripts/
RUN chmod +x /tmp/setup-scripts/*
RUN mv /tmp/setup-scripts/*  /usr/local/bin/
# Copy the mcu schema to validate the config files against
COPY ./.src/util-files/mcu_config_schema.json /opt/validation-schema/mcu_config_schema.json
# Copy the project creator cargo-templates
COPY ./.src/util-files/dual-core /opt/.project-creator-templates/dual-core
COPY ./.src/util-files/single-core /opt/.project-creator-templates/single-core
# Copy the mcu configs
COPY ./mcu-configs /opt/mcu-configs
# Copy the file containing the labels of the supported families
COPY ./.src/mcu_families.sup /opt/mcu_families.sup
# Copy the command scripts and make them executable
COPY ./.src/utils/ /commands/utils
COPY ./.src/entrypoint.sh /commands/entrypoint.sh
RUN chmod -R +x /commands/
# [ =============================================================== ]


# [ ============ Final image  ============ ]
FROM resources as final
VOLUME /project
# Set the working directory
WORKDIR /project
# Needed for cargo
ENV USER=root
# Accept architecture targets as a build-time argument
ARG TARGETS=""
# Run the script to add the specified architectures to the Rust toolchain
RUN /usr/local/bin/add_rust_targets.sh ${TARGETS}
# Create a symbolic link to the project creator script
RUN ln -s /commands/utils/create-project/create_project.sh /usr/local/bin/create_project
# Set up the entrypoint script
ENTRYPOINT ["/commands/entrypoint.sh"]
## [ =============================================================== ]


