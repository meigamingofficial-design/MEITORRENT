#!/usr/bin/env python3
"""
Realign ELF LOAD segments to 16 KB (0x4000) page size.

Strategy: INSERT padding before misaligned LOAD segments so that each
segment's file offset satisfies  p_offset ≡ p_vaddr (mod 0x4000).

• All original data is preserved – the file may only grow, never shrink.
• ALL program headers (LOAD and non-LOAD) have their p_offset updated.
• Section header table offset (e_shoff) and per-section sh_offset are updated.
• Virtual addresses (p_vaddr / p_paddr) are NOT changed, keeping the virtual
  memory layout identical to the original – this is the safest approach.

Needed for Android 15+ / Google Play API 35+ 16 KB page-size compliance.
"""

import struct
import sys
import os
import shutil

PT_LOAD = 1
PAGE_SIZE_16K = 0x4000


def realign_elf(input_path, output_path):
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())

    # ── Validate ELF magic ────────────────────────────────────────────────
    if data[:4] != b'\x7fELF':
        print("  Not an ELF file, skipping.")
        shutil.copy2(input_path, output_path)
        return True

    ei_class = data[4]          # 1 = 32-bit, 2 = 64-bit
    is64 = (ei_class == 2)
    endian = '<' if data[5] == 1 else '>'

    # ── Parse ELF header fields ───────────────────────────────────────────
    if is64:
        e_phoff     = struct.unpack_from(endian + 'Q', data, 32)[0]
        e_shoff     = struct.unpack_from(endian + 'Q', data, 40)[0]
        e_phentsize = struct.unpack_from(endian + 'H', data, 54)[0]
        e_phnum     = struct.unpack_from(endian + 'H', data, 56)[0]
        e_shentsize = struct.unpack_from(endian + 'H', data, 58)[0]
        e_shnum     = struct.unpack_from(endian + 'H', data, 60)[0]
    else:
        e_phoff     = struct.unpack_from(endian + 'I', data, 28)[0]
        e_shoff     = struct.unpack_from(endian + 'I', data, 32)[0]
        e_phentsize = struct.unpack_from(endian + 'H', data, 42)[0]
        e_phnum     = struct.unpack_from(endian + 'H', data, 44)[0]
        e_shentsize = struct.unpack_from(endian + 'H', data, 46)[0]
        e_shnum     = struct.unpack_from(endian + 'H', data, 48)[0]

    print(f"  ELF: {'64' if is64 else '32'}-bit, {e_phnum} program headers")

    # ── Parse ALL program headers ─────────────────────────────────────────
    phdrs = []
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        if is64:
            p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = \
                struct.unpack_from(endian + 'IIQQQQQQ', data, off)
        else:
            p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_flags, p_align = \
                struct.unpack_from(endian + 'IIIIIIII', data, off)

        phdrs.append({
            'index': i, 'hdr_off': off,
            'p_type': p_type, 'p_flags': p_flags,
            'p_offset': p_offset, 'p_vaddr': p_vaddr, 'p_paddr': p_paddr,
            'p_filesz': p_filesz, 'p_memsz': p_memsz, 'p_align': p_align,
        })

    # ── Identify LOAD segments that violate 16 KB congruence ──────────────
    loads = sorted(
        [p for p in phdrs if p['p_type'] == PT_LOAD],
        key=lambda p: p['p_offset'],
    )

    needs_fix = False
    for seg in loads:
        congruent = (seg['p_offset'] % PAGE_SIZE_16K) == (seg['p_vaddr'] % PAGE_SIZE_16K)
        aligned   = seg['p_align'] >= PAGE_SIZE_16K
        ok = congruent and aligned
        tag = '✓' if ok else '← NEEDS FIX'
        if not ok:
            needs_fix = True
        print(f"  LOAD[{seg['index']}]: offset={seg['p_offset']:#x} "
              f"vaddr={seg['p_vaddr']:#x} filesz={seg['p_filesz']:#x} "
              f"align={seg['p_align']:#x} {tag}")

    if not needs_fix:
        print("  Already 16KB aligned, no changes needed.")
        shutil.copy2(input_path, output_path)
        return True

    # ── Calculate padding insertions ──────────────────────────────────────
    insertions = []          # [(original_offset, padding_bytes), ...]
    cumulative = 0

    for seg in loads:
        effective_off = seg['p_offset'] + cumulative
        vaddr_mod   = seg['p_vaddr']   % PAGE_SIZE_16K
        current_mod = effective_off     % PAGE_SIZE_16K

        if current_mod != vaddr_mod:
            padding = (vaddr_mod - current_mod) % PAGE_SIZE_16K
            insertions.append((seg['p_offset'], padding))
            cumulative += padding
            print(f"  → Inserting {padding:#x} bytes padding before LOAD[{seg['index']}]")

    if not insertions:
        # Only p_align needs bumping, offsets already congruent
        new_data = bytearray(data)
        for seg in loads:
            h = seg['hdr_off']
            if is64:
                struct.pack_into(endian + 'Q', new_data, h + 48, PAGE_SIZE_16K)
            else:
                struct.pack_into(endian + 'I', new_data, h + 28, PAGE_SIZE_16K)
        with open(output_path, 'wb') as f:
            f.write(new_data)
        os.chmod(output_path, 0o755)
        print(f"  Written {len(new_data)} bytes (p_align only fix)")
        return True

    # ── Build new file with padding inserted ──────────────────────────────
    new_data = bytearray()
    old_pos = 0

    for (insert_at, padding) in insertions:
        new_data.extend(data[old_pos:insert_at])
        new_data.extend(b'\x00' * padding)
        old_pos = insert_at

    # Copy everything after the last insertion point
    new_data.extend(data[old_pos:])

    # ── Offset-shift helper ───────────────────────────────────────────────
    def shift_at(orig_offset):
        """Total padding inserted at or before *orig_offset*."""
        total = 0
        for (at, pad) in insertions:
            if orig_offset >= at:
                total += pad
            else:
                break
        return total

    # ── Update ALL program headers ────────────────────────────────────────
    for phdr in phdrs:
        hdr_new = phdr['hdr_off'] + shift_at(phdr['hdr_off'])
        new_p_offset = phdr['p_offset'] + shift_at(phdr['p_offset'])

        if is64:
            struct.pack_into(endian + 'Q', new_data, hdr_new + 8,  new_p_offset)
            if phdr['p_type'] == PT_LOAD:
                struct.pack_into(endian + 'Q', new_data, hdr_new + 48, PAGE_SIZE_16K)
        else:
            struct.pack_into(endian + 'I', new_data, hdr_new + 4,  new_p_offset)
            if phdr['p_type'] == PT_LOAD:
                struct.pack_into(endian + 'I', new_data, hdr_new + 28, PAGE_SIZE_16K)

    # ── Update e_phoff in ELF header ──────────────────────────────────────
    new_phoff = e_phoff + shift_at(e_phoff)
    if is64:
        struct.pack_into(endian + 'Q', new_data, 32, new_phoff)
    else:
        struct.pack_into(endian + 'I', new_data, 28, new_phoff)

    # ── Update e_shoff and section-header sh_offset fields ────────────────
    if e_shoff > 0 and e_shnum > 0:
        new_shoff = e_shoff + shift_at(e_shoff)
        if is64:
            struct.pack_into(endian + 'Q', new_data, 40, new_shoff)
        else:
            struct.pack_into(endian + 'I', new_data, 32, new_shoff)

        for j in range(e_shnum):
            sh_entry = new_shoff + j * e_shentsize
            if sh_entry + e_shentsize > len(new_data):
                break                                    # safety guard
            if is64:
                old_sh_off = struct.unpack_from(endian + 'Q', new_data, sh_entry + 24)[0]
                struct.pack_into(endian + 'Q', new_data, sh_entry + 24,
                                 old_sh_off + shift_at(old_sh_off))
            else:
                old_sh_off = struct.unpack_from(endian + 'I', new_data, sh_entry + 16)[0]
                struct.pack_into(endian + 'I', new_data, sh_entry + 16,
                                 old_sh_off + shift_at(old_sh_off))

    # ── Write output ──────────────────────────────────────────────────────
    with open(output_path, 'wb') as f:
        f.write(new_data)

    os.chmod(output_path, 0o755)

    print(f"  Written {len(new_data)} bytes to {output_path}")
    print(f"  Size change: {len(data)} → {len(new_data)} "
          f"({len(new_data) - len(data):+d} bytes)")
    return True


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input.so> <output.so>")
        sys.exit(1)

    input_path  = sys.argv[1]
    output_path = sys.argv[2]

    print(f"Realigning {input_path} → {output_path}")
    if realign_elf(input_path, output_path):
        print("  Done!")
    else:
        print("  FAILED!")
        sys.exit(1)


if __name__ == '__main__':
    main()
