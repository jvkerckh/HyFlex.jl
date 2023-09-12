using HyFlex
using Test
using Random

@testset "HyFlex.jl" begin
  @testset "VRPLocation" begin
    loc1 = VRPLocation( 0, 20, 10, 25, 8, 50, 6 )
    loc1.serviced = true
    loc2 = copyLocation(loc1)
    loc3 = VRPLocation( 1, 16, 8, 20, 4, 50, 7 )

    @test loc1.serviced
    @test !loc2.serviced

    @test loc1 == loc2
    @test loc1 != loc3
    @test isequal( loc1, loc2 )
    @test !isequal( loc1, loc3 )
    @test loc1 !== loc2
    @test loc1 !== loc3
    @test compareLocation(loc1, loc2)
    @test !compareLocation(loc1, loc3)
  end

  @testset "VRPRouteItem" begin
    nullri = HyFlex.NULL_RI
    @test nullri == HyFlex.NullVRPRouteItem()
    @test nullri === HyFlex.NullVRPRouteItem()
    
    loc1 = VRPLocation( 0, 20, 10, 25, 8, 50, 6 )
    loc2 = VRPLocation( 1, 6, 0, 30, 15, 50, 2 )
    loc3 = VRPLocation( 2, 16, 8, 20, 4, 50, 7 )

    ri0 = VRPRouteItem( loc1, nullri, nullri, 0 )
    ri1 = VRPRouteItem( loc1, nullri, nullri, 0 )
    ri2 = VRPRouteItem( loc2, nullri, nullri, 0 )
    ri3 = VRPRouteItem( loc3, nullri, nullri, 0 )

    @test ri0 == ri1
    @test isequal( ri0, ri1 )
    @test ri0 !== ri1
    @test compareRouteItem( ri0, ri1 )

    ri1.next = ri2
    ri2.prev = ri1
    ri2.next = ri3
    ri3.prev = ri2

    # Only location, arrival time, and waiting time are checked!
    @test ri0 == ri1
    @test isequal( ri0, ri1 )
    @test ri0 !== ri1
    @test compareRouteItem( ri0, ri1 )

    @test ri2 != ri1
    @test !isequal( ri2, ri1 )
    @test ri2 !== ri1
    @test !compareRouteItem( ri2, ri1 )

    ri1.timeArrived = 5
    ri1.waitingTime = 3

    @test ri0 != ri1
    @test !isequal( ri0, ri1 )
    @test ri0 !== ri1
    @test !compareRouteItem( ri0, ri1 )
  end

  @testset "VRPRoute" begin
    loc1 = VRPLocation( 0, 20, 10, 0, 8, 50, 6 )  # Depot has demand 0
    loc2 = VRPLocation( 1, 6, 0, 30, 15, 50, 2 )
    loc3 = VRPLocation( 2, 16, 8, 20, 4, 50, 7 )

    rt = VRPRoute( loc1, 0, 50 )
    @test rt.first === rt.last.prev
    @test rt.first.next === rt.last

    addPenultimate!( rt, loc2, 35 )
    @test rt.first === rt.last.prev.prev
    @test rt.first.next === rt.last.prev
    @test rt.first.next.next === rt.last

    addPenultimate!( rt, loc3, 40 )
    @test rt.first === rt.last.prev.prev.prev
    @test rt.first.next === rt.last.prev.prev
    @test rt.first.next.next === rt.last.prev
    @test rt.first.next.next.next === rt.last

    insertAfter!( rt, rt.first, loc3, 15 )
    @test rt.first === rt.last.prev.prev.prev.prev
    @test rt.first.next === rt.last.prev.prev.prev
    @test rt.first.next.next === rt.last.prev.prev
    @test rt.first.next.next.next === rt.last.prev
    @test rt.first.next.next.next.next === rt.last

    removeRouteItem!( rt, rt.last.prev )
    @test rt.first === rt.last.prev.prev.prev
    @test rt.first.next === rt.last.prev.prev
    @test rt.first.next.next === rt.last.prev
    @test rt.first.next.next.next === rt.last

    @test sizeOfRoute(rt) == 4
    @test calcVolume(rt) == rt.volume == 50

    rt2 = copyRoute(rt)
    @test rt == rt2
    @test isequal( rt, rt2 )
    @test rt !== rt2
    @test compareRoute( rt, rt2 )
  end

  @testset "VRP" begin
    vrp = VRP()
    @test verify(vrp)
    vrp2 = VRP(3141592)
    @test verify(vrp2)
    @test vrp2.rng == MersenneTwister(3141592)

    @test_throws AssertionError VRPInstance(12)

    loadInstance( vrp2, 5 )
    
    setMemorySize!( vrp2, 6 )
    @test length(vrp2.solutions) == 6

    @test_throws BoundsError initialiseSolution( vrp2, 9 )
  end

  @testset "VRP heuristics" begin
    vrp = VRP(3141592)
    @test verify(vrp)

    loadInstance( vrp, 5 )
    rt = VRPRoute( vrp.instance.depot, 0, 200 )

    @testset "twoOpt" begin
      @test isnothing(HyFlex.twoOptMutate( vrp, rt ))

      ntests = 100
      ngood = 0
      maxsets = 25
      nsets = 0

      while iszero(ngood) && nsets < maxsets
        rt2 = VRPRoute( vrp.instance.depot, 0, 200 )
        rtinds = randperm(100)[1:4] .+ 1
        @inbounds locs = vrp.instance.demands[rtinds]
        sort!( locs, by=loc -> loc.dueDate )
        swind = rand(1:3)
        @inbounds locs[(0:1) .+ swind] = locs[(1:-1:0) .+ swind]
        foreach( loc -> addPenultimate!( rt2, loc, 0.5 * loc.dueDate ), locs )
    
        for _ in 1:ntests
          nrt = HyFlex.twoOptMutate( vrp, rt2 )
          isnothing(nrt) || (ngood += 1)
        end

        nsets += 1
      end

      println(ngood, " out of ", ntests, " after ", nsets, " runs")
    end

    @testset "orOpt" begin
      @test isnothing(HyFlex.orOptMutate( vrp, rt ))

      ntests = 100
      ngood = 0
      maxsets = 25
      nsets = 0

      while iszero(ngood) && nsets < maxsets
        rt2 = VRPRoute( vrp.instance.depot, 0, 200 )
        rtinds = randperm(100)[1:6] .+ 1
        @inbounds locs = vrp.instance.demands[rtinds]
        sort!( locs, by=loc -> loc.dueDate )
        swind = rand(1:3)
        @inbounds locs[(0:3) .+ swind] = locs[[2,3,0,1] .+ swind]
        foreach( loc -> addPenultimate!( rt2, loc, 0.5 * loc.dueDate ), locs )
    
        for _ in 1:ntests
          nrt = HyFlex.orOptMutate( vrp, rt2 )
          isnothing(nrt) || (ngood += 1)
        end

        nsets += 1
      end

      println(ngood, " out of ", ntests, " after ", nsets, " runs")
    end

    setMemorySize!( vrp, 11 )
    foreach( ii -> initialiseSolution( vrp, ii ), 1:11 )

    @testset "locRR" begin
      HyFlex.locRR( vrp, 3, 4 )
    end

    @testset "timeRR" begin
      HyFlex.timeRR( vrp, 4, 5 )
    end

    @testset "shift" begin
      HyFlex.shift( vrp, 5, 6 )
    end

    @testset "combine" begin
      HyFlex.combine( vrp, 5, 6, 7 )
    end

    @testset "combine" begin
      HyFlex.combine( vrp, 6, 7, 8 )
    end

    @testset "shiftMutate" begin
      HyFlex.shiftMutate( vrp, 8, 9 )
    end

    @testset "twoOptStar" begin
      HyFlex.twoOptStar( vrp, 9, 10 )
    end

    @testset "GENI" begin
      HyFlex.GENI( vrp, 10, 11 )
    end
  end
end
