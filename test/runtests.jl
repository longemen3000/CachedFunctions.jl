using CachedFunctions
using Test


#strain test, different types, a dict.
@testset "basics" begin
    function f!(y,x)
        y[:p] = x[1]
        y[:t] = x[2]+ y[:p]
        for i = 1:10
            y[:p] = cos(y[:p]+1.5)
        end
        y
    end
    y0 = Dict(:t=>0.0,:p=>0.0)
    x = rand(2)
    ff = CachedFunction(f!,x,y0)
    ff(x) 
    @test length(cached_methods(ff)) == 1
    @test calls(ff) == 1
    allocate!(ff,BigFloat)
    @test length(cached_methods(ff)) == 2
    ff(big.(rand(2)))
    @test length(cached_methods(ff)) == 2 #check if no new caches were created.
    @test calls(ff) == 2
end
