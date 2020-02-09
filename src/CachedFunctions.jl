module CachedFunctions
using SparseArrays
export CachedFunction, input, output, evaluate, evaluate!, calls, allocate!

include("storage_constructors.jl")
include("cached_function.jl")

end # module
