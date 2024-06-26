using NeuralEstimators
import NeuralEstimators: simulate
using NeuralEstimatorsGNN
using Distances: pairwise, Euclidean
using LinearAlgebra
using Folds

ξ = (
	Ω = Ω,
	p = length(Ω),
	parameter_names = String.(collect(keys(Ω))),
	n = 256,
	ν = 1.0,  # smoothness to use if ν is not included in Ω
	σ = 1.0,  # marginal standard deviation to use if σ is not included in Ω
	invtransform = identity # inverse of variance-stabilising transformation
)

function simulate(parameters::Parameters, m::R; convert_to_graph::Bool = true) where {R <: AbstractRange{I}} where I <: Integer
  
  p, K = size(parameters)
	m = rand(m, K)
  θ = parameters.θ
	chols        = parameters.chols
	chol_pointer = parameters.chol_pointer
	loc_pointer  = parameters.loc_pointer
	graphs       = parameters.graphs

	z = Folds.map(1:K) do k
		Lₖ = chols[chol_pointer[k]][:, :]
		mₖ = m[k]
		zₖ = simulategaussianprocess(Lₖ, mₖ)
		if p > 1 # add measurement error
			τₖ = θ[1, k]
			zₖ = zₖ + τₖ * randn(size(zₖ)...)
		end
		zₖ = Float32.(zₖ)
		if convert_to_graph
			gₖ = graphs[loc_pointer[k]]
			zₖ = spatialgraph(gₖ, zₖ)
		end
		zₖ
	end

	return z
end
simulate(parameters::Parameters, m::Integer; kwargs...) = simulate(parameters, range(m, m); kwargs...)
