abstract type AbstractVRPRouteItem2 end
struct NullVRPRouteItem2 <: AbstractVRPRouteItem2 end

const NULL_RI2 = NullVRPRouteItem2()


export  VRPRouteItem2


mutable struct VRPRouteItem2 <: AbstractVRPRouteItem2
  currLocation::VRPLocation2
  timeArrived::Float64
  waitingTime::Float64

  VRPRouteItem2( cl::VRPLocation2, ta::Real ) = new( cl, ta, 0.0 )
end


function Base.show( io::IO, ri::VRPRouteItem2 )
  print( io, "Location ID: ", ri.currLocation, "   Time arrived: ", ri.timeArrived, "   Waiting time: ", ri.waitingTime )
end


Base.:(==)( ri1::VRPRouteItem2, ri2::VRPRouteItem2 ) =
  ri1.currLocation == ri2.currLocation &&
    ri1.timeArrived == ri2.timeArrived &&
    ri1.waitingTime == ri2.waitingTime
