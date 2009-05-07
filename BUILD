# $Id$
#
# mfsBSD building instructions
# Copyright (c) 2007-2008 Martin Matuska <mm at FreeBSD.org>
#
# Version 1.0-BETA3

BUILDING INSTRUCTIONS:
 1. Configuration
    Read hints in the sample configuration files in the conf/ directory, copy
    these files to files without .sample ending and make modifications to suit 
    your needs.

 2. Additional packages
    If you want any packages installed, copy the .tbz files that should be 
    automatically installed into the packages/ directory
    WARNING: Your image should not exceed 45MB in total, otherwise kernel panic
             may occur on boot-time.

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

    a) disc image
      examples: make BASE=/cdrom/7.0-RELEASE
                make CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1

    b) bootable ISO file:
      examples: make iso BASE=/cdrom/7.0-RELEASE
                make iso CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1

    c) .tar.gz file:
      examples: make tar BASE=/cdrom/7.0-RELEASE
                make tar CUSTOM=1 BUILDWORLD=1 BUILDKERNEL=1
