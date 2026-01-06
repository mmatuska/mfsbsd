# mfsBSD

Copyright (c) 2019 Martin Matuska <mm at FreeBSD.org>

Version 2.4

## Description

This is a set of scripts that generates a minimal installation of FreeBSD in
a bootable image, ISO file or raw boot archives, e.g., `.tar.gz` files`. The
minimal installation gets completely loaded into memory using the memory disk
(aka `md`) subsystem.

The image may be written directly on to any bootable block device, e.g.,
`/dev/da0`, etc, or a bootable partition/slice, e.g., `/dev/ada0p1`.

## Supported File Formats

A variety of output file formats are supported by mfsbsd:

- General purpose disk images.
    - This is the ideal use case for SD cards, USB keys, etc.
- GCE compatible tar file artifacts.
- ISO images.
- Basic tar, e.g., `.tar.gz`, files.

The [Build Examples](./BUILD.md#Examples) section provides some examples for how
one can build the supported mfsbsd file formats.

## Build-time requirements
 - FreeBSD 11 or higher installed.
      - This was tested on i386, amd64 and arm64
 - `base.txz` and `kernel.txz` from a FreeBSD 11 or higher distribution, _or_ a
    FreeBSD 11 based or newer FreeBSD source tree.

## Runtime requirements
 - A minimum of 512MB system memory

## Other information

See [BUILD](./BUILD.md) and [INSTALL](./INSTALL.md) for building and
installation instructions.

Project homepage: http://mfsbsd.vx.sk

This project was inspired by the [depenguinator project](http://www.daemonology.net/depenguinator/).
