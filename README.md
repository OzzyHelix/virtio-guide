# Ozzy's Guide to KVM/QEMU
#### Config files and Guide

![Image of VFIO Setup](vfio.png)

### Introduction
VFIO allows people to run Windows for apps that simply can't run in Linux. Its a good solution for app compatibility. Its not perfect but it would allow people to run games and apps that will not run in Wine or Steam Proton.
The draw back its not the best solution for apps that use anti-cheat software to protect multiplayer experiences.


### System Specs
* **Motherboard:** MSI X470 GAMING PLUS MAX
* **CPU:** Ryzen 7 5700G @ Stock
* **RAM:** 2 x 16GB (32GB) @ 3000 MHZ
* **GPU1 (Host):** PowerColor Figher RX 6600 8GB @ Stock
* **GPU2 (Guest):** Zotac RTX 3060 12GB @ Stock
* **Storage:** 1 x 1TB WD BLUE SSD, 1 x 500GB PNY SSD, 2 x 3TB Toshiba HDD*
* **OS (Guest):** Windows 11 Pro
* **OS (Host):** Arch Linux running on the Linux Zen Kernel

*Host on the WD Blue drive and Guest drives are stored on an SSD and HDD with the other HDD serving as a backup drive.*

### Troubleshooting
### Zen Kernel and ACS Patch
I recommend the Linux Zen Kernel because it includes the ACS Patch as a kernel launch option in your bootloader of choice that flag being `pcie_acs_override=downstream,multifunction`
#### Motherboard
The X470 GAMING PLUS MAX serves as a good option for VFIO,  It's GPU/USB card IOMMU groups are as follows (all groups in the iommu file): 
```
IOMMU Group 25:
        23:00.0 Network controller [0280]: Intel Corporation Wi-Fi 6 AX200 [8086:2723] (rev 1a)
IOMMU Group 26:
        25:00.0 USB controller [0c03]: Renesas Technology Corp. uPD720201 USB 3.0 Host Controller [1912:0014] (rev 03)
IOMMU Group 13:
        12:00.0 VGA compatible controller [0300]: NVIDIA Corporation GA106 [GeForce RTX 3060 Lite Hash Rate] [10de:2504] (rev a1)
IOMMU Group 14:
        12:00.1 Audio device [0403]: NVIDIA Corporation GA106 High Definition Audio Controller [10de:228e] (rev a1)
```
The RTX 3060 is fully isolated and works with the VM and the RX 6600 is not

#### Configuring hardware and dedicated drives
Then a Virtio SCSI controller must be configured in virt-manager ('Add Hardware' -> 'Controller' -> 'SCSI'). Finally, you must go into the vm and install special drivers for the SCSI controller that should show up in Device Manager. Those drivers can be located in the iso [here](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/)

### Looking Glass
I use looking glass to interface with the VM
Looking Glass is a powerful tool that allows Windows and Linux applications to live side by side, but requires a little extra configuration. (1920x1080) display. if you wanna use it on an ultrawide (2560x1080) display. you need to change the shared memory buffer to 64MB
```
size unit='M'>64</size>
```
#### Blue screen upon starting looking-glass-client
A blue screen for looking glass is simply displayed when the client is waiting for the host to start relaying frames. Make sure that the host is correctly configured, and looking-glass-host is running. 
#### Getting Looking Glass working
a link to the aur package for looking glasss is [here](https://aur.archlinux.org/packages/looking-glass). and a link to the Windows installer for the guest is [here](https://looking-glass.io/downloads). installing looking glass on the Windows guest will install the IVSHMEM Drivers needed for looking glass to work

#### Scream Audio
Scream is a network based sound device driver for Windows on Linux there is a client that you can run from the command line and you can install the driver in Windows which can be found [here](https://github.com/duncanthrax/scream). I recommend setting up a network bridge in Linux so you can do the command `scream -i <bridge_network>` and you should be able to get audio over a bridge network that runs internal to the system
