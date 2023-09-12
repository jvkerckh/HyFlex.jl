# This heuristic selects a number of routes to mutate and randomly selects two adjecent stops to swap.
function twoOpt( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution(vrp.solutions[ssid])
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
function orOpt( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution( vrp.solutions[ssid] )
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


function locRR( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution( vrp.solutions[ssid] )
  rts = copyS.routes

  # Ruin phase.

  # Select a random stop on a random route.
  rtc = rand( vrp.rng, rts )
  routePos = rand( vrp.rng, 0:sizeOfRoute(rtc)-2 )
  ri = rtc.first

  for _ in 1:routePos
    ri = ri.next
  end

  baseLocation = ri.currLocation

  # Find stop on routes with furthest distance from baseLocation.
  # Note, this isn't necessary the potential location furthest from baseLocation as this might not be servied by any route.
  furthest = 0.0

  for rt in rts
    ri = rt.first

    while ri !== NULL_RI
      furthest = max( furthest, calcDistance( ri.currLocation, baseLocation ) )
      ri = ri.next
    end
  end

  # Find all locations along routes in solution that are a set distance away from baseLocation and delete them from routes. Also clear routes that have no more stops.
  distanceWindow = 0.75 * vrp.intensityOfMutation * furthest
  locs = VRPLocation[]
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


function timeRR( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution(vrp.solutions[ssid])
  rts = copyS.routes

  # Ruin phase.
  @inbounds maxTime = rts[1].last.currLocation.dueDate
  timeRef = rand( 1:maxTime ) - 1
  timeWindow = 0.5 * vrp.intensityOfMutation * maxTime
  locs = VRPLocation[]
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


function shift( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution( vrp.solutions[ssid] )
  @inbounds copyS2 = copySolution( vrp.solutions[sdid] )
  rts = copyS.routes
  numRoutesToUse = max( floor( Int, vrp.depthOfSearch * length(rts) ), 1 )
  @inbounds routesToUse = randperm( length(rts) )[1:numRoutesToUse]
  @inbounds routesToUse = getfield.( rts[routesToUse], :id )

  for useID in routesToUse
    rts2 = copyS2.routes
    firstFunc = calcFunction(rts2)
    shiftAux( vrp, rts2, useID )
    newFunc = calcFunction(rts2)

    if newFunc < firstFunc
      copyS.routes = rts2
      copyS2.routes = rts2
      copyS = copySolution(copyS)
    else
      copyS2.routes = copySolution(copyS).routes
    end  
  end

  deleteUnwantedRoutes!(copyS.routes)
  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


function combine( vrp::VRP, ssid1::Integer, ssid2::Integer, sdid::Integer )
  @inbounds copyS1 = copySolution(vrp.solutions[ssid1])
  @inbounds copyS2 = copySolution(vrp.solutions[ssid2])
  rts1 = copyS1.routes
  rts2 = copyS2.routes
  locs = Int[]

  for rt in rts1
    ri = rt.first

    while (ri = ri.next).next !== NULL_RI
      push!( locs, ri.currLocation.id )
    end
  end

  perc = rand( vrp.rng, 26:75 ) / 100
  rnd = rand( vrp.rng, Bool )
  chosenOnes = rnd ? rts1 : rts2    
  others = rnd ? rts2 : rts1

  newRoutes = VRPRoute[]
  addedLocations = Int[]

  for rt in chosenOnes
    if rand(vrp.rng) < perc
      push!( newRoutes,rt )
      ri = rt.first

      while (ri = ri.next).next != NULL_RI
        push!( addedLocations, ri.currLocation.id )
      end
    end
  end

  for rt in others
    if useableRoute( rt, addedLocations )
      push!( newRoutes, rt )
      ri = rt.first

      while (ri = ri.next).next !== NULL_RI
        push!( addedLocations, ri.currLocation.id )
      end
    end
  end

  for rt in others
    ri = rt.first

    while (ri = ri.next).next !== NULL_RI
      if ri.currLocation.id ∉ addedLocations
        push!( addedLocations, ri.currLocation.id )
        insertLocIntoRoute!( vrp, newRoutes, ri.currLocation )
      end
    end
  end

  @inbounds vrp.solutions[sdid] = VRPSolution(newRoutes)
  getFunctionValue( vrp, sdid )
end


function combineLong( vrp::VRP, ssid1::Integer, ssid2::Integer, sdid::Integer )
  @inbounds copyS1 = copySolution(vrp.solutions[ssid1])
  @inbounds copyS2 = copySolution(vrp.solutions[ssid2])
  rts1 = copyS1.routes
  rts2 = copyS2.routes
  locs = Int[]
  newRoutes = VRPRoute[]
  orderedRoutes = VRPRoutes[]

  for rt in vcat( rts1, rts2 )
    ii = 0

    while ii < length(orderedRoutes)
      ii += 1

      @inbounds if sizeOfRoute(rt) > sizeOfRoute(orderedRoutes[ii])
        insert!( orderedRoutes, ii, rt )
        break
      end

      ii == length(orderedRoutes) && push!( orderedRoutes, rt )
    end

    isempty(orderedRoutes) && push!( orderedRoutes, rt )
  end

  for rt in ordredRoutes
    if useableRoute( rt, addedLocations )
      push!( newRoutes, rt )
      ri = rt.first

      while (ri = ri.next).next !== NULL_RI
        push!( addedLocations, ri.currLocation.id )
      end
    end
  end

  remainingLocsRoutes = rand( vrp.rng, Bool ) ? rts1 : rts2

  for rt in remainingLocsRoutes
    ri = rt.first

    while (ri = ri.next).next !== NULL_RI
      if ri.currLocation.id ∉ addedLocations
        push!( addedLocations, ri.currLocation.id )
        insertLocIntoRoute!( vrp, newRoutes, ri.currLocation )
      end
    end
  end

  @inbounds vrp.solutions[sdid] = VRPSolution(newRoutes)
  getFunctionValue( vrp, sdid )
end


function shiftMutate( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution(vrp.solutions[ssid])
  @inbounds copyS2 = copySolution(vrp.solutions[ssid])
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
    pos = 0
    ri = rt2.first

    while (ri = ri.next).next !== NULL_RI
      pos += 1
      dist = ( calcDistance( ri.prev, ri ) + calcDistance( ri.next, ri ) ) * rand(vrp.rng)
  
      if dist > greatestDistance
        greatestDistance = dist
        bestPos = pos
      end
    end
  
    ri = rt2.first

    for _ in 1:bestPos
      ri = ri.next
    end
  
    locToInsert = ri.currLocation
    ri.prev.next = ri.next
    ri.next.prev = ri.prev
    ri = ri.prev

    if sizeOfRoute(rt2) == 2
      deleteat!( rts2, rt2ind )
    else
      while (ri = ri.next).next !== NULL_RI
        prev = ri.prev
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
    copyS = copySolution(copyS)
  end

  deleteUnwantedRoutes!(copyS.routes)
  @inbounds vrp.solutions[sdid] = copyS
  getFunctionValue( vrp, sdid )
end


function twoOptStar( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution(vrp.solutions[ssid])
  rts = copyS.routes
  numTimesToPerform = rand( vrp.rng, 1:max( floor( Int, vrp.depthOfSearch * length(rts) ), 1 ) )

  for _ in 1:numTimesToPerform
    copyS2 = copySolution(copyS)
    rts2 = copyS2.routes
    # To ensure two different routes can be selected
    length(rts2) < 2 && break
    @inbounds rtinds = randperm( vrp.rng, length(rts2) )[1:2]
    @inbounds rt1, rt2 = rts2[rtinds]
    bestScore = Inf
    bestR1Pos = -1
    bestR2Pos = -1
    currR1Pos = 0
    ri = rt1.first

    while (ri = ri.next) !== NULL_RI
      currR1Pos += 1
      currR2Pos = 0
      ri2 = rt2.first

      while (ri2 = ri2.next) !== NULL_RI
        currR2Pos += 1
        score = feasibilityAndScore( vrp, rt1, rt2, currR1Pos, currR2Pos )

        if score <= bestScore
          bestR1Pos, bestR2Pos = currR1Pos, currR2Pos
          bestScore = score
        end
      end
    end

    ri = rt1.first
    ri2 = rt2.first

    for _ in 1:bestR1Pos
      ri = ri.next
    end

    for _ in 1:bestR2Pos
      ri2 = ri2.next
    end

    # Swap ri.prev and ri2.prev
    ri.prev.next = ri2
    ri2.prev.next = ri
    ritmp = ri.prev
    ri.prev = ri2.prev
    ri2.prev = ritmp

    # Optimise routes.
    reOptimise!(rt1)
    reOptimise!(rt2)
    deleteUnwantedRoutes!(rts2)
    oldFunc = calcFunction(copyS.routes)
    newFunc = calcFunction(rts2)
    newFunc > oldFunc || (copyS.routes = rts2)
  end

  @inbounds vrp.solutions[sdid] = copySolution(copyS)
  getFunctionValue( vrp, sdid )
end


function GENI( vrp::VRP, ssid::Integer, sdid::Integer )
  @inbounds copyS = copySolution(vrp.solutions[ssid])
  rts = copyS.routes
  numTimesToPerform = rand( vrp.rng, 1:max( floor( Int, vrp.depthOfSearch * length(rts) ), 1 ) )

  for _ in 1:numTimesToPerform
    copyS2 = copySolution(copyS)
    rts2 = copyS2.routes
    validroutes = filter( rt -> sizeOfRoute(rt) > 3, rts2 )
    length(validroutes) < 2 && break
    @inbounds rtinds = randperm( length(validroutes) )[1:2]
    rt1, rt2 = validroutes[rtinds]

    worstri = rt1.first
    worstScore = 0
    ri = rt1.first

    while (ri = ri.next).next !== NULL_RI
      tempScore = ri.currLocation.readyTime - ri.prev.currLocation.readyTime + ri.next.currLocation.dueDate - ri.currLocation.dueDate + calcDistance( ri, ri.prev ) + calcDistance( ri, ri.next )

      if tempScore > worstScore
        worstScore = tempScore
        worstri = ri
      end
    end

    # Remove worstri from the route.
    worstri.prev.next = worstri.next
    worstri.next.prev = worstri.prev

    # Find two closest locations to worstri.
    firstClosestScore = Inf
    secondClosestScore = Inf
    firstri = rt2.first
    secondri = rt2.first
    ri2 = rt2.first

    while (ri2 = ri2.next).next !== NULL_RI
      score = abs( worstri.currLocation.dueDate - ri2.currLocation.dueDate ) + calcDistance( worstri, ri2 )

      if score < firstClosestScore
        secondClosestScore = firstClosestScore
        secondri = firstri
        firstClosestScore = score
        firstri = ri2
      elseif score < secondClosestScore
        secondClosestScore = score
        secondri = ri2
      end
    end

    # Fix pointers (insert worstri right between earlyri and lateri).
    earlyri, lateri = secondri.currLocation.dueDate < firstri.currLocation.dueDate ? (secondri, firstri) : (firstri, secondri)
    lateri.next.prev = lateri.prev
    lateri.prev.next = lateri.next
    lateri.next = earlyri.next
    earlyri.next.prev = lateri
    lateri.prev = worstri
    worstri.next = lateri
    earlyri.next = worstri
    worstri.prev = earlyri

    reOptimise!(rt1)
    reOptimise!(rt2)

    # Test feasibility.
    feasible = true
    volume = 0
    ri2 = rt2.first

    while feasible && (ri = ri.next) !== NULL_RI
      volume += ri.currLocation.demand
      feasible = ri.timeArrived <= ri.currLocation.dueDate
    end

    volume > vrp.instance.vehicleCapacity && (feasible = false)

    if feasible
      oldFunc = calcFunction(copyS.routes)
      newFunc = calcFunction(rts2)
      newFunc > oldFunc || (copyS.routes = rts2)
    end
  end

  @inbounds vrp.solutions[sdid] = copySolution(copyS)
  getFunctionValue( vrp, sdid )
end
