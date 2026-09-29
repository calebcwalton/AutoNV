"""Quantum simulation tools and a reproducible, agent-driven laboratory workflow."""
module AutoNV

using LinearAlgebra, Random, Dates, SHA, TOML, Serialization
using QuantumToolbox, Distributions, JSON3
import SciMLBase

const PACKAGE_ROOT = dirname(@__DIR__)

export ModelSpec, DeviceDescription, Observation, ExperimentSpec, Evolution, Pulse
export experiment_to_dict, experiment_from_dict, description_to_dict, device_description
export generic_qubit_model, nv_model, default_experiments, predict, predict_batch
export reference_predict, reference_predict_batch, validate_model, resolve_backend
export simulation_metadata, score
export cpmg_operations, SyntheticDevice, execute
export campaign_init, campaign_status, campaign_acquire, campaign_validate, campaign_review, campaign_import

include("simulation.jl")
include("fixtures.jl")
include("device.jl")
include("campaign.jl")
include("interface.jl")

end
