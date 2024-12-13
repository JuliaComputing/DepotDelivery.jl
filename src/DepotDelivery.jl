module DepotDelivery

public build

#-----------------------------------------------------------------------------# build
"""
    build(src = pwd(), dest; triplet, platform, verbose, precompiled)

Arguments:
- `src = pwd()`: A `String`/`Vector{String}` of the project path/paths containing `Project.toml` or `JuliaProject.toml` files.
- `dest::String = <tempdir>`: The depot directory to populate.
- `platform::AbstractPlatform = <host platform>`: The target `Base.BinaryPlatforms.Platform`.
- `triplet = nothing`: The target triplet of the platform to build for.  If not `nothing`, it overrides `platform`.
- `verbose = true`: Whether to display verbose output during the build process (default is `true`).
- `precompiled = false`: Whether to enable precompilation of packages.

Returns:
- `dest::String`

Example:
    depot_path = build("/path/to/your/project")
"""
function build(
        src::String = pwd(),  # paths separated with ':'
        dest::String = joinpath(mktempdir(), "depot");
        triplet = nothing,
        platform = Base.BinaryPlatforms.HostPlatform(),
        verbose = true,
        precompiled = false,
        offline = false
        )
    julia = Base.julia_cmd()
    script_jl = joinpath(@__DIR__, "build_script.jl")
    triplet = isnothing(triplet) ? Base.BinaryPlatforms.triplet(platform) : triplet
    cmd = `$julia $script_jl $verbose $triplet $src $dest $precompiled $offline`
    read(cmd, String)
end

build(sources::Vector{String}, dest::String=joinpath(mktempdir(), "depot"); kw...) = build(join(sources, ':'), dest; kw...)



#-----------------------------------------------------------------------------# test
function test(depot::String)
    script = """
    @info "DepotDelivery.test: Loading the startup.jl script"
    include(raw"$(joinpath(depot, "config", "startup.jl"))")
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
                return false
            end
        end
    end
    return true
end

end  # DepotDelivery module
