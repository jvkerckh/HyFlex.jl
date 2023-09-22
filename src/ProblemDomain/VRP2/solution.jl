export  VRPSolution2

mutable struct VRPSolution2
  routes::Vector{VRPRoute2}
end


function Base.show( io::IO, sol::VRPSolution2 )
  for (ii, rt) in enumerate(sol.routes)
    print( io, "Route $ii" )

    for ri in rt.routeitems
      print( io, "\nLocation ", ri.currLocation.id, " visited at ", ri.timeArrived )
    end
  end
end
