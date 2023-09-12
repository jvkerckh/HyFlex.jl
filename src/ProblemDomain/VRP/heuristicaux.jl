# twoOpt
function twoOptMutate( vrp::VRP, rt::VRPRoute )
  rtsize = sizeOfRoute(rt)
  # This doesn't do anything if the route is depot-single stop-depot
  # because there aren't two adjacent stops to swap.
  rtsize < 4 && return

  startRI = rand( vrp.rng, 0:rtsize-4 )
  rt2 = copyRoute(rt)
  ri = rt2.first

  for _ in 1:startRI
    ri = ri.next
  end

  # These instructions swap ri.next and ri.next.next around.
  tRI = ri.next
  ri.next = tRI.next
  ri.next.prev = ri
  tRI.next = ri.next.next
  tRI.prev = ri.next
  ri.next.next = tRI
  tRI.next.prev = tRI

  feasible = true

  while (ri = ri.next).next !== NULL_RI
    prev = ri.prev
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

  rL = rt2.last
  depotDiff = rL.currLocation.dueDate - ( rL.prev.timeArrived + rL.prev.currLocation.serviceTime + calcDistance( rL, rL.prev ) )

  feasible && depotDiff >= 0 ? rt2 : nothing
end


# orOpt
function orOptMutate( vrp::VRP, rt::VRPRoute )
  rtsize = sizeOfRoute(rt)
  # This doesn't do anything if the route has less than four stops between the depots.
  rtsize < 6 && return

  startRI = rand( vrp.rng, 0:rtsize-6 )
  rt2 = copyRoute(rt)
  ri = rt2.first

  for _ in 1:startRI
    ri = ri.next
  end

  # These instructions swap ri.next, ri.next.next with ri.next^3 and ri.next^4 respectively.
  tRI = ri.next
  tRI2 = ri
  ri.next = tRI.next.next
  ri.next.prev = ri
  ri = ri.next.next
  ri.next.prev = tRI.next
  tRI.next.next = ri.next
  tRI.prev = ri
  ri.next = tRI
  ri = tRI2

  # Exactly the same checks as for twoOpt.
  feasible = true

  while (ri = ri.next).next !== NULL_RI
    prev = ri.prev
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

  rL = rt2.last
  depotDiff = rL.currLocation.dueDate - ( rL.prev.timeArrived + rL.prev.currLocation.serviceTime + calcDistance( rL, rL.prev ) )

  feasible && depotDiff >= 0 ? rt2 : nothing
end


# locRR
function ruinLoc( rt::VRPRoute, ii::Integer, baseLocation::VRPLocation, locs::Vector{VRPLocation}, routesToDelete::Vector{Int}, distanceWindow::Real )
  ri = rt.first

  while (ri = ri.next).next !== NULL_RI
    dist = calcDistance( ri.currLocation, baseLocation )

    if dist < distanceWindow
      push!( locs, ri.currLocation )
      # This removes ri from the route.
      ri.prev.next = ri.next
      ri.next.prev = ri.prev
    end
  end

  # If all stops on the route have been deleted for being too close to the base location, flag route for deletion.
  if sizeOfRoute(rt) <= 2
    push!( routesToDelete, ii )
    return
  end

  # Recalculate times.
  ri = rt.first

  while (ri = ri.next).next !== NULL_RI
    prev = ri.prev
    prevridist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + prevridist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( 0.0, diff - readyDueDiff )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + prevridist
  end
end


function insertLocIntoRoute!( vrp::VRP, rts::Vector{VRPRoute}, loc::VRPLocation )
  bestRouteNum = 0
  bestRouteElemPosition = 0
  bestWaitingTime = Inf

  for (ii, rt) in enumerate(rts)
    routeElemPosition = 0
    @inbounds ri = rt.first

    while (ri = ri.next).next !== NULL_RI
      routeElemPosition += 1

      if checkFeasibility( vrp, rt, routeElemPosition, loc )
        prev = ri.prev
        locDist = calcDistance( loc, prev.currLocation )
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
  end

  if iszero(bestRouteNum)
    @inbounds newR = VRPRoute( isempty(rts) ? vrp.instance.depot : rts[1].first.currLocation, length(rts), 0 )
    ri = newR.first
    locDist = calcDistance( loc, ri.currLocation )
    timeDiff = loc.dueDate - ( ri.timeArrived + ri.currLocation.serviceTime + locDist )
    readyDueDiff = loc.dueDate - loc.readyTime
    ri.waitingTime = max( timeDiff - readyDueDiff, 0 )

    # insert newRI into the new route
    newRI = VRPRouteItem( loc, ri, ri.next, ri.timeArrived + ri.currLocation.serviceTime + locDist )
    ri.next.prev = newRI
    ri.next = newRI
    push!( rts, newR )
  else
    @inbounds currR = rts[bestRouteNum]
    ri = currR.first

    for _ in 1:bestRouteElemPosition
      ri = ri.next
    end

    prev = ri.prev
    locDist = calcDistance( loc, prev.currLocation )
    timeDiff = loc.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = loc.dueDate - loc.readyTime
    prev.waitingTime = max( timeDiff - readyDueDiff, 0 )

    # insert newRI at the best spot of the best route.
    newRI = VRPRouteItem( loc, prev, prev.next, prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist )
    prev.next.prev = newRI
    prev.next = newRI
    ri = newRI

    while (ri = ri.next).next !== NULL_RI
      prev = ri.prev
      locDist = calcDistance( ri, prev )
      diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
      readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
      prev.waitingTime = max( diff - readyDueDiff, 0 )
      ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
    end
  end
end


function checkFeasibility( vrp::VRP, rt::VRPRoute, pos::Integer, loc::VRPLocation )
  calcVolume(rt) + loc.demand > vrp.instance.vehicleCapacity && return false

  rtc = copyRoute(rt)
  ri = rtc.first

  for _ in 1:pos
    ri = ri.next
  end

  prev = ri.prev
  locDist = calcDistance( loc, prev.currLocation )
  diff = loc.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
  diff < 0 && return false

  readyDueDiff = loc.dueDate - loc.readyTime
  prev.waitingTime = max( diff - readyDueDiff, 0 )

  # Insert newRI after prev.
  newRI = VRPRouteItem( loc, prev, prev.next, prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist )
  prev.next.prev = newRI
  prev.next = newRI
  ri = newRI

  while (ri = ri.next).next !== NULL_RI
    prev = ri.prev
    locDist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( diff - readyDueDiff, 0 )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
  end

  ri = rtc.last
  ri.currLocation.dueDate >= ri.prev.timeArrived + ri.prev.currLocation.serviceTime + calcDistance( ri.prev, ri )
end


deleteUnwantedRoutes!( rts::Vector{VRPRoute} ) =
  filter!( rt -> sizeOfRoute(rt) > 2, rts )


# timeRR
function ruinTime( rt::VRPRoute, ii::Integer, timeRef::Real, locs::Vector{VRPLocation}, routesToDelete::Vector{Int}, timeWindow::Real )
  ri = rt.first

  while (ri = ri.next).next !== NULL_RI
    timeDiff = abs( ri.timeArrived - timeRef )

    if timeDiff < timeWindow
      push!( locs, ri.currLocation )
      # Remove the stop from the route.
      ri.prev.next = ri.next
      ri.next.prev = ri.prev
    end
  end

  if sizeOfRoute(rt) == 2
    push!( routesToDelete, ii )
    return
  end

  ri = rt.first

  while (ri = ri.next).next !== NULL_RI
    prev = ri.prev
    locDist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( diff - readyDueDiff, 0 )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
  end
end


# shift
function shiftAux( vrp::VRP, rts2::Vector{VRPRoute}, useID::Integer )
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
end


# combine
function useableRoute( rt::VRPRoute, ls::Vector{Int} )
  ri = rt.first

  while (ri = ri.next).next !== NULL_RI
    any( ls .== ri.currLocation.id ) && return false
  end

  true
end


# twoOptStar
function feasibilityAndScore( vrp::VRP, rt1::VRPRoute, rt2::VRPRoute, rt1Pos::Integer, rt2Pos::Integer )
  rt11 = copyRoute(rt1)
  rt22 = copyRoute(rt2)
  ri = rt11.first
  ri2 = rt22.first

  for _ in 1:rt1Pos
    ri = ri.next
  end

  for _ in 1:rt2Pos
    ri2 = ri2.next
  end

  # Swap ri.prev and ri2.prev
  ri.prev.next = ri2
  ri2.prev.next = ri
  ritmp = ri.prev
  ri.prev = ri2.prev
  ri2.prev = ritmp

  # Optimise routes.
  reOptimise!(rt11)
  reOptimise!(rt22)

  # Check feasibility and calculate score.
  volume = 0
  score = 0
  ri = rt11.first
  ri2 = rt22.first

  while (ri = ri.next) !== NULL_RI
    volume += ri.currLocation.demand
    ri.timeArrived > ri.currLocation.dueDate && return Inf
    score += calcDistance( ri.prev, ri )
  end

  volume > vrp.instance.vehicleCapacity && return Inf
  volume = 0

  while (ri2 = ri2.next) !== NULL_RI
    volume += ri2.currLocation.demand
    ri2.timeArrived > ri2.currLocation.dueDate && return Inf
    score += calcDistance( ri2.prev, ri2 )
  end

  volume > vrp.instance.vehicleCapacity && return Inf
  (sizeOfRoute(rt11) > 2 && sizeOfRoute(rt22) > 2) || (score -= 1000)
  score
end


function reOptimise!( rt::VRPRoute )
  ri = rt.first

  while (ri = ri.next).next !== NULL_RI
    prev = ri.prev
    locDist = calcDistance( ri, prev )
    diff = ri.currLocation.dueDate - ( prev.timeArrived + prev.currLocation.serviceTime + locDist )
    readyDueDiff = ri.currLocation.dueDate - ri.currLocation.readyTime
    prev.waitingTime = max( diff - readyDueDiff, 0 )
    ri.timeArrived = prev.timeArrived + prev.currLocation.serviceTime + prev.waitingTime + locDist
  end
end
