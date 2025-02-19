DESCRIPTION = "Userspace libraries for PowerVR SGX chipset on TI SoCs"
HOMEPAGE = "https://git.ti.com/graphics/omap5-sgx-ddk-um-linux"
LICENSE = "TI-TSPA"
LIC_FILES_CHKSUM = "file://TI-Linux-Graphics-DDK-UM-Manifest.doc;md5=550702a031857e0426ef7d6f6cf2d9f4"

COMPATIBLE_MACHINE = "ti33x|ti43x|omap-a15"
PACKAGE_ARCH = "${MACHINE_SOCARCH}"

BRANCH = "ti-img-sgx/rocko/${PV}"

SRC_URI = "\
    git://git.ti.com/graphics/omap5-sgx-ddk-um-linux.git;protocol=git;branch=${BRANCH} \
    file://0001-rc.pvr-add-proper-error-return-code.patch \
    file://0002-rc.pvr-don-t-load-the-bc_example-module.patch \
"
SRCREV = "bc62c9d0c590dfbc801bf6b10176c3a8b6a39d98"

# There's only hardfp version available
inherit tune_features_check
REQUIRED_TUNE_FEATURES = "arm vfp thumb callconvention-hard"

TARGET_PRODUCT_omap-a15 = "jacinto6evm"
TARGET_PRODUCT:ti33x = "ti335x"
TARGET_PRODUCT_ti43x = "ti437x"

INITSCRIPT_NAME = "rc.pvr"
INITSCRIPT_PARAMS = "defaults 8"

inherit update-rc.d

PR = "r32"
PROVIDES += "virtual/egl virtual/libgles1 virtual/libgles2 omap5-sgx-ddk-um-linux"

DEPENDS += "libdrm udev libgbm wayland libffi"
RDEPENDS:${PN} += "libdrm libudev libgbm wayland libffi libdrm-omap"

RPROVIDES:${PN} = "libegl libgles1 libgles2 omap5-sgx-ddk-um-linux"
RPROVIDES:${PN}-dev = "libegl-dev libgles1-dev libgles2-dev omap5-sgx-ddk-um-linux-dev"
RPROVIDES:${PN}-dbg = "libegl-dbg libgles1-dbg libgles2-dbg omap5-sgx-ddk-um-linux-dbg"

RPROVIDES:${PN} += "libGLESv2.so.1"

RREPLACES:${PN} = "libegl libgles1 libgles2 omap5-sgx-ddk-um-linux"
RREPLACES:${PN}-dev = "libegl-dev libgles1-dev libgles2-dev omap5-sgx-ddk-um-linux-dev"
RREPLACES:${PN}-dbg = "libegl-dbg libgles1-dbg libgles2-dbg omap5-sgx-ddk-um-linux-dbg"

RCONFLICTS:${PN} = "libegl libgles1 libgles2 omap5-sgx-ddk-um-linux"
RCONFLICTS:${PN}-dev = "libegl-dev libgles1-dev libgles2-dev omap5-sgx-ddk-um-linux-dev"
RCONFLICTS:${PN}-dbg = "libegl-dbg libgles1-dbg libgles2-dbg omap5-sgx-ddk-um-linux-dbg"

S = "${WORKDIR}/git"

do_install () {
    oe_runmake install DESTDIR=${D} TARGET_PRODUCT=${TARGET_PRODUCT}
    mkdir -p ${D}${libdir}/gbm
    ln -sf ../libpvrGBMWSEGL.so.${PV} ${D}${libdir}/gbm/gbm_pvr.so
    ln -sf libGLESv2.so.${PV} ${D}${libdir}/libGLESv2.so.1

    rm -f ${D}${libdir}/pkgconfig/wayland-egl.pc

    # fix host-user-contaminated files
    chown -R root.root ${D}
}

FILES:${PN} =  "${bindir}/*"
FILES:${PN} += " ${libdir}/*"
FILES:${PN} +=  "${includedir}/*"
FILES:${PN} +=  "${sysconfdir}/*"

PACKAGES =+ "${PN}-plugins"
FILES:${PN}-plugins = "${libdir}/libsrv_init.so ${libdir}/libsrv_um.so ${libdir}/libglslcompiler.so ${libdir}/libPVRScopeServices.so ${libdir}/libGLESv2.so ${libdir}/libGLES_CM.so ${libdir}/libpvrDRMWSEGL.so  ${libdir}/libpvrGBMWSEGL.so  ${libdir}/libpvrws_WAYLAND.so"
RDEPENDS:${PN} += "${PN}-plugins"

ALLOW_EMPTY:${PN}-plugins = "1"

INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_SYSROOT_STRIP = "1"

INSANE_SKIP:${PN} += "dev-so ldflags useless-rpaths already-stripped"
INSANE_SKIP:${PN}-plugins = "dev-so"

CLEANBROKEN = "1"
