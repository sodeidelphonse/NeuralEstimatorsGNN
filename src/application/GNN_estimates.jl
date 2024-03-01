using CSV
using DataFrames
using Folds
using LinearAlgebra
using NeuralEstimators
using NeuralEstimatorsGNN
using GraphNeuralNetworks
using RData
using Statistics: mean
using StatsBase: sample
using SparseArrays

## ---- Load the data ----

model = joinpath("GP", "nuFixed")
include(joinpath(pwd(), "src", model, "model.jl"))
include(joinpath(pwd(), "src", "architecture.jl"))

path = "intermediates/application"
if !isdir(path) mkpath(path) end

## Load the clustered data as a single data frame, and then split by cluster
clustered_data = RData.load(joinpath(path, "clustered_data2.rds"))
clustered_data = [filter(:cluster => cluster -> cluster == i, clustered_data) for i in unique(clustered_data[:, :cluster])]

## Load the distance scaling factors
scale_factors = RData.load(joinpath(path, "scale_factors.rds")).data

## Load the adjacency matrices
adjacency_matrices = RData.load(joinpath(path, "adjacency_matrices.rds"))
adjacency_matrices = [filter(:cluster => cluster -> cluster == i, adjacency_matrices) for i in unique(adjacency_matrices[:, :cluster])]
function buildmatrix(A)
  I = A[:, :row]
  J = A[:, :col]
  V = Float32.(A[:, :v])
  return sparse(I,J,V)
end
adjacency_matrices = buildmatrix.(adjacency_matrices);


## ---- Load estimators ----

p = 3 # number of parameters

pointestimator = gnnarchitecture(p)

v = gnnarchitecture(p; final_activation = identity)
a = [minimum.(values(Ω))...]
b = [maximum.(values(Ω))...]
g = Compress(a, b)
intervalestimator = IntervalEstimator(v, g)

Flux.loadparams!(pointestimator,    loadbestweights(joinpath(path, "pointestimator")))
Flux.loadparams!(intervalestimator, loadbestweights(joinpath(path, "intervalestimator")))

## ---- Estimate ----

@info "Starting GNN estimation..."

function constructgraph(data, scale_factor, adjacency_matrix)

    A = copy(adjacency_matrix) # avoid mutating global variable adjacency_matrices

    # Restrict the sample size while prototyping
    # n = size(data, 1)
    # max_n = 2000
    # if n > max_n
    # data = data[sample(1:n, max_n; replace = false), :]
    # end

    # # Compute the adjacency matrix
    # S = data[:, [:x, :y, :z]] |> Matrix
    # k = 10 # number of neighbours to consider (same value as used during training)
    # A = adjacencymatrix(S, k; maxmin = true)

    # Scale the distances so that they are between [0, sqrt(2)]
    v = A.nzval
    v .*= scale_factor

    # Construct the graph
    Z = data[:, [:Z]] |> Matrix
    Z = Float32.(Z)
    g = GNNGraph(A, ndata = permutedims(Z))

    return g
end

t = @elapsed g = Folds.map(1:length(clustered_data)) do k
   constructgraph(clustered_data[k], scale_factors[k], adjacency_matrices[k])
end
t += @elapsed θ = estimateinbatches(pointestimator, g)
t += @elapsed θ_quantiles = estimateinbatches(intervalestimator, g)
θ = vcat(θ, θ_quantiles)

# Scale the range parameter point and quantile estimates back to original scale
for k in 1:size(θ, 2)
  θ[2 .+ (0:2)p, k] /= scale_factors[k]
end

θ = permutedims(θ)
θ = DataFrame(θ, repeat(["τ", "ρ", "σ"], 3) .* repeat(["", "_lower", "_upper"], inner = 3)) #TODO parameter names shouldn't be hardcoded like this...
CSV.write(joinpath(path, "GNN_runtime.csv"), DataFrame(time = [t]))
CSV.write(joinpath(path, "GNN_estimates.csv"), θ)

@info "Finished GNN estimation!"
