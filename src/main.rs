mod assembly;

use std::env;
use std::fs::{self, File};
use std::io::{self, Read, Seek, SeekFrom, Write};
use std::os::unix::fs::{MetadataExt, PermissionsExt};

use anyhow::{anyhow, Context, Result as AnyResult};
use goblin::elf64::{
    header::Header as Header64,
    program_header::{ProgramHeader as ProgramHeader64, PF_R, PF_X, PT_LOAD, PT_NOTE},
};
use plain::Plain;

const EH_LEN: usize = 0x40;
const OPENAT_BIN: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/openat.bin"));
const IOCTL_BIN: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/ioctl.bin"));
const MMAP_BIN: &[u8] = include_bytes!(concat!(env!("OUT_DIR"), "/mmap.bin"));

const SVR_0: &[u8] = &[0x01, 0x00, 0x00, 0xd4];

struct Patch {
    offset: usize,
    patch: Vec<u8>,
}

struct NewSegment {
    vaddr: u64,
    code: Vec<u8>,
}

impl NewSegment {
    fn new(vaddr: u64) -> Self {
        Self {
            vaddr,
            code: Vec::new(),
        }
    }

    fn add_code(&mut self, code: &[u8]) -> u64 {
        let cur = self.vaddr + self.code.len() as u64;
        self.code.extend_from_slice(code);
        cur
    }

    fn page_align(&mut self) {
        let aligned = page_align(self.code.len());
        self.code.resize(aligned, 0);
    }

    fn len(&self) -> usize {
        self.code.len()
    }
}

fn main() -> AnyResult<()> {
    let args: Vec<String> = env::args().collect();

    // TODO: clap
    let src_path = &args[1];
    let dst_path = &args[2];

    let mut src = fs::File::options()
        .read(true)
        .open(src_path)
        .context("Failed to open source")?;
    let mut dst = fs::File::options()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .open(&dst_path)
        .context("Failed to open destination")?;

    patch_rosetta(&mut src, &mut dst)?;

    if let Ok(metadata) = dst.metadata() {
        let mut permissions = metadata.permissions();
        let mode = permissions.mode() | 0o111;
        permissions.set_mode(mode);
        fs::set_permissions(dst_path, permissions)?;
    }

    Ok(())
}

fn patch_rosetta(src: &mut File, dst: &mut File) -> AnyResult<()> {
    let src_meta = src.metadata()?;
    let src_size = src_meta.size() as usize;

    let mut eh_bytes = {
        let mut buf = vec![0u8; 64];
        src.read_exact(&mut buf)?;
        buf
    };
    let eh = Header64::from_mut_bytes(&mut eh_bytes).unwrap();
    if eh.e_phoff as usize != EH_LEN {
        return Err(anyhow!(
            "ELFs with gaps between the ELF header and the program headers aren't supported"
        ));
    }

    let ph_len = eh.e_phnum as usize * eh.e_phentsize as usize;
    let mut ph_bytes = {
        let mut buf = vec![0u8; ph_len];
        src.read_exact(&mut buf)?;
        buf
    };

    let sh_off = eh.e_shoff as usize;

    let body_len = sh_off - EH_LEN - ph_len;
    let body_bytes = {
        let mut buf = vec![0u8; body_len];
        src.read_exact(&mut buf)?;
        buf
    };

    let phs = ProgramHeader64::slice_from_bytes(&ph_bytes).unwrap();
    let first_load_seg = phs
        .iter()
        .find(|seg| seg.p_type == PT_LOAD)
        .ok_or_else(|| anyhow!("No PT_LOAD segments were found"))?;

    let mut new_segment = NewSegment::new(first_load_seg.p_vaddr + 0x40000000);
    let mut try_patch = |offset, code| -> AnyResult<Option<Patch>> {
        let seg = phs.iter().find(|ph| {
            let start = ph.p_offset as usize;
            let end = start + ph.p_filesz as usize;

            ph.p_type == PT_LOAD && 0 != ph.p_flags & PF_X && offset >= start && offset < end
        });

        if let Some(seg) = seg {
            let vaddr = seg.p_vaddr + (offset as u64 - seg.p_offset);
            let return_addr = vaddr + 8;

            let mut tramp_and_code = assembly::build_trampoline(return_addr)?;
            tramp_and_code.extend_from_slice(code);
            new_segment.page_align();
            let injected_vaddr = new_segment.add_code(&tramp_and_code);
            let page_distance = (injected_vaddr >> 12) - (vaddr >> 12);

            eprintln!("🩹 call site 0x{vaddr:x} (offset=0x{offset:x}) -> tramp 0x{injected_vaddr:x} -> hook 0x{hook:x}",
                hook = injected_vaddr + 0x1000
            );

            return Ok(Some(Patch {
                offset,
                patch: assembly::build_shim(page_distance as u32)?,
            }));
        }

        Ok(None)
    };

    // Collect all patches
    let mut patches = Vec::new();
    let mut iter = body_bytes.chunks(4).enumerate();
    while let Some((idx, instruction)) = iter.next() {
        let offset = EH_LEN + ph_len + idx * 4;

        match instruction {
            // mov x8, __NR_openat
            [0x08, 0x07, 0x80, 0xd2] => {
                if let Some((_, SVR_0)) = iter.next() {
                    eprintln!("🪝 Hooking sys_openat");
                    if let Some(patch) = try_patch(offset, OPENAT_BIN)? {
                        patches.push(patch);
                    }
                }
            }

            // mov x8, __NR_ioctl
            [0xa8, 0x03, 0x80, 0xd2] => {
                if let Some((_, SVR_0)) = iter.next() {
                    eprintln!("🪝 Hooking sys_ioctl");
                    if let Some(patch) = try_patch(offset, IOCTL_BIN)? {
                        patches.push(patch);
                    }
                }
            }

            // mov x8, __NR_mmap
            [0xc8, 0x1b, 0x80, 0xd2] => {
                if let Some((_, SVR_0)) = iter.next() {
                    eprintln!("🪝 Hooking sys_mmap");
                    if let Some(patch) = try_patch(offset, MMAP_BIN)? {
                        patches.push(patch);
                    }
                }
            }

            _ => {}
        }
    }

    // Construct new ELF
    let new_sh_off;
    let ins_off;

    if sh_off == 0 {
        ins_off = page_align(src_size);
        new_sh_off = 0;
    } else {
        ins_off = page_align(sh_off);
        new_sh_off = ins_off + new_segment.len();
    }

    eh.e_shoff = new_sh_off as u64;

    let phs = ProgramHeader64::slice_from_mut_bytes(&mut ph_bytes).unwrap();
    for seg in phs {
        if seg.p_type == PT_NOTE {
            *seg = ProgramHeader64 {
                p_type: PT_LOAD,
                p_flags: PF_R | PF_X,
                p_offset: ins_off as u64,
                p_vaddr: new_segment.vaddr,
                p_paddr: new_segment.vaddr,
                p_filesz: new_segment.len() as u64,
                p_memsz: new_segment.len() as u64,
                p_align: 0x1000,
            };
        }
    }

    dst.write_all(&eh_bytes)?;
    dst.write_all(&ph_bytes)?;
    dst.write_all(&body_bytes)?;

    if ins_off != sh_off {
        dst.write_all(&vec![0u8; ins_off - sh_off])?;
    }
    dst.write_all(&new_segment.code)?;

    // Section header and maybe trailing stuff
    io::copy(src, dst)?;

    // Finally, apply the patches
    for patch in patches {
        dst.seek(SeekFrom::Start(patch.offset as u64))?;
        dst.write_all(&patch.patch)?;
    }

    Ok(())
}

fn page_align(v: usize) -> usize {
    (v + 0x1000 - 1) & !(0x1000 - 1)
}
