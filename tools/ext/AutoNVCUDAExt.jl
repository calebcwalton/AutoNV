module AutoNVCUDAExt
using AutoNV
using CUDA
# Argument dispatch avoids overwriting parent methods during precompilation.
AutoNV._cuda_available(::Val{:loaded}) = CUDA.functional()
AutoNV._cuda_transfer(A::Matrix{ComplexF64}) = CUDA.CuArray{ComplexF64}(A)
AutoNV._cuda_sync(::Val{:loaded}) = CUDA.synchronize()
end
