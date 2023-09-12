abstract type AbstractVRPRouteItem end
struct NullVRPRouteItem <: AbstractVRPRouteItem end

const NULL_RI = NullVRPRouteItem()


export  VRPRouteItem,
        compareRouteItem
        # compareRouteItem,
        # getCurrLocation, setCurrLocation!,
        # getPrev, setPrev!,
        # getNext, setNext!,
        # getTimeArrived, setTimeArrived!


mutable struct VRPRouteItem <: AbstractVRPRouteItem
  currLocation::VRPLocation
  prev::AbstractVRPRouteItem
  next::AbstractVRPRouteItem
  # prev::Union{VRPRouteItem,Nothing}
  # next::Union{VRPRouteItem,Nothing}
  timeArrived::Float64
  waitingTime::Float64

  VRPRouteItem( cl::VRPLocation, p::AbstractVRPRouteItem, n::AbstractVRPRouteItem, ta::Real ) =
    new( cl, p, n, ta, 0.0 )
end


function Base.show( io::IO, ri::VRPRouteItem )
  print( io, ri.currLocation, "\nPrevious location ID: ",
    ri.prev isa VRPRouteItem ? ri.prev.currLocation.id : "null",
    "   Next location ID: ",
    ri.next isa VRPRouteItem ? ri.next.currLocation.id : "null",
    "\nTime arrived: ", ri.timeArrived,
    "   Waiting time: ", ri.waitingTime )
end


Base.:(==)( ri1::VRPRouteItem, ri2::VRPRouteItem ) =
  ri1.currLocation == ri2.currLocation &&
    ri1.timeArrived == ri2.timeArrived &&
    ri1.waitingTime == ri2.waitingTime
compareRouteItem( ri1::VRPRouteItem, ri2::VRPRouteItem ) = ri1 == ri2

#=
# Since these are basic getindex, setindex commands on the struct's field, are they necessary?
getCurrLocation( ri::VRPRouteItem ) = ri.currLocation
setCurrLocation!( ri::VRPRouteItem, currLocation::VRPLocation ) =
  ri.currLocation = currLocation  # deepcopy?

getPrev( ri::VRPRouteItem ) = ri.prev
setPrev!( ri::VRPRouteItem, prev::VRPRouteItem ) = ri.prev = prev

getNext( ri::VRPRouteItem ) = ri.next
setNext!( ri::VRPRouteItem, next::VRPRouteItem ) = ri.next = next

getTimeArrived( ri::VRPRouteItem ) = ri.timeArrived
setTimeArrived!( ri::VRPRouteItem, timeArrived::Real ) =
  ri.timeArrived = timeArrived

getWaitingTime( ri::VRPRouteItem ) = ri.waitingTime
setWaitingTime!( ri::VRPRouteItem, waitingTime::Real ) =
  ri.waitingTime = waitingTime
=#