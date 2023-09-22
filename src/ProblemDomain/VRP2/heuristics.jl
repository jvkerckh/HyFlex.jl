# This heuristic selects a number of routes to mutate and randomly selects two adjecent stops to swap.
function twoOpt( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy(vrp.solutions[ssid])
  rts = copyS.routes
  nRoutes = length(rts)
  numRoutesToBeMutated = floor( Int, vrp.intensityOfMutation * nRoutes )
  @inbounds routesToBeMutated = randperm( vrp.rng, nRoutes )[1:numRoutesToBeMutated]

  for rtid in routesToBeMutated
    @inbounds rt = rts[rtid]
    nrt = twoOptMutate( vrp, rt )
    nrt isa Nothing || (@inbounds rts[rtid] = nrt)
  end

  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


# This heuristic selects a number of routes to mutate and randomly selects four adjecent stops to swap using this pattern: 1-2-3-4 -> 3-4-1-2.
function orOpt( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy( vrp.solutions[ssid] )
  rts = copyS.routes
  nRoutes = length(rts)
  numRoutesToBeMutated = floor( Int, vrp.intensityOfMutation * nRoutes )
  @inbounds routesToBeMutated = randperm( vrp.rng, nRoutes )[1:numRoutesToBeMutated]

  for rtid in routesToBeMutated
    @inbounds rt = rts[rtid]
    nrt = orOptMutate( vrp, rt )
    nrt isa Nothing || (@inbounds rts[rtid] = nrt)
  end

  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


# This heuristics selects a location being serviced, closes all nodes no further than a set distance from that location [ruin], and then opens new stations [recreate].
function locRR( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy(vrp.solutions[ssid])
  rts = copyS.routes

  # Ruin phase.

  # Select a random stop on a random route.
  rtc = rand( vrp.rng, rts )
  routePos = rand( vrp.rng, 2:sizeOfRoute(rtc)-1 )
  @inbounds ri = rtc[routePos]
  baseLocation = ri.currLocation

  # Find stop on routes with furthest distance from baseLocation.
  # Note, this isn't necessary the potential location furthest from baseLocation as this might not be servied by any route.
  furthest = 0.0

  for rt in rts, ri in rt.routeitems
    furthest = max( furthest, calcDistance( ri, baseLocation ) )
  end

  # Find all locations along routes in solution that are a set distance away from baseLocation and delete them from routes. Also clear routes that have no more stops.
  distanceWindow = 0.75 * vrp.intensityOfMutation * furthest
  locs = VRPLocation2[]
  routesToDelete = Int[]

  for (ii, rt) in enumerate(rts)
    ruinLoc( rt, ii, baseLocation, locs, routesToDelete, distanceWindow )
  end

  deleteat!( rts, routesToDelete )

  # Recreate phase.
  for loc in locs
    insertLocIntoRoute!( vrp, rts, loc )
  end

  deleteUnwantedRoutes!(copyS.routes)
  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


# This heuristics selects a time point and closes all nodes that are serviced within a specific time of that particular time point [ruin], and then opens new stations [recreate].
function timeRR( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy(vrp.solutions[ssid])
  rts = copyS.routes

  # Ruin phase.
  @inbounds maxTime = rts[1][end].currLocation.dueDate
  timeRef = rand( 1:maxTime ) - 1
  timeWindow = 0.5 * vrp.intensityOfMutation * maxTime
  locs = VRPLocation2[]
  routesToDelete = Int[]

  for (ii, rt) in enumerate(rts)
    ruinTime( rt, ii, timeRef, locs, routesToDelete, timeWindow )
  end

  deleteat!( rts, routesToDelete )

  # Recreate phase.
  for loc in locs
    insertLocIntoRoute!( vrp, rts, loc )
  end

  deleteUnwantedRoutes!(copyS.routes)
  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end



# Shifts locations in selected routes to other routes.
function shift( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy( vrp.solutions[ssid] )
  @inbounds copyS2 = deepcopy( vrp.solutions[sdid] )
  rts = copyS.routes
  numRoutesToUse = max( floor( Int, vrp.depthOfSearch * length(rts) ), 1 )
  @inbounds routesToUse = randperm( length(rts) )[1:numRoutesToUse]
  @inbounds routesToUse = getfield.( rts[routesToUse], :id )

  for useID in routesToUse
    rts2 = copyS2.routes
    # sizeOfRoute(rts2) == 2 && continue
    firstFunc = calcFunction(rts2)
    shiftAux( vrp, rts2, useID )
    newFunc = calcFunction(rts2)

    if newFunc < firstFunc
      copyS.routes = rts2
      copyS2.routes = rts2
      copyS = deepcopy(copyS)
    else
      copyS2.routes = deepcopy(copyS).routes
    end  
  end

  deleteUnwantedRoutes!(copyS.routes)
  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


#
function combine( vrp::VRP2, ssid1::Integer, ssid2::Integer, sdid::Integer )
  @inbounds copyS1 = deepcopy(vrp.solutions[ssid1])
  @inbounds copyS2 = deepcopy(vrp.solutions[ssid2])
  rts1 = copyS1.routes
  rts2 = copyS2.routes
  locs = Int[]

  for rt in rts1
    append!( locs, getLocs(rt) )
  end

  perc = rand( vrp.rng, 26:75 ) / 100
  rnd = rand( vrp.rng, Bool )
  chosenOnes = rnd ? rts1 : rts2    
  others = rnd ? rts2 : rts1

  newRoutes = VRPRoute2[]
  addedLocations = Int[]

  # Randomly select routes (with probability perc) to include in the new solution.
  for rt in chosenOnes
    if rand(vrp.rng) < perc
      push!( newRoutes, rt )
      append!( locs, getLocs(rt) )
    end
  end

  # Add routes from other list that doesn't have conflicting locations.
  for rt in others
    if useableRoute( rt, addedLocations )
      push!( newRoutes, rt )
      append!( locs, getLocs(rt) )
    end
  end

  # Insert remaining locations into solution.
  for rt in others
    for ii in 2:sizeOfRoute(rt)-1
      @inbounds ri = rt[ii]

      if ri.currLocation.id ∉ addedLocations
        push!( addedLocations, ri.currLocation.id )
        insertLocIntoRoute!( vrp, newRoutes, ri.currLocation )
      end
    end
  end

  @inbounds vrp.solutions[sdid] = VRPSolution2(newRoutes)
  getFunctionValue( vrp, sdid )
end


#
function combineLong( vrp::VRP2, ssid1::Integer, ssid2::Integer, sdid::Integer )
  @inbounds copyS1 = deepcopy(vrp.solutions[ssid1])
  @inbounds copyS2 = deepcopy(vrp.solutions[ssid2])
  rts1 = copyS1.routes
  rts2 = copyS2.routes
  addedLocations = Int[]
  newRoutes = VRPRoute2[]
  orderedRoutes = sort( vcat( rts1, rts2 ), rev=true, by=sizeOfRoute )

  # Pick non-conflicting routes to include in solution.
  for rt in orderedRoutes
    if useableRoute( rt, addedLocations )
      push!( newRoutes, rt )
      append!( addedLocations, getLocs(rt) )
    end
  end

  # Pick random route set and insert remaining locations into new routes
  remainingLocsRoutes = rand( vrp.rng, [rts1, rts2] )

  for rt in remainingLocsRoutes
    for ii in 2:sizeOfRoute(rt)-1
      @inbounds ri = rt[ii]

      if ri.currLocation.id ∉ addedLocations
        push!( addedLocations, ri.currLocation.id )
        insertLocIntoRoute!( vrp, newRoutes, ri.currLocation )
      end
    end
  end

  @inbounds vrp.solutions[sdid] = VRPSolution2(newRoutes)
  getFunctionValue( vrp, sdid )
end


# Move stations with largest combined distances from nearest neighbours, and put them at more appropriate positions.
function shiftMutate( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy(vrp.solutions[ssid])
  @inbounds copyS2 = deepcopy(vrp.solutions[ssid])
  rts = copyS.routes
  numRoutesToUse = max( floor( Int, vrp.intensityOfMutation * length(rts) ), 1 )
  @inbounds routesToUse = randperm( length(rts) )[1:numRoutesToUse]
  @inbounds routesToUse = getfield.( rts[routesToUse], :id )

  for useID in routesToUse
    rts2 = copyS2.routes
    firstFunc = calcFunction(rts2)

    rt2ind = findfirst( getfield.( rts2, :id ) .== useID )
    isnothing(rt2ind) && return
    @inbounds rt2 = rts2[rt2ind]
    bestPos = 1
    greatestDistance = 0.0

    for pos in 2:sizeOfRoute(rt2)-1
      @inbounds prev, ri, next = rt2[pos .+ (-1:1)]
      dist = ( calcDistance( prev, ri ) + calcDistance( next, ri ) ) * rand(vrp.rng)

      if dist > greatestDistance
        greatestDistance = dist
        bestPos = pos
      end
    end

    @inbounds locToInsert = rt2[bestPos].currLocation
    deleteat!( rt2, bestPos )

    if sizeOfRoute(rt2) == 2
      deleteat!( rts2, rt2ind )
    else
      for pos in bestPos:sizeOfRoute(rt2)
        prev, ri = rt2[pos .+ (-1:0)]
        locDist = calcDistance( ri, prev )
        diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
        readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
        prev.waitingTime = max( diff - readyDueDiff, 0 )
        ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
      end
    end

    insertLocIntoRoute!( vrp, rts2, locToInsert )
    copyS.routes = rts2
    copyS2.routes = rts2
    copyS = deepcopy(copyS)
  end

  deleteUnwantedRoutes!(copyS.routes)
  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


# Performs route crossovers between the optimal routes at the optimal point.
function twoOptStar( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy(vrp.solutions[ssid])
  rts = copyS.routes
  numTimesToPerform = rand( vrp.rng, 1:max( floor( Int, vrp.depthOfSearch * length(rts) ), 1 ) )

  numTimesToPerform = 1  # Debug

  for _ in 1:numTimesToPerform
    copyS2 = deepcopy(copyS)
    rts2 = copyS2.routes
    # To ensure two different routes can be selected
    length(rts2) < 2 && break
    @inbounds rtinds = randperm( vrp.rng, length(rts2) )[1:2]
    @inbounds rt1, rt2 = rts2[rtinds]
    bestScore = Inf
    bestR1Pos = 0
    bestR2Pos = 0

    for currR1Pos in 2:sizeOfRoute(rt1)-1, currR2Pos in 2:sizeOfRoute(rt2)-1
      @inbounds ri = rt1[currR1Pos]
      @inbounds ri2 = rt2[currR2Pos]
      score = feasibilityAndScore( vrp, rt1, rt2, currR1Pos, currR2Pos )

      if score <= bestScore
        bestR1Pos, bestR2Pos = currR1Pos, currR2Pos
        bestScore = score
      end
    end

    routeCrossover!( rt1, rt2, bestR1Pos, bestR2Pos )
    deleteUnwantedRoutes!(rts2)
    oldFunc = calcFunction(copyS.routes)
    newFunc = calcFunction(rts2)
    newFunc > oldFunc || (copyS.routes = rts2)
  end

  @inbounds vrp.solutions[sdid] = deepcopy(copyS)
  getFunctionValue( vrp, sdid )
end


# Removes location with worst score from route, inserts it at the best place in other route.
function GENI( vrp::VRP2, ssid::Integer, sdid::Integer )
  @inbounds copyS = deepcopy(vrp.solutions[ssid])
  rts = copyS.routes
  numTimesToPerform = rand( vrp.rng, 1:max( floor( Int, vrp.depthOfSearch * length(rts) ), 1 ) )

  for _ in 1:numTimesToPerform
    copyS2 = deepcopy(copyS)
    rts2 = copyS2.routes
    validroutes = filter( rt -> sizeOfRoute(rt) > 3, rts2 )
    length(validroutes) < 2 && break
    @inbounds rtinds = randperm( length(validroutes) )[1:2]
    @inbounds rt1, rt2 = validroutes[rtinds]

    _, worstPos = findmax( 2:sizeOfRoute(rt1)-1 ) do ii
      @inbounds prev, ri, next = rt1[ii .+ (-1:1)]
      ri.currLocation.readyTime - prev.currLocation.readyTime + next.currLocation.dueDate - ri.currLocation.dueDate + calcDistance( ri, prev ) + calcDistance( ri, next )
    end

    worstPos += 1
    @inbounds worstri = rt1[worstPos]

    # Remove worstri from the route.
    deleteat!( rt1, worstPos )

    # Find two closest locations in rt2 to worstri.
    @inbounds orderedinds = sortperm( map( 2:sizeOfRoute(rt2)-1 ) do ii
      @inbounds ri2 = rt2[ii]
      abs( worstri.currLocation.dueDate - ri2.currLocation.dueDate ) + calcDistance( worstri, ri2 )
    end )

    @inbounds firstpos, secondpos = orderedinds[1:2] .+ 1
    @inbounds firstri, secondri = rt2[firstpos], rt2[secondpos]
    
    # Fix pointers (insert worstri right between earlyri and lateri).
    @inbounds earlypos, latepos = rt2[secondpos].currLocation.dueDate < rt2[firstpos].currLocation.dueDate ? (secondpos, firstpos) : (firstpos, secondpos)

    @inbounds rt2tail = rt2[latepos:end]
    deleteat!( rt2, earlypos + 1 == sizeOfRoute(rt2) ? earlypos + 1 : earlypos+1:sizeOfRoute(rt2) )
    pushfirst!( rt2tail, worstri )
    append!( rt2, rt2tail )

    reOptimise!(rt1)
    reOptimise!(rt2)

    # Test feasibility.
    feasible = true
    volume = 0
    ii = 1
    rt2size = sizeOfRoute(rt2)

    while feasible && ii < rt2size
      ii += 1
      @inbounds ri2 = rt2[ii]
      volume += ri2.currLocation.demand
      feasible = ri2.timeArrived <= ri2.currLocation.dueDate
    end

    volume > vrp.instance.vehicleCapacity && (feasible = false)

    if feasible
      oldFunc = calcFunction(copyS.routes)
      newFunc = calcFunction(rts2)
      newFunc > oldFunc || (copyS.routes = rts2)
    end
  end

  @inbounds vrp.solutions[sdid] = deepcopy(copyS)
  getFunctionValue( vrp, sdid )
end
