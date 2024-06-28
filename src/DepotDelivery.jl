module DepotDelivery

using Dates, InteractiveUtils, Pkg, TOML

#-----------------------------------------------------------------------------# State
# Things we change before Pkg.instantiate-ing and need to restore.
@kwdef struct State
    depot_path = copy(DEPOT_PATH)
    precomp = get(ENV, "JULIA_PKG_PRECOMPILE_AUTO", nothing)
    project = Base.current_project()
end
function restore!!(s::State)
    isnothing(s.project) ? Pkg.activate() : Pkg.activate(s.project)
    isnothing(s.precomp) || (ENV["JULIA_PKG_PRECOMPILE_AUTO"] = s.precomp)
    append!(empty!(DEPOT_PATH), s.depot_path)
end

function sandbox(f::Function)
    state = State()
    try
        f()
    catch ex
        @warn "DepotDelivery.sandbox failed"
        rethrow(ex)
    finally
        restore!!(state)
    end
end

#-----------------------------------------------------------------------------# build
function build(path::String; platform = Base.BinaryPlatforms.HostPlatform(), verbose=true)
    path = abspath(path)
    depot = mktempdir()
    sandbox() do
        proj_file = joinpath(path, "Project.toml")
        proj_file = isfile(proj_file) ? proj_file : joinpath(path, "JuliaProject.toml")
        isfile(proj_file) || error("No Project.toml or JuliaProject.toml found in `$path`.")
        proj = TOML.parsefile(proj_file)
        name = proj["name"]
        build_spec = Dict(
            :datetime => Dates.now(),
            :versioninfo => sprint(InteractiveUtils.versioninfo),
            :project_file => proj_file,
            :project => proj,
            :platform => string(platform)
        )
        mkdir(joinpath(depot, "config"))
        mkdir(joinpath(depot, "dev"))
        push!(empty!(DEPOT_PATH), depot)
        ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"  # Needed when building for non-host platforms

        cp(path, joinpath(depot, "dev", name))  # Copy project into dev/
        Pkg.activate(joinpath(depot, "dev", name))
        Pkg.instantiate(; platform, verbose)


        # Add local/dev-ed packages to Project
        manifest_file = joinpath(dirname(proj_file), replace(basename(proj_file), "Project" => "Manifest"))
        for (uuid, entry) in Pkg.Types.read_manifest(manifest_file)
            !isnothing(entry.path) && Pkg.dev(entry.path)
        end


        open(io -> TOML.print(io, build_spec), joinpath(depot, "config", "depot_build.toml"), "w")
        open(io -> print(io, startup_script(name)), joinpath(depot, "config", "depot_startup.jl"), "w")
    end

    return depot
end

#-----------------------------------------------------------------------------# startup_script
startup_script(name) = """
    import Pkg
    let
        depot = abspath(joinpath(@__DIR__, ".."))
        Pkg.activate(joinpath(depot, "dev", "$name"))
        ENV["JULIA_DEPOT_PATH"] = depot   # For Distributed.jl workers
        push!(empty!(DEPOT_PATH), depot)  # For current process
        @info "Initializing Depot `\$depot` with project `$name`."
    end
    using $name
    """

#-----------------------------------------------------------------------------# test
function test(depot_path::String)
    script = """
    @info "DepotDelivery.test: Loading the depot_startup.jl script"
    include(raw"$(joinpath(depot_path, "config", "depot_startup.jl"))")
    """
    process = run(`$(Base.julia_cmd()) --startup-file=no -e $script`)
    process.exitcode == 0
end

# Check that artifacts do not contains certain file extensions, e.g.:
# If you build for windows, you should not have .dylib files
# If you build for linux, you should not have .dll files
function _check_artifacts(depot_path::String, not=[".dylib"])
    for (root, dirs, files) in walkdir(joinpath(depot_path, "artifacts"))
        for file in files
            ext = lowercase(splitext(file)[2])
            if ext ∈ not
                @warn "Found unexpected artifact: $file"
            end
        end
    end
    return true
end

end  # DepotDelivery module
