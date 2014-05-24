#### SinOsc ####

# Generates a sin tone at the given frequency

export SinOsc
type SinOsc <: AudioNode
    active::Bool
    deactivate_cond::Condition
    freq::Real
    phase::FloatingPoint

    function SinOsc(freq::Real)
        new(false, Condition(), freq, 0.0)
    end
end

function render(node::SinOsc, device_input::AudioBuf, info::DeviceInfo)
    phase = AudioSample[1:info.buf_size] * 2pi * node.freq / info.sample_rate
    phase .+= node.phase
    node.phase = phase[end]
    return sin(phase), is_active(node)
end

#### Gain ####
export Gain
type Gain <: AudioNode
    active::Bool
    deactivate_cond::Condition
    in_node::AudioNode
    gain::Float32

    function Gain(in_node::AudioNode, gain::Real)
        new(false, Condition(), in_node, gain)
    end
end

function render(node::Gain, device_input::AudioBuf, info::DeviceInfo)
    input, child_active = render(node.in_node, device_input, info)
    # TODO: should we check the active flag of the input?
    return input .* node.gain, is_active(node)
end


#### AudioMixer ####

# Mixes a set of inputs equally

# a convenience alias used in the array of mix inputs
typealias MaybeAudioNode Union(AudioNode, Nothing)
const MAX_MIXER_INPUTS = 32

export AudioMixer
type AudioMixer <: AudioNode
    active::Bool
    deactivate_cond::Condition
    mix_inputs::Array{MaybeAudioNode}

    function AudioMixer{T <: AudioNode}(mix_inputs::Array{T})
        input_array = Array(MaybeAudioNode, MAX_MIXER_INPUTS)
        fill!(input_array, nothing)
        for (i, node) in enumerate(mix_inputs)
            input_array[i] = node
        end
        new(false, Condition(), input_array)
    end

    function AudioMixer()
        AudioMixer(AudioNode[])
    end
end

# TODO: at some point we need to figure out what the general API is for wiring
# up AudioNodes to each other
function add_input(mixer::AudioMixer, in_node::AudioNode)
    for (i, node) in enumerate(mixer.mix_inputs)
        if node === nothing
            mixer.mix_inputs[i] = in_node
            return
        end
    end
    error("Mixer input array is full")
end

# removes the given node from the mix inputs. If the node isn't an input the
# function returns without error
function remove_input(mixer::AudioMixer, in_node::AudioNode)
    for (i, node) in enumerate(mixer.mix_inputs)
        if node === in_node
            mixer.mix_inputs[i] = nothing
            return
        end
    end
    # not an error if we didn't find it
end

function render(node::AudioMixer, device_input::AudioBuf, info::DeviceInfo)
    # TODO: we probably want to pre-allocate this buffer and share between
    # render calls. Unfortunately we don't know the right size when the object
    # is created, so maybe we check the size on every render call and only
    # re-allocate when the size changes? I suppose that's got to be cheaper
    # than the GC and allocation every frame
    mix_buffer = zeros(AudioSample, info.buf_size)
    for in_node in node.mix_inputs
        if in_node !== nothing
            in_buffer, active = render(in_node, device_input, info)
            mix_buffer += in_buffer
            if !active
                remove_input(node, in_node)
            end
        end
    end
    return mix_buffer, is_active(node)
end

#### Array Player ####

# Plays a AudioBuf by rendering it out piece-by-piece

export ArrayPlayer
type ArrayPlayer <: AudioNode
    active::Bool
    deactivate_cond::Condition
    arr::AudioBuf
    arr_index::Int

    function ArrayPlayer(arr::AudioBuf)
        new(false, Condition(), arr, 1)
    end
end

function render(node::ArrayPlayer, device_input::AudioBuf, info::DeviceInfo)
    # TODO: this should remove itself from the render tree when playback is
    # complete
    i = node.arr_index
    range_end = min(i + info.buf_size-1, length(node.arr))
    output = node.arr[i:range_end]
    if length(output) < info.buf_size
        # we're finished with the array, pad with zeros and deactivate
        output = vcat(output, zeros(AudioSample, info.buf_size - length(output)))
        deactivate(node)
    end
    node.arr_index = range_end + 1
    return output, is_active(node)
end

# Allow users to play a raw array by wrapping it in an ArrayPlayer
function play(arr::AudioBuf, args...)
    player = ArrayPlayer(arr)
    play(player, args...)
end

# If the array is the wrong floating type, convert it
function play{T <: FloatingPoint}(arr::Array{T}, args...)
    arr = convert(AudioBuf, arr)
    play(arr, args...)
end

# If the array is an integer type, scale to [-1, 1] floating point

# integer audio can be slightly (by 1) more negative than positive,
# so we just scale so that +/- typemax(T) becomes +/- 1
function play{T <: Signed}(arr::Array{T}, args...)
    arr = arr / typemax(T)
    play(arr, args...)
end

function play{T <: Unsigned}(arr::Array{T}, args...)
    zero = (typemax(T) + 1) / 2
    range = floor(typemax(T) / 2)
    arr = (arr .- zero) / range
    play(arr, args...)
end

#### AudioInput ####

# Renders incoming audio input from the hardware

export AudioInput
type AudioInput <: AudioNode
    active::Bool
    deactivate_cond::Condition
    channel::Int

    function AudioInput(channel::Int)
        new(false, Condition(), channel)
    end
end

function render(node::AudioInput, device_input::AudioBuf, info::DeviceInfo)
    @assert size(device_input, 1) == info.buf_size
    return device_input[:, node.channel], is_active(node)
end
