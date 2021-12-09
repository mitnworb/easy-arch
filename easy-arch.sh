#!/usr/bin/env -S bash -e

# Cleaning the TTY.
clear

# Pretty print (function).
print () {
    echo -e "\e[1m\e[93m[ \e[92m•\e[93m ] \e[4m$1\e[0m"
}

# Virtualization check (function).
virt_check () {
    hypervisor=$(systemd-detect-virt)
    case $hypervisor in
        kvm )   print "KVM has been detected."
                print "Installing guest tools."
                pacstrap /mnt qemu-guest-agent
                print "Enabling specific services for the guest tools."
                systemctl enable qemu-guest-agent --root=/mnt &>/dev/null
                ;;
        vmware  )   print "VMWare Workstation/ESXi has been detected."
                    print "Installing guest tools."
                    pacstrap /mnt open-vm-tools
                    print "Enabling specific services for the guest tools."
                    systemctl enable vmtoolsd --root=/mnt &>/dev/null
                    systemctl enable vmware-vmblock-fuse --root=/mnt &>/dev/null
                    ;;
        oracle )    print "VirtualBox has been detected."
                    print "Installing guest tools."
                    pacstrap /mnt virtualbox-guest-utils
                    print "Enabling specific services for the guest tools."
                    systemctl enable vboxservice --root=/mnt &>/dev/null
                    ;;
        microsoft ) print "Hyper-V has been detected."
                    print "Installing guest tools."
                    pacstrap /mnt hyperv
                    print "Enabling specific services for the guest tools."
                    systemctl enable hv_fcopy_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_kvp_daemon --root=/mnt &>/dev/null
                    systemctl enable hv_vss_daemon --root=/mnt &>/dev/null
                    ;;
        * ) ;;
    esac
}

# Selecting a kernel to install (function). 
kernel_selector () {
    print "List of kernels:"
    print "1) Stable: Vanilla Linux kernel with a few specific Arch Linux patches applied"
    print "2) Hardened: A security-focused Linux kernel"
    print "3) LTS: Long-term support (LTS) Linux kernel"
    print "4) Zen: A Linux kernel optimized for desktop usage"
    read -r -p "Insert the number of the corresponding kernel: " choice
    case $choice in
        1 ) print "linux will be installed."
            kernel="linux"
            ;;
        2 ) print "linux-hardened will be installed."
            kernel="linux-hardened"
            ;;
        3 ) print "linux-lts will be installed."
            kernel="linux-lts"
            ;;
        4 ) print "linux-zen will be installed."
            kernel="linux-zen"
            ;;
        * ) print "You did not enter a valid selection."
            kernel_selector
    esac
}

# Selecting a way to handle internet connection (function). 
network_selector () {
    print "Network utilities:"
    print "1) IWD: iNet wireless daemon is a wireless daemon for Linux written by Intel (WiFi-only)"
    print "2) NetworkManager: Universal network utility to automatically connect to networks (both WiFi and Ethernet)"
    print "3) wpa_supplicant: Cross-platform supplicant with support for WEP, WPA and WPA2 (WiFi-only, a DHCP client will be automatically installed as well)"
    print "4) dhcpcd: Basic DHCP client (Ethernet only or VMs)"
    print "5) I will do this on my own (only advanced users)"
    read -r -p "Insert the number of the corresponding networking utility: " choice
    case $choice in
        1 ) print "Installing IWD."    
            pacstrap /mnt iwd
            print "Enabling IWD."
            systemctl enable iwd --root=/mnt &>/dev/null
            ;;
        2 ) print "Installing NetworkManager."
            pacstrap /mnt networkmanager
            print "Enabling NetworkManager."
            systemctl enable NetworkManager --root=/mnt &>/dev/null
            ;;
        3 ) print "Installing wpa_supplicant and dhcpcd."
            pacstrap /mnt wpa_supplicant dhcpcd
            print "Enabling wpa_supplicant and dhcpcd."
            systemctl enable wpa_supplicant --root=/mnt &>/dev/null
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;;
        4 ) print "Installing dhcpcd."
            pacstrap /mnt dhcpcd
            print "Enabling dhcpcd."
            systemctl enable dhcpcd --root=/mnt &>/dev/null
            ;; 
        5 ) ;;
        * ) print "You did not enter a valid selection."
            network_selector
    esac
}

# Setting up a password for the LUKS Container (function).
password_selector () {
    read -r -s -p "Insert password for the LUKS container (you're not going to see the password): " password
    if [ -z "$password" ]; then
        print "You need to enter a password for the LUKS Container in order to continue."
        password_selector
    fi
    echo -n "$password" | cryptsetup luksFormat "$CRYPTROOT" -d -
    echo -n "$password" | cryptsetup open "$CRYPTROOT" cryptroot -d -
    BTRFS="/dev/mapper/cryptroot"
}

# Setting up the hostname (function).
hostname_selector () {
    read -r -p "Please enter the hostname: " hostname
    if [ -z "$hostname" ]; then
        print "You need to enter a hostname in order to continue."
        hostname_selector
    fi
    print "$hostname will be used as hostname."
    echo "$hostname" > /mnt/etc/hostname
}

# Setting up a user account
account_creator () {
    read -r -p "Please enter name for a user account: " username
    if [ -z "$username" ]; then
        print "You need to enter a valid username in order to continue."
        account_creator
    fi
    print "Adding the user $username to the system with root privilege."
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$username"
    sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/' /mnt/etc/sudoers
    print "Setting user password for $username." 
    arch-chroot /mnt /bin/passwd "$username"
}

# Setting up the locale (function).
locale_selector () {
    read -r -p "Please insert the locale you use (format: xx_XX or enter empty to use en_US): " locale
    if [ -z "$locale" ]; then
        print "en_US will be used as default locale."
        locale="en_US"
    fi
    print "$locale will be used as locale."
    echo "$locale.UTF-8 UTF-8"  > /mnt/etc/locale.gen
    echo "LANG=$locale.UTF-8" > /mnt/etc/locale.conf
}

# Setting up the keyboard layout (function).
keyboard_selector () {
    read -r -p "Please insert the keyboard layout you use (enter empty to use US keyboard layout): " kblayout
    if [ -z "$kblayout" ]; then
        print "US keyboard layout will be used by default."
        kblayout="us"
    fi
    print "$kblayout will be used as keyboard layout."
    echo "KEYMAP=$kblayout" > /mnt/etc/vconsole.conf
}

# Selecting the target for the installation.
print "Welcome to easy-arch, a script made in order to simplify the process of installing Arch Linux."
PS3="Please select the disk where Arch Linux is going to be installed: "
select ENTRY in $(lsblk -dpnoNAME|grep -P "/dev/sd|nvme|vd");
do
    DISK=$ENTRY
    print "Installing Arch Linux on $DISK."
    break
done

# Deleting old partition scheme.
read -r -p "This will delete the current partition table on $DISK. Do you agree [y/N]? " response
response=${response,,}
if [[ "$response" =~ ^(yes|y)$ ]]; then
    print "Wiping $DISK."
    wipefs -af "$DISK" &>/dev/null
    sgdisk -Zo "$DISK" &>/dev/null
else
    print "Quitting."
    exit
fi

# Creating a new partition scheme.
print "Creating the partitions on $DISK."
parted -s "$DISK" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 esp on \
    mkpart CRYPTROOT 513MiB 100% \

ESP="/dev/disk/by-partlabel/ESP"
CRYPTROOT="/dev/disk/by-partlabel/CRYPTROOT"

# Informing the Kernel of the changes.
print "Informing the Kernel about the disk changes."
partprobe "$DISK"

# Formatting the ESP as FAT32.
print "Formatting the EFI Partition as FAT32."
mkfs.fat -F 32 $ESP &>/dev/null

# Creating a LUKS Container for the root partition.
print "Creating LUKS Container for the root partition."
password_selector

# Formatting the LUKS Container as BTRFS.
print "Formatting the LUKS container as BTRFS."
mkfs.btrfs $BTRFS
mount $BTRFS /mnt

# Creating BTRFS subvolumes.
print "Creating BTRFS subvolumes."
for volume in @ @home @snapshots @var_log @var_pkgs
do
    btrfs su cr /mnt/$volume
done

# Mounting the newly created subvolumes.
umount /mnt
print "Mounting the newly created subvolumes."
mount -o ssd,noatime,compress-force=zstd:3,discard=async,subvol=@ $BTRFS /mnt
mkdir -p /mnt/{home,.snapshots,/var/log,/var/cache/pacman/pkg,boot}
mount -o ssd,noatime,compress-force=zstd:3,discard=async,subvol=@home $BTRFS /mnt/home
mount -o ssd,noatime,compress-force=zstd:3,discard=async,subvol=@snapshots $BTRFS /mnt/.snapshots
mount -o ssd,noatime,compress-force=zstd:3,discard=async,subvol=@var_log $BTRFS /mnt/var/log
mount -o ssd,noatime,compress-force=zstd:3,discard=async,subvol=@var_pkgs $BTRFS /mnt/var/cache/pacman/pkg
chattr +C /mnt/var/log
mount $ESP /mnt/boot/

# Setting up the kernel.
kernel_selector

# Microcode detector
CPU=$(grep vendor_id /proc/cpuinfo)
if [[ $CPU == *"AuthenticAMD"* ]]; then
    print "An AMD CPU has been detected, the AMD microcode will be installed."
    microcode="amd-ucode"
else
    print "An Intel CPU has been detected, the Intel microcode will be installed."
    microcode="intel-ucode"
fi

# Virtualization check.
virt_check

# Setting up the network.
network_selector

# Pacstrap (setting up a base sytem onto the new root).
print "Installing the base system (it may take a while)."
pacstrap /mnt base "$kernel" "$microcode" "$kernel-headers" linux-firmware refind btrfs-progs rsync snapper reflector base-devel snap-pac zram-generator git

# Setting up the hostname.
hostname_selector

# Generating /etc/fstab.
print "Generating a new fstab."
genfstab -U /mnt >> /mnt/etc/fstab

# Setting username.
account_creator

# Setting up the locale.
locale_selector

# Setting up keyboard layout.
keyboard_selector

# Setting hosts file.
print "Setting hosts file."
cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $hostname.localdomain   $hostname
EOF

# Configuring /etc/mkinitcpio.conf.
print "Configuring /etc/mkinitcpio.conf."
cat > /mnt/etc/mkinitcpio.conf <<EOF
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems)
COMPRESSION=(zstd)
EOF

# Configuring the system.    
arch-chroot /mnt /bin/bash -e <<EOF

    # Setting up timezone.
    echo "Setting up the timezone."
    ln -sf /usr/share/zoneinfo/$(curl -s http://ip-api.com/line?fields=timezone) /etc/localtime &>/dev/null
    
    # Setting up clock.
    echo "Setting up the system clock."
    hwclock --systohc
    
    # Generating locales.
    echo "Generating locales."
    locale-gen &>/dev/null
    
    # Generating a new initramfs.
    echo "Creating a new initramfs."
    mkinitcpio -P &>/dev/null
    
    # Snapper configuration
    echo "Configuring Snapper."
    umount /.snapshots
    rm -r /.snapshots
    snapper --no-dbus -c root create-config /
    btrfs subvolume delete /.snapshots &>/dev/null
    mkdir /.snapshots
    mount -a
    chmod 750 /.snapshots

    # rEFInd installation.
    echo "Installing rEFInd."
    refind-install &>/dev/null
EOF

# Setting root password.
print "Setting root password."
arch-chroot /mnt /bin/passwd

# Install AUR.
arch-chroot /mnt sudo -H -u "$username" bash -c "git clone https://aur.archlinux.org/paru.git /home/$username/paru && cd /home/$username/paru && makepkg -si --noconfirm"

# Setting up rEFInd.
print "Setting up rEFInd configuration file."
UUID=$(blkid -s UUID -o value $CRYPTROOT)
rm -rf /mnt/boot/refind_linux.conf
cat > /mnt/boot/EFI/refind/refind.conf <<EOF
timeout 20
use_nvram false
menuentry "Arch Linux" {
	icon     /EFI/refind/icons/os_arch.png
	volume   "Arch Linux"
	loader   /vmlinuz-$kernel
    initrd   /initramfs-$kernel.img
	options  "rd.luks.name=$UUID=cryptroot root=$BTRFS rootflags=subvol=@ quiet initrd=\\$microcode.img initrd=\initramfs-$kernel.img"
	submenuentry "Boot to terminal (rescue mode)" {
		add_options "systemd.unit=multi-user.target"
	}
}
EOF
print "Installing rEFInd-btrfs."
arch-chroot /mnt paru -S --noconfirm refind-btrfs

# Setting up pacman hooks.
print "Configuring /boot backup when pacman transactions are made."
mkdir /mnt/etc/pacman.d/hooks
cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = usr/lib/modules/*/vmlinuz

[Action]
Depends = rsync
Description = Backing up /boot...
When = PostTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

print "Configuring rEFInd when rEFInd is updated."
cat > /mnt/etc/pacman.d/hooks/50-bootbackup.hook <<EOF
[Trigger]
Operation=Upgrade
Type=Package
Target=refind

[Action]
Description = Updating rEFInd on ESP
When=PostTransaction
Exec=/usr/bin/refind-install
EOF

# ZRAM configuration.
print "Configuring ZRAM."
cat > /mnt/etc/systemd/zram-generator.conf <<EOF
[zram0]
zram-fraction = 1
max-zram-size = 8192
EOF

# Pacman eye-candy features.
print "Enabling colours and animations in pacman."
sed -i 's/#Colors/Colors\nILoveCandy/' /mnt/etc/pacman.conf

# Enabling various services.
print "Enabling Reflector, automatic snapshots, BTRFS scrubbing, rEFInd-btrfs and systemd-oomd."
for service in reflector.timer snapper-timeline.timer snapper-cleanup.timer btrfs-scrub@-.timer btrfs-scrub@home.timer btrfs-scrub@var-log.timer btrfs-scrub@\\x2esnapshots.timer refind-btrfs systemd-oomd
do
    systemctl enable "$service" --root=/mnt &>/dev/null
done

# Finishing up.
print "Done, you may now wish to reboot (further changes can be done by chrooting into /mnt)."
exit