use std::env;
use std::fs;
use std::process::Command;

use anyhow::Context;
use anyhow::{anyhow, Result as AnyResult};
use lazy_static::lazy_static;
use tempfile::TempDir;

const TRAMPOLINE_TEMPLATE: &str = include_str!("./trampoline.s");

lazy_static! {
    static ref CC: String = env::var("CC").unwrap_or_else(|_| "gcc".to_string());
    static ref OBJCOPY: String = env::var("OBJCOPY").unwrap_or_else(|_| "objcopy".to_string());
}

pub fn build_trampoline(return_addr: u64) -> AnyResult<Vec<u8>> {
    let asm = TRAMPOLINE_TEMPLATE.replace("%retaddr%", &format!("0x{:x}", return_addr));
    assemble(&asm)
}

pub fn build_shim(page_distance: u32) -> AnyResult<Vec<u8>> {
    if page_distance > (1u32 << 21) {
        return Err(anyhow!("Too far away"));
    }

    // adrp x8, page_distance
    let immlo = page_distance & 0b11;
    let immhi = (page_distance >> 2) & 0b1111111111111111111;
    let adrp = (1 << 31) | (immlo << 29) | (1 << 28) | (immhi << 5) | 0x8;
    let mut shim = adrp.to_le_bytes().to_vec();

    // br x8
    shim.extend_from_slice(&[0x00, 0x01, 0x1f, 0xd6]);

    if shim.len() != 8 {
        return Err(anyhow!(
            "Must result in exactly 8 bytes, got {}",
            shim.len()
        ));
    }

    Ok(shim)
}

// TODO: Just use dynasm-rs
fn assemble(asm: &str) -> AnyResult<Vec<u8>> {
    let dir = TempDir::new()?;
    let asm_path = dir.path().join("payload.S");
    let elf_path = dir.path().join("payload.o");
    let bin_path = dir.path().join("payload.bin");

    fs::write(&asm_path, asm)?;

    let gas = Command::new(&*CC)
        .arg("-c")
        .arg("-o")
        .arg(&elf_path)
        .arg(&asm_path)
        .status()
        .context("spawning gcc")?;

    if !gas.success() {
        return Err(anyhow!("Failed to assemble payload"));
    }

    let objcopy = Command::new(&*OBJCOPY)
        .args(["-O", "binary"])
        .arg(&elf_path)
        .arg(&bin_path)
        .status()
        .context("spawning objcopy")?;

    if !objcopy.success() {
        return Err(anyhow!("Failed to copy payload into raw binary"));
    }

    let bin = fs::read(&bin_path)?;

    Ok(bin)
}
