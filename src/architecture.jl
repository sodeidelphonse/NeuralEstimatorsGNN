using NeuralEstimators, Flux, GraphNeuralNetworks, Statistics

function gnnarchitecture(Ω; args...)

	# Extract prior support:
	p = length(Ω)
	a = [minimum.(values(Ω))...]
	b = [maximum.(values(Ω))...]

	# Final activation function compresses output to prior support:
	final_activation = Compress(a, b)

	return gnnarchitecture(p; final_activation = final_activation, args...)
end

function gnnarchitecture(p::Integer; final_activation = identity, expert_statistics = false)

  q = 10
  h_max = 0.15
  
	# Propagation module
	propagation = GNNChain(
	  # NB one may also use "GraphSkipConnection" for skip connections
    SpatialGraphConv(1 => 2q,  relu, w = spatialweights(h_max, q), w_out = 2q),
    SpatialGraphConv(2q => 2q, relu, w = spatialweights(h_max, q), w_out = 2q)
   )

	# Readout module
	readout = GlobalPool(mean)

  # Global features 
  globalfeatures = SpatialGraphConv(1 => 2q, relu, w = spatialweights(h_max, q), w_out = 2q, glob = true)

	# Summary network
	ψ = GNNSummary(propagation, readout, globalfeatures)
	
	# Expert summary statistics 
	if expert_statistics 
	  S = NeighbourhoodVariogram(h_max, q)
	  in = 5q 
	else 
	  S = nothing
	  in = 4q
	end
	
	# Final layer
	if isa(final_activation, Compress) 
	  final_layer = Chain(Dense(128 => p, identity), final_activation)
	else
	  final_layer = Dense(128 => p, final_activation) 
	end

	# Mapping module
	ϕ = Chain(
	  Dense(in => 128, relu), 
	  Dense(128 => 128, relu),
	  final_layer
	)

	return DeepSet(ψ, ϕ; S = S)
end

function spatialweights(h_max, q)
  Parallel(
    vcat, 
    IndicatorWeights(0.15, q),
    Chain(
    			Dense(1 => 128, sigmoid),
					Dense(128 => q, sigmoid)
					)
    )
end