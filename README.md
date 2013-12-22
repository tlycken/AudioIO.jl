PortAudio.jl
============

[![Build Status](https://travis-ci.org/ssfrr/PortAudio.jl.png)](https://travis-ci.org/ssfrr/PortAudio.jl)

This is a Julia interface to PortAudio. It is currently under heavy development
and certainly not even close to being useful.

If you want to try it anyways, from your julia console:

    julia> Pkg.clone("https://github.com/ssfrr/PortAudio.jl.git")
    julia> Pkg.build("PortAudio")

Right now you can just play and stop some sin tones in your speakers:

    julia> using PortAudio
    julia> play_sin()
    julia> stop_sin()