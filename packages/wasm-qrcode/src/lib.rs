use wasm_bindgen::prelude::*;

// Minimal scaffold: expose a function that returns an RGBA buffer filled with white pixels.
// This is a starting point for implementing a real QR generator in Rust/WASM.

#[wasm_bindgen]
pub fn generate_white_rgba(size: u32) -> Vec<u8> {
    let pixels = (size as usize) * (size as usize) * 4;
    // White pixels (RGBA)
    vec![255u8; pixels]
}

#[wasm_bindgen]
pub fn echo_len(n: u32) -> u32 {
    n
}
