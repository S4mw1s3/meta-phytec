FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

# Load with up to 4GB DDR size for i.mx8 mini and nano. Also unify TZDRAM start address
CONF_NANO_MINI = "CFG_DDR_SIZE=0x100000000 CFG_TZDRAM_START=0x56000000 CFG_CORE_LARGE_PHYS_ADDR=y CFG_CORE_ARM64_PA_BITS=36"
EXTRA_OEMAKE:append:mx8mm-nxp-bsp = " ${CONF_NANO_MINI} "
EXTRA_OEMAKE:append:mx8mn-nxp-bsp = " ${CONF_NANO_MINI} "
