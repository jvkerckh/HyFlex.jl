include("location.jl")
include("routeitem.jl")
include("route.jl")
include("solution.jl")
include("instance.jl")


const VRP_HTS = Dict(
  MUTATION => [1, 2, 8],
  RUIN_RECREATE => [3, 4],
  LOCAL_SEARCH => [5, 9, 10],
  CROSSOVER => [6, 7]
)


export VRP

mutable struct VRP <: AbstractProblemDomain
  rng::MersenneTwister
  depthOfSearch::Float64
  intensityOfMutation::Float64
  heuristicCallRecord::Vector{Int}
  heuristicCallTimeRecord::Vector{Int}

  instance::VRPInstance
  solutions::Vector{VRPSolution}
  bestSolutionValue::Float64
  bestSolution::VRPSolution

  heuristicTypes::Dict{HeuristicType,Vector{Int}}

  function VRP( ;
    rng::MersenneTwister=MersenneTwister(),
    depthOfSearch::Real=0.2,
    intensityOfMutation::Real=0.2 )
    vrp = new()
    vrp.rng = rng
    vrp.depthOfSearch = depthOfSearch
    vrp.intensityOfMutation = intensityOfMutation
    # vrp.heuristicCallRecord = fill( 0, getNumberOfHeuristics(vrp) )
    # vrp.heuristicCallTimeRecord = fill( 0, getNumberOfHeuristics(vrp) )
    vrp.heuristicCallRecord = []
    vrp.heuristicCallTimeRecord = []

    vrp.solutions = []
    vrp.bestSolutionValue = Inf
    vrp.bestSolution = VRPSolution([])

    vrp.heuristicTypes = VRP_HTS
    vrp
  end
end

VRP( seed::Integer ) = VRP( rng=MersenneTwister(seed) )


getHeuristicsOfType( vrp::VRP, heuristicType::HeuristicType ) =
  get( vrp.heuristicTypes, heuristicType, nothing )

getHeuristicsThatUseIntensityOfMutation( ::VRP ) = [1, 2, 3, 4]

getHeuristicsThatUseDepthOfSearch( ::VRP ) = [5, 9, 10]

loadInstance( vrp::VRP, instanceID::Integer ) =
  vrp.instance = VRPInstance(instanceID)


function setMemorySize!( vrp::VRP, msize::Integer )
  nold = length(vrp.solutions)

  if msize <= nold
    @inbounds vrp.solutions = vrp.solutions[1:msize]
    return
  end

  append!( vrp.solutions, map( ii -> VRPSolution([]), (nold+1):msize ) )
end


function initialiseSolution( vrp::VRP, ii::Integer )
  ii ∈ eachindex(vrp.solutions) || throw(BoundsError( vrp, ii ))

  @inbounds vrp.solutions[ii] = constructiveHeuristic( vrp, vrp.instance )
  getFunctionValue( vrp, ii )
end


getNumberOfHeuristics( ::VRP ) = 10


function applyHeuristic( vrp::VRP, heuristicID::Integer, ssid::Integer, sdid::Integer )
  if !(1 <= heuristicID <= 10)
    @error "Heuristic $heuristicID does not exist"
    return 0.0
  end

  if !all( [ssid, sdid] .∈ Ref(eachindex(vrp.solutions)) )
    @error "Source and/or destination index are out of bounds"
    return 0.0
  end

  startTime = now()

  if heuristicID ∈ getHeuristicsOfType( vrp, CROSSOVER )
    @inbounds vrp.solutions[sdid] = copySolution( vrp.solutions[ssid] )
    return getFunctionValue( vrp, sdid )
  end

  heuristicFunction = VRP_HEURISTIC_FUNCTIONS[heuristicID]
  score = heuristicFunction( vrp, ssid, sdid )
  @inbounds vrp.heuristicCallRecord[heuristicID] += 1
  @inbounds vrp.heuristicCallTimeRecord[heuristicID] += ( now() - startTime ).value
  score
end

function applyHeuristic( vrp::VRP, heuristicID::Integer, ssid1::Integer, ssid2::Integer, sdid::Integer )
  if !(1 <= heuristicID <= 10)
    @error "Heuristic $heuristicID does not exist"
    return 0.0
  end

  if !all( [ssid1, ssid2, sdid] .∈ Ref(eachindex(vrp.solutions)) )
    @error "Source and/or destination index are out of bounds"
    return 0.0
  end

  startTime = now()
  heuristicFunction = VRP_HEURISTIC_FUNCTIONS[heuristicID]
  # These functions should be implemented: twoOpt, orOpt, locRR, timeRR, shift, combine, combineLong, shiftMutate, twoOptStar, GENI
  score = heuristicFunction( vrp,
    (heuristicID ∈ getHeuristicsOfType( vrp, CROSSOVER ) ? [ssid1, ssid2] : [ssid1])...,
    sdid )
  @inbounds vrp.heuristicCallRecord[heuristicID] += 1
  @inbounds vrp.heuristicCallTimeRecord[heuristicID] += ( now() - startTime ).value
  score
end


copySolution( vrp::VRP, ssid::Integer, sdid::Integer ) =
  @inbounds vrp.solutions[sdid] = copySolution(vrp.solutions[ssid])

getNumberOfInstances( ::VRP ) = 56

bestSolutionToString( vrp::VRP ) = string(vrp.bestSolution)

# This one is redundant.
function getBestSolutionValue( vrp::VRP )
  @warn "This function is redundant. Use `vrp.bestSolutionValue` instead"
  vrp.bestSolutionValue
end

solutionToString( vrp::VRP, sid::Integer ) =
  @inbounds string(vrp.solutions[sid])


function getFunctionValue( vrp::VRP, solutionIndex::Integer )
  @inbounds sol = vrp.solutions[solutionIndex]
  @inbounds value = calcFunction(sol.routes)

  if value < vrp.bestSolutionValue
    vrp.bestSolutionValue = value
    @inbounds vrp.bestSolution = copySolution(sol)
  end

  value
end


function compareSolutions( vrp::VRP, sid1::Integer, sid2::Integer )
  @inbounds rts1 = vrp.solutions[sid1].routes
  @inbounds rts2 = vrp.solutions[sid2].routes

  for ii in eachindex(rts1)
    @inbounds compareRoute( rts1[ii], rts2[ii] ) || return false
  end

  true
end


# Non exported methods
include("auxiliary.jl")
include("heuristics.jl")
include("heuristicaux.jl")


const VRP_HEURISTIC_FUNCTIONS = [
  twoOpt
  orOpt
  locRR
  timeRR
  shift
  combine
  combineLong
  shiftMutate
  twoOptStar
  GENI
]
