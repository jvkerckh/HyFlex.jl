# Extensions of existing methods.
function Base.insert!( ll::MutableLinkedList{T1}, ii::Integer, el::T2 ) where {T1, T2 <: T1}
  nel = length(ll)
  1 <= ii <= nel + 1 || throw( BoundsError( ll, ii ) )
  ii > nel && return push!( ll, el )
  ii == 1 && return pushfirst!( ll, el )

  tmpll = MutableLinkedList{T1}( el, (ii == nel ? [ll[nel]] : ll[ii:nel])... )
  ii == nel ? pop!(ll) : delete!( ll, ii:nel )
  append!( ll, tmpll... )
end


Base.getindex( rt::VRPRoute2, ii::Integer ) = rt.routeitems[ii]
Base.getindex( rt::VRPRoute2, inds::Vector{T} ) where T <: Integer =
  rt.routeitems[inds]
Base.getindex( rt::VRPRoute2, inds::OrdinalRange{T} ) where T <: Integer =
  rt.routeitems[inds]
  
Base.lastindex( rt::VRPRoute2 ) = length(rt.routeitems)

Base.setindex!( rt::VRPRoute2, ri::VRPRouteItem2, ii::Integer ) =
  rt.routeitems[ii] = ri

Base.insert!( rt::VRPRoute2, ii::Integer, ri::VRPRouteItem2 ) =
  insert!( rt.routeitems, ii, ri )

Base.deleteat!( rt::VRPRoute2, ii::Integer ) = delete!( rt.routeitems, ii )
Base.deleteat!( rt::VRPRoute2, inds::OrdinalRange{T} ) where T <: Integer =
  delete!( rt.routeitems, inds )

Base.append!( rt::VRPRoute2, rilist::MutableLinkedList{VRPRouteItem2} ) =
  append!( rt.routeitems, rilist... )
