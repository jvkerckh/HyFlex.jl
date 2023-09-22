include("VRP/VRP.jl")
include("VRP2/VRP.jl")

# Methods common to all subtypes of AbstractProblemDomain
# export  getHeuristicCallRecord,
#         getHeuristicCallTimeRecord,
#         getDepthOfSearch, setDepthOfSearch!,
#         getIntensityOfMutation, setIntensityOfMutation!
export  setDepthOfSearch!, setIntensityOfMutation!

#=
getHeuristicCallRecord( pd::AbstractProblemDomain ) =
  pd.heuristicCallRecord

getHeuristicCallTimeRecord( pd::AbstractProblemDomain ) =
  pd.heuristicCallTimeRecord

getDepthOfSearch( pd::AbstractProblemDomain ) =
  pd.depthOfSearch
  =#
setDepthOfSearch!( pd::AbstractProblemDomain, dos::Real ) =
  pd.depthOfSearch = clamp( dos, 0, 1 )

# getIntensityOfMutation( pd::AbstractProblemDomain ) =
#   pd.intensityOfMutation
setIntensityOfMutation!( pd::AbstractProblemDomain, iom::Real ) =
  pd.intensityOfMutation = clamp( iom, 0, 1 )
