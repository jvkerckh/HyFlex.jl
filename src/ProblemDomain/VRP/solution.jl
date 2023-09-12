export  VRPSolution

mutable struct VRPSolution
  routes::Vector{VRPRoute}
end


function Base.show( io::IO, sol::VRPSolution )
  for (ii, rt) in enumerate(sol.routes)
    print( io, "Route $ii" )
    ri = rt.first

    while ri !== NULL_RI
      print( io, "\nLocation ", ri.currLocation.id, " visited at ", ri.timeArrived )
      ri = ri.next
    end
  end
end


copySolution( sol::VRPSolution ) =
  VRPSolution( copyRoute.(sol.routes) )
