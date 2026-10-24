use std::env;
use std::path::PathBuf;
use std::process::Command;

const HOOKS: &[&str] = &["ioctl"];

fn main() {
    println!("cargo:rerun-if-changed=vendor");
    println!("cargo:rerun-if-changed=src/hooks");

    let base_dir = PathBuf::from(&env::var("CARGO_MANIFEST_DIR").unwrap());
    let out_dir = PathBuf::from(env::var("OUT_DIR").unwrap());
    let compile_sh = base_dir.join("src/hooks/compile.sh");

    for hook in HOOKS {
        let compile = Command::new("bash")
            .arg(&compile_sh)
            .arg(base_dir.join(&format!("src/hooks/{}.c", hook)))
            .arg(out_dir.join(&format!("{}.bin", hook)))
            .status()
            .unwrap();

        if !compile.success() {
            panic!("Failed to compile hook {}", hook);
        }
    }
}
