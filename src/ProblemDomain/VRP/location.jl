export  VRPLocation,
        copyLocation,
        compareLocation


mutable struct VRPLocation
  id::Int
  x::Int
  y::Int
  demand::Int
  dueDate::Int
  readyTime::Int
  serviceTime::Int
  serviced::Bool

  VRPLocation( id::Integer, x::Integer, y::Integer, d::Integer, rt::Integer, dd::Integer, st::Integer ) =
    new( id, x, y, d, dd, rt, st, false )
end


function Base.show( io::IO, loc::VRPLocation )
  print( io, "For location ", loc.id, ", at (", loc.x, ",", loc.y, "), demand is ", loc.demand, ", ready time is ", loc.readyTime, ", due time is ", loc.dueDate, " and service time is ", loc.serviceTime )
end


function copyLocation( loc::VRPLocation )
  newloc = deepcopy(loc)
  newloc.serviced = false
  newloc
end


function Base.:(==)( loc1::VRPLocation, loc2::VRPLocation )
  all( map( fieldnames(VRPLocation) ) do fn
    fn === :serviced && return true
    getfield( loc1, fn ) == getfield( loc2, fn )
  end )
end

compareLocation( loc1::VRPLocation, loc2::VRPLocation ) = loc1 == loc2
