
# Ozzy's In-Depth Guide to KVM/QEMU

## Config Files and Guide

### Starting Point
This guide is tailored for Arch Linux and similar Arch-based distributions. 
With the Arch Based distro that it has been testing on are as follow, EndeavourOS, Garuda, and Manjaro Linux.

Follow these steps to set up a system and a VM.

### Installing, Copying Configs, and Getting a Patched Kernel

1. **Download Configs**
   - Get the configs from [GitHub](https://github.com/OzzyHelix/virtio-guide/tree/main/configs).
   - copy them to the directories that the configs folder mimicks
   - you'll need to edit those configs to fit your system check to make sure they work for you

2. **Grub, Dracut and Mkinitcpio Configuration**

   2a. **Grub Configuration**
   if you are using dracut there are config files for it you can get them here [GitHub](https://raw.githubusercontent.com/OzzyHelix/virtio-guide/main/configs/etc/default/grub).
   - Copy the config files to `/etc/default/grub` and run:
     ```bash
     sudo grub-mkconfig -o /boot/grub/grub.cfg
     ```
   2b. **Dracut Configuration**
   if you are using dracut there are config files for it you can get them here [GitHub](https://github.com/OzzyHelix/virtio-guide/tree/main/configs).
   - Copy the config files to `/etc/dracut.conf.d` and run:
     ```bash
     sudo dracut-rebuild
     ```
   2c. **Mkinitcpio Configuration**
   if you are using mkinitcpio the config file for it you can get them here [GitHub](https://raw.githubusercontent.com/OzzyHelix/virtio-guide/main/configs/etc/mkinitcpio.conf).
   - Copy the config file to `/etc/mkinitcpio.conf` and run:
     ```bash
     sudo mkinitcpio -P # to update all kernels to accept the configurations 
     ```


4. **Patched Kernel**
   - Here are your options:
     - Install the `linux-zen` and `linux-zen-headers`.
     - Install `linux-vfio-lts` and `linux-vfio-lts-headers`.
     - Patch the kernel yourself.

### Editing the Configs

1. **The IOMMU Situation**
   - you will grab your PCIE IDS from here save them to a text file or something you'll need them for the next step. They look like this `[10de:228e]`
   - Use this script to figure out your IOMMU situation:
     ```bash
     #!/bin/bash
     shopt -s nullglob
     for g in $(find /sys/kernel/iommu_groups/* -maxdepth 0 -type d | sort -V); do
         echo "IOMMU Group ${g##*/}:"
         for d in $g/devices/*; do
             echo -e "	$(lspci -nns ${d##*/})"
         done;
     done;
     ```
   - Example output:
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

3. **Editing `vfio.conf`**
   doing this will bind the PCIE devices to the vfio-pci driver with their PCIE ID this means you can't use them in Linux they will be setup to be attached to a VM
   to proceed
   - Command:
     ```bash
     sudo nano /etc/modprobe.d/vfio.conf
     ```
   - Add the PCIe IDs to the line:
     ```bash
     options vfio-pci ids=<PCIe IDs>
     ```

### Installing and Setting Up Libvirt and KVM/QEMU

1. **Enable Virtualization**
   - Ensure SVM is enabled in your BIOS.
   - Check:
     ```bash
     grep -Ec '(vmx|svm)' /proc/cpuinfo
     ```
     if the output is greater than zero then you are good

     if the output is less than one you need to enable vmx or svm in your BIOS/UEFI firmware
     
2. **Install Required Packages**
   this is stuff needed for running VMs in general so we will install this, With Manjaro Linux, the commands are sometimes weird so you may need to use pamac in place of pacman, so keep that in mind.
   - Command:
     ```bash
     sudo pacman -Sy qemu-full virt-manager virt-viewer dnsmasq bridge-utils libguestfs ebtables vde2 openbsd-netcat
     ```

4. **Configure libvirtd Service**
   we need to enable the libvirt service so we will do that
   - Enable and start the service:
     ```bash
     sudo systemctl enable --now libvirtd.service
     ```
   - we will check its status:
     ```bash
     sudo systemctl status libvirtd.service
     ```

6. **Edit `libvirtd.conf`**
   we now need to edit the libvirtd.conf
   - Command:
     ```bash
     sudo nano /etc/libvirt/libvirtd.conf
     ```
   - Uncomment:
     ```bash
     unix_sock_group = "libvirt"
     unix_sock_rw_perms = "0770"
     ```
   - Save and exit.

7. **Edit `qemu.conf`**

   we now need to edit the `/etc/libvirt/qemu.conf` to add your user to it so you can pass your mic to the VM so in the event you want to use your mic on the VM you can
   - Command:
     ```bash
     sudo nano /etc/libvirt/qemu.conf
     ```
   - Uncomment or Add:
     ```bash
     user = "your-username"
     ```
   - Save and exit.

9. **Add User to `libvirt` Group**
   we will now add your user to the libvirt
   - Command:
     ```bash
     sudo usermod -aG libvirt $USER
     ```
   - Restart libvirt:
     ```bash
     sudo systemctl restart libvirtd.service
     ```

### Creating the VM

1. **Launch virt-manager**
   - Open `virt-manager` from your applications list.
   - Create a new VM and select "Local install media".
   - Navigate to your ISO directory, e.g., `/home/user/.iso`.

2. **Configure VM Settings**
   - Adjust RAM and CPU settings.
   - Enable storage for the VM by creating a storage pool for `qcow2` images.

3. **Advanced Configuration**
   - On the Overview page, select:
     ```
     UEFI x86_64: /usr/share/OVMF/OVMF_CODE.fd
     ```
   - Set CPU options to:
     ```
     host-passthrough
     Enable available CPU security flaw mitigations
     ```
   - Add virtIO drivers and configure NIC for improved performance.

4. **Passthrough Devices**
   - Add PCI Host Devices corresponding to your GPU and other components.
   - Ensure boot options are set correctly.

### Installing Windows and Additional Software

1. **Windows Installation**
   - Proceed with a standard Windows installation.
   - Post-installation, install the guest tooling from [virtio-win-iso]([https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.240-1/virtio-win-0.1.240.iso](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.248-1/virtio-win-0.1.248.iso)).

2. **Install Scream**
   - On Windows, run the provided PowerShell script:
     ```powershell
     https://raw.githubusercontent.com/OzzyHelix/virtio-guide/main/scripts/install-screams.ps1
     ```
   - On Linux, install Scream using:
     ```bash
     yay -Sy scream
     ```

3. **Configure Network for Scream**
   - Set up a network bridge or NAT on the VM. this can be done with cockpit
   - to install cockpit run `sudo pacman -Sy cockpit && sudo systemctl enable --now cockpit.socket`
   - you can then go to http://localhost:9090 in your browser and go to the networking tab and create a network bridge with your ethernet adaptor
   - Once you've done that run:
     ```bash
     scream -i <virtual_network>
     ```
   - Optionally, create a bash alias for convenience or create a script and have it start with your desktop.

### Attaching Hardware to the VM

1. **Using Virt-Manager**
   - Open your VM, add hardware, and select PCI Host Device for the provisioned vfio-pci.

### CPU Pinning
you need to do this to make you phyical cores be assigned to your virtual cores that way your VM runs with good performance
1. **Determine CPU Layout**
   - Command:
     ```bash
     lstopo --of console -p
     ```

2. **Pin CPU Threads**
   - Example configuration:
     ```xml
     <vcpupin vcpu='0' cpuset='0'/>
     <vcpupin vcpu='1' cpuset='6'/>
     <!-- Add more pairs as needed -->
     ```

3. **Set CPU Governors to Performance**
   - Command:
     ```bash
     for i in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do echo performance | sudo tee $i; done
     ```

### Anti-Cheat Compatibility
we do this so games like VRChat will run in our VM
1. **Edit XML Configuration**
   - Add to `<os>`:
     ```xml
     <smbios mode='host'/>
     ```
   - Add to `<features>`
     ```xml
     <vpindex state="on"/>
     <runtime state="on"/>
     <stimer state="on"/>
     <reset state="on"/>
     ```

   - Add to just under `<features>`
     ```xml
      <kvm> 
       <hidden state='on'/> 
      </kvm>
     ```
   - Add to `<cpu>`:
     ```xml
     <feature policy='disable' name='hypervisor'/>
     ```
3. you need enable Hyper-V in Windows to hide the Linux Hypervisor
   this tells any anti cheat software that its running under Microsoft Hv or Hyper V and will basically trick any anti cheat software into thinking its running on Microsoft's solution 

### Installing Looking Glass
this will let us access our VM from our Linux desktop
1. **Configure Shared Memory Buffer**
   - Add before `</devices>`:
     ```xml
     <shmem name="looking-glass">
       <model type="ivshmem-plain"/>
       <size unit="M">64</size>
     </shmem>
     ```

2. **Install Looking Glass on Linux**
   - Use AUR helper:
     ```bash
     yay -Sy looking-glass looking-glass-module-dkms
     ```

3. **Install Looking Glass on Windows** 
   - Download and install from [Looking Glass](https://looking-glass.io/downloads).
   - Make sure your looking glass version do match if the host computer if the host computer is running b7 then the vm should be running b7, just always make sure both version are the same.

### Finishing Windows Setup

1. **Install GPU Drivers**
2. **Install Looking Glass Host Program**
