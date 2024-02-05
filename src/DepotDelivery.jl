module DepotDelivery

import Malt

export build_project

#-----------------------------------------------------------------------------# utils
global worker::Malt.Worker

function __init__()
    global worker = Malt.Worker()
end

#-----------------------------------------------------------------------------# build_project
function build_project(file::String; platform = Base.BinaryPlatforms.HostPlatform())
    Malt.remote_eval_fetch(worker, quote
        import Pkg, TOML, Dates, InteractiveUtils
        project = Pkg.Types.read_project($file)

        path = mkpath(joinpath(mktempdir(), project.name * "_depot"))
        push!(empty!(DEPOT_PATH), path)

        config = mkpath(joinpath(path, "config"))
        build_spec = Dict(
            :datetime => Dates.now(),
            :versioninfo => (buf = IOBuffer(); InteractiveUtils.versioninfo(buf); String(take!(buf))),
            :project_file => $(abspath(file)),
            :project => TOML.parsefile($file),
            :platform => $(string(platform))
        )

        ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"
        ENV["JULIA_DEPOT_PATH"] = path  # needed?
        Pkg.activate(path)
        Pkg.instantiate(; platform = $platform, verbose=true)

        @info "Writing: $config/depot_build.toml"
        open(io -> TOML.print(io, build_spec), joinpath(config, "depot_build.toml"), "w")

        path
    end)
end

#-----------------------------------------------------------------------------# test_build
function test_build(path::String; kw...)
    Malt.remote_eval_fetch(worker, quote
        path = $path
        import Pkg, TOML

        build_spec = TOML.parsefile(joinpath(path, "config", "buildspec.toml"))

        push!(empty!(DEPOT_PATH), path)
        Pkg.activate(path)
        Pkg.test(; $kw...)

        @info "Testing depot with build_spec" build_spec
    end)
end

end  # DepotDelivery module
