# Copyright (C) 2014-2015 PHYTEC Messtechnik GmbH,
# Author: Stefan Mueller-Klieser <s.mueller-klieser@phytec.de>
DESCRIPTION = "Linux Kernel Phytec common base"
SECTION = "kernel"
LICENSE = "GPL-2.0-only"
LIC_FILES_CHKSUM ?= "file://COPYING;md5=6bc538ed5bd9a7fc9398086aedcd7e46"

CVE_VERSION = "${@d.getVar("PV").split('-')[0]}"

inherit kernel
inherit kconfig

FILESEXTRAPATHS:prepend := "${THISDIR}/linux-common:"
SRC_URI:append = " \
  ${@bb.utils.contains('DISTRO_FEATURES', 'virtualization', 'file://lxc.cfg', '', d)} \
  ${@bb.utils.contains('DISTRO_FEATURES', 'virtualization', 'file://docker.cfg', '', d)} \
  ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'file://systemd.cfg', '', d)} \
  ${@bb.utils.contains('DEBUG_BUILD', '1', 'file://debugging.cfg', '', d)} \
  ${@bb.utils.contains('MACHINE_FEATURES', 'tpm2', 'file://tpm2.cfg', '', d)} \
  ${@bb.utils.contains('MACHINE_FEATURES', 'caam', 'file://caam.cfg', '',   d)} \
"

INC_PR = "r0"

DEPENDS += "lzop-native lz4-native"
PATCHTOOL = "git"

SRCTREECOVEREDTASKS ?= "do_unpack do_fetch"

include linux-common-secureboot.inc
# Copy .dts and .dtsi from SRC_URI to the kernel boot/dts path
# This should go to poky/meta/classes/kernel-devicetree.bbclass
# returns all the elements from the src uri that are .dts or .dtsi files
def find_dtss(d):
    sources=src_patches(d, True)
    dtss_list=[]
    for s in sources:
        base, ext = os.path.splitext(s)
        if ext in [".dtsi", ".dts"]:
            dtss_list.append(s)

    return dtss_list

def set_path(d, dts):
    k_dt = d.getVar('KERNEL_DEVICETREE', '')
    k_dt_list = k_dt.split()
    dtsb = os.path.basename(dts)
    base, ext = os.path.splitext(dtsb)
    dtsb = base + ".dtb"
    for tmp in k_dt_list:
        if dtsb in tmp:
            head, tail = os.path.split(tmp)
            return head
    return ''

python do_dtsfixup () {
    import shutil
    srcdir = d.getVar('STAGING_KERNEL_DIR')
    arch = d.getVar('ARCH')
    for dts in find_dtss(d):
        cptarget=os.path.join(srcdir, "arch", arch, "boot", "dts",
                              set_path(d, dts), os.path.basename(dts))
        bb.note("copying dts from: %s to: %s" % (dts, cptarget))
        shutil.copyfile(dts, cptarget)
}

addtask dtsfixup after do_symlink_kernsrc before do_compile

def get_oftree(d):
    kdt = d.getVar('KERNEL_DEVICETREE', '')
    return os.path.basename(kdt.split()[0])

KERNEL_IMAGE_NAME = "${KERNEL_IMAGETYPE}-${PN}-${PKGV}-${PKGR}-${MACHINE}${IMAGE_VERSION_SUFFIX}"
FIRST_DTS = "${@get_oftree(d)}"
do_deploy:append() {
    install -m 644 ${B}/.config ${DEPLOYDIR}/${KERNEL_IMAGE_NAME}.config
    ln -sf ${KERNEL_IMAGE_NAME}.config ${DEPLOYDIR}/${KERNEL_IMAGETYPE}.config
    if [ -z "${EXTERNAL_KERNEL_DEVICETREE}" ]; then
        ln -sf ${FIRST_DTS}  ${DEPLOYDIR}/oftree
    fi
}
