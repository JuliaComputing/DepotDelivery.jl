# DepotDelivery

[![Build Status](https://github.com/joshday/DepotDelivery.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/joshday/DepotDelivery.jl/actions/workflows/CI.yml?query=branch%3Amain)


## Why Would I Use This?

1. You're trying to install software within an air-gapped environment.
2. Julia is already installed.
3. The install environment may be different than the build environment.


## Usage

```julia
using DepotDelivery

b = BuildSpec(path_to_project_toml; platform = Base.BinaryPlatforms.HostPlatform())

path = build(b)
```
