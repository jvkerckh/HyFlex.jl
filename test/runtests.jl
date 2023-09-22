using HyFlex
using Test
using DataStructures, Random

@testset "HyFlex.jl" begin
  @testset "VRPLocation2" begin
    loc1 = VRPLocation2( 0, 20, 10, 25, 8, 50, 6 )
    loc1.serviced = true
    loc2 = deepcopy(loc1)
    loc3 = VRPLocation2( 1, 16, 8, 20, 4, 50, 7 )

    @test loc1.serviced
    @test !loc2.serviced

    @test loc1 == loc2
    @test loc1 != loc3
    @test isequal( loc1, loc2 )
    @test !isequal( loc1, loc3 )
    @test loc1 !== loc2
    @test loc1 !== loc3
  end

  @testset "VRPRouteItem2" begin
    nullri = HyFlex.NULL_RI2
    @test nullri == HyFlex.NullVRPRouteItem2()
    @test nullri === HyFlex.NullVRPRouteItem2()
    
    loc1 = VRPLocation2( 0, 20, 10, 25, 8, 50, 6 )
    loc2 = VRPLocation2( 1, 6, 0, 30, 15, 50, 2 )
    loc3 = VRPLocation2( 2, 16, 8, 20, 4, 50, 7 )

    ri0 = VRPRouteItem2( loc1, 0 )
    ri1 = VRPRouteItem2( loc1, 0 )
    ri2 = VRPRouteItem2( loc2, 0 )
    ri3 = VRPRouteItem2( loc3, 0 )

    @test ri0 == ri1
    @test isequal( ri0, ri1 )
    @test ri0 !== ri1

    # Only location, arrival time, and waiting time are checked!
    @test ri0 == ri1
    @test isequal( ri0, ri1 )
    @test ri0 !== ri1

    @test ri2 != ri1
    @test !isequal( ri2, ri1 )
    @test ri2 !== ri1

    ri1.timeArrived = 5
    ri1.waitingTime = 3

    @test ri0 != ri1
    @test !isequal( ri0, ri1 )
    @test ri0 !== ri1
  end

  @testset "VRPRoute2" begin
    loc1 = VRPLocation2( 0, 20, 10, 0, 8, 50, 6 )  # Depot has demand 0
    loc2 = VRPLocation2( 1, 6, 0, 30, 15, 50, 2 )
    loc3 = VRPLocation2( 2, 16, 8, 20, 4, 50, 7 )

    rt = VRPRoute2( loc1, 0, 50 )
    addPenultimate!( rt, loc2, 35 )
    addPenultimate!( rt, loc3, 40 )
    insertAfter!( rt, first(rt.routeitems), loc3, 15 )
    removeRouteItem!( rt, rt[4] )

    @test sizeOfRoute(rt) == 4
    @test calcVolume(rt) == rt.volume == 50
  end

  @testset "VRP2" begin
    vrp = VRP2()
    @test verify(vrp)
    vrp2 = VRP2(3141592)
    @test vrp2.rng == MersenneTwister(3141592)
    
    @test_throws AssertionError VRPInstance(12)
    
    loadInstance( vrp, 5 )
    loadInstance( vrp2, 5 )
    
    setMemorySize!( vrp, 10 )
    @test length(vrp.solutions) == 10
    setMemorySize!( vrp2, 10 )
    
    @test_throws BoundsError initialiseSolution( vrp2, 15 )
    
    initialiseSolution.( Ref(vrp), 1:10 )
    initialiseSolution.( Ref(vrp2), 1:10 )
    
    @testset "twoOpt" begin
      ntests = 100
      ngood = 0
      maxsets = 25
      nsets = 0
      
      while iszero(ngood) && nsets < maxsets
        rt = VRPRoute2( vrp.instance.depot, 0, 200 )
        
        rtinds = randperm(100)[1:4] .+ 1
        @inbounds locs = vrp.instance.demands[rtinds]
        sort!( locs, by=loc -> loc.dueDate )
        swind = rand(1:3)
        @inbounds locs[(0:1) .+ swind] = locs[(1:-1:0) .+ swind]
        foreach( loc -> addPenultimate!( rt, loc, 0.5 * loc.dueDate ), locs )
        
        for _ in 1:ntests
          nrt = HyFlex.twoOptMutate( vrp, rt )
          isnothing(nrt) || (ngood += 1)
        end

        nsets += 1
      end

      println(ngood, " out of ", ntests, " after ", nsets, " runs")
    end

    @testset "orOpt" begin
      ntests = 100
      ngood = 0
      maxsets = 100
      nsets = 0

      while iszero(ngood) && nsets < maxsets
        rt2 = VRPRoute2( vrp.instance.depot, 0, 200 )
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

    for ii in 1:8
      applyHeuristic( vrp2, ii+2, ii, ii+1 )
    end

    for ii in 1:8
      applyHeuristic( vrp2, ii+2, 11-ii, 10-ii, 9-ii )
    end
  end
end
