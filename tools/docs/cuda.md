# Optional CUDA environment

The default environment is CPU-only. On a machine with an NVIDIA CUDA device,
create the separate local environment once from the checkout root:

```sh
julia --project=tools -e 'using Pkg; Pkg.activate("workspace/environments/cuda"); Pkg.develop(path="tools"); Pkg.add(PackageSpec(name="CUDA", version="6")); Pkg.instantiate()'
AUTONV_PROJECT="$PWD/workspace/environments/cuda" tools/bin/autonv simulate --system nv --backend cuda
```

The CUDA environment has its own generated manifest. Its path dependency points
to `tools/`; regenerate it after moving the checkout. Its files stay in the writable
workspace so research setup does not edit maintained tool files. Keep the CPU manifest
independent. CUDA.jl installs its runtime when needed; a compatible NVIDIA driver
must be provided by the host. This does not enable CUDA on Apple GPUs.

In Julia, load the optional extension with `using CUDA, AutoNV`, then call
`predict_batch(model, experiments; backend=:cuda)`. The CLI loads CUDA when its
active environment contains it. `auto` selects a functional CUDA device or falls
back to CPU; `cuda` explicitly requested without a working device is an error.

Operators and dense Liouvillians are assembled on the CPU and transferred to the
device; QuantumToolbox evolves device states and performs their matrix products
on CUDA. Independent experiments use bounded tasks
with CUDA's task-local streams; this is concurrent GPU work, not a fused
trajectory kernel. A single qubit or small register often runs faster on CPU.
Both backends use double precision and the same probability/solver checks.

Run the tests in the CUDA environment after setup:

```sh
julia --project=workspace/environments/cuda --threads=auto -e 'using CUDA; include("tools/test/runtests.jl")'
```

See [QuantumToolbox CUDA support](https://qutip.org/QuantumToolbox.jl/stable/users_guide/extensions/cuda)
and [CUDA.jl installation](https://cuda.juliagpu.org/stable/installation/overview/).
