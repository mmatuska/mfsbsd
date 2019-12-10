# mfsBSD installation (deployment) instructions

Copyright (c) 2019 Martin Matuska <mm at FreeBSD.org>

## Build
For customized build please see the [BUILD](./BUILD.md) file

## Deploy

### Scenario 1
You have a linux server without console access and want to install
FreeBSD on this server.

1. modify your configuration files (do this properly, or no ssh access)
2. create an image file (e.g. make BASE=/cdrom/usr/freebsd-dist)
3. write image with dd to the bootable harddrive of the linux server
4. reboot
5. ssh to your machine and enjoy :)

### Scenario 2
You want a rescue CD-ROM with a minimal FreeBSD installation that doesn't
need to remain in the tray after booting.

1. modify your configuration files
2. create an iso image file (e.g. make iso BASE=/cdrom/usr/freebsd-dist)
3. burn ISO image onto a writable CD
4. boot from the CD and enjoy :)

### Scenario 3
You want a rescue partition on your FreeBSD system so you can re-partition
all harddrives remotely.

1. modify your configuration files
2. create an .tar.gz file (e.g. make tar BASE=/cdrom/usr/freebsd-dist)
3. create your UFS partition with sysinstall or gpart (e.g. ada0p2)
4. create a filesystem on the partition (e.g. newfs /dev/ada0p2)
5. mount the partition and extract your .tar.gz file on it
6. configure a bootmanager (e.g. gpart bootcode -b /poot/pmbr -p /boot/gptboot -i 1 ada0)
7. boot from your rescue system and enjoy :)
