using DepotDelivery
using Pkg
using Test

depot = DepotDelivery.build(joinpath(@__DIR__, "TestProject"))

@test DepotDelivery.test(depot)

DepotDelivery.sandbox() do
    include(joinpath(depot, "config", "depot_startup.jl"))
    @test !any(x -> occursin(".julia", x), DEPOT_PATH) # Ensure DEPOT_PATH changed
    @test !occursin(".julia", pathof(TestProject))
    @test !occursin(".julia", pathof(TestProject.HDF5))
    @test !occursin(".julia", pathof(TestProject.HDF5.API.HDF5_jll))
end


depot2 = DepotDelivery.build(joinpath(@__DIR__, "TestProject"), platform = Pkg.BinaryPlatforms.Windows(:x86_64))

path = joinpath(depot2, "packages", "HDF5_jll")


#------------------------------------------------------------------------------------
#------------------------------------------------------------------------------------
# Testing multiple workflows
packages_list = readdir("MultipleWorkflows/");
proj_paths = joinpath.("./MultipleWorkflows/", packages_list);
depot = DepotDelivery.build(proj_paths, precompiled=true)

DepotDelivery.sandbox() do 
    push!(empty!(DEPOT_PATH), depot)
    
    # Test that for every project instantiated, their dependencies exist 
    # and the depot path does not point to the default value
    @testset for (proj, package) in zip(proj_paths, packages_list)
        Pkg.activate(proj)
        package_symbol = Symbol(package)
        @eval using $package_symbol
        package_value = eval(package_symbol)
        @test !occursin(".julia", pathof(package_value))
    end

    # Ensure compiled folders are populated
    @testset for package in packages_list
        @test length(readdir(joinpath(depot, "compiled", "v$(VERSION.major).$(VERSION.minor)", package))) > 1
    end
end
