using Pkg, Dates, UUIDs, InteractiveUtils

verbose, triplet, sources, dest, precomp, offline = ARGS

function get_project(path)
    file = joinpath(path, "Project.toml")
    file = isfile(file) ? file : joinpath(path, "JuliaProject.toml")
    isfile(file) || error("No Project.toml or JuliaProject.toml file found in `$path`.")
    return Pkg.Types.read_project(file)
end

get_project_name(path) = (p = get_project(path); isnothing(p.name) ? splitpath(path)[end] : p.name)

#-----------------------------------------------------------------------------# ARGS
verbose = verbose == "true"
offline = offline == "true"
delim = Base.Sys.iswindows() ? ';' : ':'
source_dict = Dict(x => get_project_name(x) for x in abspath.(split(sources, delim)))
platform = Base.parse(Base.BinaryPlatforms.Platform, triplet)

for src in keys(source_dict)
    isdir(src) || error("Source directory `$src` does not exist.")
end
isdir(dest) || mkpath(dest)

verbose && @info """
    Building depot

    - Sources:
        - $(join(["$v: $k" for (k,v) in source_dict], "\n    - "))
    - Destination: $dest
    - Triplet: $triplet
    - Platform: $platform
    """

spec = Dict(
    :datetime => Dates.now(),
    :versioninfo => sprint(InteractiveUtils.versioninfo),
    :sources => source_dict,
    :destination => dest,
    :triplet => triplet,
    :platform => string(platform)
)

#-----------------------------------------------------------------------------# populate dest
ENV["JULIA_PKG_PRECOMPILE_AUTO"] = precomp == "true" ? 1 : 0
ENV["JULIA_DEPOT_PATH"] = dest
DEPOT_PATH[1] = dest

# PIRACY: This is more reliable than setting the `platform` keyword argument in `Pkg` functions.
Base.BinaryPlatforms.HostPlatform() = platform

Pkg.activate()
mkpath(joinpath(dest, "dev"))
for (path, name) in source_dict
    path = cp(path, joinpath(dest, "dev", name), force=true)
    proj = get_project(path)
    if any(isnothing, (proj.name, proj.uuid))
        @info "$path is not a valid Julia project.  Assigning necessary name/uuid..."
        proj.name = isnothing(proj.name) ? get_project_name(path) : proj.name
        proj.uuid = isnothing(proj.uuid) ? UUIDs.uuid4() : proj.uuid
        file = isfile(joinpath(path, "Project.toml")) ? "Project.toml" : "JuliaProject.toml"
        Pkg.Types.write_project(proj, joinpath(path, file))
    end
    Pkg.develop(path=path)
end
Pkg.instantiate(; verbose)

#-----------------------------------------------------------------------------# config
mkpath(joinpath(dest, "config"))

startup = """
# This file was automatically generated by DepotDelivery.jl
# Created at: $(Dates.now())
$(offline ? "import Pkg; Pkg.offline(true)" : "")
let
    depot = abspath(joinpath(@__DIR__, ".."))
    ENV["JULIA_DEPOT_PATH"] = depot     # For Distributed workers
    DEPOT_PATH[1] = depot               # For current process
end
@info "DepotDelivery startup: `using $(join(values(source_dict), ", "))`"
using $(join(values(source_dict), ", "))
"""

write(joinpath(dest, "config", "startup.jl"), startup)
write(joinpath(dest, "config", "DepotDeliveryBuild.toml"), sprint(Pkg.TOML.print, spec))

print(dest)
