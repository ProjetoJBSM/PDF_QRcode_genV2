# wasm-qrcode (scaffold)

This folder contains a minimal Rust + wasm-bindgen scaffold for building a QR generator that returns an RGBA pixel buffer.

What is included
- `Cargo.toml` — minimal crate definition
- `src/lib.rs` — tiny stub exposing `generate_white_rgba(size)` which returns a white RGBA buffer (placeholder)

How to build (inside the container or on your host with Rust + wasm-pack installed)

1. Build with wasm-pack (target web):

   wasm-pack build --target web --out-dir ../pkg

   The command above will produce a `pkg` directory adjacent to this crate that contains an ES module you can import from the web app.

2. Integration suggestions

- Implement a real QR generator using `qrcode` or `qrcodegen` crates, render into an RGBA Vec<u8>, and return the Vec<u8> from the exported function — wasm-bindgen will convert it to a `Uint8Array` in JS.
- Return dimensions implicitly (e.g., width and height computed from module count and scale) or expose helper functions to fetch them.
