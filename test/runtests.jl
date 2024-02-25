using DepotDelivery
using Pkg
using Test

depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"))

@test DepotDelivery.test(depot)

# debugging artifacts in CI
function print_file_tree(path, depth=0)
    if isfile(path)
        printstyled("    " ^ depth, basename(path), '\n', color=:light_blue)
    else
        println("    " ^ depth, basename(path), "/")
        for f in readdir(path)
            print_file_tree(joinpath(path, f), depth + 1)
        end
    end
end



DepotDelivery.sandbox() do
    @info isdir(depot)
    @info readdir(depot)
    print_file_tree(joinpath(depot, "artifacts"))  # debugging artifacts in CI

    include(joinpath(depot, "config", "depot_startup.jl"))
    @test !occursin(".julia", pathof(TestProject))
    @test !occursin(".julia", pathof(TestProject.HDF5))
end
