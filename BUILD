# $Id$
#
# mfsBSD building instructions
# Copyright (c) 2007-2013 Martin Matuska <mm at FreeBSD.org>
#
# Version 2.1

This fork (github.com/johnko/mfsbsd) of mfsBSD is setup as follows:
./conf
./keys                     # allows organizing different directories to include/exclude
./keys/all                 # a sub tree that can be copied
./keys/all/root            # copied to /root, overwrites any existing files
./keys/all/root/bin        # some tools should be moved to here
./keys/all/server          # this is my custom folder, I don't think anyone will ever use this
./keys/mfsbsdonly          # another sub tree that can be copied
./keys/mfsbsdonly/boot     # copied to /boot, overwrites any existing files
./keys/private
./mfsbsdonly               # the default sub tree that is copied first (later ones overwrite this)
./mfsbsdonly/boot          # copied to /boot first
./mfsbsdonly/etc           # now contains *.conf files, copied to /etc first
./mfsbsdonly/etc/rc.conf.d
./mfsbsdonly/etc/rc.d      # startup scripts
./mfsbsdonly/root          # root users's home folder, copied to /root first
./mfsbsdonly/root/.ssh     # contains authorized_keys
./tools
./tools/roothack

QUICK START:
git clone https://github.com/johnko/mfsbsd.git mfsbsd && cd mfsbsd && ./build.sh nox all $CSV
# where $CSV is your own custom folder in ./keys like 'private' in the example above

BUILDING INSTRUCTIONS:
 1. Configuration
    Read hints in the sample configuration files in the conf/ directory, copy
    these files to files without .sample ending and make modifications to suit 
    your needs.

 2. Additional packages and files
    If you want any packages installed, copy the .t?z files that should be
    automatically installed into the pkginstall/ directory.

    Add any additional files into the files/ directory. These will be copied
    recursively into the root of the boot image.

    WARNING: Your image should not exceed 45MB in total, otherwise kernel panic
             may occur on boot-time. To allow bigger images, you have to
             recompile your kernel with increased NKPT (e.g. NKPT=120)

 3. Distribution or custom world and kernel
    You may choose to build from a FreeBSD distribution (e.g. CDROM), or by
    using make buildworld / buildkernel from your own world and kernel
    configuration.

    To use a distribution (e.g. FreeBSD cdrom), you need access to it 
    (e.g. a mounted FreeBSD ISO via mdconfig) and use BASE=/path/to/distribution

    To use your own but already built world and kernel, use CUSTOM=1
    If you want this script to do make buildworld and make buildkernel for you,
    use BUILDWORLD=1 and BUILDKERNEL=1

4. Creating images

    You may create three types of output: disc image for use by dd(1), 
    ISO image or a simple .tar.gz file

    Examples:

    a) disc image
	make BASE=/cdrom/usr/freebsd-dist
	make BASE=/cdrom/9.2-RELEASE
        make CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1

    b) bootable ISO file:
	make iso BASE=/cdrom/usr/freebsd-dist
	make iso BASE=/cdrom/9.2-RELEASE
	make iso CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1

    c) .tar.gz file:
	make tar BASE=/cdrom/usr/freebsd-dist
	make tar BASE=/cdrom/9.2-RELEASE
	make tar CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1

    d) roothack edition:
	make iso CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1 ROOTHACK=1

    e) special edition (with FreeBSD distribution):
	make iso BASE=/cdrom/9.2-RELEASE RELEASE=9.2-RELEASE ARCH=amd64

    f) GCE-compatible .tar.gz file:
	make gce BASE=/cdrom/usr/freebsd-dist
	make gce BASE=/cdrom/9.2-RELEASE
	make gce CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1
