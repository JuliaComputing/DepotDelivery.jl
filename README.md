# DepotDelivery

[![Build Status](https://github.com/joshday/DepotDelivery.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/joshday/DepotDelivery.jl/actions/workflows/CI.yml?query=branch%3Amain)

**DepotDelivery** provides a mechanism of delivering standalone Julia applications into environments where Julia is already installed.

It uses Julia's fantastic Pkg/Artifacts system to "cross compile" for different platforms.


## Usage

```julia
using DepotDelivery

b = BuildSpec(path_to_project_toml; platform = Base.BinaryPlatforms.HostPlatform())

path = build(b)
```

## Why Would I Use This?

- This is really only useful for installing into air-gapped environments.
