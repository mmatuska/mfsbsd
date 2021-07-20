# $Id$
#
# mfsBSD
# Copyright (c) 2019 Martin Matuska <mm at FreeBSD.org>

#
# User-defined variables
#
BASE?=			/cdrom/usr/freebsd-dist
KERNCONF?=		GENERIC
MFSROOT_FREE_INODES?=	10%
MFSROOT_FREE_BLOCKS?=	10%
MFSROOT_MAXSIZE?=	120m
MFSROOT_SECTOR_SIZE?=	512
ROOTPW_HASH?=		$$6$$051DdQA7fTvLymkY$$Z5f6snVFQJKugWmGi8y0motBNaKn9em0y2K0ZsJMku3v9gkiYh8M.OTIIie3RvHpzT6udumtZUtc0kXwJcCMR1
ROOTHACK?=		0

# The primary targets in this file are:
#
# clean 	Clean up
# all		Create raw image file
# image 	Create raw image file
# iso		Create a bootable ISO image
# tar		Create tar.gz file with kernal and mfsroot
# gce		Create GCE-compatible .tar.gz file
# mini		Create mfsBSD-mini edition: image,iso,tar,gce
#
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
# If you want to build mfsBSD-mini , you need to set
# MINITYPE={image,iso,tar,gce} and run for example:
# make mini MINITYPE=tar

#
# Paths
#
SRC_DIR?=		/usr/src
CFGDIR?=		conf
SCRIPTSDIR?=		scripts
PACKAGESDIR?=		packages
CUSTOMFILESDIR?=	customfiles
CUSTOMSCRIPTSDIR?=	customscripts
TOOLSDIR?=		tools
PRUNELIST?=		${TOOLSDIR}/prunelist
KERN_EXCLUDE?=		${TOOLSDIR}/kern_exclude
PKG_STATIC?=		/usr/local/sbin/pkg-static
#
# Program defaults
#
MKDIR?=		/bin/mkdir
CHOWN?=		/usr/sbin/chown
CAT?=		/bin/cat
PWD?=		/bin/pwd
TAR?=		/usr/bin/tar
GTAR?=		/usr/local/bin/gtar
CP?=		/bin/cp
MV?=		/bin/mv
RM?=		/bin/rm
RMDIR?=		/bin/rmdir
CHFLAGS?=	/bin/chflags
GZIP?=		/usr/bin/gzip
TOUCH?=		/usr/bin/touch
INSTALL?=	/usr/bin/install
LS?=		/bin/ls
LN?=		/bin/ln
FIND?=		/usr/bin/find
PW?=		/usr/sbin/pw
SED?=		/usr/bin/sed
UNAME?=		/usr/bin/uname
BZIP2?=		/usr/bin/bzip2
XZ?=		/usr/bin/xz
MAKEFS?=	/usr/sbin/makefs
MKISOFS?=	/usr/local/bin/mkisofs
SSHKEYGEN?=	/usr/bin/ssh-keygen
SYSCTL?=	/sbin/sysctl
PKG?=		/usr/local/sbin/pkg
OPENSSL?=	/usr/bin/openssl
CUT?=		/usr/bin/cut
#
WRKDIR?=	${.CURDIR}/work
#
BSDLABEL?=	bsdlabel
#
DOFS?=		${TOOLSDIR}/doFS.sh
DO_GPT?=	${TOOLSDIR}/do_gpt.sh
SCRIPTS?=	mdinit mfsbsd interfaces packages
BOOTMODULES?=	acpi ahci geom_mirror daemon_saver
.if defined(LOADER_4TH)
BOOTFILES?=	defaults cdboot device.hints loader_4th *.rc *.4th
.else
BOOTFILES?=	defaults cdboot device.hints loader_lua lua
.endif
MFSMODULES?=	aesni crypto cryptodev ext2fs geom_eli geom_mirror geom_nop \
		geom_label geom_part_mbr geom_part_bsd ipfw daemon_saver \
		ipmi ntfs nullfs opensolaris smbus snp tmpfs zfs
# Sometimes the kernel is compiled with a different destination.
KERNDIR?=	kernel
#
XZ_FLAGS?=
#

VERBOSE=
.if defined(V)
_v=
VERB=1
VERBOSE=	--verbose
.else
_v=@
VERB=
.endif

.if !defined(ARCH)
TARGET!=	${SYSCTL} -n hw.machine_arch
.else
TARGET=		${ARCH}
.endif

.if !defined(RELEASE)
RELEASE!=	${UNAME} -r
.endif

.if !defined(PKG_ABI)
PKG_ABI!=	echo "FreeBSD:`${UNAME} -U | ${CUT} -c 1-2`:`${UNAME} -m`"
.endif

.if !defined(SE)
IMAGE_PREFIX?=	mfsbsd
.else
IMAGE_PREFIX?=	mfsbsd-se
.endif

IMAGE?=		${IMAGE_PREFIX}-${RELEASE}-${TARGET}.img
ISOIMAGE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.iso
TARFILE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar
GCEFILE?=	${IMAGE_PREFIX}-${RELEASE}-${TARGET}.tar.gz
_DISTDIR=	${WRKDIR}/dist/${RELEASE}-${TARGET}

MINITYPE?=	image
SALT?=		`${OPENSSL} rand -base64 16`

.if !defined(DEBUG)
EXCLUDE=	--exclude *.symbols
.else
EXCLUDE=
.endif

# Roothack stuff
.if ${ROOTHACK} ==  0
NO_ROOTHACK=	1
.endif

.if !defined(NO_ROOTHACK)
. if defined(ROOTHACK_FILE) && exists(${ROOTHACK_FILE})
ROOTHACK_PREBUILT=1
. else
ROOTHACK_FILE=	${WRKDIR}/roothack/roothack
. endif
.endif

# Check if we are installing FreeBSD 9 or higher
.if exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
FREEBSD9?=	yes
BASEFILE?=	${BASE}/base.txz
KERNELFILE?=	${BASE}/kernel.txz
.else
BASEFILE?=	${BASE}/base/base.??
KERNELFILE?=	${BASE}/kernels/generic.??
.endif

.if defined(MAKEJOBS)
_MAKEJOBS=	-j${MAKEJOBS}
.endif

_ROOTDIR=	${WRKDIR}/mfs
_BOOTDIR=	${_ROOTDIR}/boot
.if !defined(NO_ROOTHACK)
_DESTDIR=	${_ROOTDIR}/rw
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
	WITHOUT_INFO=1 \
	WITHOUT_LPR=1 \
	WITHOUT_MAN=1 \
	WITHOUT_SENDMAIL=1 \
	WITHOUT_TESTS=1 \
	WITHOUT_LIB32=1

# Environment for custom install
INSTALLENV?= ${BUILDENV} \
	WITHOUT_TOOLCHAIN=1
.endif

# Environment for custom scripts
CUSTOMSCRIPTENV?= env \
	WRKDIR=${WRKDIR} \
	DESTDIR=${_DESTDIR} \
	DISTDIR=${_DISTDIR} \
	BASE=${BASE}

.if defined(FULLDIST)
NO_PRUNE=1
WITH_RESCUE=1
.endif

.PHONY: destdir extract prune build install packages packages-mini \
config customfiles customscripts genkeys boot compress roothack \
install-roothack prepare prepare-mini mfsroot fbsddist image iso tar gce mini \
all clean clean-roothack clean-pkgcache clean-skip-pkgcache

all: image

destdir: ${WRKDIR}/.destdir_done
${WRKDIR}/.destdir_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Make directory - ${_DESTDIR}"
	${_v}${MKDIR} -p ${_DESTDIR} && ${CHOWN} root:wheel ${_DESTDIR}
	@echo "Make directory - ${_BOOTDIR}"
	${_v}${MKDIR} -p ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && ${CHOWN} -R root:wheel ${_BOOTDIR}
	${_v}${TOUCH} ${WRKDIR}/.destdir_done
	@echo " done"

extract: destdir ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
	@echo "---------------------------------------------------- $(@F)"
.if !defined(CUSTOM)
	${_v}if [ ! -d "${BASE}" ]; then \
		echo "Please set the environment variable BASE to a path"; \
		echo "with FreeBSD distribution files (e.g. /cdrom/9.2-RELEASE)"; \
		echo "Examples:"; \
		echo "make BASE=/cdrom/9.2-RELEASE"; \
		echo "make BASE=/cdrom/usr/freebsd-dist"; \
		exit 1; \
	fi
.if !defined(FREEBSD9)
	${_v}for DIR in base kernels; do \
		if [ ! -d "${BASE}/$$DIR" ]; then \
			echo "Cannot find directory \"${BASE}/$$DIR\""; \
			exit 1; \
		fi \
	done
.endif
	@echo "Extracting base and kernel ..."
	${_v}${CAT} ${BASEFILE} | ${TAR} --unlink -xpzf - -C ${_DESTDIR}
.if !defined(FREEBSD9)
	${_v}${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_BOOTDIR}
	${_v}${MV} ${_BOOTDIR}/${KERNCONF}/* ${_BOOTDIR}/kernel
	${_v}${RMDIR} ${_BOOTDIR}/${KERNCONF}
.else
	${_v}${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_ROOTDIR}
.endif
.else
	@echo "Skip extracting base and kernel ..."
.endif
	${_v}${TOUCH} ${WRKDIR}/.extract_done
	@echo " done"

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
. if defined(BUILDWORLD)
	@echo "---------------------------------------------------- $(@F)"
	@echo "Building world ..."
	${_v}cd ${SRC_DIR} && \
	${BUILDENV} make ${_MAKEJOBS} buildworld TARGET=${TARGET}
. endif
. if defined(BUILDKERNEL)
	@echo "---------------------------------------------------- $(@F)"
	@echo "Building kernel KERNCONF=${KERNCONF} ..."
	${_v}cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET=${TARGET}
. endif
.else
	@echo "---------------------------------------------------- $(@F)"
	@echo "Skip building world and kernel."
.endif
	${_v}${TOUCH} ${WRKDIR}/.build_done
	@echo " done"

install: destdir build ${WRKDIR}/.install_done prune
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing world and kernel KERNCONF=${KERNCONF} ..."
	${_v}cd ${SRC_DIR} && \
	${INSTALLENV} make installworld distribution DESTDIR="${_DESTDIR}" TARGET=${TARGET} && \
	${INSTALLENV} make installkernel KERNCONF=${KERNCONF} DESTDIR="${_ROOTDIR}" TARGET=${TARGET}
.else
	@echo "---------------------------------------------------- $(@F)"
	@echo "Skip installing world and kernel."
.endif
.if defined(SE)
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@echo "---------------------------------------------------- $(@F)"
	@echo "Copying base.txz and kernel.txz ..."
. else
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating base.txz and kernel.txz ..."
. endif
	${_v}${MKDIR} -p ${_DISTDIR}
. if !defined(NO_ROOTHACK)
	${_v}${CP} -rp ${_BOOTDIR}/${KERNDIR} ${_DESTDIR}/boot
.  if "${KERNDIR}" != "kernel"
	${_v}${MV} -f ${_DESTDIR}/boot/${KERNDIR} ${_DESTDIR}/boot/kernel
.  endif
. endif
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	${_v}${CP} ${BASE}/base.txz ${_DISTDIR}/base.txz
	${_v}${CP} ${BASE}/kernel.txz ${_DISTDIR}/kernel.txz
. else
	${_v}${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} --exclude "boot/${KERNDIR}/*" -f ${_DISTDIR}/base.txz .
	${_v}${TAR} -c -C ${_DESTDIR} -J ${EXCLUDE} -f ${_DISTDIR}/kernel.txz boot/kernel
. endif
	@echo " done"
. if !defined(NO_ROOTHACK)
	${_v}${RM} -rf ${_DESTDIR}/boot/${KERNDIR}
. endif
.endif
	${_v}${CHFLAGS} -R noschg ${_DESTDIR} > /dev/null 2> /dev/null || exit 0
.if !defined(WITHOUT_RESCUE) && defined(RESCUE_LINKS)
	${_v}cd ${_DESTDIR} && \
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
	${_v}cd ${_DESTDIR} && ${RM} -rf rescue
.endif
	${_v}${TOUCH} ${WRKDIR}/.install_done
	@echo " done"

prune: ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
.if !defined(NO_PRUNE)
	@echo "---------------------------------------------------- $(@F)"
	${_v}if [ -d "${_DESTDIR}" ]; then \
		echo "Removing selected files from distribution ..."; \
		if [ -f "${PRUNELIST}" ]; then \
			for FILE in `${CAT} ${PRUNELIST}`; do \
				if [ -n "$${FILE}" ]; then \
					${RM} -rf ${_DESTDIR}/$${FILE}; \
				fi; \
			done; \
		fi; \
	else \
		echo "Skip removing selected files from distribution ..."; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"
.endif

packages: install ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
	@echo "---------------------------------------------------- $(@F)"
.  if !exists(${PKG_STATIC})
	@echo "pkg-static not found at: ${PKG_STATIC}"
	${_v}exit 1
.  endif
	${_v}if [ ! -f "${_DESTDIR}/usr/local/sbin/pkg" ]; then \
		echo "Installing pkgng ..." ; \
		${MKDIR} -p ${_DESTDIR}/usr/local/sbin ; \
		${INSTALL} -o root -g wheel -m 0755 ${PKG_STATIC} ${_DESTDIR}/usr/local/sbin/ ; \
		${LN} -sf ${_DESTDIR}/usr/local/sbin/pkg-static ${_DESTDIR}/usr/local/sbin/pkg ; \
	fi
	@echo "Installing user packages ..."
	${_v}if [ -f "${TOOLSDIR}/packages" ]; then \
		_PKGS="${TOOLSDIR}/packages"; \
		elif [ -f "${TOOLSDIR}/packages.sample" ]; then \
		_PKGS="${TOOLSDIR}/packages.sample"; \
	fi;
	${_v}if [ -n "$${_PKGS}" ]; then \
		env ASSUME_ALWAYS_YES=yes \
		PKG_ABI="${PKG_ABI}" \
		PKG_CACHEDIR=${WRKDIR}/pkgcache \
		${PKG} -r ${_DESTDIR} install `${CAT} $${_PKGS}`; \
	fi;
	${_v}${TOUCH} ${WRKDIR}/.packages_done
	@echo " done"

packages-mini: install ${WRKDIR}/.packages_mini_done
${WRKDIR}/.packages_mini_done:
	@echo "---------------------------------------------------- $(@F)"
.  if !exists(${PKG_STATIC})
	@echo "pkg-static not found at: ${PKG_STATIC}"
	${_v}exit 1
.  endif
	${_v}if [ ! -f "${_DESTDIR}/usr/local/sbin/pkg" ]; then \
		echo "Installing pkgng ..." ; \
		${MKDIR} -p ${_DESTDIR}/usr/local/sbin ; \
		${INSTALL} -o root -g wheel -m 0755 ${PKG_STATIC} ${_DESTDIR}/usr/local/sbin/ ; \
		${LN} -sf ${_DESTDIR}/usr/local/sbin/pkg-static ${_DESTDIR}/usr/local/sbin/pkg ;\
	fi
	@echo "Installing additional mini packages ..."
	${_v}if [ -f "${TOOLSDIR}/packages-mini" ]; then \
		_PKGS="${TOOLSDIR}/packages-mini"; \
		elif [ -f "${TOOLSDIR}/packages-mini.sample" ]; then \
		_PKGS="${TOOLSDIR}/packages-mini.sample"; \
	fi;
	${_v}if [ -n "$${_PKGS}" ]; then \
		env ASSUME_ALWAYS_YES=yes \
		PKG_ABI="${PKG_ABI}" \
		PKG_CACHEDIR=${WRKDIR}/pkgcache \
		${PKG} -r ${_DESTDIR} install `${CAT} $${_PKGS}`; \
	fi;
	@echo "Check installing pkgng and user packages ."
	${_v}if [ ! -f "${WRKDIR}/.packages_done" ]; then \
		echo "Skip installing pkgng and user packages ." ; \
		${TOUCH} ${WRKDIR}/.packages_done ; \
	fi;
	${_v}${TOUCH} ${WRKDIR}/.packages_mini_done
	@echo " done"

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing configuration scripts and files ..."
.for FILE in boot.config loader.conf rc.conf rc.local resolv.conf interfaces.conf ttys login.access
. if !exists(${CFGDIR}/${FILE}) && !exists(${CFGDIR}/${FILE}.sample)
	@echo "Missing ${CFGDIR}/${FILE}.sample" && exit 1
. endif
.endfor
.if defined(SE)
	${_v}${INSTALL} -m 0644 ${TOOLSDIR}/motd.se ${_DESTDIR}/etc/motd
	${_v}${INSTALL} -d -m 0755 ${_DESTDIR}/cdrom
.else
	${_v}${INSTALL} -m 0644 ${TOOLSDIR}/motd ${_DESTDIR}/etc/motd
.endif
	${_v}${MKDIR} -p ${_DESTDIR}/stand ${_DESTDIR}/etc/rc.conf.d
	${_v}if [ -f "${CFGDIR}/boot.config" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/boot.config ${_DESTDIR}/boot.config; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/boot.config.sample ${_DESTDIR}/boot.config; \
	fi
	${_v}if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${_BOOTDIR}/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${_BOOTDIR}/loader.conf; \
	fi
	${_v}if [ -f "${CFGDIR}/rc.local" ]; then \
		${INSTALL} -m 0744 ${CFGDIR}/rc.local ${_DESTDIR}/etc/rc.local; \
	else \
		${INSTALL} -m 0744 ${CFGDIR}/rc.local.sample ${_DESTDIR}/etc/rc.local; \
	fi
.for FILE in rc.conf ttys login.access
	${_v}if [ -f "${CFGDIR}/${FILE}" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE} ${_DESTDIR}/etc/${FILE}; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/${FILE}.sample ${_DESTDIR}/etc/${FILE}; \
	fi
.endfor
.if !defined(NO_ROOTHACK)
	@echo 'root_rw_mount="NO"' >> ${_DESTDIR}/etc/rc.conf
.endif
	${_v}if [ -f "${CFGDIR}/resolv.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/resolv.conf ${_DESTDIR}/etc/resolv.conf; \
	fi
	${_v}if [ -f "${CFGDIR}/interfaces.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/interfaces.conf ${_DESTDIR}/etc/rc.conf.d/interfaces; \
	fi
	${_v}if [ -f "${CFGDIR}/authorized_keys" ]; then \
		${INSTALL} -d -m 0700 ${_DESTDIR}/root/.ssh; \
		${INSTALL} ${CFGDIR}/authorized_keys ${_DESTDIR}/root/.ssh/; \
	fi
	${_v}${MKDIR} -p ${_DESTDIR}/root/bin
	${_v}${INSTALL} ${TOOLSDIR}/zfsinstall ${_DESTDIR}/root/bin
	${_v}${INSTALL} ${TOOLSDIR}/destroygeom ${_DESTDIR}/root/bin
	${_v}for SCRIPT in ${SCRIPTS}; do \
		${INSTALL} -m 0555 ${SCRIPTSDIR}/$${SCRIPT} ${_DESTDIR}/etc/rc.d/; \
	done
#	${_v}${SED} -I -E 's/\(ttyv[2-7].*\)on /\1off/g' ${_DESTDIR}/etc/ttys
.if defined(NO_ROOTHACK)
	${_v}echo "/dev/md0 / ufs rw 0 0" > ${_DESTDIR}/etc/fstab
	${_v}echo "tmpfs /tmp tmpfs rw,mode=1777 0 0" >> ${_DESTDIR}/etc/fstab
.else
	${_v}${TOUCH} ${_DESTDIR}/etc/fstab
.endif
	@echo "Add user accounts ..."
.if defined(ROOTPW)
	${_v}echo '${ROOTPW}' | ${OPENSSL} passwd -6 -stdin -salt ${SALT} | ${PW} -V ${_DESTDIR}/etc usermod root -H 0
.elif !empty(ROOTPW_HASH)
	${_v}echo '${ROOTPW_HASH}' | ${PW} -V ${_DESTDIR}/etc usermod root -H 0
.endif
	${_v}echo PasswordAuthentication yes >> ${_DESTDIR}/etc/ssh/sshd_config
	${_v}echo PubkeyAuthentication yes >> ${_DESTDIR}/etc/ssh/sshd_config
#	${_v}echo ChallengeResponseAuthentication no >> ${_DESTDIR}/etc/ssh/sshd_config
#	${_v}echo UsePAM no >> ${_DESTDIR}/etc/ssh/sshd_config
	${_v}echo PermitEmptyPasswords no >> ${_DESTDIR}/etc/ssh/sshd_config
	${_v}echo PermitRootLogin yes >> ${_DESTDIR}/etc/ssh/sshd_config
.if exists(${CFGDIR}/hosts)
	${_v}${INSTALL} -m 0644 ${CFGDIR}/hosts ${_DESTDIR}/etc/hosts
.elif exists(${CFGDIR}/hosts.sample)
	${_v}${INSTALL} -m 0644 ${CFGDIR}/hosts.sample ${_DESTDIR}/etc/hosts
.else
	@echo "Missing ${CFGDIR}/hosts.sample" && exit 1
.endif
	${_v}${TOUCH} ${WRKDIR}/.config_done
	@echo " done"

genkeys: config ${WRKDIR}/.genkeys_done
${WRKDIR}/.genkeys_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Generating SSH host keys ..."
	${_v}test -f ${_DESTDIR}/etc/ssh/ssh_host_key || ${SSHKEYGEN} -t rsa1 -b 1024 -f ${_DESTDIR}/etc/ssh/ssh_host_key -N '' > /dev/null 2> /dev/null || true
	${_v}test -f ${_DESTDIR}/etc/ssh/ssh_host_dsa_key || ${SSHKEYGEN} -t dsa -f ${_DESTDIR}/etc/ssh/ssh_host_dsa_key -N '' > /dev/null 2> /dev/null || true
	${_v}test -f ${_DESTDIR}/etc/ssh/ssh_host_rsa_key || ${SSHKEYGEN} -t rsa -f ${_DESTDIR}/etc/ssh/ssh_host_rsa_key -N '' > /dev/null
	${_v}test -f ${_DESTDIR}/etc/ssh/ssh_host_ecdsa_key || ${SSHKEYGEN} -t ecdsa -f ${_DESTDIR}/etc/ssh/ssh_host_ecdsa_key -N '' > /dev/null
	${_v}test -f ${_DESTDIR}/etc/ssh/ssh_host_ed25519_key || ${SSHKEYGEN} -t ed25519 -f ${_DESTDIR}/etc/ssh/ssh_host_ed25519_key -N '' > /dev/null
	${_v}${TOUCH} ${WRKDIR}/.genkeys_done
	@echo " done"

customfiles: config ${WRKDIR}/.customfiles_done
${WRKDIR}/.customfiles_done:
.if exists(${CUSTOMFILESDIR})
	@echo "---------------------------------------------------- $(@F)"
	@echo "Copying user files ..."
	${_v}${CP} -afv ${CUSTOMFILESDIR}/ ${_DESTDIR}/
	${_v}${TOUCH} ${WRKDIR}/.customfiles_done
	@echo " done"
.endif

customscripts: config ${WRKDIR}/.customscripts_done
${WRKDIR}/.customscripts_done:
.if exists(${CUSTOMSCRIPTSDIR})
	@echo "---------------------------------------------------- $(@F)"
	@echo "Running user scripts ..."
	@for SCRIPT in `find ${CUSTOMSCRIPTSDIR} -type f`; do \
		chmod +x $$SCRIPT; \
		${CUSTOMSCRIPTENV} $$SCRIPT; \
	done
	${_v}${TOUCH} ${WRKDIR}/.customscripts_done
	@echo " done"
.endif

compress: packages packages-mini genkeys customfiles customscripts boot ${WRKDIR}/.compress_done
${WRKDIR}/.compress_done:
.if defined(NO_ROOTHACK)
	@echo "---------------------------------------------------- $(@F)"
	@echo "Compressing usr FS ..."
	${_v}${TAR} -c -J -C ${_DESTDIR} -f ${_DESTDIR}/.usr.tar.xz usr
	$(_v}${CHFLAGS} -R noschg ${_DESTDIR}/usr || exit 1
	${_v}${RM} -rf ${_DESTDIR}/usr && ${MKDIR} -p ${_DESTDIR}/usr
.else
	@echo "---------------------------------------------------- $(@F)"
	@echo "Compressing root FS ..."
	${_v}${TAR} -c -C ${_ROOTDIR} -f - rw | \
	${XZ} ${XZ_FLAGS} -v -c > ${_ROOTDIR}/root.txz
	${_v}${CHFLAGS} -R noschg ${_DESTDIR} || exit 1
	${_v}${RM} -rf ${_DESTDIR} && ${MKDIR} -p ${_DESTDIR}
.endif
	${_v}${TOUCH} ${WRKDIR}/.compress_done
	@echo " done"

roothack: ${WRKDIR}/.roothack_done
${WRKDIR}/.roothack_done:
	@echo "---------------------------------------------------- $(@F)"
.if !defined(ROOTHACK_PREBUILT)
	@echo "Make roothack ..."
	${_v}${MKDIR} -p ${WRKDIR}/roothack
	${_v}cd ${TOOLSDIR}/roothack && env MAKEOBJDIR=${WRKDIR}/roothack make
.else
	@echo "Skip make roothack ..."
.endif
	${_v}${TOUCH} ${WRKDIR}/.roothack_done
	@echo " done"

install-roothack: roothack ${WRKDIR}/.install-roothack_done
${WRKDIR}/.install-roothack_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Installing roothack ..."
	${_v}${MKDIR} -p ${_ROOTDIR}/dev ${_ROOTDIR}/sbin
	${_v}${INSTALL} -m 555 ${ROOTHACK_FILE} ${_ROOTDIR}/sbin/init
	${_v}${TOUCH} ${WRKDIR}/.install-roothack_done
	@echo " done"

boot: config ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Configuring boot environment ..."
	${_v}${MKDIR} -p ${WRKDIR}/disk/boot/kernel
	${_v}${CHOWN} root:wheel ${WRKDIR}/disk
	${_v}${TAR} -c -X ${KERN_EXCLUDE} -C ${_BOOTDIR}/${KERNDIR} -f - . | ${TAR} -xv -C ${WRKDIR}/disk/boot/kernel -f -
	${_v}${CP} -rp ${_DESTDIR}/boot.config ${WRKDIR}/disk
.for FILE in ${BOOTFILES}
	${_v}${CP} -rp ${_DESTDIR}/boot/${FILE} ${WRKDIR}/disk/boot
.endfor
.if defined(LOADER_4TH)
	${_v}${MV} -f ${WRKDIR}/disk/boot/loader_4th ${WRKDIR}/disk/boot/loader
.else
	${_v}${MV} -f ${WRKDIR}/disk/boot/loader_lua ${WRKDIR}/disk/boot/loader
.endif
	${_v}${RM} -rf ${WRKDIR}/disk/boot/kernel/*.ko ${WRKDIR}/disk/boot/kernel/*.symbols
.if defined(DEBUG)
	${_v}-${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/kernel.symbols ${WRKDIR}/disk/boot/kernel
.endif
	# Install modules need to boot into the kernel directory
	${_v}${FIND} ${_BOOTDIR}/${KERNDIR} -name 'acpi*.ko' -exec ${INSTALL} -m 0555 {} ${WRKDIR}/disk/boot/kernel \;
	${_v}${FIND} ${_BOOTDIR}/${KERNDIR} -name 'daemon_saver.ko' -exec ${INSTALL} -m 0555 {} ${WRKDIR}/disk/boot/kernel \;
	${_v}${FIND} ${_BOOTDIR}/${KERNDIR} -name 'geom_mirror.ko' -exec ${INSTALL} -m 0555 {} ${WRKDIR}/disk/boot/kernel \;
.for FILE in ${BOOTMODULES}
	${_v}[ ! -f ${_BOOTDIR}/${KERNDIR}/${FILE}.ko ] || \
		${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko ${WRKDIR}/disk/boot/kernel
. if defined(DEBUG)
	${_v}[ ! -f ${_BOOTDIR}/${KERNDIR}/${FILE}.ko.symbols ] || \
		${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko.symbols ${WRKDIR}/disk/boot/kernel
. endif
.endfor
	${_v}${MKDIR} -p ${_DESTDIR}/boot/modules
.for FILE in ${MFSMODULES}
	${_v}[ ! -f ${_BOOTDIR}/${KERNDIR}/${FILE}.ko ] || \
		${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko ${_DESTDIR}/boot/modules
. if defined(DEBUG)
	${_v}[ ! -f ${_BOOTDIR}/${KERNDIR}/${FILE}.ko.symbols ] || \
		${INSTALL} -m 0555 ${_BOOTDIR}/${KERNDIR}/${FILE}.ko.symbols ${_DESTDIR}/boot/modules
. endif
.endfor
.if !defined(NO_ROOTHACK)
	${_v}${MKDIR} -p ${_ROOTDIR}/boot/modules
	${_v}${INSTALL} -m 0666 ${_BOOTDIR}/${KERNDIR}/tmpfs.ko ${_ROOTDIR}/boot/modules
.endif
	${_v}${RM} -rf ${_BOOTDIR}/${KERNDIR} ${_BOOTDIR}/*.symbols
	${_v}${MKDIR} -p ${WRKDIR}/boot
	${_v}${CP} -p ${_DESTDIR}/boot/pmbr ${_DESTDIR}/boot/gptboot ${WRKDIR}/boot
	${_v}${TOUCH} ${WRKDIR}/.boot_done
	@echo " done"

.if !defined(NO_ROOTHACK)
mfsroot: compress install-roothack ${WRKDIR}/.mfsroot_done
.else
mfsroot: compress ${WRKDIR}/.mfsroot_done
.endif
${WRKDIR}/.mfsroot_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating and compressing mfsroot ..."
	${_v}${MKDIR} -p ${WRKDIR}/mnt
	${_v}${MAKEFS} -t ffs -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} \
		  -S ${MFSROOT_SECTOR_SIZE} -b ${MFSROOT_FREE_BLOCKS} \
		  ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt
	${_v}${GZIP} -9 -f ${WRKDIR}/disk/mfsroot
	${_v}${GZIP} -9 -f ${WRKDIR}/disk/boot/kernel/kernel
	${_v}if [ -f "${CFGDIR}/loader.conf" ]; then \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf ${WRKDIR}/disk/boot/loader.conf; \
	else \
		${INSTALL} -m 0644 ${CFGDIR}/loader.conf.sample ${WRKDIR}/disk/boot/loader.conf; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.mfsroot_done
	@echo " done"

fbsddist: mfsroot ${WRKDIR}/.fbsddist_done
${WRKDIR}/.fbsddist_done:
.if defined(SE)
	@echo "---------------------------------------------------- $(@F)"
	@echo "Copying FreeBSD installation image ..."
	${_v}${CP} -rf ${_DISTDIR} ${WRKDIR}/disk/
	@echo " done"
.else
	@echo "---------------------------------------------------- $(@F)"
	@echo "Skip copying FreeBSD installation image ..."
.endif
	${_v}${TOUCH} ${WRKDIR}/.fbsddist_done
	@echo " done"

image: fbsddist ${WRKDIR}/.image_done
${WRKDIR}/.image_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating image file - ${IMAGE} ..."
	${_v}if [ -f ${.CURDIR}/${IMAGE} ]; then \
		${RM} ${.CURDIR}/${IMAGE} ; \
	fi
.if defined(BSDPART)
	${_v}${MKDIR} -p ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	${_v}${INSTALL} -d -D${WRKDIR}/trees/base/boot ${WRKDIR}/disk/boot
	@echo "\"DOFS DISKLABEL MACHINE FSIMG RD MNT FSSIZE FSPROTO FSINODE FSLABEL\""
	${_v}${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
.else
	@echo "\"DO_GPT FSIMG FSPROTO FSSIZE BOOTDIR VERBOSE\""
	${_v}${DO_GPT} ${WRKDIR}/disk.img ${WRKDIR}/disk 0 ${WRKDIR}/boot ${VERB}
.endif
	${_v}${MV} ${WRKDIR}/disk.img ${.CURDIR}/${IMAGE}
	${_v}${LS} -l ${.CURDIR}/${IMAGE}
	${_v}${TOUCH} ${WRKDIR}/.image_done
	@echo " done"

gce: fbsddist image ${WRKDIR}/.gce_done
${WRKDIR}/.gce_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating GCE-compatible tarball - ${GCEFILE} ..."
	${_v}if [ -f ${.CURDIR}/${GCEFILE} ]; then \
		${RM} ${.CURDIR}/${GCEFILE} ; \
	fi
.if !exists(${GTAR})
	${_v}echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	${_v}${GTAR} -C ${.CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	${_v}${LS} -l ${.CURDIR}/${GCEFILE}
	${_v}${TOUCH} ${WRKDIR}/.gce_done
	@echo " done"
.endif

iso: fbsddist ${WRKDIR}/.iso_done
${WRKDIR}/.iso_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating ISO image - ${ISOIMAGE} ..."
	${_v}if [ -f ${.CURDIR}/${ISOIMAGE} ]; then \
		${RM} ${.CURDIR}/${ISOIMAGE} ; \
	fi
.if defined(USE_MKISOFS)
. if !exists(${MKISOFS})
	@echo "${MKISOFS} is missing, please install sysutils/cdrtools first"; exit 1
. else
	${_v}${MKISOFS} ${VERBOSE} -b boot/cdboot -no-emul-boot -r -J -V mfsBSD -o ${.CURDIR}/${ISOIMAGE} ${WRKDIR}/disk
. endif
.else
	${_v}${MAKEFS} -t cd9660 -o rockridge,bootimage=i386\;/boot/cdboot,no-emul-boot,label=mfsBSD ${.CURDIR}/${ISOIMAGE} ${WRKDIR}/disk
.endif
	${_v}${LS} -l ${.CURDIR}/${ISOIMAGE}
	${_v}${TOUCH} ${WRKDIR}/.iso_done
	@echo " done"

tar: fbsddist ${WRKDIR}/.tar_done
${WRKDIR}/.tar_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating tar file - ${TARFILE} ..."
	${_v}if [ -f ${.CURDIR}/${TARFILE} ]; then \
		${RM} ${.CURDIR}/${TARFILE} ; \
	fi
	${_v}cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${.CURDIR}/${TARFILE} {} \;
	${_v}${LS} -l ${.CURDIR}/${TARFILE}
	${_v}${TOUCH} ${WRKDIR}/.tar_done
	@echo " done"

prepare: packages packages-mini genkeys customfiles customscripts boot
prepare-mini: packages-mini genkeys customfiles customscripts boot

mini: prepare-mini ${WRKDIR}/.mini_done
${WRKDIR}/.mini_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo "Creating mfsBSD-mini: ${MINITYPE} ..."
	${_v}(cd ${.CURDIR}/mini && $(MAKE) clean && $(MAKE) ${MINITYPE})
	@echo "------------------------------------------- continue $(@F)"
	${_v}${TOUCH} ${WRKDIR}/.mini_done
	@echo " done"

clean-roothack:
	${_v}${RM} -rf ${WRKDIR}/roothack

clean-pkgcache:
	${_v}${RM} -rf ${WRKDIR}/cache

clean:
	${_v}if [ -d ${WRKDIR} ]; then \
		${CHFLAGS} -R noschg ${WRKDIR} && \
		cd ${WRKDIR} && \
		${RM} -rf mfs mnt disk dist trees .*_done; \
	fi

clean-skip-pkgcache: clean clean-roothack
clean-all: clean clean-roothack clean-pkgcache ${WRKDIR}/.clean-all_done
${WRKDIR}/.clean-all_done:
	@echo "---------------------------------------------------- $(@F)"
	@echo " done"
