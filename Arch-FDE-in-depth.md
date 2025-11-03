# Ozzy's In-Depth Guide to Arch Linux with PQ-FDE and KDE Plasma 6

## Config Files and Guide

### Starting Point
This guide is a complete system installation guide, tailored for Arch Linux and similar Arch-based distributions. It includes full disk encryption (FDE) with a focus on strong, future-proof ciphers, and the installation of the **KDE Plasma 6** desktop environment. It also covers advanced package management with **Chaotic-AUR**.

Follow these steps to set up your new, secure system.

### Installation Prep and Post-Quantum Full Disk Encryption (PQ-FDE)

1. **Boot and Connect**
   - Boot from the Arch Linux installation ISO.
   - Connect to the internet. For wireless, use `iwctl`. For wired, `dhcpcd` should start automatically.
     ```bash
     ping archlinux.org # Test connection
     timedatectl set-ntp true # Ensure clock is accurate
     ```

2. **Partitioning Scheme**
   - Identify your disk (e.g., `/dev/sda`).
   - Command:
     ```bash
     fdisk /dev/sda
     # Create a small EFI partition (e.g., 550M) with type 'EFI System'
     # Create the main Linux partition (the rest of the disk) with type 'Linux filesystem'
     ```

3. **Post-Quantum Full Disk Encryption (FDE)**
   We will use **LUKS2** with strong parameters. While true quantum-safe algorithms like Dilithium are currently experimental for FDE, we use a robust, future-proof cipher configuration as a secure starting point.
   - Command:
     ```bash
     # Format the main partition (e.g., /dev/sda2)
     sudo cryptsetup luksFormat --type luks2 -c aes-xts-plain64 -s 512 -h sha512 /dev/sda2
     # Open the encrypted volume, naming it 'cryptroot'
     sudo cryptsetup open /dev/sda2 cryptroot
     ```

4. **Formatting and Mounting**
   - Format the opened volume:
     ```bash
     sudo mkfs.ext4 /dev/mapper/cryptroot
     ```
   - Format the EFI partition (e.g., `/dev/sda1`):
     ```bash
     sudo mkfs.fat -F 32 /dev/sda1
     ```
   - Mount the root filesystem:
     ```bash
     sudo mount /dev/mapper/cryptroot /mnt
     # Create and mount the EFI directory
     sudo mkdir -p /mnt/boot/efi
     sudo mount /dev/sda1 /mnt/boot/efi
     ```

### Base Installation and Configuration

1. **Install Base Packages**
   - Command:
     ```bash
     sudo pacstrap /mnt base linux linux-firmware nano man-db man-pages
     ```

2. **Fstab and Chroot**
   - Generate the file system table:
     ```bash
     sudo genfstab -U /mnt >> /mnt/etc/fstab
     ```
   - Change root into the new system:
     ```bash
     arch-chroot /mnt
     ```

3. **System Configuration**
   - Set the timezone: `ln -sf /usr/share/zoneinfo/Region/City /etc/localtime`
   - Run `hwclock --systohc`
   - Set locale: Uncomment `en_US.UTF-8 UTF-8` in `/etc/locale.gen` and run:
     ```bash
     locale-gen
     echo LANG=en_US.UTF-8 > /etc/locale.conf
     ```
   - Set hostname: `echo myhostname > /etc/hostname`
   - Set root password: `passwd`

4. **Dracut/Mkinitcpio Configuration for FDE**
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

5. **Bootloader Configuration**
   You have two popular options for the bootloader: **GRUB** or **systemd-boot**. Both require the same kernel parameters to unlock the full disk encryption. You can get the UUID of your encrypted partition (e.g., `/dev/sda2`) using: `blkid -s UUID -o value /dev/sda2`.

   #### Alternative A: GRUB (Standard and Flexible)
   - Install GRUB:
     ```bash
     pacman -S grub efibootmgr
     grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
     ```
   - Edit `/etc/default/grub` to pass the LUKS parameters to the kernel. Replace `<UUID>` with the UUID of your encrypted partition.
     ```bash
     GRUB_CMDLINE_LINUX="... cryptdevice=UUID=<UUID>:cryptroot root=/dev/mapper/cryptroot"
     ```
   - Generate the final GRUB configuration:
     ```bash
     grub-mkconfig -o /boot/grub/grub.cfg
     ```

   #### Alternative B: systemd-boot (Simple and Modern)
   This option is only available for **UEFI** systems. Ensure your EFI partition is mounted at `/boot/efi`.
   - Install systemd-boot:
     ```bash
     pacman -S systemd
     bootctl install
     ```
   - Create a bootloader entry file at `/boot/loader/entries/arch.conf`:
     ```bash
     sudo nano /boot/loader/entries/arch.conf
     ```
   - Add the following content, making sure to replace `<UUID>` with the UUID of your encrypted partition.
     ```ini
     title   Arch Linux
     linux   /vmlinuz-linux
     initrd  /initramfs-linux.img
     options cryptdevice=UUID=<UUID>:cryptroot root=/dev/mapper/cryptroot rw
     ```
   - You can also optionally edit the file `/boot/loader/loader.conf` to set a default entry or timeout.

---

### Installing KDE Plasma 6 and Chaotic-AUR

1. **Add User and Enable Services**
   - Add a non-root user: `useradd -m -g users -G wheel,video,audio,storage -s /bin/bash your-username`
   - Set password: `passwd your-username`
   - Install networking services and a display manager:
     ```bash
     pacman -S networkmanager sudo
     systemctl enable NetworkManager
     ```
   - Uncomment the `%wheel ALL=(ALL) ALL` line in `/etc/sudoers` (use `visudo`).

2. **Configure Chaotic-AUR Repository**
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

3. **Install KDE Plasma 6**
   - Update your mirror list and sync repositories: `pacman -Sy`
   - Install the KDE Plasma 6 group and Xorg/Mesa:
     ```bash
     pacman -S xorg plasma-meta sddm mesa
     ```
   - Enable the display manager:
     ```bash
     systemctl enable sddm
     ```

---

### Backing Up and Restoring AUR Packages

1. **Install an AUR Helper**
   - After rebooting and logging in as your user, install an AUR helper like `paru` (available in Chaotic-AUR):
     ```bash
     sudo pacman -S paru
     ```

2. **Backing Up Package Lists**
   To backup **only** packages that originated from the AUR (or Chaotic-AUR) by filtering packages not in the official repositories:
   - Command:
     ```bash
     pacman -Qm > ~/package_list_aur_only.txt
     ```
   - **Backup the `package_list_aur_only.txt` file** to external storage.

3. **Restoring Packages with Chaotic-AUR Integration**
   When restoring on a new system where **Chaotic-AUR** is already configured, the AUR helper will first check it for a pre-built binary.
   - Command:
     ```bash
     # Restore only the AUR packages from the list
     paru -S --needed - < ~/package_list_aur_only.txt
     ```
   - The command uses `paru` to install packages (`-S`) from the list (`- < ...`) and only installs them if they are not already installed (`--needed`).

4. **Final Steps**
   - Exit chroot: `exit`
   - Unmount and reboot:
     ```bash
     sudo umount -R /mnt
     sudo reboot
     ```
   Your system should now boot, prompt for your FDE password, and then load the KDE Plasma 6 login screen.
