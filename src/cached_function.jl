#real size, returns size or length
function _size(out::OUT) where OUT
    if Base.IteratorSize(OUT) == Base.HasLength() #linear struct
        return length(out)
    elseif typeof(Base.IteratorSize(OUT)) <: Base.HasShape #sized struct
        return size(out)
    else
        error("the size of the output is not known")
    end
end

function _size(out::NTuple{N,Int}) where N
    return out
end

function _size(out::Int)
    return (out,)
end



struct CachedFunction{F,I,O}
    f!::F
    in_size::I
    out_size::O
    x_cache::IdDict{DataType, Union{AbstractArray,Number}}
    closures::IdDict{DataType, Function}
    f_calls::Vector{Int64}
end



CachedFunction(f!,in,out) = CachedFunction(f!,_size(in),_size(out),IdDict{DataType, Union{AbstractArray,Number}}(),IdDict{DataType, Function}(),[0])

function make_cache(f!,in,out) 
    return deepcopy(out)
end

function make_cache(f!,in,out::NTuple{N,Int}) where N 
    return similar(in,out)
end

#generates an array of eltype in
function make_cache(f!,in::Type{T},out::NTuple{N,Int}) where {T<:Number,N} 
    out_size = _size(out)
    return Array{T,length(out_size)}(undef,out_size)
end


function make_out_of_place_func(f!,in,out)
    out_cache = make_cache(f!,in,out)
    return x -> f!(out_cache, x)
end

eval_f(f::F, x) where {F} = f(x) 

function (cached_fn::CachedFunction{F,O})(x) where {F,O}
    X = eltype(x)
    out = cached_fn.out_size
    f = get!(() -> make_out_of_place_func(cached_fn.f!, x,out), cached_fn.closures, X)
    cached_fn.f_calls[1] +=1
    return eval_f(f, x)
end

function allocate!(cached_fn::CachedFunction{F,O},x)  where {F,O}
    X = eltype(x)
    out = cached_fn.out_size
    get!(cached_fn.x_cache,X,similar(x))
    get!(() -> make_out_of_place_func(cached_fn.f!, x,out), cached_fn.closures, X)
    return nothing
end

function allocate!(cached_fn::CachedFunction{F,O},x::Type{X})  where {F,O,X}
    out = cached_fn.out_size
    in_size = _size(cached_fn.in_size)
    xarray = Array{X,length(in_size)}(undef,in_size)
    get!(cached_fn.x_cache,X,xarray)
    get!(() -> make_out_of_place_func(cached_fn.f!, x,out), cached_fn.closures, X)
    return nothing
end
#@btime c($[1.0,2.0])




###calls###

calls(f::CachedFunction) = f.f_calls[]


###output####

"""
returns the output cache stored in ´f´
Returns `f(x)`, it doesn' t store the input
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
        error("there aren't any output caches of type $T in cached function.")
        else
            return res.out_cache
        end
    end
end

output(f::CachedFunction,x) = output(f,eltype(x))



###input####

function input(f::CachedFunction,x::Type{T}) where T
    if length(c.x_cache) == 0
        error("there aren't any input caches allocated in cached function")
    else
        res = get(c.x_cache,T,nothing)
        if isnothing(res)
        error("there aren't any input caches of type $T in cached function.")
        else
            return res
        end
    end
end

input(f::CachedFunction,x) = input(f,eltype(x))


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
function evaluate!(cached_fn::CachedFunction,x)
    X = eltype(x)
    out = cached_fn.out_size
    if haskey(cached_fn.x_cache,X)
        xx = get(cached_fn.x_cache,X,nothing)
        copyto!(xx,x)
    else
        xx = get!(cached_fn.x_cache,X,x)
    end
    f = get!(() -> make_out_of_place_func(cached_fn.f!, x,out), cached_fn.closures, X)
    cached_fn.f_calls[1] +=1
    return eval_f(f, xx)
end


function Base.show(io::IO, fn::CachedFunction)
    n_methods = length(fn.closures)
    _methods = n_methods == 1 ? "method" : "methods"
    name = string(fn.f!)
    println(io, "cached version of $name (function with $n_methods cached $_methods)")
end

methods(f::CachedFunction) = f.closures
