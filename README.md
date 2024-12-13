# DepotDelivery

[![Build Status](https://github.com/juliacomputing/DepotDelivery.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/juliacomputing/DepotDelivery.jl/actions/workflows/CI.yml?query=branch%3Amain)

<p align="center"><b>DepotDelivery</b> bundles a Julia project into a standalone depot (contents of a `.julia/` directory).</p>



## Features

- Bundles all Julia code of one or more projects.
- Can be deployed in air-gapped environments.
- Build for platforms other than the host platform.
- Can precompile all dependencies to built path.

## Usage

```julia
build(src = pwd(), dest=mktempdir(); triplet, platform, verbose, precompiled)
```

Arguments:
- `src = pwd()`: A `String`/`Vector{String}` of the project path/paths containing `Project.toml` or `JuliaProject.toml` files.
- `dest::String = <tempdir>`: The depot directory to populate.
- `platform::AbstractPlatform = <host platform>`: The target `Base.BinaryPlatforms.Platform`.
- `triplet = nothing`: The target triplet of the platform to build for.  If not `nothing`, it overrides `platform`.
- `verbose = true`: Whether to display verbose output during the build process (default is `true`).
- `precompiled = false`: Whether to enable precompilation of packages.

Returns:
- `dest::String`


## Examples

```julia
using DepotDelivery

# `path/Project.toml` (or `path/JuliaProject.toml`) must exist
path = abspath(joinpath(pathof(DepotDelivery), "..", ".."))

depot = DepotDelivery.build(path)
```

Then in your production environment, either:
  1. Replace the `.julia/` directory with `depot`
  2. Run `include(joinpath(depot, "config", "startup.jl"))` to begin your Julia session.

## Notes

### General

Be aware that `build` will copy everything inside the source directories to `depot/dev/`. Avoid populating those directories with unnecessary files. For example, when starting a new project, it's better to run `julia --project=./isolated_folder/` rather than `julia --project=.`, as in the latter case the `Project.toml` file will coexist with other stuff.

### Building for Non-Host Platforms

- Use any `Base.BinaryPlatforms.AbstractPlatform` as the `platform` or [target triplet](https://wiki.osdev.org/Target_Triplet) as the `triplet`.
- See [Julia's supported OS/architectures](https://www.julialang.org/downloads/index.html#supported_platforms).
- See `?Base.BinaryPlatforms.Platform` and the types in `Pkg.BinaryPlatforms` for details, e.g.

```julia
import Pkg

Base.BinaryPlatforms.HostPlatform()

Base.BinaryPlatforms.Platform("windows", "x86_64"; cuda == "10.1")

# `arch` argument must be in (:x86_64, :i686m, :armv7l, :armv6l, :aarch64, :powerpc64le)
Pkg.BinaryPlatforms.Windows(:x86_64)
Pkg.BinaryPlatforms.MacOS()
Pkg.BinaryPlatforms.Linux(:powerpc64le)
Pkg.BinaryPlatforms.FreeBSD(:armv7l)
```
