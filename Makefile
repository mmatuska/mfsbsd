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
ROOTPW_HASH?=		$$6$$051DdQA7fTvLymkY$$Z5f6snVFQJKugWmGi8y0motBNaKn9em0y2K0ZsJMku3v9gkiYh8M.OTIIie3RvHpzT6udumtZUtc0kXwJcCMR1

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
MKDIR?=		/bin/mkdir -p
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
SCRIPTS?=	mdinit mfsbsd interfaces packages
BOOTMODULES?=	acpi ahci
.if defined(LOADER_4TH)
BOOTFILES?=	defaults device.hints loader_4th *.rc *.4th
EFILOADER?=	loader_4th.efi
.else
BOOTFILES?=	defaults device.hints loader_lua lua
EFILOADER?=	loader_lua.efi
.endif
MFSMODULES?=	aesni crypto cryptodev ext2fs geom_eli geom_mirror geom_nop \
		ipmi ntfs nullfs opensolaris smbus snp tmpfs zfs
# Sometimes the kernel is compiled with a different destination.
KERNDIR?=	kernel
#
XZ_FLAGS?=
#

.if defined(V)
_v=
VERB=1
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

.if !defined(DEBUG)
EXCLUDE=	--exclude *.symbols
.else
EXCLUDE=
.endif

# Roothack stuff
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

all: image

destdir: ${_DESTDIR} ${_BOOTDIR}
${_DESTDIR}:
	${_v}${MKDIR} ${_DESTDIR} && ${CHOWN} root:wheel ${_DESTDIR}

${_BOOTDIR}:
	${_v}${MKDIR} ${_BOOTDIR}/kernel ${_BOOTDIR}/modules && ${CHOWN} -R root:wheel ${_BOOTDIR}

extract: destdir ${WRKDIR}/.extract_done
${WRKDIR}/.extract_done:
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
	@echo -n "Extracting base and kernel ..."
	${_v}${CAT} ${BASEFILE} | ${TAR} --unlink -xpzf - -C ${_DESTDIR}
.if !defined(FREEBSD9)
	${_v}${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_BOOTDIR}
	${_v}${MV} ${_BOOTDIR}/${KERNCONF}/* ${_BOOTDIR}/kernel
	${_v}${RMDIR} ${_BOOTDIR}/${KERNCONF}
.else
	${_v}${CAT} ${KERNELFILE} | ${TAR} --unlink -xpzf - -C ${_ROOTDIR}
.endif
	@echo " done"
.endif
	${_v}${TOUCH} ${WRKDIR}/.extract_done

build: extract ${WRKDIR}/.build_done
${WRKDIR}/.build_done:
.if defined(CUSTOM)
. if defined(BUILDWORLD)
	@echo -n "Building world ..."
	${_v}cd ${SRC_DIR} && \
	${BUILDENV} make ${_MAKEJOBS} buildworld TARGET=${TARGET}
. endif
. if defined(BUILDKERNEL)
	@echo -n "Building kernel KERNCONF=${KERNCONF} ..."
	${_v}cd ${SRC_DIR} && make buildkernel KERNCONF=${KERNCONF} TARGET=${TARGET}
. endif
.endif
	${_v}${TOUCH} ${WRKDIR}/.build_done

install: destdir build ${WRKDIR}/.install_done
${WRKDIR}/.install_done:
.if defined(CUSTOM)
	@echo -n "Installing world and kernel KERNCONF=${KERNCONF} ..."
	${_v}cd ${SRC_DIR} && \
	${INSTALLENV} make installworld distribution DESTDIR="${_DESTDIR}" TARGET=${TARGET} && \
	${INSTALLENV} make installkernel KERNCONF=${KERNCONF} DESTDIR="${_ROOTDIR}" TARGET=${TARGET}
.endif
.if defined(SE)
. if !defined(CUSTOM) && exists(${BASE}/base.txz) && exists(${BASE}/kernel.txz)
	@echo -n "Copying base.txz and kernel.txz ..."
. else
	@echo -n "Creating base.txz and kernel.txz ..."
. endif
	${_v}${MKDIR} ${_DISTDIR}
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

prune: install ${WRKDIR}/.prune_done
${WRKDIR}/.prune_done:
.if !defined(NO_PRUNE)
	@echo -n "Removing selected files from distribution ..."
	${_v}if [ -f "${PRUNELIST}" ]; then \
		for FILE in `${CAT} ${PRUNELIST}`; do \
			if [ -n "$${FILE}" ]; then \
				${RM} -rf ${_DESTDIR}/$${FILE}; \
			fi; \
		done; \
	fi
	${_v}${TOUCH} ${WRKDIR}/.prune_done
	@echo " done"
.endif

cdboot: install prune ${WRKDIR}/.cdboot_done
${WRKDIR}/.cdboot_done:
	@echo -n "Copying out cdboot and EFI loader ..."
	${_v}${MKDIR} ${WRKDIR}/cdboot
	${_v}${CP} ${_DESTDIR}/boot/cdboot ${WRKDIR}/cdboot/
	${_v}${CP} ${_DESTDIR}/boot/loader_4th.efi ${_DESTDIR}/boot/loader_lua.efi ${WRKDIR}/cdboot/
	${_v}${TOUCH} ${WRKDIR}/.cdboot_done
	@echo " done"

packages: install prune cdboot ${WRKDIR}/.packages_done
${WRKDIR}/.packages_done:
	@echo -n "Installing pkgng ..."
.  if !exists(${PKG_STATIC})
	@echo "pkg-static not found at: ${PKG_STATIC}"
	${_v}exit 1
.  endif
	${_v}mkdir -p ${_DESTDIR}/usr/local/sbin
	${_v}${INSTALL} -o root -g wheel -m 0755 ${PKG_STATIC} ${_DESTDIR}/usr/local/sbin/
	${_v}${LN} -sf pkg-static ${_DESTDIR}/usr/local/sbin/pkg
	@echo " done"
	@echo  "Installing user packages ..."
	${_v}if [ -f "${TOOLSDIR}/packages" ]; then \
		_PKGS="${TOOLSDIR}/packages"; \
		elif [ -f "${TOOLSDIR}/packages.sample" ]; then \
		_PKGS="${TOOLSDIR}/packages.sample"; \
		fi; \
		if [ -n "$${_PKGS}" ]; then \
		env ASSUME_ALWAYS_YES=yes \
		PKG_ABI="${PKG_ABI}" \
		PKG_CACHEDIR=${WRKDIR}/pkgcache \
		${PKG} -r ${_DESTDIR} install `${CAT} $${_PKGS}`; \
		fi;
	${_v}${TOUCH} ${WRKDIR}/.packages_done

packages-mini: packages ${WRKDIR}/.packages_mini_done
${WRKDIR}/.packages_mini_done:
	@echo  "Installing additional mini packages ..."
	${_v}if [ -f "${TOOLSDIR}/packages-mini" ]; then \
		_PKGS="${TOOLSDIR}/packages-mini"; \
		elif [ -f "${TOOLSDIR}/packages-mini.sample" ]; then \
		_PKGS="${TOOLSDIR}/packages-mini.sample"; \
		fi; \
		if [ -n "$${_PKGS}" ]; then \
		env ASSUME_ALWAYS_YES=yes \
		PKG_ABI="${PKG_ABI}" \
		PKG_CACHEDIR=${WRKDIR}/pkgcache \
		${PKG} -r ${_DESTDIR} install `${CAT} $${_PKGS}`; \
		fi;
	${_v}${TOUCH} ${WRKDIR}/.packages_mini_done

config: install ${WRKDIR}/.config_done
${WRKDIR}/.config_done:
	@echo -n "Installing configuration scripts and files ..."
.for FILE in boot.config loader.conf rc.conf rc.local resolv.conf interfaces.conf ttys
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
	${_v}${MKDIR} ${_DESTDIR}/stand ${_DESTDIR}/etc/rc.conf.d
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
.for FILE in rc.conf ttys
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
	${_v}${MKDIR} ${_DESTDIR}/root/bin
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
.if defined(ROOTPW)
	${_v}echo '${ROOTPW}'| ${OPENSSL} passwd -6 -stdin | ${PW} -V ${_DESTDIR}/etc usermod root -H 0
.elif !empty(ROOTPW_HASH)
	${_v}echo '${ROOTPW_HASH}'| ${PW} -V ${_DESTDIR}/etc usermod root -H 0
.endif
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
	@echo -n "Generating SSH host keys ..."
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
	@echo "Copying user files ..."
	${_v}${CP} -afv ${CUSTOMFILESDIR}/ ${_DESTDIR}/
	${_v}${TOUCH} ${WRKDIR}/.customfiles_done
	@echo " done"
.endif

customscripts: config ${WRKDIR}/.customscripts_done
${WRKDIR}/.customscripts_done:
.if exists(${CUSTOMSCRIPTSDIR})
	@echo -n "Running user scripts ..."
	@for SCRIPT in `find ${CUSTOMSCRIPTSDIR} -type f`; do \
		chmod +x $$SCRIPT; \
		${CUSTOMSCRIPTENV} $$SCRIPT; \
	done
	${_v}${TOUCH} ${WRKDIR}/.customscripts_done
	@echo " done"
.endif

compress-usr: install prune cdboot config genkeys customfiles customscripts boot efiboot packages ${WRKDIR}/.compress-usr_done
${WRKDIR}/.compress-usr_done:
.if defined(NO_ROOTHACK)
	@echo -n "Compressing usr ..."
	${_v}${TAR} -c -J -C ${_DESTDIR} -f ${_DESTDIR}/.usr.tar.xz usr 
	${_v}${RM} -rf ${_DESTDIR}/usr && ${MKDIR} ${_DESTDIR}/usr 
.else
	@echo -n "Compressing root ..."
	${_v}${TAR} -c -C ${_ROOTDIR} -f - rw | \
	${XZ} ${XZ_FLAGS} -v -c > ${_ROOTDIR}/root.txz
	${_v}${RM} -rf ${_DESTDIR} && ${MKDIR} ${_DESTDIR}
.endif
	${_v}${TOUCH} ${WRKDIR}/.compress-usr_done
	@echo " done"

roothack: ${WRKDIR}/roothack/roothack
${WRKDIR}/roothack/roothack:
.if !defined(ROOTHACK_PREBUILT)
	${_v}${MKDIR} -p ${WRKDIR}/roothack
	${_v}cd ${TOOLSDIR}/roothack && env MAKEOBJDIR=${WRKDIR}/roothack make
.endif

install-roothack: compress-usr roothack ${WRKDIR}/.install-roothack_done
${WRKDIR}/.install-roothack_done:
	@echo -n "Installing roothack ..."
	${_v}${MKDIR} -p ${_ROOTDIR}/dev ${_ROOTDIR}/sbin
	${_v}${INSTALL} -m 555 ${ROOTHACK_FILE} ${_ROOTDIR}/sbin/init
	${_v}${TOUCH} ${WRKDIR}/.install-roothack_done
	@echo " done"

boot: install prune cdboot ${WRKDIR}/.boot_done
${WRKDIR}/.boot_done:
	@echo -n "Configuring boot environment ..."
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

efiboot: install prune cdboot config genkeys customfiles customscripts boot ${WRKDIR}/.efiboot_done
${WRKDIR}/.efiboot_done:
.if !defined(NO_EFIBOOT)
	@echo -n "Creating EFI boot image ..."
	${_v}${MKDIR} -p ${WRKDIR}/efiroot/EFI/BOOT
	${_v}${CP} ${WRKDIR}/cdboot/${EFILOADER} ${WRKDIR}/efiroot/EFI/BOOT/BOOTX64.efi
	${_v}${MAKEFS} -t msdos -s 2048k -o fat_type=12,sectors_per_cluster=1 ${WRKDIR}/cdboot/efiboot.img ${WRKDIR}/efiroot
	${_v}${TOUCH} ${WRKDIR}/.efiboot_done
	@echo " done"
.endif

.if !defined(NO_ROOTHACK)
mfsroot: install prune cdboot config genkeys customfiles customscripts boot efiboot compress-usr packages install-roothack ${WRKDIR}/.mfsroot_done
.else
mfsroot: install prune cdboot config genkeys customfiles customscripts boot efiboot compress-usr packages ${WRKDIR}/.mfsroot_done
.endif
${WRKDIR}/.mfsroot_done:
	@echo -n "Creating and compressing mfsroot ..."
	${_v}${MKDIR} ${WRKDIR}/mnt
	${_v}${MAKEFS} -t ffs -m ${MFSROOT_MAXSIZE} -f ${MFSROOT_FREE_INODES} -b ${MFSROOT_FREE_BLOCKS} ${WRKDIR}/disk/mfsroot ${_ROOTDIR} > /dev/null
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

fbsddist: install prune cdboot config genkeys customfiles customscripts boot efiboot compress-usr packages mfsroot ${WRKDIR}/.fbsddist_done
${WRKDIR}/.fbsddist_done:
.if defined(SE)
	@echo -n "Copying FreeBSD installation image ..."
	${_v}${CP} -rf ${_DISTDIR} ${WRKDIR}/disk/
	@echo " done"
.endif
	${_v}${TOUCH} ${WRKDIR}/.fbsddist_done

image: install prune cdboot config genkeys customfiles customscripts boot efiboot compress-usr mfsroot fbsddist ${IMAGE}
${IMAGE}:
	@echo -n "Creating image file ..."
.if defined(BSDPART)
	${_v}${MKDIR} ${WRKDIR}/mnt ${WRKDIR}/trees/base/boot
	${_v}${INSTALL} -m 0444 ${WRKDIR}/disk/boot/boot ${WRKDIR}/trees/base/boot/
	${_v}${DOFS} ${BSDLABEL} "" ${WRKDIR}/disk.img ${WRKDIR} ${WRKDIR}/mnt 0 ${WRKDIR}/disk 80000 auto > /dev/null 2> /dev/null
	${_v}${RM} -rf ${WRKDIR}/mnt ${WRKDIR}/trees
	${_v}${MV} ${WRKDIR}/disk.img ${.TARGET}
.else
	${_v}${TOOLSDIR}/do_gpt.sh ${.TARGET} ${WRKDIR}/disk 0 ${WRKDIR}/boot ${WRKDIR}/cdboot/efiboot.img ${VERB}
.endif
	@echo " done"
	${_v}${LS} -l ${.TARGET}

gce: install prune cdboot config genkeys customfiles customscripts boot efiboot compress-usr mfsroot fbsddist ${IMAGE} ${GCEFILE}
${GCEFILE}:
	@echo -n "Creating GCE-compatible tarball..."
.if !exists(${GTAR})
	${_v}echo "${GTAR} is missing, please install archivers/gtar first"; exit 1
.else
	${_v}${GTAR} -C ${.CURDIR} -Szcf ${GCEFILE} --transform='s/${IMAGE}/disk.raw/' ${IMAGE}
	@echo " GCE tarball built"
	${_v}${LS} -l ${GCEFILE}
.endif

iso: install prune cdboot config genkeys customfiles customscripts boot efiboot compress-usr mfsroot fbsddist ${ISOIMAGE}
${ISOIMAGE}:
	@echo -n "Creating ISO image ..."
.if !defined(NO_EFIBOOT)
	${_v}${MAKEFS} -t cd9660 -o rockridge,label=mfsBSD \
	-o bootimage=i386\;${WRKDIR}/cdboot/cdboot,no-emul-boot \
	-o bootimage=i386\;${WRKDIR}/cdboot/efiboot.img,no-emul-boot,platformid=efi \
	${ISOIMAGE} ${WRKDIR}/disk
.else
	${_v}${MAKEFS} -t cd9660 -o rockridge,label=mfsBSD \
	-o bootimage=i386\;${WRKDIR}/cdboot/cdboot,no-emul-boot \
	${ISOIMAGE} ${WRKDIR}/disk
.endif
	@echo " done"
	${_v}${LS} -l ${ISOIMAGE}

tar: install prune cdboot config customfiles customscripts boot efiboot compress-usr mfsroot fbsddist ${TARFILE}
${TARFILE}:
	@echo -n "Creating tar file ..."
	${_v}cd ${WRKDIR}/disk && ${FIND} . -depth 1 \
		-exec ${TAR} -r -f ${.CURDIR}/${TARFILE} {} \;
	@echo " done"
	${_v}${LS} -l ${TARFILE}

prepare-mini: packages-mini config boot cdboot

clean-roothack:
	${_v}${RM} -rf ${WRKDIR}/roothack

clean-pkgcache:
	${_v}${RM} -rf ${WRKDIR}/pkgcache

clean:
	${_v}if [ -d ${WRKDIR} ]; then \
	${CHFLAGS} -R noschg ${WRKDIR} && \
	cd ${WRKDIR} && \
	${RM} -rf boot mfs mnt disk dist trees cdboot efiroot .*_done; \
	fi

clean-all: clean clean-roothack clean-pkgcache
