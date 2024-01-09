module DepotDelivery

using Dates, GZip, Pkg, Scratch, Tar

export BuildSpec, build, clear!

#-----------------------------------------------------------------------------# __init__
RELEASES::String = ""   # default directory to place releases: /RELEASES/$(proj.uuid)/$platform/$predicate.tar
DEPOTS::String = ""      # default directory to reuse as a depot

function __init__()
    global RELEASES = @get_scratch!("RELEASES")
    global DEPOTS = @get_scratch!("DEPOTS")
end

#-----------------------------------------------------------------------------# utils
clear!() = clear_scratch!(DepotDelivery)

default_drop_patterns = (".git", ".gitignore")

default_predicate(path) = !any(x -> occursin(x, path), default_drop_patterns)

#-----------------------------------------------------------------------------# BuildSpec
Base.@kwdef struct BuildSpec
    project_file::String = Base.current_project()
    platforms::Dict{String, Base.BinaryPlatforms.AbstractPlatform} = Dict("host" => Base.BinaryPlatforms.HostPlatform())
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
    depot = joinpath(DEPOTS, string(proj.uuid))
    releases = joinpath(RELEASES, string(proj.uuid))

    out = Dict{String, Dict{String, String}}(name => Dict{String, String}() for name in keys(b.platforms))
    try
        for (platform_name, platform) in pairs(b.platforms)
            push!(empty!(DEPOT_PATH), depot)
            Pkg.instantiate(; platform)
            for (predicate_name, predicate) in b.tar_predicates
                @info "Creating tarball for platform `$platform` with predicate `$predicate_name`"
                path = joinpath(releases, platform_name, predicate_name * ".tar")
                mkpath(dirname(path))
                Tar.create(predicate, depot, path; portable=true)
                out[platform_name][predicate_name] = path
            end
        end
    catch ex
        @warn "An error occured while building tarballs."
        rethrow(ex)
    finally
        isnothing(_precomp_auto) || (ENV["JULIA_PKG_PRECOMPILE_AUTO"] = _precomp_auto)
        append!(empty!(DEPOT_PATH), _depot_path)
    end
    return out
end


end
