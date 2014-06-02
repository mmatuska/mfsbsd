# $Id$
#
# mfsBSD
# Copyright (c) 2007-2013 Martin Matuska <mm at FreeBSD.org>
#
# Version 2.1
#

#
# User-defined variables
#
# Not really debug, but can't unset DEBUG since undef doesn't work
NODEBUG=yes
BASE?=/cdrom/usr/freebsd-dist
KERNCONF?= GENERIC
MFSROOT_FREE_INODES?=10%
MFSROOT_FREE_BLOCKS?=10%
MFSROOT_MAXSIZE?=64m
DOFSSIZE?=200000

# If you want to build your own kernel and make you own world, you need to set
# -DCUSTOM or CUSTOM=1
#
# To make buildworld use 
# -DCUSTOM -DBUILDWORLD or CUSTOM=1 BUILDWORLD=1
#
# To make buildkernel use
# -DCUSTOM -DBUILDKERNEL or CUSTOM=1 BUILDKERNEL=1
#
# For all of this use
# -DCUSTOM -DBUILDWORLD -DBUILDKERNEL or CUSTOM=1 BUILDKERNEL=1 BUILDWORLD=1
#
# To use pkgng, specify
# -DPKGNG or PKGNG=1

#
# Paths
#
KEYCFG?=none
KEYSDIR=keys
SRC_DIR?=/usr/src
MFSBSDONLY=mfsbsdonly
FILESDIR=all
PACKAGESDIR?=packages
PKGINSTALLDIR?=pkginstall
CUSTOMFILESDIR=customfiles
TOOLSDIR=tools
PRUNELIST?=${TOOLSDIR}/prunelist
PKG_STATIC?=${TOOLSDIR}/pkg-static
#
# Program defaults
#
MKDIR=/bin/mkdir -p
CHOWN=/usr/sbin/chown
CHMOD=/bin/chmod
CAT=/bin/cat
PWD=/bin/pwd
TAR=/usr/bin/tar
GTAR=/usr/local/bin/gtar
CP=/bin/cp
MV=/bin/mv
RM=/bin/rm
RMDIR=/bin/rmdir
CHFLAGS=/bin/chflags
GZIP=/usr/bin/gzip
TOUCH=/usr/bin/touch
INSTALL=/usr/bin/install
LS=/bin/ls
LN=/bin/ln
FIND=/usr/bin/find
GREP=/usr/bin/egrep
PW=/usr/sbin/pw
SED=/usr/bin/sed
UNAME=/usr/bin/uname
BZIP2=/usr/bin/bzip2
XZ=/usr/bin/xz
MAKEFS=/usr/sbin/makefs
MKISOFS=/usr/local/bin/mkisofs
SSHKEYGEN=/usr/bin/ssh-keygen
SYSCTL=/sbin/sysctl
PKG=/usr/local/sbin/pkg-static
#
CURDIR!=${PWD}
WRKDIR?=${CURDIR}/tmp
#
BSDLABEL=bsdlabel
#
DOFS=${TOOLSDIR}/doFS.sh
BOOTMODULES?=acpi ahci aesni
MFSMODULES?=geom_mirror geom_nop opensolaris zfs ext2fs snp smbus ipmi ntfs nullfs tmpfs acpi ahci aesni geom_eli geom_label smbfs crypto zlib linux nvidia snd_uaudio if_lagg carp pf pflog

.if !defined(ARCH)
TARGET!=	${SYSCTL} -n hw.machine_arch
.else
TARGET=		${ARCH}
.endif

.if !defined(RELEASE)
RELEASE!=${UNAME} -r
.endif

.if !defined(SE)
IMAGE_PREFIX?=	mfsbsd
.else
IMAGE_PREFIX?=	mfsbsd-se
.endif

IMAGE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.img
ISOIMAGE?= ${IMAGE_PREFIX}-${RELEASE}-${TARGET}.iso
TARFILE?= ${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar
GCEFILE?= ${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar.gz
_DISTDIR= ${WRKDIR}/dist/${RELEASE}-${TARGET}

.if !defined(DEBUG) || defined(NODEBUG)
EXCLUDE=--exclude *.symbols
.else
EXCLUDE=
.endif

# Roothack stuff
.if defined(ROOTHACK_FILE) && exists(${ROOTHACK_FILE})
ROOTHACK=1
ROOTHACK_PREBUILT=1
_ROOTHACK_FILE=${ROOTHACK_FILE}
.else
_ROOTHACK_FILE=${WRKDIR}/roothack/roothack
.endif

# Check if we are installing FreeBSD 9 or higher
.if exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
FREEBSD9?=yes
BASEFILE?=${BASE}/base.txz
KERNELFILE?=${BASE}/kernel.txz
.else
BASEFILE?=${BASE}/base/base.??
KERNELFILE?=${BASE}/kernels/generic.??
.endif

.if defined(MAKEJOBS)
_MAKEJOBS=	-j${MAKEJOBS}
.endif

_ROOTDIR=	${WRKDIR}/mfs
_BOOTDIR=	${_ROOTDIR}/boot
.if defined(ROOTHACK)
_DESTDIR=	${_ROOTDIR}/rw
WITHOUT_RESCUE=1
MFSROOT_FREE_INODES?=1%
MFSROOT_FREE_BLOCKS?=1%
.else
_DESTDIR=	${_ROOTDIR}
.endif

.if !defined(SE)
# Environment for custom build
BUILDENV?= env \
	NO_FSCHG=1 \
	WITHOUT_CLANG=1 \
	WITHOUT_DICT=1 \
	WITHOUT_GAMES=1 \
	WITHOUT_LIB32=1

. if defined(WITHOUT_RESCUE)
BUILDENV+=	WITHOUT_RESCUE=1
. endif

# Environment for custom install
INSTALLENV?= ${BUILDENV} \
	WITHOUT_TOOLCHAIN=1
.endif

.if defined(FULLDIST)
NO_PRUNE=1
NO_RESCUE_LINKS=1
.endif

all: image

destdir: ${_DESTDIR} ${_BOOTDIR}
${_DESTDIR}:
	@${MKDIR} ${_DESTDIR} && ${CHOWN} root:wheel ${_DESTDIR}

${_BOOTDIR}:
	@${MKDIR} ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && ${CHOWN} -R root:wheel ${_BOOTDIR}

extract: destdir ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
.if !defined(CUSTOM)
	@if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable BASE to a path"; \
		echo "with FreeBSD distribution files (e.g. /cdrom/9.2-RELEASE)"; \
		echo "Examples:"; \
		echo "make BASE=/cdrom/9.2-RELEASE"; \
		echo "make BASE=/cdrom/usr/freebsd-dist"; \
		exit 1; \
	fi
.if !defined(FREEBSD9)
	@for DIR in base kernels; do \
		if [ ! -d "${BASE}/$$DIR" ]; then \
			echo "Cannot find directory \"${BASE}/$$DIR\""; \
			exit 1; \
		fi \
	done
.endif
	@echo -n "Extracting base and kernel ..."
	@${CAT} ${BASEFILE} | ${TAR} --unlink -xpzf - -C ${_DESTDIR}
.if !defined(FREEBSD9)
	@${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_BOOTDIR}
	@${MV} ${_BOOTDIR}/${KERNCONF}/* ${_BOOTDIR}/kernel
	@${RMDIR} ${_BOOTDIR}/${KERNCONF}
.else
	@${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_ROOTDIR}
.endif
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
. if defined(BUILDWORLD)
	@echo -n "Building world ..."
	@cd ${SRC_DIR} && \
	${BUILDENV} make ${_MAKEJOBS} buildworld TARGET=${TARGET}
. endif
. if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET=${TARGET}
. endif
.endif
	@${TOUCH} ${WRKDIR}/.build_done

install: destdir build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	@cd ${SRC_DIR} && \
	${INSTALLENV} make installworld distribution DESTDIR="${_DESTDIR}" TARGET=${TARGET} && \
	${INSTALLENV} make installkernel KERNCONF=${KERNCONF} DESTDIR="${_ROOTDIR}" TARGET=${TARGET}
.endif
.if defined(SE)
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@echo -n "Copying base.txz and kernel.txz ..."
. else
	@echo -n "Creating base.txz and kernel.txz ..."
. endif
	@${MKDIR} ${_DISTDIR}
. if defined(ROOTHACK)
	@${CP} -rp ${_BOOTDIR}/kernel ${_DESTDIR}/boot
. endif
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@${CP} ${BASE}/base.txz ${_DISTDIR}/base.txz
	@${CP} ${BASE}/kernel.txz ${_DISTDIR}/kernel.txz
. else
	@${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} --exclude "boot/kernel/*" -f ${_DISTDIR}/base.txz .
	@${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} -f ${_DISTDIR}/kernel.txz boot/kernel
. endif
	@echo " done"
. if defined(ROOTHACK)
	@${RM} -rf ${_DESTDIR}/boot/kernel
. endif
.endif
	@${CHFLAGS} -R noschg ${_DESTDIR} > /dev/null 2> /dev/null || exit 0
.if !defined(WITHOUT_RESCUE) || defined(NO_RESCUE_LINKS)
	@cd ${_DESTDIR} && \
	for FILE in `${FIND} rescue -type f`; do \
	FILE=$${FILE##rescue/}; \
	if [ -f bin/$$FILE ]; then \
		${RM} bin/$$FILE && \
		${LN} rescue/$$FILE bin/$$FILE; \
	elif [ -f sbin/$$FILE ]; then \
		${RM} sbin/$$FILE && \
		${LN} rescue/$$FILE sbin/$$FILE; \
	elif [ -f usr/bin/$$FILE ]; then \
		${RM} usr/bin/$$FILE && \
		${LN} -s ../../rescue/$$FILE usr/bin/$$FILE; \
	elif [ -f usr/sbin/$$FILE ]; then \
		${RM} usr/sbin/$$FILE && \
		${LN} -s ../../rescue/$$FILE usr/sbin/$$FILE; \
	fi; \
	done
.endif
.if defined(WITHOUT_RESCUE)
	@cd ${_DESTDIR} && ${RM} -rf rescue
.endif
	@${TOUCH} ${WRKDIR}/.install_done

prune: install ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
.if !defined(NO_PRUNE)
	@echo -n "Removing selected files from distribution ..."
	@if [ -f "${PRUNELIST}" ]; then \
		for FILE in `cat ${PRUNELIST}`; do \
			if [ -n "$${FILE}" ]; then \
				${RM} -rf ${_DESTDIR}/$${FILE}; \
			fi; \
		done; \
	fi
	@${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"
.endif

packages: install prune ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
.if defined(PKGNG)
	@echo -n "Installing pkgng ..."
.  if !exists(${PKG_STATIC})
	@echo "pkg-static not found at: ${PKG_STATIC}"
	@exit 1
.  endif
	@{MKDIR} ${_DESTDIR}/usr/local/sbin
	@${INSTALL} -o root -g wheel -m 0755 ${PKG_STATIC} ${_DESTDIR}/usr/local/sbin/
	@${LN} -sf pkg-static ${_DESTDIR}/usr/local/sbin/pkg
	@echo " done"
.endif
	@if [ -d "${PACKAGESDIR}" ]; then \
		echo -n "Copying user packages to disk image ..."; \
		${CP} -rf ${PACKAGESDIR} ${_DESTDIR}; \
		echo " done"; \
	fi
	@if [ -d "${PKGINSTALLDIR}" ]; then \
		echo -n "Copying user packages for install ..."; \
		${CP} -rf ${PKGINSTALLDIR} ${_DESTDIR}; \
		echo " done"; \
	fi
	@if [ -d "${_DESTDIR}/${PKGINSTALLDIR}" ]; then \
		echo -n "Installing user packages ..."; \
	fi
.if defined(PKGNG)
	@if [ -d "${_DESTDIR}/${PKGINSTALLDIR}" ]; then \
		cd ${_DESTDIR}/${PKGINSTALLDIR} && \
			${PKG} -c ${_DESTDIR} add `/bin/ls -1 *.t?z | /usr/bin/awk '{ print "/${PKGINSTALLDIR}/"$$1 }' | /usr/bin/tr '\n' ' '` || echo "SOME ALREADY INSTALLED"; \
		echo " done"; \
	fi
.else
	@if [ -d "${_DESTDIR}/${PKGINSTALLDIR}" ]; then \
		cd ${_DESTDIR}/packages && for FILE in *; do \
			env PKG_PATH=/packages pkg_add -fi -C ${_DESTDIR} /packages/$${FILE} > /dev/null; \
		done; \
	fi
.endif
	@if [ -d "${_DESTDIR}/${PKGINSTALLDIR}" ]; then \
		${RM} -rf ${_DESTDIR}/${PKGINSTALLDIR}; \
		echo " done"; \
	fi
	@${TOUCH} ${WRKDIR}/.packages_done

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
# /boot
	@for MYDIR in ${MFSBSDONLY} ${FILESDIR} ; do \
		FILEPERM=644 ; \
		if [     -d "$${MYDIR}/boot" ]; then \
			${FIND}  $${MYDIR}/boot -type d -exec ${CHMOD} 755 {} \;; \
			${FIND}  $${MYDIR}/boot -type f -exec ${CHMOD} $${FILEPERM} {} \;; \
			${CP} -a $${MYDIR}/boot ${_DESTDIR}; \
		fi ; \
	done
	@for MYDIR in ${KEYCFG} ; do \
		FILEPERM=600 ; \
		if [     -d "${KEYSDIR}/$${MYDIR}/boot" ]; then \
			${FIND}  ${KEYSDIR}/$${MYDIR}/boot -type d -exec ${CHMOD} 755 {} \;; \
			${FIND}  ${KEYSDIR}/$${MYDIR}/boot -type f -exec ${CHMOD} $${FILEPERM} {} \;; \
			${CP} -a ${KEYSDIR}/$${MYDIR}/boot ${_DESTDIR}; \
		fi ; \
	done
	@${INSTALL} -d -m 0700 ${_DESTDIR}/boot/keys
.for FILE in boot.config
. if !exists(${CFGDIR}/${FILE}) && !exists(${CFGDIR}/${FILE}.sample)
	@echo "Missing ${CFGDIR}/${FILE}.sample" && exit 1
. endif
.endfor
.for FILE in loader.conf
. if !exists(${_DESTDIR}/boot/${FILE}) && !exists(${_DESTDIR}/boot/${FILE}.sample)
	@echo "Missing ${_DESTDIR}/boot/${FILE}.sample" && exit 1
. endif
.endfor
# /etc
	@for MYDIR in ${MFSBSDONLY} ${FILESDIR} ; do \
		FILEPERM=644 ; \
		if [     -d "$${MYDIR}/etc" ]; then \
			${FIND}  $${MYDIR}/etc -type d -exec ${CHMOD} 755 {} \;; \
			${FIND}  $${MYDIR}/etc -type f -exec ${CHMOD} $${FILEPERM} {} \;; \
			if [ -d "$${MYDIR}/etc/rc.d" ]; then \
			 ${FIND} $${MYDIR}/etc/rc.d -type f -exec ${CHMOD} 755 {} \;; \
			fi ; \
			if [ -d "$${MYDIR}/etc/periodic" ]; then \
			 ${FIND} $${MYDIR}/etc/periodic -type f -exec ${CHMOD} 755 {} \;; \
			fi ; \
			${CP} -a $${MYDIR}/etc ${_DESTDIR}; \
		fi ; \
	done
	@for MYDIR in ${KEYCFG}; do \
		FILEPERM=600 ; \
		if [     -d "${KEYSDIR}/$${MYDIR}/etc" ]; then \
			${FIND}  ${KEYSDIR}/$${MYDIR}/etc -type d -exec ${CHMOD} 755 {} \;; \
			${FIND}  ${KEYSDIR}/$${MYDIR}/etc -type f -exec ${CHMOD} $${FILEPERM} {} \;; \
			if [ -d "${KEYSDIR}/$${MYDIR}/etc/rc.d" ]; then \
			 ${FIND} ${KEYSDIR}/$${MYDIR}/etc/rc.d -type f -exec ${CHMOD} 755 {} \;; \
			fi ; \
			if [ -d "${KEYSDIR}/$${MYDIR}/etc/periodic" ]; then \
			 ${FIND} ${KEYSDIR}/$${MYDIR}/etc/periodic -type f -exec ${CHMOD} 755 {} \;; \
			fi ; \
			${CP} -a ${KEYSDIR}/$${MYDIR}/etc ${_DESTDIR}; \
		fi ; \
	done
.for FILE in rc.conf rc.local resolv.conf ttys
. if !exists(${_DESTDIR}/etc/${FILE}) && !exists(${_DESTDIR}/etc/${FILE}.sample)
	@echo "Missing ${_DESTDIR}/etc/${FILE}.sample" && exit 1
. endif
.endfor
.if defined(SE)
	@${INSTALL} -m 0644 ${MFSBSDONLY}/etc/motd.se ${_DESTDIR}/etc/motd
	@${INSTALL} -d -m 0755 ${_DESTDIR}/cdrom
.else
	@${INSTALL} -m 0644 ${MFSBSDONLY}/etc/motd ${_DESTDIR}/etc/motd
.endif
	@${MKDIR} ${_DESTDIR}/stand ${_DESTDIR}/etc/rc.conf.d
.for FILE in interfaces.conf
. if !exists(${_DESTDIR}/etc/rc.conf.d/${FILE}) && !exists(${_DESTDIR}/etc/rc.conf.d/${FILE}.sample)
	@echo "Missing ${_DESTDIR}/etc/rc.conf.d/${FILE}.sample" && exit 1
. endif
.endfor
.if defined(ROOTHACK)
	@echo 'root_rw_mount="NO"' >> ${_DESTDIR}/etc/rc.conf
.endif
	@${MKDIR} ${_DESTDIR}/root/bin
# /root
	@for MYDIR in ${MFSBSDONLY} ${FILESDIR} ; do \
		FILEPERM=600 ; \
		if [     -d "$${MYDIR}/root" ]; then \
			${FIND}  $${MYDIR}/root -type d -exec ${CHMOD} 700 {} \;; \
			${FIND}  $${MYDIR}/root -type f -exec ${CHMOD} $${FILEPERM} {} \;; \
			${CP} -a $${MYDIR}/root ${_DESTDIR}; \
		fi ; \
	done
	@for MYDIR in ${KEYCFG}; do \
		FILEPERM=600 ; \
		if [     -d "${KEYSDIR}/$${MYDIR}/root" ]; then \
			${FIND}  ${KEYSDIR}/$${MYDIR}/root -type d -exec ${CHMOD} 700 {} \;; \
			${FIND}  ${KEYSDIR}/$${MYDIR}/root -type f -exec ${CHMOD} $${FILEPERM} {} \;; \
			${CP} -a ${KEYSDIR}/$${MYDIR}/root ${_DESTDIR}; \
		fi ; \
	done
	@if [ -f "${_DESTDIR}/root/.ssh/authorized_keys" ]; then \
		${CHMOD} go-rwx ${_DESTDIR}/root/.ssh; \
		${CHMOD} go-rwx ${_DESTDIR}/root/.ssh/authorized_keys; \
	fi
#	@${SED} -I -E 's/\(ttyv[2-7].*\)on /\1off/g' ${_DESTDIR}/etc/ttys
.if !defined(ROOTHACK)
	@echo "/dev/md0 / ufs rw 0 0" > ${_DESTDIR}/etc/fstab
	@echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_DESTDIR}/etc/fstab
.else
	@${TOUCH} ${_DESTDIR}/etc/fstab
.endif
	@echo "/dev/mirror/swap.eli none swap sw,aalgo=HMAC/SHA256 0 0" >> ${_DESTDIR}/etc/fstab
.if defined(ROOTPW)
	@echo ${ROOTPW} | ${PW} -V ${_DESTDIR}/etc usermod root -h 0
.endif
	@echo PermitRootLogin yes >> ${_DESTDIR}/etc/ssh/sshd_config
	@${TOUCH} ${WRKDIR}/.config_done
	@echo " done"

genkeys: config ${WRKDIR}/.genkeys_done
${WRKDIR}/.genkeys_done:
	@echo -n "Generating SSH host keys ..."
	@${SSHKEYGEN} -t rsa -f ${_DESTDIR}/etc/ssh/ssh_host_rsa_key -N '' > /dev/null
	@${CHMOD} go-rwx ${_DESTDIR}/etc/ssh/ssh_host*key
	@${TOUCH} ${WRKDIR}/.genkeys_done
	@echo " done"

customfiles: config ${WRKDIR}/.customfiles_done
${WRKDIR}/.customfiles_done:
.if exists(${CUSTOMFILESDIR})
	@echo "Copying user files ..."
	@${CP} -afv ${CUSTOMFILESDIR}/ ${_DESTDIR}/
	@${TOUCH} ${WRKDIR}/.customfiles_done
	@echo " done"
.endif

compress-usr: install prune config genkeys customfiles boot packages ${WRKDIR}/.compress-usr_done
${WRKDIR}/.compress-usr_done:
.if !defined(ROOTHACK)
	@echo -n "Compressing usr ..."
	@${TAR} -c -J -C ${_DESTDIR} -f ${_DESTDIR}/.usr.tar.xz usr 
	@${FIND} ${_DESTDIR}/usr -type l -exec ${CHFLAGS} -h nosunlink {} \;
	@${RM} -rf ${_DESTDIR}/usr && ${MKDIR} ${_DESTDIR}/usr 
.else
	@echo -n "Compressing root ..."
	@${TAR} -c -C ${_ROOTDIR} -f - rw | \
	${XZ} -v -c > ${_ROOTDIR}/root.txz
	@${FIND} ${_DESTDIR} -type l -exec ${CHFLAGS} -h nosunlink {} \;
	@${RM} -rf ${_DESTDIR} && ${MKDIR} ${_DESTDIR}
.endif
	@${TOUCH} ${WRKDIR}/.compress-usr_done
	@echo " done"

roothack: ${WRKDIR}/roothack/roothack
${WRKDIR}/roothack/roothack:
.if !defined(ROOTHACK_PREBUILT)
	@${MKDIR} -p ${WRKDIR}/roothack
	@cd ${TOOLSDIR}/roothack && env MAKEOBJDIR=${WRKDIR}/roothack make
.endif

install-roothack: compress-usr roothack ${WRKDIR}/.install-roothack_done
${WRKDIR}/.install-roothack_done:
	@echo -n "Installing roothack ..."
	@${MKDIR} -p ${_ROOTDIR}/dev ${_ROOTDIR}/sbin
	@${INSTALL} -m 555 ${_ROOTHACK_FILE} ${_ROOTDIR}/sbin/init
	@${TOUCH} ${WRKDIR}/.install-roothack_done
	@echo " done"

boot: install prune ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
	@${MKDIR} ${WRKDIR}/disk/boot && ${CHOWN} root:wheel ${WRKDIR}/disk
	@${RM} -f ${_BOOTDIR}/kernel/kernel.debug
	@${CP} -rp ${_BOOTDIR}/kernel ${WRKDIR}/disk/boot
.for FILE in boot defaults loader loader.help *.rc *.4th
	@${CP} -rp ${_DESTDIR}/boot/${FILE} ${WRKDIR}/disk/boot
.endfor
	@${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko ${WRKDIR}/disk/boot/kernel/*.symbols
.if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/kernel.symbols \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/kernel.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
.endif
.for FILE in ${BOOTMODULES}
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko.symbols ${WRKDIR}/disk/boot/kernel >/dev/null 2>/dev/null || exit 0
. endif
.endfor
	@${MKDIR} -p ${_DESTDIR}/boot/modules
.for FILE in ${MFSMODULES}
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko ${_DESTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. if defined(DEBUG)
	@test -f ${_BOOTDIR}/kernel/${FILE}.ko.symbols \
	&& ${INSTALL} -m 0555 ${_BOOTDIR}/kernel/${FILE}.ko.symbols ${_DESTDIR}/boot/modules >/dev/null 2>/dev/null || exit 0
. endif
.endfor
.if defined(ROOTHACK)
	@echo -n "Installing tmpfs module for roothack ..."
	@${MKDIR} ${_ROOTDIR}/boot/modules
	@${INSTALL} -m 0666 ${_BOOTDIR}/kernel/tmpfs.ko ${_ROOTDIR}/boot/modules
	@echo " done"
.endif
	@${RM} -rf ${_BOOTDIR}/kernel ${_BOOTDIR}/*.symbols
	@${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

.if defined(ROOTHACK)
mfsroot: install prune config genkeys customfiles boot compress-usr packages install-roothack ${WRKDIR}/.mfsroot_done
.else
mfsroot: install prune config genkeys customfiles boot compress-usr packages ${WRKDIR}/.mfsroot_done
.endif
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	@${MKDIR} ${WRKDIR}/mnt
	@${MAKEFS} -t ffs -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
	@${FIND} ${_DESTDIR} -type l -exec ${CHFLAGS} -h nosunlink {} \;
	@${RM} -rf ${WRKDIR}/mnt ${_DESTDIR}
	@${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	@${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
# /boot for disk and iso
	@for MYDIR in ${MFSBSDONLY} ${FILESDIR} ; do \
		if [     -d "$${MYDIR}/boot" ]; then \
			${CP} -a $${MYDIR}/boot ${WRKDIR}/disk/; \
		fi ; \
	done
	@for MYDIR in ${KEYCFG} ; do \
		if [     -d "${KEYSDIR}/$${MYDIR}/boot" ]; then \
			${CP} -a ${KEYSDIR}/$${MYDIR}/boot ${WRKDIR}/disk/; \
		fi ; \
	done
	@${TOUCH} ${WRKDIR}/.mfsroot_done
	@echo " done"

fbsddist: install prune config genkeys customfiles boot compress-usr packages mfsroot ${WRKDIR}/.fbsddist_done
${WRKDIR}/.fbsddist_done:
.if defined(SE)
	@echo -n "Copying FreeBSD installation image ..."
	@${CP} -rf ${_DISTDIR} ${WRKDIR}/disk/
	@echo " done"
.endif
	@${TOUCH} ${WRKDIR}/.fbsddist_done

image: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
	@${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	@${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	@${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt ${DOFSSIZE} ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	@${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	@${MV} ${WRKDIR}/disk.img ${IMAGE}
	@echo " done"
	@${LS} -l ${IMAGE}

gce: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${IMAGE} ${GCEFILE}
${GCEFILE}:
	@echo -n "Creating GCE-compatible tarball..."
.if !exists(${GTAR})
	@echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	@${GTAR} -C ${CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	@${LS} -l ${GCEFILE}
.endif

iso: install prune config genkeys customfiles boot compress-usr mfsroot fbsddist ${ISOIMAGE}
${ISOIMAGE}:
	@echo -n "Creating ISO image ..."
.if defined(USE_MKISOFS)
. if !exists(${MKISOFS})
	@echo "${MKISOFS} is missing, please install sysutils/cdrtools first"; exit 1
. else
	@${MKISOFS} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${ISOIMAGE} ${WRKDIR}/disk > /dev/null 2> /dev/null
. endif
.else
	@${MAKEFS} -t cd9660 -o rockridge,bootimage=i386\;/boot/cdboot,no-emul-boot,label=mfsBSD ${ISOIMAGE} ${WRKDIR}/disk
.endif
	@echo " done"
	@${LS} -l ${ISOIMAGE}

tar: install prune config customfiles boot compress-usr mfsroot fbsddist ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar file ..."
	@cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${CURDIR}/${TARFILE} {} \;
	@echo " done"
	@${LS} -l ${TARFILE}

clean-roothack:
	@${RM} -rf ${WRKDIR}/roothack

clean: clean-roothack
	@if [ -d ${WRKDIR} ]; then ${CHFLAGS} -R noschg ${WRKDIR}; fi
	@cd ${WRKDIR} && ${RM} -rf mfs mnt disk dist trees .*_done
