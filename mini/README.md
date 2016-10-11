# mfsBSD-mini

Copyright (c) 2015-2016 Martin Matuska <mm at FreeBSD.org>

## Description

This is a set of scripts that generates a small bootable image, ISO file or 
tar archive from a installed FreeBSD system. The image gets completely loaded
into memory.

The image may be written directly using dd(1) onto any bootable block device,
e.g. a hard disk or a USB stick e.g. /dev/da0, or a bootable partition only, 
e.g. /dev/ada0p2

## Building

You need to do "make extract" in the main mfsBSD directory 

Project homepage: http://mfsbsd.vx.sk
