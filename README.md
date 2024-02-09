# DepotDelivery

[![Build Status](https://github.com/juliacomputing/DepotDelivery.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/juliacomputing/DepotDelivery.jl/actions/workflows/CI.yml?query=branch%3Amain)

<p align="center"><b>DepotDelivery</b> bundles a Julia project into a standalone depot that can run in air-gapped environments.</p>



## Features

- Bundles all necessary Julia code and artifacts needed to run without internet access.
- Build for platforms other than the host platform.

## Usage

```julia
using DepotDelivery: build

path = build(path_to_project; platform = Base.BinaryPlatforms.HostPlatform())
```

- `path` is the ready-to-ship depot.
- Your project lives at `$path/dev/MyProject`.
- The build settings live in `$path/config/depot_build.toml`
- Run this in the production environment to get started: `include("$path/config/depot_startup.jl")`.

## Building for Non-Host Platforms

- Use any `Base.BinaryPlatforms.AbstractPlatform` as the `platform` argument.
- See [Julia's supported OS/architectures](https://www.julialang.org/downloads/index.html#supported_platforms).
- See `?Base.BinaryPlatforms.Platform` and the types in `Pkg.BinaryPlatforms` for details, e.g.

```julia
import Pkg

Base.BinaryPlatforms.Platform("windows", "x86_64"; cuda == "10.1")

# `arch` argument must be in (:x86_64, :i686m, :armv7l, :armv6l, :aarch64, :powerpc64le)
Pkg.BinaryPlatforms.Windows(:x86_64)
Pkg.BinaryPlatforms.MacOS()
Pkg.BinaryPlatforms.Linux(:powerpc64le)
Pkg.BinaryPlatforms.FreeBSD(:armv7l)
```

## Limitations

- The parts of your dependencies that expect/require internet access will not work (this should be expected).
- It's assumed your package is completely standalone, and won't need to be used with packages outside of the provided project file.
