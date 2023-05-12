# mfsBSD building instructions

Copyright (c) 2019 Martin Matuska <mm at FreeBSD.org>

## Configuration
Read hints in the sample configuration files in the conf/ directory, copy
these files to files without .sample ending and make modifications to suit 
your needs.

The default root password is "mfsroot". You can pick a difrerent password
with the `ROOTPW` or `ROOTPW_HASH` make variables.

This password can be used to log in as root over SSH.

To disable remote root login, pass `PERMIT_ROOT_LOGIN=no` to make.

To disallow password authentication for root, set
`PERMIT_ROOT_LOGIN=without-password`. If you do so, remember to add your SSH
keys to `conf/authorized_keys` if you want to be able to log in via SSH.

## Additional packages and files
If you want any packages installed, copy the .tbz files that should be 
automatically installed into the packages/ directory.

Add any additional files into the customfiles/ directory. These will be copied
recursively into the root of the boot image.

WARNING:
Your image should not exceed MFSROOT_MAXSIZE in total.
Please adjust the variable for larger images.

## Distribution or custom world and kernel
You may choose to build from a FreeBSD distribution (e.g. CDROM), or by
using make buildworld / buildkernel from your own world and kernel
configuration.

To use a distribution (e.g. FreeBSD cdrom), you need access to it 
(e.g. a mounted FreeBSD ISO via mdconfig) and use BASE=/path/to/distribution

To use your own but already built world and kernel, use CUSTOM=1
If you want this script to do make buildworld and make buildkernel for you,
use BUILDWORLD=1 and BUILDKERNEL=1

## Creating images

You may create three types of output: disc image for use by dd(1), 
ISO image or a simple .tar.gz file

##Examples

1. disc image

  ```bash
  make BASE=/cdrom/usr/freebsd-dist
  make BASE=/cdrom/10.2-RELEASE
  make CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1
  ```

2. bootable ISO file:

  ```bash
  make iso BASE=/cdrom/usr/freebsd-dist
  make iso BASE=/cdrom/10.2-RELEASE
  make iso CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1
  ```

3. .tar.gz file:

  ```bash
  make tar BASE=/cdrom/usr/freebsd-dist
  make tar BASE=/cdrom/10.2-RELEASE
  make tar CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1
  ```

4. roothack edition:

  ```bash
  make iso CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1 ROOTHACK=1
  ```

5. special edition (with FreeBSD distribution):

  ```bash
  make iso BASE=/cdrom/11.0-RELEASE RELEASE=11.0-RELEASE ARCH=amd64
  ```

6. GCE-compatible .tar.gz file:

  ```bash
  make gce BASE=/cdrom/11.0-RELEASE
  make gce CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1
  ```
