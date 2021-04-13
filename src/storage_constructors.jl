#quality of life constants
const SIZE = NTuple{N,Int} where N 
const LENGTH = SIZE{1}


#prototype abstract, stores the storage type in S
abstract type AbstractPrototype{S} end


#prototype stores the type to dispatch and the data necesary to create a new instance of other element types.
struct Prototype{S,T}
    type::S
    data::T #a tuple to store associated data
end


prototype(x::T) where T<:Array = Prototype(T,(eltype(x),size(x)))
prototype(d::T) where T<:Dict = Prototype(T,(valtype(d),d.slots, d.keys, d.ndel, d.count, d.age, d.idxfloor, d.maxprobe))
prototype(sv::T) where T<:SparseArrays.SparseVector = Prototype(T,(eltype(sv),sv.n,sv.nzind))                            
prototype(sm::T) where T<:SparseArrays.SparseMatrixCSC = Prototype(T,(eltype(sm),size(sm),sm.rowval,sm.colptr))                            


function make_cache!(f!,p::P,elem_type) where {P <: Prototype}
    return make_cache!(p.type,f!,p,elem_type)
end

function make_cache!(::Type{T1},f!,p::P,elem_type::Type{T2}) where {T1 <: Array, P <: Prototype, T2}
    s = p.data[2]
    n = length(s)
    return Array{T2,n}(undef,s)
end

#the approach here is more like Dictionaries.jl
function make_cache!(::Type{T1},f!,p::P,elem_type::Type{T2}) where {T1 <: Dict, P <: Prototype, T2}
    t, slots, keys, ndel, count, age, idxfloor, maxprobe = p.data
    n = length(slots)
    K = eltype(keys)
    vals = Vector{T2}(undef,n)
    return Dict{K,T2}(slots,keys,vals,ndel,count,age,idxfloor,maxprobe) 
end

function make_cache!(::Type{T1},f!,p::P,elem_type::Type{T2}) where {T1 <: SparseArrays.SparseVector, P <: Prototype, T2,K,V}
    t,n,nzind = p.data
    nzval = Vector{T2}(undef,n)
    return SparseArrays.SparseVector{T2,eltype(nzind)}(n,nzind,nzval)
end

function make_cache!(::Type{T1},f!,p::P,elem_type::Type{T2}) where {T1 <: SparseArrays.SparseMatrixCSC, P <: Prototype, T2,K,V}
    t,s,rowval,colptr = p.data
    m,n = s
    l = length(rowval)
    t,n,nzind = p.data
    nzval = Vector{T2}(undef,l)
    return SparseArrays.SparseVector{T2,eltype(nzind)}(m,n,colptr,nzind,nzval)
end



