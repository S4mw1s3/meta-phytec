set_doraucboot_1 () {
    bbnote "Setting \"doraucboot\" to \"1\""
    sed -i "s/\(setenv doraucboot \)[01]/\11/" ${S}/include/configs/phycore_*.h
}

python do_patch:append:update () {
    bb.build.exec_func('set_doraucboot_1', d)
}
