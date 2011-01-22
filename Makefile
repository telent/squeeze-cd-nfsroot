# Regenerate the root filesystem and boot image for "diskless" nodes
# (frontend/app server nodes).  

# to overwrite an existing drive on elastichosts (i.e. this is not 
# the first time the script has been run), set this to the drive uuid
#DRIVE_UUID=-d ef2879c7-1f1a-42d9-a081-576af113e38d

# Rootfs

# first we copy the master root, then we customise by overlaying files
# from the template/ subdirectory containing client config
rootfs:
	rsync --delete -ax \
	--exclude /usr --exclude /boot --exclude /home \
	--exclude /var/spool/\* --exclude /var/cache/\* \
	--exclude /dev/\* \
	--exclude /tmp/\* \
	--exclude /var/lib/apt \
	--exclude /etc/hostname \
	--exclude /etc/mtab \
	--exclude /etc/exports \
	--exclude /var/lib/dpkg \
	--exclude /var/log/\* \
	--exclude /vmlinuz --exclude /initrd.img \
	--exclude /var/run/\* \
	--exclude /etc/network/run \
	--exclude /var/\* \
	/ /usr/local/client/nfsroot/
	: # debian bug 592361: isc dhcp is linked -lz -lcrypto #fail
	mkdir -p nfsroot/usr/lib
	cp /usr/lib/libcrypto.so.0.9.8 /usr/lib/libz.so.1  nfsroot/usr/lib
	rsync -ax template/ nfsroot/
	test -d nfsroot/scratch || mkdir nfsroot/scratch
	-find nfsroot -user dan -print0 | xargs -0 chown root 
	rm -f nfsroot/etc/udev/rules.d/*persistent*
	rm nfsroot/etc/hostname
	insserv -p nfsroot/etc/init.d -r dnsmasq postgresql nfs-kernel-server exim4
	for i in mount_scratch_disk rticulate template/etc/init.d/* ; do \
	  insserv -p nfsroot/etc/init.d `basename $$i`;\
	done

# Boot image

boot_cd/isolinux:
	mkdir -p $@

boot_cd/isolinux/ramfs.img: rootfs
	mkinitramfs -d nfsroot/etc/initramfs-tools -o boot_cd/isolinux/ramfs.img

boot_cd/isolinux/isolinux.bin: /usr/lib/syslinux/isolinux.bin
	cp $< $@

boot_cd/isolinux/isolinux.cfg: isolinux.cfg
	cp $< $@

boot_cd/isolinux/zimage: $(shell realpath /vmlinuz)
	cp $< $@

boot_cd.iso: boot_cd/isolinux boot_cd/isolinux/isolinux.bin boot_cd/isolinux/ramfs.img boot_cd/isolinux/zimage boot_cd/isolinux/isolinux.cfg
	mkisofs -o boot_cd.iso -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table boot_cd

iso: boot_cd.iso

upload:  boot_cd.iso
	. /etc/default/elastichosts && \
	 bin/elastichosts-upload $(DRIVE_UUID) -s boot_cd.iso

clean:
	rm -rf boot_cd

# do not run this lightly if there may be clients active - they are
# using this directory
distclean: clean
	rm -rf nfsroot 
