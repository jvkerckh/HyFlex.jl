export  VRPLocation,
        copyLocation,
        compareLocation
        # compareLocation,
        # getId, setId!,
        # getXCoord, setXCoord!,
        # getYCoord, setYCoord!,
        # getDemand, setDemand!,
        # getDueDate, setDueDate!,
        # getServiceTime, setServiceTime!,
        # isServiced, setServiced!


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


#=
getId( loc::VRPLocation ) = loc.id
setId!( loc::VRPLocation, id::Integer ) = loc.id = id

getXCoord( loc::VRPLocation ) = loc.x
setXCoord!( loc::VRPLocation, x::Integer ) = loc.x = x

getYCoord( loc::VRPLocation ) = loc.y
setYCoord!( loc::VRPLocation, y::Integer ) = loc.y = y

getDemand( loc::VRPLocation ) = loc.demand
setDemand!( loc::VRPLocation, demand::Integer ) = loc.demand = demand

getDueDate( loc::VRPLocation ) = loc.dueDate
setDueDate!( loc::VRPLocation, dueDate::Integer ) = loc.dueDate = dueDate

getServiceTime( loc::VRPLocation ) = loc.serviceTime
setServiceTime!( loc::VRPLocation, serviceTime::Integer ) =
  loc.serviceTime = serviceTime

isServiced( loc::VRPLocation ) = loc.serviced
setServiced!( loc::VRPLocation, serviced::Bool ) =
  loc.serviced = serviced

getReadyTime( loc::VRPLocation ) = loc.readyTime
setReadyTime!( loc::VRPLocation, readyTime::Integer ) =
  loc.readyTime = readyTime
=#
