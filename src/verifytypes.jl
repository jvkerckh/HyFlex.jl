export  verify


function verify( T::DataType )
  T <: AbstractHyperHeuristic && return verifyHH(T)
  T <: AbstractProblemDomain && return verifyPD(T)

  @error "Data type $T is not a subtype of AbstractHyperHeuristic or AbstractProblemDomain"
  false
end

verify(x) = verify( typeof(x) )


const PD_FIELDS = [
  :rng
  :depthOfSearch
  :intensityOfMutation
  :heuristicCallRecord
  :heuristicCallTimeRecord
  :heuristicTypes
]

const PD_METHODNAMES = [
  :getHeuristicsOfType
  :getHeuristicsThatUseIntensityOfMutation
  :getHeuristicsThatUseDepthOfSearch
  :loadInstance
  :setMemorySize!
  :initialiseSolution
  :getNumberOfHeuristics
  :applyHeuristic  # 2 versions
  :copySolution
  # :string  # from toString
  :getNumberOfInstances
  :bestSolutionToString
  :getBestSolutionValue
  :solutionToString
  :getFunctionValue
  :compareSolutions
]

eval( Meta.parse( string( "export ", join( PD_METHODNAMES, ", " ) ) ) )

foreach( PD_METHODNAMES ) do pdm
  eval( Meta.parse("$pdm() = nothing") )
end

const PD_METHODS = Dict{Function,Vector{Vector{DataType}}}(
  getHeuristicsOfType => [[HeuristicType]],
  getHeuristicsThatUseIntensityOfMutation => [[]],
  getHeuristicsThatUseDepthOfSearch => [[]],
  loadInstance => [[Integer]],
  setMemorySize! => [[Integer]],
  initialiseSolution => [[Integer]],
  getNumberOfHeuristics => [[]],
  applyHeuristic => [
    [Integer, Integer, Integer],
    [Integer, Integer, Integer, Integer]
  ],
  copySolution => [[Integer, Integer]],
  # :string  # from toString
  getNumberOfInstances => [[]],
  bestSolutionToString => [[]],
  getBestSolutionValue => [[]],
  solutionToString => [[Integer]],
  getFunctionValue => [[Integer]],
  compareSolutions => [[Integer, Integer]],
)


function verifyPD(T::DataType)
  pdokayfields = hasfield.( Ref(T), PD_FIELDS )
  pdokay = all(pdokayfields)
  
  if !all(pdokayfields)
    @error string( "Data type $T is missing these fields: ", join( PD_FIELDS[.!pdokayfields], "   " ) )
  end

  pdokaymethods = map( pdm -> verifyMethod( pdm, T ), collect( keys(PD_METHODS) ) )

  return pdokay && all(pdokaymethods)
end


function verifyMethod( method::Function, T::DataType )
  targetsigs = vcat.( T, PD_METHODS[method] )
  
  # methods(f) is a MethodList
  # elements of methods(f) are of type Method
  # field :sig of a Method holds the function signature, of type Tuple
  # field :types of a Tuple holds the types, BUT as a Core.SimpleVector
  # collect converts this to a regular vector
  isokay = map(targetsigs) do tsig
    sigexists = any(map( fm -> collect(fm.sig.types[2:end]) == tsig, methods(method) ))
    sigexists || @error string( "Data type ", T, " must define a method ", method, "(", join( string.( "::", tsig ), ", " ), ")" )
    any(sigexists)
  end

  all(isokay)
end
