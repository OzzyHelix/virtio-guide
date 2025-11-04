# Arch Linux Installation Guide

## PART 1: Preparation and Disk Partitioning

### Preparation

#### Items Necessary
1. A 4GB or higher USB stick

#### Downloads Necessary
2. Arch Linux ISO image  
   [https://www.archlinux.org/download/](https://www.archlinux.org/download/)

##### Creating a Bootable USB on Windows
3. Rufus

##### Creating a Bootable USB on Linux
3a.
```bash
sudo dd bs=4M if=/path/to/archlinux.iso of=/dev/sdX status=progress && sync
```
*(Replace `sdX` with your USB stick. Find it using `lsblk`.)*

#### Enabling EFI Mode via BIOS
Check your motherboard manual to enable EFI/UEFI mode in BIOS.

#### Booting from USB in EFI Mode
Insert your Arch USB stick, reboot, and either:
- Set the USB stick as the first boot device in BIOS, or
- Use the hotkey (e.g. `F11`, `DEL`) to select the USB stick.

Select **“Arch Linux archiso x86_64 UEFI USB”** when booting.  
You’ll arrive at:
```
root@archiso ~ #
```

#### Verifying Internet Connectivity
Test your internet connection:
```bash
ping -c 4 www.google.com
```
If you get a response, you’re online.

#### Verifying EFI Mode
```bash
efivar -l
```
If you get a list of variables, EFI mode is active.

---

### Disk Partitioning

#### Finding Available Drives
```bash
lsblk
```
Example output:
```
sda 238.5GB – SSD
sdb 931.5GB – HDD
sdc – USB stick
```

#### Wiping the Existing Partition Table
⚠️ **This erases the entire drive!**
```bash
gdisk /dev/sdX
x   (expert mode)
z  (clears partition table)
y  (confirm)
y  (confirm)
```

#### Creating Boot Partition (EF00)
```bash
cgdisk /dev/sdX
```
Create a **2GiB EFI boot partition**:
```
Size: 2048MiB
Hex Code: EF00
Name: boot
```
#### Creating Root and Home
- **Root** = `/` (like C:\ in Windows)
- **Home** = `/home` (user data)

If you keep `/home` inside root, use all space for root:
```
Name: root
```

If you want separate `/home`:
```
root: 120GiB
home: whatever you want it to be
```

#### Writing Partition Table
Select **[Write] → yes → [Quit]**, then reboot.

#### Setting File Systems with Full Disk Encryption
We will use **LUKS2** with strong parameters. While true quantum-safe algorithms like Dilithium are currently experimental for FDE, we use a robust, future-proof cipher configuration as a secure starting point.
```bash
mkfs.fat -F32 /dev/sda1
     # encrypt the root partition (e.g., /dev/sda2)
     sudo cryptsetup luksFormat --type luks2 --c aes-xts-plain64 --key-size 512 --h sha256 --pbkdf argon2id --pbkdf-memory 1048576 --pbkdf-parallel 4 --pbkdf-force-iterations 4 /dev/sd2
     # Open the encrypted volume, naming it 'cryptroot'
     sudo cryptsetup open /dev/sda2 cryptroot
     mkfs.ext4 /dev/mapper/cryptroot # you can replace ext4 with btrfs or whatever filesystem you want
     # repeat this for each drive or partition you want encrypted and take note of cryptroot there your device will be mounted at /dev/mapper/<whatever you named cryptroot or other partitions in the sudo cryptsetup open cmd here is an example
```

---

## PART 2: Installing Arch and Making It Boot

### Mounting Partitions
```bash
mount /dev/sda1 /mnt/boot
# say you have already formatted the /dev/mapper device you just mount it on the mount point you want
 mkdir /boot
 mount /dev/mapper/cryptroot /mnt
 mkdir /mnt/home
mount /dev/sda1 /mnt/boot
mount /dev/mapper/crypthome /mnt/home
```

### Mirrorlist Setup
```bash
cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
sudo pacman -S pacman-contrib
sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
rankmirrors -n 6 /etc/pacman.d/mirrorlist.backup > /etc/pacman.d/mirrorlist
```

### Install Base System
we will be using the zen kernel because it works with acs patch without patching the kernel
```bash
pacstrap -i /mnt base base-devel nano zsh linux-zen linux-zen-headers linux-firmware
```

### Generate fstab
```bash
genfstab -U -p /mnt >> /mnt/etc/fstab
nano /mnt/etc/fstab
```

### Setup /etc/crypttab
Here will will be using UUIDs to set the `/etc/crypttab`
```bash
# repeat this with the actual partition names of your encrypted partitions /dev/sda2 /dev/sda3 etc it will add it to cryptab
# you will also start the echo command with what you want to name the /dev/mapper device as shown below
echo "cryptroot UUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p1) none  luks,discard,no-read-workqueue,no-write-workqueue" >> /mnt/etc/cryptab
# you can review cryptab with this command
cat /etc/crypttab
```
### Chroot into the System
```bash
arch-chroot /mnt
```
### Language
```bash
nano /etc/locale.gen
locale-gen
echo LANG=en_US.UTF-8 > /etc/locale.conf
export LANG=en_US.UTF-8
```

### Time
```bash
ln -s /usr/share/zoneinfo/America/New_York > /etc/localtime
hwclock --systohc --utc
```

### Hostname
```bash
echo yourhostname > /etc/hostname
# go ahead and enable trim
systemctl enable fstrim.timer
```

### Enable Multilib
```bash
nano /etc/pacman.conf
# Uncomment:
[multilib]
Include = /etc/pacman.d/mirrorlist

pacman -Sy
```
### Dracut/Mkinitcpio Configuration for FDE
   - Install required packages for kernel image generation:
     ```bash
     pacman -S dracut cryptsetup
     ```
   - Edit the Dracut configuration (`/etc/dracut.conf.d/luks.conf`) or Mkinitcpio (`/etc/mkinitcpio.conf`) to ensure `encrypt` and `luks` hooks are included **before** the `filesystems` hook.
   - **Crucially**, configure the kernel image to recognize the encrypted volume using its UUID.
     ```bash
     # Find UUID of the encrypted partition (e.g., /dev/sda2)
     # blkid -s UUID -o value /dev/sda2
     ```
     - For Dracut, modify the kernel command line in your **Bootloader configuration** (next step).
     - For Mkinitcpio, rebuild the images: `mkinitcpio -P`

### User Setup
```bash
passwd
useradd -m -g users -G wheel,video,audio,storage -s /bin/bash yourusername
passwd yourusername
```

### Sudoers
```bash
EDITOR=nano visudo
# Uncomment:
%wheel ALL=(ALL) ALL
```

### Bootloader
```bash
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
bootctl install
```

Create config:
```bash
nano /boot/loader/entries/arch.conf
```
```
title Arch Linux
linux /vmlinuz-linux-zen
initrd /initramfs-linux-zen.img
```
now we do 
```bash
# replace /dev/nvme0n1p1 with your root partition. you can find it with lsblk
echo "options root=/dev/mapper/cryptroot cryptdevice=UUID=$(blkid -s PARTUUID -o value /dev/nvme0n1p1):cryptroot zswap.enabled=0 rw" nowatchdog
# that will add the last part your boot loader entry
````

### Microcode
```bash
pacman -S intel-ucode # for Intel
pacman -Sy amd-ucode # for AMD
```
Add to `/boot/loader/entries/arch.conf`:
```
initrd /intel-ucode.img # or /amd-ucode.img if you have an AMD cpu
initrd /initramfs-linux.img
```

### Network
```bash
sudo pacman -S networkmanager
sudo systemctl enable NetworkManager.service
```

### NVIDIA Drivers
```bash
sudo pacman -S linux-zen-headers
sudo pacman -S nvidia-open-dkms hip-runtime-nvidia lib32-nvidia-utils lib32-opencl-nvidia libva-nvidia-driver nvidia-settings nvidia-utils opencl-nvidia
```

Update modules:
```bash
sudo nano /etc/mkinitcpio.conf
# MODULES="nvidia nvidia_modeset nvidia_uvm nvidia_drm"
save the file then run `mkinitcpio -P` to compile for all kernels
```

Add kernel parameter:
```bash
options root=PARTUUID=xxxx rw nowatchdog nvidia-drm.modeset=1
# the nowatchdog flag makes it so you only have to enter the passsword for decrypting the drives one if you gave them all the same password
```

Add pacman hook:
```bash
sudo nano /etc/pacman.d/hooks/nvidia.hook
```
```
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=nvidia-open-dkms

[Action]
Depends=mkinitcpio
When=PostTransaction
Exec=/usr/bin/mkinitcpio -P
```

Reboot:
```bash
exit
umount -R /mnt
reboot
```

---

## PART 3: Making It User-Friendly

### Touchpad Support
```bash
sudo pacman -S xf86-input-synaptics
```

### 3D Support
```bash
sudo pacman -S mesa
```

### KDE Plasma
```bash
sudo pacman -S plasma sddm
sudo systemctl enable sddm.service
```

### NVIDIA Screen Tearing Fix
```bash
sudo nvidia-settings
```
Enable **Force Composition Pipeline** and **Force Full Composition Pipeline**, then save.

### AUR Helper (Yay)
```bash
wget https://aur.archlinux.org/cgit/aur.git/snapshot/yay.tar.gz
tar -xvzf yay.tar.gz
cd yay
makepkg -csi
cd ..
sudo rm -R yay
```

## Setting up the Chaotic-AUR for autobuilt aur software

### Configure Chaotic-AUR Repository
   This repository provides pre-built AUR packages, saving compile time.
   - Command (as root/in chroot):
     ```bash
     pacman-key --recv-key 3056513887B64CC9
     pacman-key --lsign-key 3056513887B64CC9
     pacman -U '[https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst](https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst)' '[https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst](https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst)'
     ```
   - Edit `/etc/pacman.conf` and add the following at the end:
     ```
     [chaotic-aur]
     Include = /etc/pacman.d/chaotic-mirrorlist
     ```

### Speed Up Compilation
```bash
sudo pacman -S ccache
sudo nano /etc/makepkg.conf
```
Edit:
```
BUILDENV=(!distcc color ccache check !sign)
MAKEFLAGS="-j17 -l16"
```

Add to `~/.bashrc`:
```bash
export PATH="/usr/lib/ccache/bin/:$PATH"
export MAKEFLAGS="-j17 -l16"
```

---

## Done!
🎉 **Enjoy your new Arch Linux system!**

References:
- [Arch Wiki](https://wiki.archlinux.org)
- [Gloriuous eggroll's Blog](https://www.gloriouseggroll.tv/arch-linux-efi-install-guide/)
- [Tom’s Hardware Guide](http://www.tomshardware.com/faq/id-1860905/install-arch-linux-uefi.html)
- [LinuxVeda](http://www.linuxveda.com/2014/06/07/arch-linux-tutorial/)
- [ServerFault Discussion](http://serverfault.com/questions/5841/how-much-swap-space-on-a-high-memory-system)

