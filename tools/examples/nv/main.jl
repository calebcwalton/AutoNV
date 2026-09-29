using AutoNV

# Illustrative physical-Sz convention: the ms=-1 branch has ωL-A_parallel.
# These sample parameters are not asserted properties of an unknown device.
build_model() = nv_model(detuning_mhz=0.03, omega_l_mhz=0.5,
                        a_parallel_mhz=0.08, a_perp_mhz=0.12)
