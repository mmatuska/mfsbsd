#!/bin/sh
#
# bhyve.sh
#

#set -x

usage() {
        printf "Install: $0 -I [-F] -n vmname [-c numcpu] [-m ramsize] [-s disksize] \n\t\t[-i extnic] [-t tap] [-z zpool] [-f isopath]\n" 1>&2
        printf "Example: $0 -n ubuntu0 -c 2 -m 1024M -s 16G -i em0 -t tap0 -z zones \n\t\t-f ubuntu-16.04.3-server-amd64.iso\n" 1>&2
        printf "Run: $0 -R -n vmname [-c numcpu] [-m ramsize] [-s disksize] \n\t\t[-i extnic] [-t tap] [-z zpool] [-f isopath]\n" 1>&2
        printf "Example: $0 -R -n ubuntu0 -c 2 -m 1024M -s 16G -i em0 -t tap0 -z zones\n" 1>&2
        printf "Console: $0 -C -n vmname\n" 1>&2
        printf "Example: $0 -C -n ubuntu0 \n" 1>&2
        printf "Kill: $0 -K -n vmname\n" 1>&2
        printf "Example: $0 -K -n ubuntu0 \n" 1>&2
}

ask() {
	while true; do
		read -p "Is this correct?" yn
		case $yn in
			[Yy]* ) break;;
			[Nn]* ) exit;;
			* ) echo "Please answer yes or no.";;
		esac
	done
}


plan() {
        printf "Bhyve Plan:\n"
	printf "Virtual Machine\n"
	echo "---------------"
	printf "name:\t%s\n" $VM_NAME
	printf "# CPU:\t%s\n" $VM_NUM_CPU
	printf "Memory:\t%s\n" $VM_MEM
	printf "Disk: \t%s\n" $VM_DISK_SIZE

	printf "\nNetworking\n"
	echo "----------"
	printf "External NIC: \t%s\n" $IFNET
	printf "Bridge: \t%s\n" $BRIDGE
	printf "Tap: \t\t%s\n" $TAP

	printf "\nResources\n"
	echo "---------"
	printf "zvol: \t%s\n" "${POOL_NAME}/${VM_NAME}"
	printf "iso: \t%s\n" "${ISO_PATH}/${ISO_NAME}"
	printf "com1: \t%s\n" $SERIAL_CONSOLE1
	printf "com2: \t%s\n" $SERIAL_CONSOLE2
	printf "\n"

	ask
}

####################  Variables  ###############################################
### Defaults
# Flags
FORCE=0 # Force means do not ask if my plan is correct -- should be completely
	# non-interactive script
INSTALL=0 # When true, create networking infrastructure, storage (zvol), and boot from iso
RUN=0 # When true, boot image from disk
CONSOLE=0 # When true, attach to console
KILL=0 # When true, kill VM at end of script

# VM Configuration
VM_NAME=
VM_MEM="1024M"
VM_NUM_CPU="1"
VM_DISK_SIZE="16G"

# VM Console
SERIAL_CONSOLE="/dev/nmdm"
COM_NUM1=0
COM_NUM2=$(($COM_NUM1 + 1))
SERIAL_CONSOLE1="${SERIAL_CONSOLE}${COM_NUM1}A"
SERIAL_CONSOLE2="${SERIAL_CONSOLE}${COM_NUM2}A"

# Networking
IFNET="em0"
BRIDGE="bridge0"
TAP="tap0"

# Disk
POOL_NAME="zroot"

# Install Image
ISO_URL="http://releases.ubuntu.com/16.04.3/ubuntu-16.04.3-server-amd64.iso"
ISO_NAME=$(basename ${ISO_URL})
ISO_PATH="./"

# Device Map
DEVICE_MAP="device.map"

if [ $# -eq 0 ]; then
        usage
        exit 2
fi

while getopts ":c:Cf:Fhi:IKm:n:Rs:u:z:" opt; do
        case $opt in
                c)
                        VM_CPU=$OPTARG
                        ;;
                C)
                        CONSOLE=1
                        ;;
                f)
                        ISO_PATH=$OPTARG
			;;
                F)
                        FORCE=1
			;;
                h)
                        usage
                        exit 1
                        ;;
                i)
                        IFNET=$OPTARG
                        ;;
		I)
			INSTALL=1
			;;
		K)
			KILL=1
			;;
                m)
                        VM_MEM=$OPTARG
                        ;;
                n)
                        VM_NAME=$OPTARG
                        ;;
                R)
                        RUN=1
                        ;;
                s)
                        VM_DISK_SIZE=$OPTARG
                        ;;
                t)
                        TAP=$OPTARG
                        ;;
                u)
                        COM_NUM1=$OPTARG
			COM_NUM2=$(($COM_NUM1 + 1))
			SERIAL_CONSOLE1="${SERIAL_CONSOLE}${COM_NUM1}A"
			SERIAL_CONSOLE2="${SERIAL_CONSOLE}${COM_NUM2}A"
                        ;;
                z)
                        POOL_NAME=$OPTARG
                        ;;
                \?)
                        usage
                        exit 1
                        ;;
                :)
                        echo "Invalid option: $OPTARG requires an argument" 1>&2
                        ;;
                *)
                        usage
                        exit 1
                        ;;
        esac
done
if [ $INSTALL == 1 || $RUN == 1 || $KILL == 1 ]; then
	printf "Invalid Input: Must set -I, -R or -K\n"
	exit 2
fi
if [ -z ${VM_NAME} ]; then
	printf "Invalid Input: Must set vm name\n"
	exit 2
fi
shift $(($OPTIND - 1))

################################################################################
if [ $FORCE != 1 || $KILL == 1 ]; then
	plan # Print plan for user and ask for confirmation
fi

################################################################################
if [ $INSTALL == 1 ]; then
	## Set up bridge
	ifconfig ${TAP} create
	sysctl net.link.tap.up_on_open=1
	ifconfig ${BRIDGE} create
	ifconfig ${BRIDGE} addm ${IFNET} addm ${TAP}
	ifconfig ${BRIDGE} up

	## Download Image
	if [ ! -f ${ISO_PATH}/${ISO_NAME} ]; then
		fetch -am ${ISO_URL}
	fi

	## Setup VM zvol
	zfs create -V${VM_DISK_SIZE} -o volmode=dev ${POOL_NAME}/${VM_NAME}

	## Write out device.map
	if [ ! -f ${VM_NAME}-${DEVICE_MAP} ]; then
		cat > ${VM_NAME}-${DEVICE_MAP} <<EOF
(hd0) ./${IMG_NAME}
(cd0) ${ISO_PATH}/${ISO_NAME}
EOF
	fi

	## Load Linux Kernel 
	# 	Note: We're assuming we're booting from an ISO,
	# 	change cd0 here and above to change that.
	grub-bhyve -m ${DEVICE_MAP} -r cd0 -M ${VM_MEM} ${VM_NAME}

	## Start bhyve for install
	# 	Serial Consoles
	# 	One can connect to these at /dev/nmdm{0,1}B
	# 	ex: `sudo cu -l /dev/nmdm0B`
	bhyve -A -H -P \
		-s 0:0,hostbridge \
		-s 1:0,lpc \
		-s 2:0,virtio-net,${TAP} \
		-s 3:0,virtio-blk,/dev/zvol/zroot/${VM_NAME} \
		-s 4:0,ahci-cd,${ISO_PATH}/${ISO_NAME} \
		-l com1,${SERIAL_CONSOLE1} \
		-l com2,${SERIAL_CONSOLE2} \
		-c ${VM_NUM_CPU} \
		-m ${VM_MEM} \
		${VM_NAME} &
fi

# Run VM from disk
if [ $RUN == 1 ]; then
	## Load Linux Kernel 
	# 	Note: We're assuming we're booting from an ISO,
	# 	change cd0 here and above to change that.
	grub-bhyve -m ${DEVICE_MAP} -r hd0,msdos1 -M ${VM_MEM} ${VM_NAME}

	## Start bhyve for install
	bhyve -A -H -P \
		-s 0:0,hostbridge \
		-s 1:0,lpc \
		-s 2:0,virtio-net,${TAP} \
		-s 3:0,virtio-blk,/dev/zvol/zroot/${VM_NAME} \
		-l com1,${SERIAL_CONSOLE1} \
		-l com2,${SERIAL_CONSOLE2} \
		-c ${VM_NUM_CPU} \
		-m ${VM_MEM} \
		${VM_NAME} &
fi

# Attach to first serial console
if [ $CONSOLE == 1 ]; then
	cu -l ${SERIAL_CONSOLE}${COM_NUM1}B
fi

# Kill VM named by -n VM
if [ $KILL == 1 ]; then
	# https://www.youtube.com/watch?v=wQMMYSS14yM
	bhyvectl --destroy --vm=${VM_NAME}
fi
