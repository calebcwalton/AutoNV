"""A synthetic device. Its model and random state belong only in the device process."""
struct SyntheticDevice{M,R}
    model::M
    rng::R
end

"""Acquire binary measurement counts; never return the device's exact probabilities."""
function execute(device::SyntheticDevice, experiments::AbstractVector)
    probabilities = predict_batch(device.model, experiments; backend=:cpu)
    [Observation(experiment, rand(device.rng, Binomial(experiment.shots, p)), experiment.shots)
     for (experiment, p) in zip(experiments, probabilities)]
end

# Atomic replacement also makes a device request safe to retry after a pipe breaks.
function write_json_atomic(path::AbstractString, value)
    mkpath(dirname(path))
    temporary = path * ".tmp-" * string(getpid())
    open(temporary, "w") do io
        JSON3.write(io, value)
        write(io, '\n')
        flush(io)
    end
    mv(temporary, path; force=true)
    path
end

read_json(path) = JSON3.read(read(path, String), Dict{String,Any})

"""Persistent JSON Lines device connection owned by a campaign controller."""
mutable struct DeviceClient
    process::Base.Process
    sequence::Int
end

function DeviceClient(private_dir::AbstractString, system::AbstractString)
    mkpath(private_dir)
    # launch_device is supplied by the CLI layer, which locates the Julia project.
    process = open(launch_device(private_dir, system), "r+")
    DeviceClient(process, 0)
end

function Base.close(client::DeviceClient)
    try
        close(client.process.in)
    catch
    end
    # EOF normally shuts the server down cleanly. Bound the wait so interruption
    # during a long solve can still terminate the child promptly.
    if timedwait(()->!process_running(client.process), 5.0; pollint=.05) == :timed_out
        kill(client.process)
    end
    wait(client.process)
    nothing
end

function device_request!(client::DeviceClient, request::AbstractDict)
    JSON3.write(client.process, request)
    write(client.process, '\n')
    flush(client.process)
    line = readline(client.process)
    isempty(line) && error("Device process closed its response stream; resume this campaign to retry.")
    result = JSON3.read(line, Dict{String,Any})
    get(result, "ok", false) || error("Device request failed: " * string(get(result, "error", "unknown error")))
    result
end

device_acquire!(client::DeviceClient, id, experiments) =
    device_request!(client, Dict("action"=>"acquire", "id"=>id, "experiments"=>experiments))["observations"]

"""Check solver agreement inside the device; expose aggregate error, never truth."""
device_check!(client::DeviceClient, experiments) =
    device_request!(client, Dict("action"=>"check", "experiments"=>experiments))["numerical"]

"""Public independent uniform sampling intervals in MHz for synthetic NV devices.

These bounds specify a compact four-dimensional electron–carbon-13 model, not
universal material constants. Actual draws and RNG seeds stay in private storage.
"""
function device_sampling_bounds(system::AbstractString="nv")
    system == "nv" || error("Public bounded sampling is defined for the NV example only")
    Dict("detuning_mhz"=>[.015, .055], "omega_l_mhz"=>[.35, .65],
         "a_parallel_mhz"=>[.035, .095], "a_perp_mhz"=>[.04, .12])
end

function device_numerical_check(model, experiments)
    isempty(experiments) && error("At least one check experiment is required")
    probabilities = predict_batch(model, experiments; backend=:cpu)
    reference = reference_predict_batch(model, experiments)
    discrepancy = maximum(abs.(probabilities .- reference))
    Dict("metadata"=>simulation_metadata(; backend=:cpu),
         "reference_method"=>"matrix_exponential", "settings_checked"=>length(experiments),
         "max_absolute_error"=>discrepancy, "tolerance"=>1e-7,
         "pass"=>isfinite(discrepancy) && discrepancy <= 1e-7)
end

function private_device_config(directory, system)
    path = joinpath(directory, "device.json")
    if isfile(path)
        config = read_json(path)
        config["system"] == system || error("Private device system differs from campaign system")
        return config
    end
    seed = rand(Random.RandomDevice(), UInt64)
    rng = Random.Xoshiro(seed)
    parameters = if system == "generic"
        Dict("omega_x_mhz"=>0.07 + .01randn(rng), "omega_y_mhz"=>-.04 + .01randn(rng),
             "omega_z_mhz"=>.31 + .02randn(rng))
    elseif system == "nv"
        Dict(name=>bounds[1] + (bounds[2]-bounds[1])*rand(rng)
             for (name, bounds) in sort(collect(device_sampling_bounds(system)); by=first))
    else
        error("Unknown synthetic device: $system")
    end
    config = Dict("system"=>system, "seed"=>string(seed; base=16), "parameters"=>parameters)
    write_json_atomic(path, config)
    chmod(path, 0o600)
    config
end

function model_from_private_config(config)
    p = config["parameters"]
    if config["system"] == "generic"
        generic_qubit_model(; omega_x_mhz=p["omega_x_mhz"], omega_y_mhz=p["omega_y_mhz"], omega_z_mhz=p["omega_z_mhz"])
    else
        nv_model(; detuning_mhz=p["detuning_mhz"], omega_l_mhz=p["omega_l_mhz"],
                 a_parallel_mhz=p["a_parallel_mhz"], a_perp_mhz=p["a_perp_mhz"])
    end
end

"""Serve synthetic-device requests on stdin/stdout; diagnostics belong on stderr.

Each acquisition ID has a persisted response. Retrying it returns the same counts,
including after restart, while reusing it for different experiments is an error.
The private seed derives a distinct reproducible random stream for each request.
"""
function device_main(private_dir::AbstractString, system::AbstractString)
    mkpath(private_dir)
    chmod(private_dir, 0o700)
    config = private_device_config(private_dir, system)
    model = model_from_private_config(config)
    for line in eachline(stdin)
        response = try
            request = JSON3.read(line, Dict{String,Any})
            if request["action"] == "describe"
                Dict("ok"=>true, "description"=>description_to_dict(device_description(Symbol(system))))
            elseif request["action"] == "check"
                experiments_json = request["experiments"]
                validate_public_experiments(experiments_json, system)
                Dict("ok"=>true, "numerical"=>device_numerical_check(model, experiment_from_dict.(experiments_json)))
            elseif request["action"] == "acquire"
                id = string(request["id"])
                isempty(id) && error("Acquisition ID must not be empty")
                key = bytes2hex(SHA.sha256(id))
                record_path = joinpath(private_dir, "acquisitions", key * ".json")
                experiments_json = request["experiments"]
                if isfile(record_path)
                    record = read_json(record_path)
                    record["experiments"] == experiments_json || error("Acquisition ID already used for different experiments")
                    record["response"]
                else
                    experiments = experiment_from_dict.(experiments_json)
                    isempty(experiments) && error("At least one experiment is required")
                    digest = SHA.sha256(config["seed"] * ":" * id)
                    seed = foldl((a, b)->(a << 8) | UInt64(b), digest[1:8]; init=UInt64(0))
                    observations = execute(SyntheticDevice(model, Random.Xoshiro(seed)), experiments)
                    result = Dict("ok"=>true, "id"=>id, "observations"=>[
                        Dict("experiment"=>e, "counts"=>o.counts, "shots"=>o.shots)
                        for (e, o) in zip(experiments_json, observations)])
                    write_json_atomic(record_path, Dict("experiments"=>experiments_json, "response"=>result))
                    result
                end
            else
                error("Unknown device action")
            end
        catch exception
            # Avoid exposing model internals through backend stack traces.
            println(stderr, "Device request failed: ", typeof(exception))
            Dict("ok"=>false, "error"=>"Invalid request or simulation failure")
        end
        JSON3.write(stdout, response)
        write(stdout, '\n')
        flush(stdout)
    end
end
