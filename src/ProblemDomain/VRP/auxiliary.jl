function constructiveHeuristic( vrp::VRP, inst::VRPInstance )
  tempLocs = inst.demands
  @inbounds depot = copyLocation(tempLocs[1])
  @inbounds locations = copyLocation.(tempLocs[2:end])

  numRoutes = 1
  routes = [VRPRoute( depot, numRoutes, 0 )]
  
  while !isempty(locations)
    bestIndex = -1
    bestScore = typemax(Float64)
    bestTimeMinusReady = 0.0
    @inbounds lastRoute = routes[end]
    scoreTimes = fill( Inf, length(locations), 2 )

    foreach( eachindex(locations) ) do jj
      @inbounds loc = locations[jj]
      lastRoute.volume + loc.demand < inst.vehicleCapacity || return

      diff1 = lastRoute.last.currLocation.dueDate - ( loc.readyTime + loc.serviceTime + calcDistance( loc, lastRoute.last.currLocation ) )
      diff1 > 0 || return

      lastStop = lastRoute.last.prev
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
        # (dist + (due - lastTime)) * randnums[jj],
        timeDiff - readyDueDiff
      ]
    end

    @inbounds bestScore, bestIndex = findmin(scoreTimes[:, 1])
    @inbounds bestTimeMinusReady = scoreTimes[bestIndex, 2]

    if bestScore < Inf
      lastStop = lastRoute.last.prev
      prevLocation = lastStop.currLocation
      lastStop.waitingTime = max( 0, bestTimeMinusReady )
      @inbounds bestLoc = locations[bestIndex]
      addPenultimate!( lastRoute, bestLoc, lastStop.timeArrived + prevLocation.serviceTime + lastStop.waitingTime + calcDistance( prevLocation, bestLoc ) )
      deleteat!( locations, bestIndex )
    end

    numRoutes += 1
    push!( routes, VRPRoute( depot, numRoutes, 0 ) )
  end

  VRPSolution(routes)
end


calcDistance( loc1::VRPLocation, loc2::VRPLocation ) =
  sqrt( (loc1.x - loc2.x)^2 + (loc1.y - loc2.y)^2 )
calcDistance( ri1::VRPRouteItem, ri2::VRPRouteItem ) =
  calcDistance( ri1.currLocation, ri2.currLocation )


function calcFunction( rts::Vector{VRPRoute} )
  distances = map( rts ) do rt
    ri = rt.first
    distance = 0.0

    while ri.next !== NULL_RI
      distance += calcDistance( ri, ri.next )
      ri = ri.next
    end

    distance
  end

  return 1000 * length(rts) + sum(distances)
end
