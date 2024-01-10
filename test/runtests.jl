using DepotDelivery
using Test

b = BuildSpec()

res = build(b, tar_predicates=Dict(
    "no_artifacts" => path -> !occursin("artifacts", path),
    "only_artifacts" => path -> occursin("artifacts", path),
    ))

path = res["host"]["no_artifacts"]
