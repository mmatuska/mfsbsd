# bhyve.sh instructions
## Usage
For basic usage and all command line flags
```
bhyve.sh -h
```

bhyve.sh will ask you before creating or running to check if your parameters are correct.

## Killing the VM
Killing a VM uses the kill (-K) command.
If bhyve gets in a bad state or you just want to quickly/non-gracefully kill a vm
use: 
```
bhyve.sh -K -n <vm_name>
```

You can check if the vm is still using resources by running. This is also a good way
to figure out the name of a vm.

```
ls /dev/vmm
```

## Creating a VM
Creating a VM uses the install (-I) command.

This VM has:
Virtual Machine
---------------
name:	joe-test
# CPU:	15
Memory:	16G
Disk: 	20G

Networking
----------
External NIC: 	cc1

Resources
---------
zvol: 	zones/joe-test
iso: 	.//ubuntu-16.04.3-server-amd64.iso
com1: 	/dev/nmdm0A
com2: 	/dev/nmdm1A

```
sh bhyve.sh -I -n joe-test -c 16 -m 16G -s 20G -i cc1 -z zones
```

## Running a VM
Running a VM uses the run (-R) command.
Since VM configuration is not currently persisted, most configuration parameters must
be manually specified each time you run a virtual machine.

```
sh bhyve.sh -I -n joe-test -c 16 -m 16G -i cc1 -z zones
```

## Using the VM Console
Grabbing the VM console can be done with the console (-C) command.
You currently have to know which device number you ran your VM on. The default is 0 and 1.

```
bhyve.sh -C -u <dev number>
```


