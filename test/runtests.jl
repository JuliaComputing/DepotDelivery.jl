using DepotDelivery
using Test


#-----------------------------------------------------------------------------# Single Project
depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"), precompiled=false)
@test !isdir(joinpath(depot, "compiled"))
@test DepotDelivery.test(depot)

depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"), precompiled=true)
@test isdir(joinpath(depot, "compiled"))
@test DepotDelivery.test(depot)


depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"), triplet="x86_64-w64-mingw32")
@test !isdir(joinpath(depot, "compiled"))
@test DepotDelivery._check_artifacts(depot, [".dylib"])

depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"), triplet="aarch64-apple-darwin")
@test !isdir(joinpath(depot, "compiled"))
@test DepotDelivery._check_artifacts(depot, [".dll"])

#-----------------------------------------------------------------------------# Multiple Projects
cd(joinpath(@__DIR__, "MultipleWorkflows")) do
    depot = DepotDelivery.build(readdir())
    @test DepotDelivery.test(depot)
end
