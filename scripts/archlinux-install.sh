#!/usr/bin/env bash
# Written by esc, wuputah
# 2015-12-26

##### Bootstrap Script #####

## Turn comments into literal programming, including output during execution.
function reporter() {
    message="$1"
    shift
    echo
    echo "${message}"
    for (( i=0; i<${#message}; i++ )); do
        echo -n '-'
    done
    echo
}

reporter "Confirming internet connection"
if [[ ! $(curl -Is http://www.google.com/ | head -n 1) =~ "200 OK" ]]; then
  echo "Your Internet seems broken. Press Ctrl-C to abort or enter to continue."
  read
else
  echo "Connection successful"
fi
reporter "Making 2 partitions on the disk -- boot and root"
parted -s /dev/sda mktable msdos
parted -s /dev/sda mkpart primary 0% 100m
parted -s /dev/sda mkpart primary 100m 100%

reporter "Make filesystems"
mkfs.ext2 /dev/sda1  # /boot
mkfs.ext4 /dev/sda2 # /

reporter "Set up /mnt"
mount /dev/sda2 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot

reporter "Rank pacman mirrors (take a coffee break if you have slow internet)"
mv /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
rankmirrors -n 6 /etc/pacman.d/mirrorlist.orig >/etc/pacman.d/mirrorlist

reporter "Install base packages"
pacman -Syy
pacstrap /mnt base base-devel

reporter "Install system"
arch-chroot /mnt pacman --noconfirm -S \
    ansible \
    syslinux

reporter "Install new ranked mirrorlist"
cp /etc/pacman.d/mirrorlist* /mnt/etc/pacman.d

reporter "Generate fstab"
genfstab -p /mnt >>/mnt/etc/fstab

reporter "Chroot-ing into /mnt"
arch-chroot /mnt /bin/bash <<END_OF_CHROOT


##### Bootstrap Variables #####

## Turn comments into literal programming, including output during execution.
function reporter() {
    message="$1"
    shift
    echo
    echo "${message}"
    for (( i=0; i<${#message}; i++ )); do
        echo -n '-'
    done
    echo
}

# todo: make modifications to mkinitcpio.conf
mkinitcpio -p linux

reporter "Install syslinux bootloader"
syslinux-install_update -i -a -m

# todo: abstract update functionality -- currently duplicating code
reporter "Shorten syslinux boot delay"
sed 's/Timeout.*/Timeout 5/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

reporter "Update syslinux config with correct root disk"
sed 's/root=.*/root=\/dev\/sda2 ro/' < /boot/syslinux/syslinux.cfg > /boot/syslinux/syslinux.cfg.new
mv /boot/syslinux/syslinux.cfg.new /boot/syslinux/syslinux.cfg

reporter "Install yaourt"
cat <<EOF >> /etc/pacman.conf

[archlinuxfr]
SigLevel = Never
Server = http://repo.archlinux.fr/\$arch
EOF
pacman --noconfirm -Sy yaourt

reporter "Congure yaourt"
cat <<EOF >> /etc/yaourtrc

# esc's customizations
NOCONFIRM=1
UP_NOCONFIRM=1
BUILD_NOCONFIRM=1
EDITFILES=0
NOENTER=1
USECOLOR=1
EOF

reporter "Set root password to \"root\""
echo root:root | chpasswd

END_OF_CHROOT

# unmount
umount /mnt/{boot,}

echo "Done! Unmount the CD image from the VM, then type 'reboot'."

# todo: abstract this report with a method to register created users
echo -e "User summary:"
echo -e "\tUser:\t\tPassword:"
echo -e "=========================="
echo -e "\troot\t\troot"
echo -e
echo -e

# todo:
echo -e "Host summary:"
echo -e "============="
