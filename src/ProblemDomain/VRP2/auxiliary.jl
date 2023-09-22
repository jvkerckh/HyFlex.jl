function constructiveHeuristic( vrp::VRP2, inst::VRPInstance2 )
  tempLocs = inst.demands
  @inbounds depot = deepcopy(tempLocs[1])
  @inbounds locations = deepcopy.(tempLocs[2:end])

  numRoutes = 1
  routes = [VRPRoute2( depot, numRoutes, 0 )]
  
  while !isempty(locations)
    bestIndex = -1
    bestScore = typemax(Float64)
    bestTimeMinusReady = 0.0
    @inbounds lastRoute = routes[end]
    scoreTimes = fill( Inf, length(locations), 2 )

    foreach( eachindex(locations) ) do jj
      @inbounds loc = locations[jj]
      lastRoute.volume + loc.demand < inst.vehicleCapacity || return

      diff1 = lastRoute[end].currLocation.dueDate - ( loc.readyTime + loc.serviceTime + calcDistance( loc, lastRoute[end] ) )
      diff1 > 0 || return

      lastStop = lastRoute[end-1]
      prevLocation = lastStop.currLocation
      dist = calcDistance( prevLocation, loc )
      due = loc.dueDate
      lastTime = lastStop.timeArrived
      timeDiff = due - ( lastTime + prevLocation.serviceTime + dist )
      timeDiff < 0 && return

      readyDueDiff = due - loc.readyTime
      diff1 < readyDueDiff - timeDiff && return

      @inbounds scoreTimes[jj, :] = [
        (dist + (due - lastTime)) * rand( vrp.rng ),
        timeDiff - readyDueDiff
      ]
    end

    @inbounds bestScore, bestIndex = findmin(scoreTimes[:, 1])
    @inbounds bestTimeMinusReady = scoreTimes[bestIndex, 2]

    if bestScore < Inf
      lastStop = lastRoute[end-1]
      prevLocation = lastStop.currLocation
      lastStop.waitingTime = max( 0, bestTimeMinusReady )
      @inbounds bestLoc = locations[bestIndex]
      addPenultimate!( lastRoute, bestLoc, lastStop.timeArrived + prevLocation.serviceTime + lastStop.waitingTime + calcDistance( prevLocation, bestLoc ) )
      deleteat!( locations, bestIndex )
    end

    numRoutes += 1
    push!( routes, VRPRoute2( depot, numRoutes, 0 ) )
  end

  VRPSolution2(routes)
end


calcDistance( loc1::VRPLocation2, loc2::VRPLocation2 ) =
  sqrt( (loc1.x - loc2.x)^2 + (loc1.y - loc2.y)^2 )
calcDistance( loc1::VRPLocation2, loc2::VRPRouteItem2 ) =
  calcDistance( loc1, loc2.currLocation )
calcDistance( loc1::VRPRouteItem2, loc2::VRPLocation2 ) =
  calcDistance( loc1.currLocation, loc2 )
calcDistance( ri1::VRPRouteItem2, ri2::VRPRouteItem2 ) =
  calcDistance( ri1.currLocation, ri2.currLocation )


function calcFunction( rts::Vector{VRPRoute2} )
  distances = map( rts ) do rt
    sum( 2:lastindex(rt) ) do ii
      @inbounds calcDistance( rt[ii-1], rt[ii] )
    end
  end

  return 1000 * length(rts) + sum(distances)
end
  