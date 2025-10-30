FROM node:18-bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    ca-certificates \
    pkg-config \
    libssl-dev \
    python3 \
  && rm -rf /var/lib/apt/lists/*

# Install Rust toolchain (non-interactive) and wasm-pack
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y \
  && . $HOME/.cargo/env \
  && /root/.cargo/bin/cargo install wasm-pack --locked || true

ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /workspace

# Copy full repo into workspace inside the image
COPY . /workspace

# Create two copies: js (unaltered) and wasm (to evolve with rust/wasm)
RUN mkdir -p /app && cp -r /workspace /app/js && cp -r /workspace /app/wasm

EXPOSE 5173 5174

# Default to an interactive shell. Use docker-compose to run the dev servers.
CMD ["/bin/bash"]
