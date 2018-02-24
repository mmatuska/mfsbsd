#!/bin/sh
#
# bhyve.sh
#

#set -x

# Check if you're root
if [ "$(id -u)" != "0" ]; then
	echo "This script must be run as root" 1>&2
	exit 1
fi

# Load Modules
kldload vmm nmdm > /dev/null 2>&1 || true

usage() {
        printf "Install: $0 -I [-F] -n vmname [-c numcpu] [-m ramsize] [-s disksize] \n\t\t[-i extnic] [-z zpool] [-f isopath] [-u num console]\n" 1>&2
        printf "Example: $0 -n ubuntu0 -c 2 -m 1024M -s 16G -i em0 -z zones \n\t\t-f ubuntu-16.04.3-server-amd64.iso\n" 1>&2
        printf "Run: $0 -R -n vmname [-c numcpu] [-m ramsize] [-s disksize] \n\t\t[-i extnic] [-z zpool] [-f isopath]\n" 1>&2
        printf "Example: $0 -R -n ubuntu0 -c 2 -m 1024M -s 16G -i em0 -z zones\n" 1>&2
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
	#printf "Bridge: \t%s\n" $BRIDGE
	#printf "Tap: \t\t%s\n" $TAP

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
if [ "${INSTALL}" = 0 ] && [ "${RUN}" = 0 ] && [ "${KILL}" = 0 ]; then
	printf "Invalid Input: Must set -I, -R or -K\n"
	exit 2
fi
if [ -z "${VM_NAME}" ]; then
	printf "Invalid Input: Must set vm name\n"
	exit 2
fi
shift $(($OPTIND - 1))

################################################################################
if [ "${FORCE}" != 1 ] && [ "${KILL}" != 1 ]; then
	plan # Print plan for user and ask for confirmation
fi

################################################################################
if [ "${INSTALL}" = 1 ]; then
	## Download Image
	if [ ! -f "${ISO_PATH}/${ISO_NAME}" ]; then
		fetch -am "${ISO_URL}"
	fi

	## Setup VM zvol
	zfs create -p "-V${VM_DISK_SIZE}" -o volmode=dev "${POOL_NAME}/${VM_NAME}/disk0"

	## Write out device.map
	if [ ! -f "${VM_NAME}-${DEVICE_MAP}" ]; then
		cat > "/${POOL_NAME}/${VM_NAME}/${DEVICE_MAP}" <<EOF
(hd0) /dev/zvol/${POOL_NAME}/${VM_NAME}/disk0
(cd0) ${ISO_PATH}/${ISO_NAME}
EOF
	fi

	## Load Linux Kernel 
	grub-bhyve -S -m "/${POOL_NAME}/${VM_NAME}/${DEVICE_MAP}" -r cd0 -M "${VM_MEM}" "${VM_NAME}"

	## Start bhyve for install
	# 	Serial Consoles
	# 	One can connect to these at /dev/nmdm{0,1}B
	# 	ex: `sudo cu -l /dev/nmdm0B`
	IFNET_MAC=$(ifconfig ${IFNET} | grep ether | awk '{ print $2 }')
	bhyve -A -H -P -S \
		-s 0,hostbridge \
		-s 1,lpc \
		-s "2,kvirtio-net,${IFNET},mtu=1500,queues=4,intf=cc1,mac=${IFNET_MAC}" \
		-s "3,virtio-blk,/dev/zvol/${POOL_NAME}/${VM_NAME}/disk0" \
		-s "4,ahci-cd,${ISO_PATH}/${ISO_NAME}" \
		-l "com1,${SERIAL_CONSOLE1}" \
		-l "com2,${SERIAL_CONSOLE2}" \
		-c "${VM_NUM_CPU}" \
		-m "${VM_MEM}" \
		"${VM_NAME}" &
fi

# Run VM from disk
if [ $RUN = 1 ]; then
	## Load Linux Kernel 
	# 	Note: We're assuming we're booting from an ISO,
	# 	change cd0 here and above to change that.
#grub-bhyve -S -m /chyves/zones/guests/transcode/device.map -r hd0,msdos1 -c /dev/nmdm50A -M 1G chy-transcode && bhyve -A -H -P -S -c 16 -p 0:36 -p 1:37 -p 2:38 -p 3:39 -p 4:40 -p 5:41 -p 6:42 -p 7:43 -p 8:44 -p 9:45 -p 10:46 -p 11:47 -p 12:48 -p 13:49 -p 14:50 -p 15:51 -U c129e601-06e7-11e8-81e3-0cc47a17e9f8 -m 1G -s 0,hostbridge -s 4,ahci-hd,/dev/zvol/zones/chyves/guests/transcode/disk0 -s 5,virtio-net,tap50,mac=00:a0:98:49:fb:0b -s 6,kvirtio-net,mtu=1500,queues=4,intf=cc1,mac=00:07:43:40:5f:38 -l com1,/dev/nmdm50A -s 31,lpc chy-transcode	
	grub-bhyve -S -m "/${POOL_NAME}/${VM_NAME}/${DEVICE_MAP}" -r hd0,msdos1 -c "${SERIAL_CONSOLE1}" -M "${VM_MEM}" "${VM_NAME}"

	## Start bhyve for install
	IFNET_MAC=$(ifconfig ${IFNET} | grep ether | awk '{ print $2 }')
	bhyve -A -H -P -S \
		-s 0,hostbridge \
		-s 1,lpc \
		-s "2,kvirtio-net,${IFNET},mtu=1500,queues=4,intf=cc1,mac=${IFNET_MAC}" \
		-s "3,virtio-blk,/dev/zvol/${POOL_NAME}/${VM_NAME}/disk0" \
		-l "com1,${SERIAL_CONSOLE1}" \
		-l "com2,${SERIAL_CONSOLE2}" \
		-c "${VM_NUM_CPU}" \
		-m "${VM_MEM}" \
		"${VM_NAME}" &
fi

# Attach to first serial console
if [ $CONSOLE = 1 ]; then
	cu -l "${SERIAL_CONSOLE}${COM_NUM1}B"
fi

# Kill VM named by -n VM
if [ $KILL = 1 ]; then
	# https://www.youtube.com/watch?v=wQMMYSS14yM
	bhyvectl --destroy --vm="${VM_NAME}"
fi

