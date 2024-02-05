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
        file = $(abspath(file))
        path = mktempdir()
        push!(empty!(DEPOT_PATH), path)
        ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

        import Pkg, TOML, Dates, InteractiveUtils

        config = mkpath(joinpath(path, "config"))
        dev = mkpath(joinpath(path, "dev"))

        project = TOML.parsefile(file)
        build_spec = Dict(
            :datetime => Dates.now(),
            :versioninfo => (buf = IOBuffer(); InteractiveUtils.versioninfo(buf); String(take!(buf))),
            :project_file => abspath(file),
            :project => project,
            :platform => $(string(platform))
        )

        @info "Copying project to `\$depot/dev/$(project["name"])`"
        dev_proj = joinpath(dev, project["name"])
        cp(dirname(file), dev_proj)

        Pkg.activate(dev_proj)
        Pkg.instantiate(; platform = $platform, verbose=true)
        Pkg.activate()
        Pkg.develop(project["name"])

        @info "Writing `\$depot/config/depot_build.toml`"
        open(io -> TOML.print(io, build_spec), joinpath(config, "depot_build.toml"), "w")

        @info "Writing `\$depot/config/depot_startup.jl`"
        open(joinpath(config, "depot_startup.jl"), "w") do io
            println(io, """
            import Pkg

            ENV["JULIA_DEPOT_PATH"] = "$path"  # Needed for Distributed.jl to work

            push!(empty!(DEPOT_PATH), "$path")

            @info "`using $(project["name"])`"
            using $(project["name"])
            """)
        end
        path
    end)
end

#-----------------------------------------------------------------------------# test_build
function test_build(path::String; kw...)
    Malt.remote_eval_fetch(worker, quote
        include(joinpath($path, "config", "depot_startup.jl"))
    end)
end

end  # DepotDelivery module
