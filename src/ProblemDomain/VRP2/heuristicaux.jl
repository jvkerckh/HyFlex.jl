# twoOpt
function twoOptMutate( vrp::VRP2, rt::VRPRoute2 )
  rtsize = sizeOfRoute(rt)
  # This doesn't do anything if the route is depot-single stop-depot
  # because there aren't two adjacent stops to swap.
  rtsize < 4 && return

  startRI = rand( vrp.rng, 2:rtsize-2 )
  rt2 = deepcopy(rt)
  @inbounds rt2[startRI+1], rt2[startRI] = rt2[startRI .+ (0:1)]
  optChecks( rt2, startRI, rtsize )
end


function optChecks( rt2::VRPRoute2, startRI::Integer, rtsize::Integer )
  feasible = true

  while (startRI += 1) < rtsize
    @inbounds prev, ri = rt2[startRI .+ (-1:0)]
    prevridist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + prevridist )

    if diff < 0.0
      feasible = false
      break
    end

    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( 0.0, diff - readyDueDiff )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + prevridist
  end

  @inbounds prev, rL = rt2[end .+ (-1:0)]
  depotDiff = rL.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + calcDistance( rL, prev ) )

  feasible && depotDiff >= 0 ? rt2 : nothing
end


# orOpt
function orOptMutate( vrp::VRP2, rt::VRPRoute2 )
  rtsize = sizeOfRoute(rt)
  # This doesn't do anything if the route has less than four stops between the depots.
  rtsize < 6 && return

  startRI = rand( vrp.rng, 2:rtsize-4 )
  rt2 = deepcopy(rt)
  @inbounds rt2[startRI+2], rt2[startRI+3], rt2[startRI], rt2[startRI+1] = rt2[startRI .+ (0:3)]
  optChecks( rt2, startRI, rtsize )
end


# locRR
function ruinLoc( rt::VRPRoute2, ii::Integer, baseLocation::VRPLocation2, locs::Vector{VRPLocation2}, routesToDelete::Vector{Int}, distanceWindow::Real )
  jj = 2

  # Clear stops that are too close to baseLocation.
  while jj < sizeOfRoute(rt)
    @inbounds ri = rt[jj]
    dist = calcDistance( ri, baseLocation )

    if dist < distanceWindow
      push!( locs, ri.currLocation )
      deleteat!( rt, jj )
    else
      jj += 1
    end
 end

  # If all stops on the route have been deleted for being too close to the base location, flag route for deletion.
  rtsize = sizeOfRoute(rt)

  if rtsize <= 2
    push!( routesToDelete, ii )
    return
  end

  # Recalculate times.
  jj = 1

  while (jj += 1) < rtsize
    @inbounds prev, ri = rt[jj-1:jj]
    prevridist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + prevridist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( 0.0, diff - readyDueDiff )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + prevridist
  end
end


function insertLocIntoRoute!( vrp::VRP2, rts::Vector{VRPRoute2}, loc::VRPLocation2 )
  bestRouteNum = 0
  bestRouteElemPosition = 0
  bestWaitingTime = Inf

  for (ii, rt) in enumerate(rts), routeElemPosition in 2:sizeOfRoute(rt)-1
    @inbounds prev, ri = rt[routeElemPosition .+ (-1:0)]

    if checkFeasibility( vrp, rt, routeElemPosition, loc )
      locDist = calcDistance( loc, prev )
      timeDiff = loc.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
      readyDueDiff = loc.dueDate + loc.readyTime

      if timeDiff > readyDueDiff
        newbwt = timeDiff - readyDueDiff + locDist

        if bestWaitingTime > newbwt
          bestWaitingTime = newbwt
          bestRouteNum = ii
          bestRouteElemPosition = routeElemPosition
        end
      else
        if bestWaitingTime > locDist
          bestWaitingTime = locDist
          bestRouteNum = ii
          bestRouteElemPosition = routeElemPosition
        end
      end
    end
  end

  if iszero(bestRouteNum)
    @inbounds newR = VRPRoute2( isempty(rts) ? vrp.instance.depot : rts[1][1].currLocation, length(rts), 0 )
    ri = newR[1]
    locDist = calcDistance( loc, ri )
    timeDiff = loc.dueDate - ( ri.timeArrived + ri.currLocation.serviceTime + locDist )
    readyDueDiff = loc.dueDate - loc.readyTime
    ri.waitingTime = max( timeDiff - readyDueDiff, 0 )

    # insert newRI into the new route
    newRI = VRPRouteItem2( loc, ri.timeArrived + ri.currLocation.serviceTime + locDist )
    insert!( newR, 2, newRI )
    push!( rts, newR )
  else
    @inbounds currR = rts[bestRouteNum]
    @inbounds prev, ri = currR[bestRouteElemPosition .+ (-1:0)]
    locDist = calcDistance( loc, prev )
    timeDiff = loc.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = loc.dueDate - loc.readyTime
    prev.waitingTime = max( timeDiff - readyDueDiff, 0 )

    # insert newRI at the best spot of the best route.
    newRI = VRPRouteItem2( loc, prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist )
    insert!( currR, bestRouteElemPosition, newRI )
    rtsize = sizeOfRoute(currR)

    while (bestRouteElemPosition += 1) < rtsize
      @inbounds prev, ri = currR[bestRouteElemPosition .+ (-1:0)]
      locDist = calcDistance( ri, prev )
      diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
      readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
      prev.waitingTime = max( diff - readyDueDiff, 0 )
      ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
    end
  end
end


function checkFeasibility( vrp::VRP2, rt::VRPRoute2, pos::Integer, loc::VRPLocation2 )
  calcVolume(rt) + loc.demand > vrp.instance.vehicleCapacity && return false

  rtc = deepcopy(rt)
  @inbounds prev, ri = rtc[pos .+ (0:1)]
  locDist = calcDistance( loc, prev )
  diff = loc.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
  diff < 0 && return false

  readyDueDiff = loc.dueDate - loc.readyTime
  prev.waitingTime = max( diff - readyDueDiff, 0 )

  # Insert newRI after prev.
  newRI = VRPRouteItem2( loc, prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist )
  insert!( rtc, pos, newRI )

  rtsize = sizeOfRoute(rtc)

  while (pos += 1) < rtsize
    @inbounds prev, ri = rtc[pos .+ (-1:0)]
    locDist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( diff - readyDueDiff, 0 )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
  end

  prev, ri = rtc[end .+ (-1:0)]
  ri.currLocation.dueDate >= prev.timeArrived + prev.currLocation.serviceTime + calcDistance( prev, ri )
end


deleteUnwantedRoutes!( rts::Vector{VRPRoute2} ) =
  filter!( rt -> sizeOfRoute(rt) > 2, rts )


# timeRR
function ruinTime( rt::VRPRoute2, ii::Integer, timeRef::Real, locs::Vector{VRPLocation2}, routesToDelete::Vector{Int}, timeWindow::Real )
  jj = 2

  while jj < sizeOfRoute(rt)
    @inbounds ri = rt[jj]
    timeDiff = abs( ri.timeArrived - timeRef )

    if timeDiff < timeWindow
      push!( locs, ri.currLocation )
      deleteat!( rt, jj )
    else
      jj += 1
    end
  end

  rtsize = sizeOfRoute(rt)

  if rtsize == 2
    push!( routesToDelete, ii )
    return
  end

  jj = 1

  while (jj += 1) < rtsize
    @inbounds prev, ri = rt[jj .+ (-1:0)]
    locDist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( diff - readyDueDiff, 0 )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
  end
end


# shift
function shiftAux( vrp::VRP2, rts2::Vector{VRPRoute2}, useID::Integer )
  rt2ind = findfirst( getfield.( rts2, :id ) .== useID )
  isnothing(rt2ind) && return
  @inbounds rt2 = rts2[rt2ind]
  bestPos = 1
  greatestDistance = 0.0

  # Finds the triplet with the largest combined distance.
  rtsize = sizeOfRoute(rt2)
  pos = 1

  while (pos += 1) < rtsize
    prev, ri, next = rt2[pos .+ (-1:1)]
    dist = ( calcDistance( prev, ri ) + calcDistance( next, ri ) ) * rand(vrp.rng)

    if dist > greatestDistance
      greatestDistance = dist
      bestPos = pos
    end
  end

  # Removes the middle element of that triplet and adds it into other routes.
  @inbounds locToInsert = rt2[bestPos].currLocation
  deleteat!( rt2, bestPos )
  bestPos -= 1
  rtsize = sizeOfRoute(rt2)

  if sizeOfRoute(rt2) == 2
    deleteat!( rts2, rt2ind )
  else
    while (bestPos += 1) < rtsize
      @inbounds prev, ri = rt2[bestPos .+ (-1:0)]
      locDist = calcDistance( ri, prev )
      diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
      readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
      prev.waitingTime = max( diff - readyDueDiff, 0 )
      ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
    end
  end

  insertLocIntoRoute!( vrp, rts2, locToInsert )
end


# combine
function getLocs( rt::VRPRoute2 )
  rtsize = sizeOfRoute(rt)
  rtsize == 2 && return Int[]
  @inbounds rtsize == 3 && return rt[2].currLocation.id
  @inbounds getfield.( getfield.( rt[2:end-1], :currLocation ), :id )
end


function useableRoute( rt::VRPRoute2, ls::Vector{Int} )
  locs = getLocs(rt)
  isempty(locs) && return true
  !any( locs .∈ Ref(ls) )
end


# twoOptStar
function feasibilityAndScore( vrp::VRP2, rt1::VRPRoute2, rt2::VRPRoute2, rt1Pos::Integer, rt2Pos::Integer )
  rt11 = deepcopy(rt1)
  rt22 = deepcopy(rt2)
  routeCrossover!( rt11, rt22, rt1Pos, rt2Pos )

  # Check feasibility and calculate score.
  score1, volume = computeRouteScore(rt11)
  volume > vrp.instance.vehicleCapacity && return Inf

  score2, volume = computeRouteScore(rt22)
  volume > vrp.instance.vehicleCapacity && return Inf

  score = score1 + score2
  (sizeOfRoute(rt11) > 2 && sizeOfRoute(rt22) > 2) || (score -= 1000)
  score
end


function routeCrossover!( rt1::VRPRoute2, rt2::VRPRoute2, rt1Pos::Integer, rt2Pos::Integer )
  rt1part = rt1[rt1Pos:end]
  rt2part = rt2[rt2Pos:end]

  deleteat!( rt1, rt1Pos:sizeOfRoute(rt1) )
  deleteat!( rt2, rt2Pos:sizeOfRoute(rt2) )
  append!( rt1, rt2part )
  append!( rt2, rt1part )

  # Optimise routes.
  reOptimise!(rt1)
  reOptimise!(rt2)
end


function reOptimise!( rt::VRPRoute2 )
  for ii in 2:sizeOfRoute(rt)-1
    @inbounds prev, ri = rt[ii .+ (-1:0)]
    locDist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( diff - readyDueDiff, 0 )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
  end
end


function computeRouteScore( rt::VRPRoute2 )
  score = 0
  volume = 0

  for ii in 2:sizeOfRoute(rt)
    @inbounds prev, ri = rt[ii .+ (-1:0)]
    volume += ri.currLocation.demand
    ri.timeArrived > ri.currLocation.dueDate && return -Inf, Inf
    score += calcDistance( prev, ri )
  end

  score, volume
  # ri = rt.first

  # while (ri = ri.next) !== NULL_RI
  #   volume += ri.currLocation.demand
  #   ri.timeArrived > ri.currLocation.dueDate && return Inf
  #   score += calcDistance( ri.prev, ri )
  # end
end
