export  VRPRoute,
        copyRoute,
        compareRoute,
        addPenultimate!,
        insertAfter!,
        removeRouteItem!,
        sizeOfRoute,
        calcVolume
        # calcVolume,
        # getFirst, setFirst!,
        # getLast, setLast!,
        # getVolume, setVolume!,
        # getId, setId!


# A route is basically a doubly linked list.
# Optimization: use the MutableLinkedList from DataStructures?
mutable struct VRPRoute
  id::Int
  first::AbstractVRPRouteItem
  last::AbstractVRPRouteItem
  volume::Int

  function VRPRoute( l::VRPLocation, id::Integer, t::Real )
    iszero(l.demand) || @warn "Demand of depot must be zero. Route volume calculations might be off."

    rt = new()
    rt.volume = 0  # Can be changed to 2 * l.demand

    rt.id = id
    rt.first = VRPRouteItem( l, NULL_RI, NULL_RI, 0 )
    rt.last = VRPRouteItem( l, rt.first, NULL_RI, t )
    rt.first.next = rt.last
    rt
  end
end


function Base.show( io::IO, rt::VRPRoute )
  ri = rt.first

  while ri isa VRPRouteItem
    loc = ri.currLocation
    print( io, "Location ", loc.id, " at (", loc.x, ',', loc.y, ") has been visited at ", ri.timeArrived, '\n' )
    ri = ri.next
  end

  print( io, "Route volume: ", rt.volume )
end


function copyRoute( rt::VRPRoute )
  # What is going on here???
  # Wouldn't a deepcopy do essentially the same?
  # No, because of copyLocation.
  newrt = VRPRoute( copyLocation(rt.first.currLocation), rt.id, rt.last.timeArrived )
  newrt.first.waitingTime = rt.first.waitingTime

  currRI, currnewRI = getfield.( [rt, newrt], :first )

  while (currRI = currRI.next).next isa VRPRouteItem
    currnewRI.next = VRPRouteItem( copyLocation(currRI.currLocation), currnewRI, currnewRI.next, currRI.timeArrived )
    currnewRI = currnewRI.next
    currnewRI.next.prev = currnewRI
    currnewRI.waitingTime = currRI.waitingTime
  end

  newrt.volume = rt.volume
  newrt
end


function Base.:(==)( rt1::VRPRoute, rt2::VRPRoute )
  # Check id and volume
  rt1.id == rt2.id || return false
  rt1.volume == rt2.volume || return false

  thisri = rt1.first
  thatri = rt2.first
  
  while thisri isa VRPRouteItem && thatri isa VRPRouteItem
    # Check individual RouteItem elements
    thisri == thatri || return false
    thisri = thisri.next
    thatri = thatri.next
  end

  # If all things are the same so far, check if both Routes have reached the end
  thisri === NULL_RI && thatri === NULL_RI
end

compareRoute( rt1::VRPRoute, rt2::VRPRoute ) = rt1 == rt2


function addPenultimate!( rt::VRPRoute, l::VRPLocation, t::Real )
  ri = VRPRouteItem( l, rt.last.prev, rt.last, t )
  rt.last.prev = rt.last.prev.next = ri
  rt.volume += l.demand
end


function insertAfter!( rt::VRPRoute, ri::VRPRouteItem, l::VRPLocation, t::Real )
  if ri.next === NULL_RI
    @warn "Last location must be depot"
    return
  end

  r = VRPRouteItem( l, ri, ri.next, t )
  ri.next = ri.next.prev = r
  rt.volume += l.demand
end


function removeRouteItem!( rt::VRPRoute, ri::VRPRouteItem )
  if ri.prev === NULL_RI || ri.next === NULL_RI
    @warn "Cannot delete depot"
    return
  end

  ri.prev.next = ri.next
  ri.next.prev = ri.prev
  rt.volume -= ri.currLocation.demand
end


function sizeOfRoute( rt::VRPRoute )
  size = 1
  ri = rt.first

  while (ri = ri.next) !== NULL_RI
    size += 1
  end

  size
end


function calcVolume( rt::VRPRoute )
  ri = rt.first
  volume = 0

  while ri !== NULL_RI
    volume += ri.currLocation.demand
    ri = ri.next
  end

  return volume
end

#=
getFirst( rt::VRPRoute ) = rt.first
setFirst!( rt::VRPRoute, ri::VRPRouteItem ) = rt.first = ri

getLast( rt::VRPRoute ) = rt.last
setLast!( rt::VRPRoute, ri::VRPRouteItem ) = rt.last = ri

getVolume( rt::VRPRoute ) = rt.volume
setVolume!( rt::VRPRoute, volume::Integer ) = rt.volume = volume

getId( rt::VRPRoute ) = rt.id
setID!( rt::VRPRoute, id::Integer ) = rd.id = id
=#
