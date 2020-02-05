#quality of life constants
const SIZE = NTuple{N,Int} where N 
const LENGTH = SIZE{1}

#overload of size to always use tuples
function _size(out::OUT) where OUT
    if Base.IteratorSize(OUT) == Base.HasLength() #linear struct
        return length(out)
    elseif typeof(Base.IteratorSize(OUT)) <: Base.HasShape #sized struct
        return size(out)
    else
        error("the size of the output is not known")
    end
end

function _size(out::SIZE)
    return out
end

function _size(out::Int)
    return (out,)
end



#like eltype, but gives the value type with dicts
_eltype(x) = eltype(x)
function _eltype(x::T) where T<:AbstractDict{K,V} where {K,V}
    return V 
end

#provide errors when the type cannot conform to the size
function _only1d_error(type)
    _type = type.name.wrapper
    return error("incorrect size provided. The $_type type can only have length.")
end

#provide errors when the type cannot conform to the size
function _only2d_error(type)
    _type = type.name.wrapper
    return error("incorrect size provided. The $_type type can only two dimensions.")
end



#used to generate an appropiate type constructor for storage
#the storage should only depend on the element type and the size, nothing more, nothing less.



#instance of type instead of type
type_constructor(storage_type,size::SIZE) = type_constructor(typeof(storage_type),size)
    
#array
function type_constructor(storage_type::Type{T1},size::SIZE) where T1 <: AbstractArray{T2,T3} where {T2,T3}
    return storage_type.name.wrapper{T,prod(size)} where T
end

#sparse vector
function type_constructor(storage_type::Type{T1},size::LENGTH) where T1 <: SparseVector
    return SparseVector{T,Int64} where T
end

#sparse vector error with different sizes
function type_constructor(storage_type::Type{T1},size::SIZE) where T1 <: SparseVector
    return _only1d_error(T1)
end

#sparse matrix
function type_constructor(storage_type::Type{T1},size::SIZE{2}) where T1 <: SparseMatrixCSC
    return SparseMatrixCSC{T,Int64} where T
end

#sparse matrix  error with different sizes
function type_constructor(storage_type::Type{T1},size::SIZE) where T1 <: SparseMatrixCSC
    return _only2d_error(T1)
end


#abstract dict
function type_constructor(storage_type::Type{T1},size::LENGTH) where T1 <: AbstractDict{K,V} where {K,V}
    return storage_type.name.wrapper{K,T} where T
end

#abstract dict error
function type_constructor(storage_type::Type{T1},size::SIZE) where T1 <: AbstractDict{K,V} where {K,V}
    return _only1d_error(T1)
end




#make_cache! generates an instance of the object, given its storage type and size

#general constructor for arrays
function make_cache!(f!,storage_type::T1,element_type,_size::SIZE) where T1 <: AbstractArray
    t = type_constructor(storage_type,_size){element_type}
    return t(undef,_size)
end

#sparse matrix
function make_cache!(f!,storage_type::T1,element_type,_size::SIZE{2}) where T1 <: SparseMatrixCSC
    return spzeros(storage_type,_size...)
end


#sparse vector
function make_cache!(f!,storage_type::T1,element_type,_size::LENGTH) where T1 <: SparseVector
    return spzeros(storage_type,first(_size))
end

#abstract dict
function make_cache!(f!,storage_type::T1,element_type,_size::LENGTH) where T1 <: AbstractDict{K,V} where {K,V}
    dict = type_constructor(storage_type,_size){element_type}()
    sizehint!(dict,prod(_size))
end