# CachedFunctions

[![Build Status](https://travis-ci.com/longemen3000/CachedFunctions.jl.svg?branch=master)](https://travis-ci.com/longemen3000/CachedFunctions.jl)

Bored of creating your cache each time when having a function `f!(out,x)`?

Problems defining a higher order jacobian with inplace functions?

Out of names for the output caches?

This package maybe can help you.

## limits

This package works with implace functions of the form: `f(out,x)`, where:
1. `eltype(x) == eltype(out)`
2. `x` is of type Array
help on easing those limits is appreciated.

## usage

This is the simplest way to use this Package:
```julia
#example inplace function
function f!(y,x)
    y[1] = exp(sum(x))
    y[2] = x[1]+x[2] - x[3]
    y
end

x1 = rand(3)
x2 = rand(3)
x3 = rand(Float32,3)
x4 = rand(Float32,3)

f = CachedFunction(f!,3,2) #if multidimentional, use CachedFunction(f!,(1,2),(2,3))
f(x1) #allocates one time
f(x2) #all caches created and allocated! 
evaluate(f,x1) #other way to call the function
f(x3) #a specific cache for Float32 is created
f(x4) #no allocations, again.
```

Let's see a little bit about what whe can do with this `f`

```julia-repl
julia> f
cached version of f! (function with 2 cached methods)
julia> calls(f)
5
julia> methods(f)
IdDict{DataType,Function} with 2 entries:
  Float64 => #198
  Float32 => #198
```
All the cached methods are stored in `methods(f)`. you can take one and use it if you want. each method is a closure
with the specific cache created.

What happens if i dont want allocate during runtime?, The solution: use `allocate!(f,Type)`

```julia-repl
julia> f
cached version of f! (function with 2 cached methods)
julia> allocate!(f,BigFloat)
julia> f
cached version of f! (function with 3 cached methods)
```
## Accesing without evaluating

by default, a `CachedFunction` does not store any type of x, so calling `f(x)` will just create a cache for ´out´ . If you also want to store the input values, you can use `evaluate!(f,x)`

```julia
x1 = [1.0,2.0,3.0]
evaluate!(f,x1) #x1 is stored
in1 = input(f,Float64) #accesses the input value when the eltype is a Float64
in1 == x1 #true
out1 = output(f,Float64) #accesses the output value when the eltype is a Float64

x2 = rand(3)
evaluate(f,x2) #evaluates on f2, the cache is changed, but x2 is not stored.
in2 = input(f,Float64) #x1 is stored here, not x2
in2 == x2 #false
out1 ==   output(f,Float64) #false
evaluate(f,x1) #restores the output cache to f(x1)
out1 ==   output(f,Float64) #true
```
## I can do this myself, why did you do this?

The problem occurs when you need to calculate jacobians of jacobians. how many caches i need to create? of what types?

## I like it! but i want more functionality

i'm open,really open to pull requests and issues. write something and we will se what we can do.

