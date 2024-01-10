using DepotDelivery
using Test

b = BuildSpec()

path = build(p)

@test occursin("scratchspace", path)
