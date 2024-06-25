using DepotDelivery
using Pkg
using Test

depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"))

@test DepotDelivery.test(depot)

DepotDelivery.sandbox() do
    include(joinpath(depot, "config", "depot_startup.jl"))
    @test !occursin(".julia", pathof(TestProject))
    @test !occursin(".julia", pathof(TestProject.HDF5))
    @test !occursin(".julia", pathof(TestProject.HDF5.API.HDF5_jll))
end


depot2 = DepotDelivery.build(joinpath(@__DIR__, "TestProject"), platform = Pkg.BinaryPlatforms.Windows(:x86_64))

path = joinpath(depot2, "packages", "HDF5_jll")
