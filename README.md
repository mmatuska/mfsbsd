mfsBSD
=========

Copyright (c) 2007-2012 Martin Matuska <mm at FreeBSD.org>

## Description

This is a set of scripts that generates a bootable image, ISO file or boot 
files only, that create a working minimal installation of FreeBSD. This
minimal installation gets completely loaded into memory.

The image may be written directly using dd(1) onto any bootable block device,
e.g. a hard disk or a USB stick e.g. /dev/da0, or a bootable slice only, 
e.g. /dev/ad0s1

## Build-time requirements
 - FreeBSD 7 or higher installed, tested on i386 or amd64
 - Base and kernel from a FreeBSD 7 or higher distribution
   (release or snapshots, e.g mounted CDROM disc1 or ISO file)

## Runtime requirements
 - a minimum of 512MB system memory

## Other information

See BUILD and INSTALL files for building and installation instructions.

Project homepage: http://mfsbsd.vx.sk

This project is based on the ideas of the depenguinator project:
http://www.daemonology.net/depenguinator/
