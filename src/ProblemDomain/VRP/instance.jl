const VRP_INSTANCE_CONFIGS = [
  "Solomon_100_customer_instances/RC/RC207.txt"
  "Solomon_100_customer_instances/R/R101.txt"
  "Solomon_100_customer_instances/RC/RC103.txt"
  "Solomon_100_customer_instances/R/R201.txt"
  "Solomon_100_customer_instances/R/R106.txt"
  "Homberger_1000_customer_instances/C/C1_10_1.TXT"
  "Homberger_1000_customer_instances/RC/RC2_10_1.TXT"
  "Homberger_1000_customer_instances/R/R1_10_1.TXT"
  "Homberger_1000_customer_instances/C/C1_10_8.TXT"
  "Homberger_1000_customer_instances/RC/RC1_10_5.TXT"
]


export  VRPInstance
# export  VRPInstance,
#         getDemands, setDemands!,
#         getInstanceName, setInstanceName!,
#         getVehicleNumber, setVehicleNumber!,
#         getVehicleCapacity, setVehicleCapacity!,
#         getDepot, setDepot!


mutable struct VRPInstance
  demands::Vector{VRPLocation}
  instanceName::String
  vehicleNumber::Int
  vehicleCapacity::Int
  depot::VRPLocation


  function VRPInstance( id::Integer )
    @assert 1 <= id <= 10 "id must be between 1 and 10 (was $id)"

    inst = new()

    fileName = normpath(joinpath( @__DIR__, "../../..", "data/vrp/", VRP_INSTANCE_CONFIGS[id] ))

    if ispath(fileName)
      isokay = open( io -> readVRPInstanceFile( inst, io ), fileName )
      isokay || @warn """Could not load instance, or instance does not exist.
      VRP instance has not been properly initialised."""
    else
      @error "Cannot find file $fileName."
      @warn "VRP instance has not been properly initialised."
    end

    inst
  end
end


function Base.show( io::IO, inst::VRPInstance )
  print( io, "Instance name is ", inst.instanceName, ", there are ", inst.vehicleNumber, " vehicles with capacity of ", inst.vehicleCapacity )
  print.( io, '\n', inst.demands )
end


function readVRPInstanceFile( inst::VRPInstance, io::IOStream )
  flines = readlines(io)
  nlines = length(flines)

  if nlines < 10
    @error """File must have 10 or more lines, has only $nlines.
    Could not load instance, or instance does not exist.
    VRP instance has not been properly initialised."""
    return false
  end

  # Line 1 contains the name of the VRP instance
  @inbounds inst.instanceName = flines[1]
  # Lines 2-4 are ignored
  
  # Line 5 contains the number of vehicles and the max capacity
  @inbounds vinfo = split(flines[5])

  if length(vinfo) < 2
    @error """Line 5 of file must have (at least) 2 white space delineated entries."""
    return false
  end

  @inbounds vnum, vcap = tryparse.( Int, vinfo[1:2] )

  if isnothing(vnum) || isnothing(vcap)
    @error """First 2 entries of line 5 of file must be integers."""
    return false
  end

  inst.vehicleNumber, inst.vehicleCapacity = vnum, vcap
  # Lines 6-9 are ignored

  # Lines 10-EOF
  ii = 10
  inst.demands = Vector{VRPLocation}( undef, nlines-9 )

  while ii <= nlines
    @inbounds linfo = split(flines[ii])

    if length(linfo) < 7
      @error """Line ii of file must have (at least) 7 white space delineated entries, has $(length(linfo))."""
      return false
    end

    @inbounds linfo = tryparse.( Int, linfo[1:7] )

    if any(isnothing.(linfo))
      @error """First 7 entries of line $ii of file must be integers."""
      return false
    end

    @inbounds inst.demands[ii-9] = VRPLocation(linfo...)
    ii == 10 && (@inbounds inst.depot = inst.demands[1])
    ii += 1
  end

  true
end

#=
getDemands( inst::VRPInstance ) = inst.demands
setDemands!( inst::VRPInstance, demands::Vector{VRPLocation} ) =
  inst.demands = demands  # Deepcopy needed?

getInstanceName( inst::VRPInstance ) = inst.instanceName
setInstanceName!( inst::VRPInstance, instanceName::AbstractString ) =
  inst.instanceName = instanceName

getVehicleNumber( inst::VRPInstance ) = inst.vehicleNumber
setVehicleNumber!( inst::VRPInstance, vehicleNumber::Integer ) =
  inst.vehicleNumber = vehicleNumber

getVehicleCapacity( inst::VRPInstance ) = inst.vehicleCapacity
setVehicleCapacity!( inst:: VRPInstance, vehicleCapacity::Integer ) =
  inst.vehicleCapacity = vehicleCapacity

getDepot( inst::VRPInstance ) = inst.depot
setDepot!( inst::VRPInstance, depot::VRPLocation ) =
  inst.depot = depot  # Deepcopy needed?
=#