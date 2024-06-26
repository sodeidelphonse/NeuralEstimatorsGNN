using NeuralEstimators
import NeuralEstimators: simulate
using NeuralEstimatorsGNN
using Distances: pairwise, Euclidean
using Distributions: Uniform
using LinearAlgebra
using Folds

Ω = (
	ρ = Uniform(0.05, 0.3),
	ν = Uniform(0.5, 1.5)
)

ξ = (
	Ω = Ω,
	p = length(Ω),
	n = 256,
	parameter_names = String.(collect(keys(Ω))),
	σ = 1.0,  # marginal variance to use if σ is not included in Ω
	r = 0.15, # cutoff distance used to define the neighbourhood of each node
	k = 30,   # maximum number of neighbours to consider when constructing the neighbourhood
	neighbourhood = "combined", # neighbourhood definition
	invtransform = exp # inverse of variance-stabilising transformation
)

function simulate(parameters::Parameters, m::R; convert_to_graph::Bool = true) where {R <: AbstractRange{I}} where I <: Integer

	K = size(parameters, 2)
	m = rand(m, K)

	chols        = parameters.chols
	chol_pointer = parameters.chol_pointer
	loc_pointer  = parameters.loc_pointer
	g            = parameters.graphs

	z = Folds.map(1:K) do k
		Lₖ = chols[chol_pointer[k]][:, :]
		mₖ = m[k]
		zₖ = simulateschlather(Lₖ, mₖ; Gumbel = true)
		zₖ = Float32.(zₖ)
		if convert_to_graph
			gₖ = g[loc_pointer[k]]
			zₖ = spatialgraph(gₖ, zₖ)
		end
		zₖ
	end
	return z
end
simulate(parameters::Parameters, m::Integer; kwargs...) = simulate(parameters, range(m, m); kwargs...)
