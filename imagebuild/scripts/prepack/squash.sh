#!/bin/sh -ex


sudo mkdir -p /mnt/squashfs /squashfs
sudo mount -o bind / /mnt/squashfs

sudo mksquashfs /mnt/squashfs /squashfs/filesystem.squashfs -comp gzip -no-exports -xattrs -noappend -no-recovery -e /mnt/squashfs/squashfs/filesystem.squashfs
sudo find /boot -name 'vmlinuz-*' -type f -exec sudo cp {} /squashfs/vmlinuz \;
sudo find /boot -name 'init*' -type f -exec sudo cp {} /squashfs/initrd.img \;

chmod -R a+r /squashfs/
chmod a+rx /squashfs/
