using AutoNV
length(ARGS) == 2 || error("usage: device.jl PRIVATE_DIRECTORY SYSTEM")
AutoNV.device_main(ARGS[1], ARGS[2])
