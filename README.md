# CycleWalk.jl

[![Test CI](https://github.com/jonmjonm/CycleWalk.jl/actions/workflows/ci.yml/badge.svg)](https://github.com/jonmjonm/CycleWalk.jl/actions/workflows/ci.yml)

This repository contains Julia code to run the Metropolized Cycle Walk algorithm, which is used to sample a user-specified distribution on the space of political redistricting plans. This MCMC algorithm is used to create an ensemble of redistricting plans that can be used to analyze the impact of different redistricting plans on electoral outcomes.

Metropolized Cycle Walk supports a number of different score/energy functions, which are used to define the distribution. The distribution encodes legal and policy preferences.

Metropolized Cycle Walk outputs the samples into an [Atlas file](https://github.com/jonmjonm/AtlasIO.jl/blob/main/atlas_format.md). AtlasIO files can be loaded using Julia or Python using the [AtlasIO.jl](https://github.com/jonmjonm/AtlasIO.jl) library.

A brief tutorial on using CycleWalk.jl, AtlasIO.jl, and the Atlas file format can be found in the Quantifying Gerrymandering [Documentation Pages](https://quantifyinggerrymandering.pages.oit.duke.edu/codedoc/). See also the arXiv paper [A Cycle Walk for Sampling Measures on Spanning Forests for Redistricting](https://arxiv.org/abs/2509.08629). More general information about the Quantifying Gerrymandering group can be found at the group's [Quantifying Gerrymandering Blog](https://sites.duke.edu/quantifyinggerrymandering/) and the [Documentation Pages](https://quantifyinggerrymandering.pages.oit.duke.edu/codedoc/).


## Metropolized Cycle Walk Algorithm

The basic Cycle Walk produces $d$-tree spanning forests where each of the $d$ spanning trees is approximately balanced in the sense that the total population of each tree is approximately balanced.

One step of the Cycle Walk proceeds by either proposing a 1-Tree Cycle Walk or a 2-Tree Cycle Walk. The 1-Tree Cycle Walk adds an edge to the tree and then removes an edge from the cycle this addition creates so that one once again has a tree. The 2-Tree Cycle Walk adds two edges between two adjacent trees and then removes two edges from the cycle these additions create so that one once again has two trees.

The Metropolized Cycle Walk algorithm uses these walks as proposals to a Metropolis-Hastings algorithm to sample from a specified target distribution. 

More details on the algorithm can be found in the [Cycle Walk paper](https://arxiv.org/abs/2509.08629).

## Example Scripts

The `examples` directory contains example scripts that demonstrate how to use the Metropolized Cycle Walk algorithm. These scripts can be run to generate redistricting plans and analyze their properties.

### Basic Usage

The script [`examples/runCycleWalk_ct.jl`](./examples/runCycleWalk_ct.jl) gives a simple example of how to run the Metropolized Cycle Walk algorithm. It creates an ensemble of congressional redistricting plans for Connecticut using the Cycle Walk algorithm with a target measure that includes a spanning forest energy and an isoperimetric score energy.

### A general run script with configuration file

The script [`examples/runCycleWalk_toml.jl`](./examples/runCycleWalk_toml.jl) demonstrates how to run the Cycle Walk algorithm with parameters specified in a TOML configuration file. This allows for easy customization of the algorithm's parameters without modifying the script itself.

There are a number of example TOML files in the `examples/toml` directory that can be used to run the script. 

The following command samples congressional redistricting plans for Connecticut using the Cycle Walk algorithm from the target measure specified in the `toml/param_ct.toml` file.
```
julia runCycleWalk_toml.jl toml/param_ct.toml
```
There are also example TOML files for grid and hexagonal districts in the `examples/toml` directory. For example, the following command samples redistricting plans for a 10x10 grid of districts using the Cycle Walk algorithm from the target measure specified in the `examples/toml/param_grid10x10.toml` file. It is run with the following command:
```
julia runCycleWalk_toml.jl toml/param_grid10x10.toml
```
One must be in the `examples` directory to run both of these commands.




