export  AbstractHyperHeuristic,
        AbstractProblemDomain,
        HeuristicType

abstract type AbstractHyperHeuristic end
abstract type AbstractProblemDomain end

@enum HeuristicType MUTATION CROSSOVER RUIN_RECREATE LOCAL_SEARCH OTHER
