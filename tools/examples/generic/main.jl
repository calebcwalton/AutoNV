using AutoNV

# Illustrative candidate, not the synthetic device's hidden Hamiltonian.
# Parameters are MHz; the constructor converts to radians per microsecond.
build_model() = generic_qubit_model(
    omega_x_mhz=0.07, omega_y_mhz=-0.04, omega_z_mhz=0.31)
