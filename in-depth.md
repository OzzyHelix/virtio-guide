### Ozzy's In Depth Guide to KVM/QEMU
## Config files and Guide

### Starting Point
this guide will be done on Arch Linux so any Arch based distro might work and this is how to setup a VM

### Installing Copying Configs and getting patched kernel
copy the configs from 
https://github.com/OzzyHelix/virtio-guide/tree/main/configs
for Dracut just copy the config and run `sudo dracut-rebuild`
after you copy the configs you will need a kernel with the acs patch its better to have the acs patch enabled than to worry about IOMMU groups being messed up
this can be done with the zen kernel by installing the `linux-zen` and `linux-zen-headers` or you can use an lts vfio kernel so you could install `linux-vfio-lts` and `linux-vfio-lts-headers` insted of the zen kernel packages.
the thrid option is to patch the kernel yourself

### EDITING THE CONFIGS you need to run
First you need to figure out your IOMMU Sitution 
it can be done with this script
```
#!/bin/bash
shopt -s nullglob
for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
    echo "IOMMU Group ${g##*/}:"
    for d in $g/devices/*; do
        echo -e "\t$(lspci -nns ${d##*/})"
    done;
done;
```
the output should look something like this
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
then from that you can find your PCIE IDs in the IOMMU groups the ids look something like this `8086:2723`
so after copying all the configs to your system do this command
`sudo nano /etc/modprobe.d/vfio.conf`
on the line that says `options vfio-pci ids=` you add the PCIE ids for the stuff you want to add to the VM (note once bound th vfio-pci you can't use it in Linux with anything only the VM can use it)



### installing and setting up Libvirt and KVM/QEMU 
first make sure you have SVM enabled in your BIOS and you will have to find an Intel equal to SVM this won't work without it
Step 1: Check if Virtualization Is Enabled

```grep -Ec '(vmx|svm)' /proc/cpuinfo```

If it's greater than 0, then virtualization is enabled and you can safely continue.
Step 2: Install the Required KVM Packages

`sudo pacman -Sy qemu-full virt-manager virt-viewer dnsmasq bridge-utils libguestfs ebtables vde2 openbsd-netcat`

Enter Y when prompted for confirmation.

Step 3: Configure the libvirtd Service 

`sudo systemctl enable --now libvirtd.service`

enables and starts it

Check if libvirtd is currently running using the status command:

`sudo systemctl status libvirtd.service`

The output should display the active (running) status in green. If it shows inactive (dead), issue the systemctl start command again.

Next, you need to make some changes to the libvirtd configuration file located at /etc/libvirt/libvirtd.conf. Open the file using nano (or your preferred text editor):
`sudo nano /etc/libvirt/libvirtd.conf`
Locate and uncomment the following lines and remove the pound (#) symbol you can search for these lines by using Ctrl+W in nano

`unix_sock_group = "libvirt"
unix_sock_rw_perms = "0770"`
hit ctrl+o to save the file and exit

now add your user to the libvirt group

`sudo usermod -aG libvirt $USER`

then restart libvirt

`systemctl restart libvirtd.service`

(note) you might need to replace my username "ozzy" in the config files if you use them

### Creating the VM
We're ready to begin creating our VM. 

Go ahead and start virt-manager from your list of applications. Select the button on the top left of the GUI to create a new VM:

<div align="center">
    <img src="./img/virtman_1.png" width="450">
</div><br>

Select the "Local install media" option. My ISOs are stored in my home directory `/home/user/.iso`, so I'll create a new pool and select the Windows 10 ISO from there:

<div align="center">
    <img src="./img/virtman_2.png" width="450">
</div><br>

Configure some custom RAM and CPU settings for your VM:

<div align="center">
    <img src="./img/virtman_3.png" width="450">
</div><br>

Next, the GUI asks us whether we want to enable storage for the VM. you create a storage pool and do it on the drive you want to storage your qcow2 images

<div align="center">
    <img src="./img/virtman_4.png" width="450">
</div><br>

On the last step, review your settings and select a name for your VM. Make sure to select the checkbox "Customize configuration before installation" and click Finish:

<div align="center">
    <img src="./img/virtman_5.png" width="450">
</div><br>

A new window should appear with more advanced configuration options. You can alter these options through the GUI or the associated libvirt XML settings. Make sure that on the Overview page under Firmware you select `UEFI x86_64: /usr/share/OVMF/OVMF_CODE.fd`:

<div align="center">
    <img src="./img/virtman_6.png" width="450">
</div><br>

Go to the CPUs page and remove the check next to `Copy host CPU configuration` and under Model type `host-passthrough`. Also make sure to check the option for `Enable available CPU security flaw mitigations` to prevent against Spectre/Meltdown vulnerabilities.

<div align="center">
    <img src="./img/virtman_7.png" width="450">
</div><br>

I've chosen to remove several of the menu options that won't be useful to my setup (feel free to keep them if you'd like):

<div align="center">
    <img src="./img/virtman_8.png" width="450">
</div><br>

Let's add the <span name="virtio-iso">virtIO drivers</span>. Click 'Add Hardware' and under 'Storage', create a custom storage device of type `CDROM`. Make sure to locate the ISO image for the virtIO drivers from earlier:

<div align="center">
    <img src="./img/virtman_9.png" width="450">
</div><br>

Under the NIC menu, change the device model to `virtIO` for improved networking performance:

<div align="center">
    <img src="./img/virtman_10.png" width="450">
</div><br>

Now it's time to configure our passthrough devices! Click 'Add Hardware' and under 'PCI Host Device', select the Bus IDs corresponding to your GPU.

<div align="center">
    <img src="./img/virtman_11.png" width="450">
</div><br>

Make sure to repeat this step for all the devices associated with your GPU in the same IOMMU group (usually VGA, audio controller, etc.):

<div align="center">
    <img src="./img/virtman_12.png" width="450">
</div><br>

Then under the 'Boot Options' menu, I added a check next to `Enable boot menu` and reorganized the devices so that I could boot directly from the 1TB SSD:

<div align="center">
    <img src="./img/virtman_14.png" width="450">
</div><br>

make sure to VGA Video on the VM so we can control it
![image](https://github.com/OzzyHelix/virtio-guide/assets/29835364/f4514a8a-68ff-4831-8e78-f6c90dde492e)

then install Windows like you would on a PC

once you have Windows installed you are going to have to install the guest tooling the iso is linked here
https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/virtio-win-0.1.240.iso

after installing the guest tooling we are going to install scream

### Installing Scream
Scream has some cert issues because of Windows licensing prices it is safe but this script fixes it so it can install so run this in powershell as admin on Windows 
https://raw.githubusercontent.com/OzzyHelix/virtio-guide/main/scripts/install-screams.ps1

as for Linux we need to install Scream from the AUR so I will recommend yay
yay -Sy scream
 ### Settings Scream up on the host
 we need to set a network bridge or nat on the VM so open virt manager and go to edit and then Connection Details from there Virtual Networks in there you hit the plus button (+)
 <div align="center">
    <img src="./img/scream1.png" width="450">
</div><br>
 <div align="center">
    <img src="./img/scream2.png" width="450">
</div><br>
 
from there you setup your network virtual network
to run scream for the VM you need to run ifconfig and find the virtual netowrk it might be like virbr0 vrirbr1 etc
and you just run in the terminal 
scream -i <virtual_network>
you probably don't want to type that every time so I suggest a bash alias

### Attaching hardware to the VM
in Virt-Manager right click on your VM and click Open from that click on add hardware then go to PCIE Host Device and Select the Hardware you provisioned for vfio-pci earlier 
 <div align="center">
    <img src="./img/hardware1.png" width="450">
</div><br>
 <div align="center">
    <img src="./img/hardware2.png" width="450">
</div><br>
 ### CPU Pinning 
Run `lstopo --of console -p` to see how your CPU is laid out 
Now pin the threads in pairs like this (don't just copy. For you the pairs might be like: 0,8; 1,9; 2,10; ... or different):

`<vcpupin vcpu='0' cpuset='0'/>`
`<vcpupin vcpu='1' cpuset='6'/>`
`<vcpupin vcpu='2' cpuset='1'/>`
`<vcpupin vcpu='3' cpuset='7'/>`
`<vcpupin vcpu='4' cpuset='2'/>`
`<vcpupin vcpu='5' cpuset='8'/>`
`<vcpupin vcpu='6' cpuset='3'/>`
`<vcpupin vcpu='7' cpuset='9'/>`
`<vcpupin vcpu='8' cpuset='4'/>`
`<vcpupin vcpu='9' cpuset='10'/>`
Don't pin emulatorpin and iothreadpin to CPUs that you pass to the vm. If you pass all CPUs leave iothreadpin and emulatorpin out. 
if you have 6 cores / 12 threads and pass only 5 cores / 10 threads, leaving 1 core / 2 threads for iothreadpin and emulatorpin. This gives me great performance - better than passing all cores!
Last but not least, make sure to set the CPU governors to performance:
`for i in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do echo performance | sudo tee $i; done`
this last step is optional

# Anti Cheat Compatibility 
this involves editing the xml code that makes up the VM settings
in VRChat's Case 
you need to add 
`<smbios mode='host'/>` to `<os></os>`
you need to add this
```
<kvm> 
  <hidden state='on'/> 
</kvm>
```
then under 
  ```
<cpu mode="host-passthrough" check="none" migratable="on">
    <topology sockets="1" dies="1" cores="6" threads="2"/>
```
you add `<feature policy='disable' name='hypervisor'/>` 
you can try and enable HyperV in the VM but I'm not sure that will do anything but its worth a try

# Installing Looking Glass
Looking Glass is a powerful tool that allows Windows and Linux applications to live side by side, but requires a little extra configuration. (1920x1080) display. if you wanna use it on an ultrawide (2560x1080) display. you need to change the shared memory buffer to 64MB
```
size unit='M'>64</size>
```
just add this code before the line `</devices>`
```
    <shmem name="looking-glass">
      <model type="ivshmem-plain"/>
      <size unit="M">64</size>
    </shmem>
```
then on Linux using an AUR helper install `looking-glass` and `looking-glass-module-dkms`
I will provide a script for running looking glass in the git repo you can use it as a bash alias

# Finishing Windows setup
you need to install the drivers for the GPU you passed to the VM
then install the looking glass host program the Windows installer for the guest is [here](https://looking-glass.io/downloads). installing looking glass on the Windows guest will install the IVSHMEM Drivers needed for looking glass to work
after which you should be good to play games with looking glass
