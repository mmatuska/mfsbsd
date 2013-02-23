# Building mfsbsd using virtio

To build with virtio driver duringbootstrap, build kernel with
increased NKPT, then run:

    make with USER_VIRTIO=1 BUILDKERNEL=1 KERNCONF=MFSBSD

To have MFSBSD kernel do following:

1. create MFSBSD kernel config with "options NKPT=150".
   see conf/MFSBSD.conf-sample for instruction to prepare kernel
   configuration file. With options BUILDKERNEL=1 KERNCONF=MFSBSD,
   the kernel with the kernel configuration will be built.

2. Download one of virtio kernel module package from:
	 http://people.freebsd.org/~kuriyama/virtio/
   then extract the contents into './modules' directory.
   (This makefile expect virtio.ko and other files in
     ./modules/boot/modules directory)
