module CachedFunctions
import ForwardDiff
export CachedFunction, input, output, evaluate, evaluate!, calls, allocate!

include("cached_function.jl")

end # module
