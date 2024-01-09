module DepotDelivery

using Dates, GZip, Pkg, Scratch, Tar


#-----------------------------------------------------------------------------# __init__
RELEASES::String = ""   # default directory to place releases: /RELEASES/$(proj.uuid)/$platform/$predicate.tar
DEPOTS::String = ""      # default directory to reuse as a depot

function __init__()
    release_dir = @get_scratch!("RELEASES")
    depot_dir = @get_scratch!("DEPOTS")
end

#-----------------------------------------------------------------------------# utils
clear!() = clear_scratch!(DepotDelivery)

default_drop_patterns = (".git", ".gitignore")

default_predicate(path) = !any(path -> occursin(path, default_drop_patterns), path)

#-----------------------------------------------------------------------------# BuildSpec
Base.@kwdef struct BuildSpec
    project_file::String = Base.current_project()
    platforms::Vector{Base.BinaryPlatforms.Platform} = [Base.BinaryPlatforms.HostPlatform()]
    tar_predicates::Dict{String, Function} = Dict("default" => default_predicate)
end
function Base.show(io::IO, b::BuildSpec)
    println(io, "BuildSpec:")
    print(io, "    project_file: "); printstyled(io, b.project_file; color=:light_green); println(io)
    println(io, "    platforms: ")
    foreach(x -> printstyled(io, "        • ", x, '\n'; color=:light_cyan), b.platforms)
    println(io, "    tar_predicates: ")
    foreach(x -> printstyled(io, "        • ", x, '\n'; color=:light_black), keys(b.tar_predicates))
end


#-----------------------------------------------------------------------------# build
function build(b::BuildSpec)
    # Things we change and need to restore in `finally`
    _depot_path = DEPOT_PATH
    _precomp_auto = get(ENV, "JULIA_PKG_PRECOMPILE_AUTO", nothing)

    # Load Project.toml
    proj = Pkg.Types.read_project(b.project_file)

    out = Dict{String, String}()
    try
        for platform in b.platforms
            push!(empty!(DEPOT_PATH), DEPOT)
            Pkg.instantiate(; platform)
            for (predicate_name, predicate) in b.predicates
                @info "Creating tarball for platform `$platform` with predicate `$predicate_name`"
                path = joinpath(RELEASES, proj.uuid, platform, predicate_name * ".tar")
                Tar.create(predicate, DEPOT, path; portable=true)
                out["$(proj.uuid) | $platform | $predicate_name"] = path
            end
        end
    catch
    finally
        isnothing(_precomp_auto) || (ENV["JULIA_PKG_PRECOMPILE_AUTO"] = _precomp_auto)
        append!(empty!(DEPOT_PATH), _depot_path)
    end
    return out
end


end
