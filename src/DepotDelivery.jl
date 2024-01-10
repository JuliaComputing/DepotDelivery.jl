module DepotDelivery

using Dates, Distributed, Pkg, Scratch

export BuildSpec, build, clear!

#-----------------------------------------------------------------------------# init
BUILDS::String = ""
SANDBOX::String = ""

function __init__()
    global BUILDS = get_scratch!(DepotDelivery, "BUILDS")
    global SANDBOX = get_scratch!(DepotDelivery, "SANDBOX")
end

#-----------------------------------------------------------------------------# utils
clear!() = clear_scratchspaces!(DepotDelivery)

mk_empty_path(path) = (rm(path; force=true, recursive=true); mkpath(path))

function set_depot!(path::String)
    push!(empty!(DEPOT_PATH), path)
    ENV["JULIA_DEPOT_PATH"] = path  # used by spawned worker processes (is this needed?)
end

#-----------------------------------------------------------------------------# sandbox
function sandbox(f::Function)
    path = mk_empty_path(SANDBOX)

    current_project = Base.current_project()
    depot_path = copy(DEPOT_PATH)
    _depot_path = get(ENV, "JULIA_DEPOT_PATH", nothing)
    _precomp = get(ENV, "JULIA_PKG_PRECOMPILE_AUTO", nothing)
    try
        cd(path) do
            Pkg.activate("path")
            ENV["JULIA_DEPOT_PATH"] = path
            ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"
            f()
        end
    catch ex
        rethrow(ex)
    finally
        Pkg.activate(current_project)
        append!(empty!(DEPOT_PATH), depot_path)
        isnothing(_depot_path) ? delete!(ENV, "JULIA_DEPOT_PATH") : (ENV["JULIA_DEPOT_PATH"] = _depot_path)
        isnothing(_precomp) ? delete!(ENV, "JULIA_PKG_PRECOMPILE_AUTO") : (ENV["JULIA_PKG_PRECOMPILE_AUTO"] = _precomp)
    end
end

#-----------------------------------------------------------------------------# BuildSpec
Base.@kwdef struct BuildSpec
    project_file::String        = Base.current_project()
    project::Pkg.Types.Project  = Pkg.Types.read_project(project_file)
    platform::Base.BinaryPlatforms.AbstractPlatform = Base.BinaryPlatforms.HostPlatform()
    add_startup::Bool           = true
end
function Base.show(io::IO, b::BuildSpec)
    print(io, "BuildSpec:", join(("\n    • $x: $(getfield(b, x))") for x in [:project_file, :platform, :add_startup]))
end

function build(b::BuildSpec)
    name = b.project.name
    sandbox() do
        project_root = mkpath(joinpath("dev", name))
        set_depot!(pwd())
        cp(dirname(b.project_file), project_root; force=true)
        Pkg.activate(project_root)
        Pkg.instantiate(; platform = b.platform)
        mkdir("config")
        write(joinpath("config", "buildspec.jld"), string(b))
        if b.add_startup
            content = """
            ENV["JULIA_DEPOT_PATH"] = joinpath(@__DIR__, "..")

            import Pkg, Serialization

            Pkg.activate(joinpath(@__DIR__, "..", "dev", "$name"))

            using $name

            __build_spec__ = read(joinpath(@__DIR__, "..", "config", "buildspec.jld"), String)

            nothing
            """
            write(joinpath("config", "startup.jl"), content)
        end

        build_dir = mkpath(joinpath(BUILDS, name))
        cp(pwd(), joinpath(build_dir, "build_$(Dates.format(now(), "yyyymmdd-HHMMSS"))"))
    end
end


end
