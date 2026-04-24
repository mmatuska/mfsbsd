# zfsinstall: add UEFI boot support via `-E` flag

## Summary

Adds `-E` option to `tools/zfsinstall` to provision UEFI-bootable
FreeBSD ZFS installations. Legacy BIOS boot remains the default
behavior — no change for existing users.

## Motivation

All modern dedicated server providers (OVH Advance/Scale/High Grade,
Scaleway Elastic Metal, Hetzner EX/AX, Latitude, Cherry Servers…)
deliver UEFI-only machines. The current `zfsinstall` produces a
legacy BIOS GPT layout (`freebsd-boot` partition + `gptzfsboot`) that
these firmwares will not boot — operators have to fall back to
`bsdinstall` with a hand-written `installerconfig` just to get an EFI
system partition.

This patch brings the same convenience `zfsinstall` offers for BIOS
to UEFI: one flag, one command line, fully unattended.

## What changes

New flags:

- `-E` : enable UEFI mode (GPT `efi` partition + `/boot/loader.efi`
  copied as `/EFI/BOOT/BOOTX64.EFI` on an msdosfs ESP).
- `-e efi_part_size` : override the ESP size (default `200M`, only
  meaningful with `-E`).

Behavior in UEFI mode:

- The first partition on each drive becomes a GPT `efi` partition
  instead of `freebsd-boot`.
- Partition is formatted with `newfs_msdos -F 32` (FAT32, label
  `EFISYS`).
- `/boot/loader.efi` from the running system is copied to
  `/EFI/BOOT/BOOTX64.EFI` — the fallback path that every UEFI firmware
  looks up when no NVRAM entry matches. This makes the installation
  bootable on any board, no `efibootmgr` dance required.
- Every drive in the pool gets its own ESP. On mirror / raidz this
  means the system keeps booting if one disk (including its ESP)
  fails. Matches the FreeBSD project recommendation documented in
  `bsdinstall`.

Legacy BIOS path is untouched: same `-b 40 -s 472` `freebsd-boot`
partition, same `gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot`.

## Prerequisites

- `/boot/loader.efi` must exist on the running system (standard on
  every FreeBSD ≥ 10.1 `base.txz`). The script checks at startup and
  aborts with a clear message if not.

## Tests

Manual tests done on the following setups:

- [ ] Single disk, UEFI, no swap : `zfsinstall -u … -d ada0 -E`
- [ ] Single disk, UEFI, with swap : `zfsinstall -u … -d ada0 -E -s 2G`
- [ ] Mirror, UEFI : `zfsinstall -u … -d ada0 -d ada1 -r mirror -E`
- [ ] Raidz2, UEFI : `zfsinstall -u … -d ada0 -d ada1 -d ada2 -d ada3 -r raidz2 -E`
- [ ] BIOS regression (no `-E` flag) : unchanged output
- [ ] `/EFI/BOOT/BOOTX64.EFI` present on each ESP after install
- [ ] Machine boots post-reboot on bare metal UEFI-only hardware

*(Maintainer: please check the boxes as each config is verified. The
author validates the BIOS regression and single-disk UEFI path
locally; raidz/mirror UEFI paths need verification on real
hardware.)*

## Compatibility

- Flag additive (`-E`, `-e`) — no breaking change.
- `-E` requires FreeBSD ≥ 10.1 (availability of `/boot/loader.efi`).
  Already the case for any release that ships current `mfsbsd`.
- UEFI partition type `efi` has been supported by `gpart(8)` since
  FreeBSD 10.1 as well.

## Related

- FreeBSD Handbook, UEFI Boot:
  https://docs.freebsd.org/en/books/handbook/advanced-networking/#uefi
- Most dedicated hosting vendors (OVH, Scaleway, Hetzner, Latitude)
  now ship UEFI-only firmware on new server generations. This patch
  brings `zfsinstall` on par with that reality.

---

*Author: Philippe Nénert (ALOLI sas, <philippe@aloli.fr>), on behalf
of the FreeBSD dedicated hosting community. Developed as part of the
`beryl` FreeBSD provisioning tool (https://github.com/aloli-crystal/crystal-beryl).*
