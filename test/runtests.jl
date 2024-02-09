using DepotDelivery
using Test

depot = DepotDelivery.build(joinpath(@__DIR__, ".."))

@test DepotDelivery.test(depot)
