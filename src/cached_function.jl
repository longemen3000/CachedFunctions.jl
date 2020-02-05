#real size, returns size or length





struct CachedFunction{F,S,I,O,L}
    f!::F
    storage_type::S ##by default, a plain array
    in_size::SIZE{I} #a ntuple of ints
    out_size::SIZE{O} #a ntuple of ints
    x_cache::IdDict{DataType, S}
    closures::IdDict{DataType, Function}
    f_calls::Vector{Int64}
    lock::L
end





function CachedFunction(f!,_in::SIZE,out::SIZE,stype=Array) 
    storage_type = type_constructor(stype,out)
    in_size = _in
    out_size = out
    x_cache =  IdDict{DataType,type_constructor(stype,in)}()
    closures = IdDict{DataType, Function}()
    f_calls = [0]
    lock = ReentrantLock()
    return CachedFunction(f!,storage_type,in_size,out_size,x_cache,closures,f_calls,lock)
end

#creates an instance of the cache, using the storage_type and the size. uses type constructor

#generates an array of _eltype in


function make_closure!(f!,stype,_eltype,_size)
    out_cache = make_cache!(f!,stype,_eltype,_size)
    return x -> f!(out_cache, x)
end

eval_f(f::F, x) where {F} = f(x) 

function (cfn::CachedFunction{F,O})(x) where {F,O}
    X = _eltype(x)
    out = cfn.out_size
    f = get!(() -> make_closure!(cfn.f!,O,X,out), cfn.closures, X)
    cfn.f_calls[1] +=1
    return eval_f(f, x)
end

function allocate!(cfn::CachedFunction{F,O},x)  where {F,O}
    X = _eltype(x)
    out = cfn.out_size
    _in = cfn.in_size
    get!(cfn.x_cache,X, x) #if x is not of the correct type, then it will throw an error.
    get!(() ->  make_closure!(cfn.f!,O,X,out), cfn.closures, X)
    return nothing
end

function allocate!(cfn::CachedFunction{F,O},x::Type{X})  where {F,O,X}
    out = cfn.out_size
    _in = _size(cfn.in_size)
    get!(cfn.x_cache,X, make_cache!(cfn.f!,O,X,_in))
    get!(() -> make_closure!(cfn.f!,O,X,out), cfn.closures, X)
    return nothing
end
#@btime c($[1.0,2.0])




###calls###
"""
returns how many times has ´f´ been called.
"""
calls(f::CachedFunction) = f.f_calls[]


###output####

"""
returns the output cache stored in ´f´
Returns `f(x)`, it doesn' t store the input.
if your function has only one type cached, you can get the output cache without adding the type.
"""
function output(f::CachedFunction)
    if length(c.closures) == 1
        return last(first(c.closures)).out_cache
    elseif length(c.closures) == 0
        error("there aren't any output caches allocated in cached function")
    else
        error("there are more than one type of output cache stored in cached function.")
    end
end

function output(f::CachedFunction,x::Type{T}) where T
    if length(c.closures) == 0
        error("there aren't any output caches allocated in cached function.")
    else
        res = get(c.closures,T,nothing)
        if isnothing(res)
            TT = T.name.wrapper
        error("there aren't any output caches of type $TT in cached function.")
        else
            return res.out_cache
        end
    end
end

output(f::CachedFunction,x) = output(f,_eltype(x))



###input####

function input(f::CachedFunction,x::Type{T}) where T
    if length(c.x_cache) == 0
        error("there aren't any input caches allocated in cached function")
    else
        res = get(c.x_cache,T,nothing)
        if isnothing(res)
        TT = T.name.wrapper
        error("there aren't any input caches of type $TT in cached function.")
        else
            return res
        end
    end
end

input(f::CachedFunction,x) = input(f,_eltype(x))


####evaluate#####
"""
Evaluates the cached function at `x`.
Returns `f(x)`, it doesn' t store the input
"""
evaluate(f::CachedFunction,x) = f(x)



####evaluate!#####
##evaluates cached_f and stores x

"""
    evaluate!(f,x)

Force (re-)evaluation of the cached function at `x`.
Returns `f(x)` and stores the input value.

"""
function evaluate!(cfn::CachedFunction,x)
    X = _eltype(x)
    out = cfn.out_size
    if haskey(cfn.x_cache,X)
        xx = get(cfn.x_cache,X,nothing)
        copyto!(xx,x)
    else
        xx = get!(cfn.x_cache,X,x)
    end
    f = get!(() -> make_closure!(cfn.f!, x,out), cfn.closures, X)
    cfn.f_calls[1] +=1
    return eval_f(f, xx)
end


function Base.show(io::IO, fn::CachedFunction)
    n_methods = length(fn.closures)
    _methods = n_methods == 1 ? "method" : "methods"
    name = string(fn.f!)
    println(io, "cached version of $name (function with $n_methods cached $_methods)")
end


methods(f::CachedFunction) = f.closures


#lock methods
Base.islocked(cfn::CachedFunction) = islocked(cfn.lock)
Base.lock(f, cfn::CachedFunction) = lock(f, cfn.lock)
Base.trylock(f, cfn::CachedFunction) = trylock(f, cfn.lock)
