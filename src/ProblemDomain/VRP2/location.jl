export VRPLocation2


mutable struct VRPLocation2
  id::Int
  x::Int
  y::Int
  demand::Int
  dueDate::Int
  readyTime::Int
  serviceTime::Int
  serviced::Bool

  VRPLocation2( id::Integer, x::Integer, y::Integer, d::Integer, rt::Integer, dd::Integer, st::Integer ) =
    new( id, x, y, d, dd, rt, st, false )
end


function Base.show( io::IO, loc::VRPLocation2 )
  print( io, "For location ", loc.id, ", at (", loc.x, ",", loc.y, "), demand is ", loc.demand, ", ready time is ", loc.readyTime, ", due time is ", loc.dueDate, " and service time is ", loc.serviceTime )
end


Base.deepcopy( loc::VRPLocation2 ) =
  VRPLocation2( loc.id, loc.x, loc.y, loc.demand, loc.readyTime, loc.dueDate, loc.serviceTime )


function Base.:(==)( loc1::VRPLocation2, loc2::VRPLocation2 )
  all( map( fieldnames(VRPLocation) ) do fn
    fn === :serviced && return true
    getfield( loc1, fn ) == getfield( loc2, fn )
  end )
end
