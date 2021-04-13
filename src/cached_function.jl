struct CachedFunction{F,I,O,S}
    f!::F
    input::I #prototype info for input
    output::O #prototype info for input
    x_cache::IdDict{DataType, S}
    closures::IdDict{DataType, Any}
    f_calls::Vector{Int64}
    lock::ReentrantLock
end

function CachedFunction(f!,_in::SIZE{N1},_out::SIZE{N2}) where {N1,N2}
    input = Prototype(Array{Float64,N1},(Float64,_in))
    output = Prototype(Array{Float64,N2},(Float64,_out))
    x_cache =  IdDict{DataType,Array{Any,N1}}()
    closures = IdDict{DataType, Any}()
    f_calls = [0]
    lock = ReentrantLock()
    return CachedFunction(f!,input,output,x_cache,closures,f_calls,lock)
end


function CachedFunction(f!,_in::T1,out::T2) where {T1,T2}
    input = prototype(_in)
    output = prototype(out)
    x_cache =  IdDict{DataType,T1.name.wrapper}()
    closures = IdDict{DataType, Any}()
    f_calls = [0]
    lock = ReentrantLock()
    return CachedFunction(f!,input,output,x_cache,closures,f_calls,lock)
end

function CachedFunction(f!,_in::Int,_out::Int) 
    return CachedFunction(f!,(_in,),(_out,))
end



#creates an instance of the cache, using the storage_type and the size. uses type constructor

#generates an array of _eltype in


function make_closure!(f!,prototype,elem_type)
    out_cache = make_cache!(f!,prototype,elem_type)
    return x -> f!(out_cache, x)
end

function make_closure!(f!,prototype,elem_type,t)
    out_cache = make_cache!(f!,prototype,elem_type)
    return (x,t) -> f!(out_cache, x,t)
end

function make_closure!(f!,prototype,elem_type,t1,t2)
    out_cache = make_cache!(f!,prototype,elem_type)
    return (x,t1,t2) -> f!(out_cache, x,t1,t2)
end

eval_f(f::F, x) where {F} = f(x) 
eval_f(f::F, x,t) where {F} = f(x,t) 
eval_f(f::F, x,t1,t2) where {F} = f(x,t1,t2) 

function (cfn::CachedFunction{F})(x) where {F}
    X = valtype(x)
    f = get!(() -> make_closure!(cfn.f!, cfn.output, X),cfn.closures,X)
    cfn.f_calls[] +=1
    return eval_f(f, x)
end

function (cfn::CachedFunction{F})(x,t) where {F}
    X = promote_type(valtype(x),eltype(t))
    f = get!(() -> make_closure!(cfn.f!, cfn.output, X,t),cfn.closures,X)
    cfn.f_calls[] +=1
    return eval_f(f, x, t)
end

function (cfn::CachedFunction{F})(x,t1,t2) where {F}
    X = promote_type(valtype(x),eltype(t1),eltype(t2))
    f = get!(() -> make_closure!(cfn.f!, cfn.output, X,t1,t2),cfn.closures,X)
    cfn.f_calls[] +=1
    return eval_f(f, x, t)
end

function allocate!(cfn::CachedFunction{F},x)  where {F}
    X = valtype(x)
    get!(() -> x,cfn.x_cache,X)
    get!(() -> make_closure!(cfn.f!, cfn.output, X),cfn.closures,X)
    return nothing
end

function allocate!(cfn::CachedFunction{F},x::Type{X})  where {F,X}
    get!(() -> make_cache!(cfn.f!, cfn.input, X),cfn.x_cache,X)
    get!(() -> make_closure!(cfn.f!, cfn.output, X),cfn.closures,X)
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
function output(cfn::CachedFunction)
    if length(cfn.closures) == 1
        return last(first(cfn.closures)).out_cache
    elseif length(cfn.closures) == 0
        error("there aren't any output caches allocated in cached function")
    else
        error("there are more than one type of output cache stored in cached function.")
    end
end

function output(cfn::CachedFunction,x::Type{T}) where T
    if length(cfn.closures) == 0
        error("there aren't any output caches allocated in cached function.")
    else
        res = get(cfn.closures,T,nothing)
        if isnothing(res)
            TT = T.name.wrapper
        error("there aren't any output caches of type $TT in cached function.")
        else
            return res.out_cache
        end
    end
end

output(f::CachedFunction,x) = output(f,valtype(x))



###input####

function input(cfn::CachedFunction,x::Type{T}) where T
    if length(cfn.x_cache) == 0
        error("there aren't any input caches allocated in cached function")
    else
        res = get(cfn.x_cache,T,nothing)
        if isnothing(res)
        TT = T.name.wrapper
        error("there aren't any input caches of type $TT in cached function.")
        else
            return res
        end
    end
end

input(f::CachedFunction,x) = input(f,valtype(x))


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
    X = valtype(x)
    out = cfn.out_size
    if haskey(cfn.x_cache,X)
        xx = get(cfn.x_cache,X,nothing)
        copyto!(xx,x)
    else
        xx = get!(cfn.x_cache,X,x)
    end
    f = get!(() -> make_closure!(cfn.f!, cfn.output, X),cfn.closures,X)
    cfn.f_calls[1] +=1
    return eval_f(f, x)
end

function Base.show(io::IO, fn::CachedFunction)
    n_methods = length(fn.closures)
    _methods = n_methods == 1 ? "method" : "methods"
    name = string(fn.f!)
    print(io, "cached version of $name (function with $n_methods cached $_methods)")
end


cached_methods(f::CachedFunction) = f.closures


#lock methods
Base.islocked(cfn::CachedFunction) = islocked(cfn.lock)
Base.lock(f, cfn::CachedFunction) = lock(f, cfn.lock)
Base.trylock(f, cfn::CachedFunction) = trylock(f, cfn.lock)
