export  VRPRoute2,
        addPenultimate!,
        insertAfter!,
        removeRouteItem!,
        sizeOfRoute,
        calcVolume



mutable struct VRPRoute2
  id::Int
  routeitems::MutableLinkedList{VRPRouteItem2}
  volume::Int

  function VRPRoute2( l::VRPLocation2, id::Integer, t::Real )
    iszero(l.demand) || @warn "Demand of depot must be zero. Route volume calculations might be off."

    rt = new()
    rt.volume = 0  # Can be changed to 2 * l.demand

    rt.id = id
    rt.routeitems = MutableLinkedList{VRPRouteItem2}( VRPRouteItem2( l, 0 ), VRPRouteItem2( l, t ) )
    rt
  end
end


function Base.show( io::IO, rt::VRPRoute2 )
  for ri in rt.routeitems
    loc = ri.currLocation
    print( io, "Location ", loc.id, " at (", loc.x, ',', loc.y, ") has been visited at ", ri.timeArrived, '\n' )
  end

  print( io, "Route volume: ", rt.volume )
end


function Base.:(==)( rt1::VRPRoute2, rt2::VRPRoute2 )
  rt1.id == rt2.id || return false
  rt1.volume == rt2.volume || return false
  length(rt1.routeitems) == length(rt2.routeitems) || return false
  all( rt1.routeitems .== rt2.routeitems )
end


function addPenultimate!( rt::VRPRoute2, l::VRPLocation2, t::Real )
  ri = VRPRouteItem2( l, t )
  insert!( rt, sizeOfRoute(rt), ri )
  rt.volume += l.demand
end


function insertAfter!( rt::VRPRoute2, ri::VRPRouteItem2, l::VRPLocation2, t::Real )
  ii = findfirst( rt.routeitems .== Ref(ri) )

  if isnothing(ii)
    @warn "Route item isn't part of the route"
    return
  end

  if ii == length(rt.routeitems)
    @warn "Last location must be depot"
    return
  end

  r = VRPRouteItem2( l, t )
  insert!( rt, ii + 1, r )
  rt.volume += l.demand
end


function removeRouteItem!( rt::VRPRoute2, ri::VRPRouteItem2 )
  ii = findfirst( rt.routeitems .== Ref(ri) )
  
  if isnothing(ii)
    @warn "Route item isn't part of the route"
    return
  end

  if ii ∈ [1, length(rt.routeitems)]
    @warn "Cannot delete depot"
    return
  end

  deleteat!( rt, ii )
  rt.volume -= ri.currLocation.demand
end


sizeOfRoute( rt::VRPRoute2 ) = length(rt.routeitems)

calcVolume( rt::VRPRoute2 ) =
  sum( getfield.( getfield.( rt.routeitems, :currLocation ), :demand ) )
