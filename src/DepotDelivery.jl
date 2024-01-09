module DepotDelivery

using Dates, Distributed, Pkg, Scratch, Tar

export BuildSpec, build, clear!

#-----------------------------------------------------------------------------# __init__
PROJECT::String = ""   # /PROJECTS/$project_root
VALIDATE::String = ""  # /VALIDATE/$project_root
RELEASES::String = ""   # /RELEASES/$(proj.uuid)/$platform/$predicate.tar
DEPOTS::String = ""     # /DEPOTS/$(proj.uuid)/

function __init__()
    global PROJECT = @get_scratch!("PROJECT")
    global VALIDATE = @get_scratch!("VALIDATE")
    global RELEASES = @get_scratch!("RELEASES")
    global DEPOTS = @get_scratch!("DEPOTS")
end

#-----------------------------------------------------------------------------# utils
clear!() = clear_scratch!(DepotDelivery)

default_drop_patterns::Vector{String} = [".git", ".gitignore"]

default_predicate(path) = !any(x -> occursin(x, path), default_drop_patterns)

#-----------------------------------------------------------------------------# BuildSpec
Base.@kwdef struct BuildSpec
    project_file::String = Base.current_project()
    project::Pkg.Types.Project = Pkg.Types.read_project(project_file)
    platforms::Dict{String, Base.BinaryPlatforms.AbstractPlatform} = Dict("host" => Base.BinaryPlatforms.HostPlatform())
    tar_predicates::Dict{String, Function} = Dict("default" => default_predicate)
end

function paths(b::BuildSpec)
    uuid = b.project.uuid
    out = (; depot = joinpath(DEPOTS, uuid), releases = joinpath(RELEASES, uuid))
    foreach(out) do x
        rm(x; force=true, recursive=true)
        mkpath(x)
    end
    return out
end


#-----------------------------------------------------------------------------# build
function build(b::BuildSpec)
    name = b.project.name
    uuid = string(b.project.uuid)
    depot, releases = paths(b)

    # Create the output, nested dict of: [platform][predicate] => path
    out = Dict{String, Dict{String, String}}(name => Dict{String, String}() for name in keys(b.platforms))

    # Things that need to be restored in `finally`
    _project = Base.current_project()
    _depot_path = DEPOT_PATH
    _precomp_auto = get(ENV, "JULIA_PKG_PRECOMPILE_AUTO", nothing)

    try
        # Change the depot to our empty one
        push!(empty!(DEPOT_PATH), depot)

        # Copy the entire project directory into `depot/dev/$project_name` and activate it
        depot_dev = mkpath(joinpath(depot, "dev", proj.name))
        cp(dirname(b.project_file), depot_dev; force=true)
        Pkg.activate(depot_dev)


        for (platform_name, platform) in pairs(b.platforms)
            # For each platform, wipe `artifacts/` and instantiate the project
            rm(joinpath(depot, "artifacts"); recursive=true, force=true)
            Pkg.instantiate(; platform)

            # Now that depot is populated, apply each predicate to create tarballs
            for (predicate_name, predicate) in b.tar_predicates
                path = joinpath(releases, platform_name, predicate_name * ".tar")
                mkpath(dirname(path))

                @info "Creating tarball for platform `$platform` with predicate `$predicate_name`..."
                Tar.create(predicate, depot, path; portable=true)
                out[platform_name][predicate_name] = path
            end
        end
    catch ex
        @warn "An error occured while building tarballs."
        rethrow(ex)
    finally
        Pkg.activate(_project)
        isnothing(_precomp_auto) || (ENV["JULIA_PKG_PRECOMPILE_AUTO"] = _precomp_auto)
        append!(empty!(DEPOT_PATH), _depot_path)
    end
    return out
end


end
