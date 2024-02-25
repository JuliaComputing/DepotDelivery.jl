using DepotDelivery
using Pkg
using Test

depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"))

@test DepotDelivery.test(depot)

DepotDelivery.sandbox() do
    include(joinpath(depot, "config", "depot_startup.jl"))
    @test !occursin(".julia", pathof(TestProject))
    @test !occursin(".julia", pathof(TestProject.HDF5))
end
