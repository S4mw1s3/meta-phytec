inherit image_types
# Copyright (C) 2014 Jan weitzel <j.weitzel@phytec.de> \
# # PHYTEC Messtechnik GmbH
# based on meta-raspberrypi/classes/sdcard_image-rpi.bbclass
#
# (C) Copyright 2015 Phytec Messtechnik GmbH
# Author: Daniel Schultz <d.schultz@phytec.de>
#
# Create an image that can by written onto a SD card using dd.
#
# The disk layout (sdcard) used is:
#
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - reserved for other data
#    IMAGE_ROOTFS_ALIGNMENT -> BOOT_SPACE                     - bootloader and kernel
#    BOOT_SPACE             -> SDIMG_SIZE                     - rootfs
#

#                                                     Default Free space = 1.3x
#                                                     Use IMAGE_OVERHEAD_FACTOR to add more space
#                                                     <--------->
#            4MiB              20MiB           SDIMG_ROOTFS
# <-----------------------> <----------> <---------------------->
#  ------------------------ ------------ ------------------------
# | IMAGE_ROOTFS_ALIGNMENT | BOOT_SPACE | ROOTFS_SIZE            |
#  ------------------------ ------------ ------------------------
# ^                        ^            ^                        ^
# |                        |            |                        |
# 0                      4MiB     4MiB + 20MiB       4MiB + 20Mib + SDIMG_ROOTFS

# The disk layout (emmc) used is:
#
#    0                      -> IMAGE_ROOTFS_ALIGNMENT         - MBR and MLOs
#    IMAGE_ROOTFS_ALIGNMENT -> BOOT_SPACE                     - bootloader and kernel
#    BOOT_SPACE             -> EMMCIMG_SIZE                   - rootfs
#

#                                                     Default Free space = 1.3x
#                                                     Use IMAGE_OVERHEAD_FACTOR to add more space
#                                                     <--------->
#            4MiB              20MiB           EMMCIMG_ROOTFS
# <-----------------------> <----------> <---------------------->
#  ------------------------ ------------ ------------------------
# | IMAGE_ROOTFS_ALIGNMENT | BOOT_SPACE | ROOTFS_SIZE            |
#  ------------------------ ------------ ------------------------
# ^     ^     ^     ^      ^            ^                        ^
# |     |     |     |      |            |                        |
# |     |     |     |      4MiB         4MiB + 20MiB             4MiB + 20Mib + EMMCIMG_ROOTFS
# |     |     |     393KiB MLO
# |     |     262KiB MLO
# |     131KiB MLO
# 0 MLO + partition table
#

# This image depends on the rootfs image
IMAGE_TYPEDEP_sdcard = "${SDIMG_ROOTFS_TYPE}"
IMAGE_TYPEDEP_emmc = "${SDIMG_ROOTFS_TYPE}"

# Boot partition volume id
BOOTDD_VOLUME_ID ?= "boot"

# Root partition volume id
ROOT_VOLUME_ID ?="root"

# Boot partition size [in KiB] (will be rounded up to IMAGE_ROOTFS_ALIGNMENT)
BOOT_SPACE ?= "20480"

# Set alignment to 4MB [in KiB]
IMAGE_ROOTFS_ALIGNMENT = "4096"

# Use an uncompressed ext4 by default as rootfs
SDIMG_ROOTFS_TYPE ?= "ext4"
SDIMG_ROOTFS = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.${SDIMG_ROOTFS_TYPE}"

IMAGE_DEPENDS_sdcard = " \
    parted-native \
    mtools-native \
    dosfstools-native \
    e2fsprogs-native \
    virtual/kernel:do_deploy \
    virtual/bootloader:do_deploy \
    virtual/prebootloader:do_deploy \
"
IMAGE_DEPENDS_emmc = " \
    parted-native \
    mtools-native \
    dosfstools-native \
    e2fsprogs-native \
    virtual/kernel:do_deploy \
    virtual/bootloader:do_deploy \
    virtual/prebootloader:do_deploy \
"

BOOTIMG_sdcard = "boot_sdcard.img"
BOOTIMG_emmc = "boot_emmc.img"

# SD image names
SDIMG_sdcard = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.sdcard"
SDIMG_emmc = "${DEPLOY_DIR_IMAGE}/${IMAGE_NAME}.rootfs.emmc"

# Compression method to apply to SDIMG after it has been created. Supported
# compression formats are "gzip", "bzip2" or "xz". The original .sdcard file
# is kept and a new compressed file is created if one of these compression
# formats is chosen. If SDIMG_COMPRESSION is set to any other value it is
# silently ignored.
#SDIMG_COMPRESSION ?= ""

# Additional files and/or directories to be copied into the vfat partition from the IMAGE_ROOTFS.
FATPAYLOAD ?= ""

# Copy additional images to the vfat partition
FATPAYLOAD_IMG ?= "${DEPLOY_DIR_IMAGE}/${IMAGE_LINK_NAME}.ubifs"

IMAGEDATESTAMP = "${@time.strftime('%Y.%m.%d',time.gmtime())}"

IMAGE_CMD_sdcard () {

	create_image ${SDIMG_sdcard}

	populate_boot_part ${SDIMG_sdcard} ${BOOTIMG_sdcard}

	finish_image ${SDIMG_sdcard} ${BOOTIMG_sdcard}

	populate_root_part ${SDIMG_sdcard}

	do_compression ${SDIMG_sdcard}

}

IMAGE_CMD_emmc () {

	create_image ${SDIMG_emmc}

	populate_boot_part ${SDIMG_emmc} ${BOOTIMG_emmc}

	finish_image ${SDIMG_emmc} ${BOOTIMG_emmc}

	populate_root_part  ${SDIMG_emmc}

	# copy the MLO to address 0x20000, 0x40000, 0x60000
	dd if=${DEPLOY_DIR_IMAGE}/${BAREBOX_IPL_BIN_SYMLINK} of=${SDIMG_emmc} seek=768 bs=512 conv=notrunc
	dd if=${DEPLOY_DIR_IMAGE}/${BAREBOX_IPL_BIN_SYMLINK} of=${SDIMG_emmc} seek=512 bs=512 conv=notrunc
	dd if=${DEPLOY_DIR_IMAGE}/${BAREBOX_IPL_BIN_SYMLINK} of=${SDIMG_emmc} seek=256 bs=512 conv=notrunc

	# copy the MLO to address 0x0 and keep the partition table
	dd if=${DEPLOY_DIR_IMAGE}/${BAREBOX_IPL_BIN_SYMLINK} of=${SDIMG_emmc} bs=446 count=1 conv=notrunc
	dd if=${DEPLOY_DIR_IMAGE}/${BAREBOX_IPL_BIN_SYMLINK} of=${SDIMG_emmc} skip=1 seek=1 conv=notrunc

	do_compression ${SDIMG_emmc}

}

create_image () {

	SDIMG=$1

	if [ -n ${FATPAYLOAD_IMG} ] ; then
		# Caclulate size of aditional image in KiB
		FATPAYLOAD_IMG_SIZE=$(expr $(stat -L -c%s "${FATPAYLOAD_IMG}") / 1024)
	else
		FATPAYLOAD_IMG_SIZE=0
	fi

	# Align partitions
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE} + ${FATPAYLOAD_IMG_SIZE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
	BOOT_SPACE_ALIGNED=$(expr ${BOOT_SPACE_ALIGNED} - ${BOOT_SPACE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
	ROOTFS_SIZE=`du -bks ${SDIMG_ROOTFS} | awk '{print $1}'`
        # Round up RootFS size to the alignment size as well
	ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE} + ${IMAGE_ROOTFS_ALIGNMENT} - 1)
	ROOTFS_SIZE_ALIGNED=$(expr ${ROOTFS_SIZE_ALIGNED} - ${ROOTFS_SIZE_ALIGNED} % ${IMAGE_ROOTFS_ALIGNMENT})
	SDIMG_SIZE=$(expr ${IMAGE_ROOTFS_ALIGNMENT} + ${BOOT_SPACE_ALIGNED} + ${ROOTFS_SIZE_ALIGNED})

	echo "Creating filesystem with Boot partition ${BOOT_SPACE_ALIGNED} KiB and RootFS ${ROOTFS_SIZE_ALIGNED} KiB"

	# Initialize sdcard image file
	dd if=/dev/zero of=${SDIMG} bs=1024 count=0 seek=${SDIMG_SIZE}

	# Create partition table
	parted -s ${SDIMG} mklabel msdos
	# Create boot partition and mark it as bootable
	parted -s ${SDIMG} unit KiB mkpart primary fat32 ${IMAGE_ROOTFS_ALIGNMENT} $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT})
	parted -s ${SDIMG} set 1 boot on
	# Create rootfs partition to the end of disk
	parted -s ${SDIMG} -- unit KiB mkpart primary ext2 $(expr ${BOOT_SPACE_ALIGNED} \+ ${IMAGE_ROOTFS_ALIGNMENT}) -1s
	parted ${SDIMG} print

}

finish_image () {

	SDIMG=$1
	BOOTIMG=$2

	# Burn Partitions
	dd if=${WORKDIR}/${BOOTIMG} of=${SDIMG} conv=notrunc,fsync seek=1 bs=$(expr ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)

}

populate_boot_part () {

	SDIMG=$1
	BOOTIMG=$2

	# Create a vfat image with boot files
	BOOT_BLOCKS=$(LC_ALL=C parted -s ${SDIMG} unit b print | awk '/ 1 / { print substr($4, 1, length($4 -1)) / 512 /2 }')
	mkfs.vfat -n "${BOOTDD_VOLUME_ID}" -S 512 -C ${WORKDIR}/${BOOTIMG} $BOOT_BLOCKS
	mcopy -i ${WORKDIR}/${BOOTIMG} -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${MACHINE}.bin ::linuximage
	mcopy -i ${WORKDIR}/${BOOTIMG} -s ${DEPLOY_DIR_IMAGE}/${KERNEL_IMAGETYPE}-${KERNEL_DEVICETREE} ::oftree

	case "${PREFERRED_PROVIDER_virtual/bootloader}" in
	"barebox")
		mcopy -i ${WORKDIR}/${BOOTIMG} -s ${DEPLOY_DIR_IMAGE}/barebox.bin ::
		mcopy -i ${WORKDIR}/${BOOTIMG} -s ${DEPLOY_DIR_IMAGE}/${BAREBOX_IPL_BIN_SYMLINK} ::
		;;
	*)
		;;
	esac
	if [ -n ${FATPAYLOAD} ] ; then
		echo "Copying payload into VFAT"
		for entry in ${FATPAYLOAD} ; do
				# add the || true to stop aborting on vfat issues like not supporting .~lock files
				mcopy -i ${WORKDIR}/${BOOTIMG} -s -v ${IMAGE_ROOTFS}$entry :: || true
		done
	fi

	if [ -n ${FATPAYLOAD_IMG} ] ; then
		echo "Copying payload image into VFAT"
		for entry in ${FATPAYLOAD_IMG} ; do
				# add the || true to stop aborting on vfat issues like not supporting .~lock files
				mcopy -i ${WORKDIR}/${BOOTIMG} -s -v $entry :: || true
		done
	fi

	# Add stamp file
	echo "${IMAGE_NAME}-${IMAGEDATESTAMP}" > ${WORKDIR}/image-version-info
	mcopy -i ${WORKDIR}/${BOOTIMG} -v ${WORKDIR}//image-version-info ::

}

populate_root_part () {

	SDIMG=$1

	# If SDIMG_ROOTFS_TYPE is ext2/3/4 set root volume id
	if echo "${SDIMG_ROOTFS_TYPE}" | egrep "ext[2|3|4]"
	then
		tune2fs -L ${ROOT_VOLUME_ID} ${SDIMG_ROOTFS}
	fi

	# If SDIMG_ROOTFS_TYPE is a .xz file use xzcat
	if echo "${SDIMG_ROOTFS_TYPE}" | egrep -q "*\.xz"
	then
		xzcat ${SDIMG_ROOTFS} | dd of=${SDIMG} conv=notrunc,fsync seek=1 bs=$(expr 1024 \* ${BOOT_SPACE_ALIGNED} + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
	else
		dd if=${SDIMG_ROOTFS} of=${SDIMG} conv=notrunc,fsync seek=1 bs=$(expr 1024 \* ${BOOT_SPACE_ALIGNED} + ${IMAGE_ROOTFS_ALIGNMENT} \* 1024)
	fi

}

do_compression () {

	SDIMG=$1

	# Optionally apply compression
	case "${SDIMG_COMPRESSION}" in
	"gzip")
		gzip -k9 "${SDIMG}"
		;;
	"bzip2")
		bzip2 -k9 "${SDIMG}"
		;;
	"xz")
		xz -k "${SDIMG}"
		;;
	esac

}

#FIXME check this first
#ROOTFS_POSTPROCESS_COMMAND += " rpi_generate_sysctl_config ; "

#rpi_generate_sysctl_config() {
#	# systemd sysctl config
#	test -d ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d && \
#		echo "vm.min_free_kbytes = 8192" > ${IMAGE_ROOTFS}${sysconfdir}/sysctl.d/rpi-vm.conf
#
#	# sysv sysctl config
#	IMAGE_SYSCTL_CONF="${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf"
#	test -e ${IMAGE_ROOTFS}${sysconfdir}/sysctl.conf && \
#		sed -e "/vm.min_free_kbytes/d" -i ${IMAGE_SYSCTL_CONF}
#	echo "" >> ${IMAGE_SYSCTL_CONF} && echo "vm.min_free_kbytes = 8192" >> ${IMAGE_SYSCTL_CONF}
#}
