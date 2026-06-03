using CellularSim;

namespace CellularSim.Tests;

public sealed class MycoTests
{
    [Fact]
    public void FixtureLoader_AcceptsZeroSlotMycoAndRejectsZeroSlotStandard()
    {
        const string mycoJson = """
        {
          "resources": ["A"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            { "id": "white", "kind": "WhiteMyco", "x": 0, "y": 0, "slots": [] }
          ]
        }
        """;

        var loaded = FixtureLoader.LoadFromJson(mycoJson);
        var myco = loaded.World.GetCell("white");

        Assert.Equal(CellKind.WhiteMyco, myco.Kind);
        Assert.Empty(myco.Pool.Slots);
        Assert.True(myco.IsGlowing);

        const string standardJson = """
        {
          "resources": ["A"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            { "id": "standard", "x": 0, "y": 0, "slots": [] }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(standardJson));
    }

    [Fact]
    public void ExistingFixedSlotMyco_AdaptsFromNeighborAtRuntime()
    {
        const string json = """
        {
          "resources": ["A", "B", "C", "D", "X"],
          "grid": { "width": 2, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "standard",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0, "capacity": 100 },
                { "resource": "B", "role": "Need", "quantity": 0, "capacity": 100 },
                { "resource": "C", "role": "Need", "quantity": 0, "capacity": 100 },
                { "resource": "D", "role": "Need", "quantity": 0, "capacity": 100 }
              ],
              "sources": [{ "resource": "A", "quantityPerTick": 32, "intervalTicks": 1 }]
            },
            {
              "id": "red",
              "kind": "RedMyco",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "X", "role": "Need", "quantity": 250, "capacity": 500 }
              ]
            }
          ]
        }
        """;

        var loaded = FixtureLoader.LoadFromJson(json);
        _ = new CellularEngine(loaded.World, loaded.Options);
        var red = loaded.World.GetCell("red");

        AssertSlotResources(red, [0, 1, 2, 3]);
        Assert.All(red.Pool.Slots, slot =>
        {
            Assert.Equal(PoolSlotRole.Need, slot.Role);
            Assert.Equal(250, slot.Quantity);
            Assert.Equal(500, slot.Capacity);
        });
    }

    [Fact]
    public void NoUsefulNeighbors_LeavesMycoWaiting()
    {
        var pool = new SwapPoolState();
        pool.AddSlot(new ResourceId(0), PoolSlotRole.Need, quantity: 250, capacity: 500);
        var myco = new CellState("white", new GridPosition(0, 0), pool, CellKind.WhiteMyco);
        var world = new GridWorld(1, 1);
        world.AddCell(myco);

        _ = new CellularEngine(world);

        Assert.Empty(myco.Pool.Slots);
    }

    [Fact]
    public void OneNormalNeighbor_UsesOfferAndThreeNeeds()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var resourceC = new ResourceId(2);
        var resourceD = new ResourceId(3);
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.SourceOutput);
        standardPool.AddSlot(resourceB, PoolSlotRole.Need);
        standardPool.AddSlot(resourceC, PoolSlotRole.Need);
        standardPool.AddSlot(resourceD, PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var myco = new CellState("red", new GridPosition(1, 0), new SwapPoolState(), CellKind.RedMyco);
        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(myco);

        _ = new CellularEngine(world);

        AssertSlotResources(myco, [0, 1, 2, 3]);
    }

    [Fact]
    public void MultipleNeighbors_ScoresLocalNeedsWhileKeepingPaymentOffer()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var resourceC = new ResourceId(2);
        var resourceD = new ResourceId(3);
        var resourceE = new ResourceId(4);
        var resourceF = new ResourceId(5);
        var leftPool = new SwapPoolState();
        leftPool.AddSlot(resourceA, PoolSlotRole.SourceOutput);
        leftPool.AddSlot(resourceC, PoolSlotRole.Need);
        leftPool.AddSlot(resourceD, PoolSlotRole.Need);
        leftPool.AddSlot(resourceE, PoolSlotRole.Need);
        var left = new CellState("left", new GridPosition(0, 1), leftPool);

        var rightPool = new SwapPoolState();
        rightPool.AddSlot(resourceB, PoolSlotRole.SourceOutput);
        rightPool.AddSlot(resourceD, PoolSlotRole.Need);
        rightPool.AddSlot(resourceE, PoolSlotRole.Need);
        rightPool.AddSlot(resourceF, PoolSlotRole.Need);
        var right = new CellState("right", new GridPosition(2, 1), rightPool);

        var myco = new CellState("red", new GridPosition(1, 1), new SwapPoolState(), CellKind.RedMyco);
        var world = new GridWorld(3, 3);
        world.AddCell(left);
        world.AddCell(right);
        world.AddCell(myco);

        _ = new CellularEngine(world);

        var resources = myco.Pool.Slots.Select(slot => slot.Resource).ToArray();
        Assert.Equal(4, resources.Length);
        Assert.Equal(4, resources.Distinct().Count());
        Assert.Contains(resourceD, resources);
        Assert.Contains(resourceE, resources);
        Assert.Contains(resources, resource => resource == resourceA || resource == resourceB);
    }

    [Fact]
    public void MovingAwayFromNeighbors_ClearsStaleMycoResources()
    {
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(new ResourceId(0), PoolSlotRole.SourceOutput);
        standardPool.AddSlot(new ResourceId(1), PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);
        var myco = new CellState("red", new GridPosition(1, 0), new SwapPoolState(), CellKind.RedMyco);
        var world = new GridWorld(3, 1);
        world.AddCell(standard);
        world.AddCell(myco);
        var engine = new CellularEngine(world);
        Assert.NotEmpty(myco.Pool.Slots);

        Assert.True(world.MoveCell("red", new GridPosition(2, 0)));
        engine.RefreshAdaptiveMyco();

        Assert.Empty(myco.Pool.Slots);
    }

    [Fact]
    public void MycoToMycoChain_CopiesAlreadyAdaptedNeighbor()
    {
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(new ResourceId(0), PoolSlotRole.SourceOutput);
        standardPool.AddSlot(new ResourceId(1), PoolSlotRole.Need);
        standardPool.AddSlot(new ResourceId(2), PoolSlotRole.Need);
        standardPool.AddSlot(new ResourceId(3), PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);
        var first = new CellState("first-red", new GridPosition(1, 0), new SwapPoolState(), CellKind.RedMyco);
        var second = new CellState("second-red", new GridPosition(2, 0), new SwapPoolState(), CellKind.RedMyco);
        var world = new GridWorld(3, 1);
        world.AddCell(standard);
        world.AddCell(first);
        world.AddCell(second);

        _ = new CellularEngine(world);

        AssertSlotResourceSet(first, [0, 1, 2, 3]);
        AssertSlotResourceSet(second, [0, 1, 2, 3]);
    }

    [Fact]
    public void RedMyco_AsCounterparty_KeepsOneUnitOutwardFee()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.SourceOutput, quantity: 5);
        standardPool.AddSlot(resourceB, PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var red = new CellState("red", new GridPosition(1, 0), new SwapPoolState(), CellKind.RedMyco);
        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(red);
        var engine = new CellularEngine(world, new EngineOptions { MaxSwapQuantityPerEdge = 4 });

        engine.Tick();

        var swap = Assert.Single(engine.Events.OfType<SwapEvent>());
        Assert.Equal("standard", swap.InitiatorCellId);
        Assert.Equal("red", swap.CounterpartyCellId);
        Assert.Equal(resourceA, swap.InitiatorPaidResource);
        Assert.Equal(resourceB, swap.CounterpartyPaidResource);
        Assert.Equal(4, swap.InitiatorPaidQuantity);
        Assert.Equal(4, swap.CounterpartyPaidQuantity);
        Assert.Equal(3, swap.InitiatorReceivedQuantity);
        Assert.Equal(4, swap.CounterpartyReceivedQuantity);
        Assert.Equal(2, standardPool.GetQuantity(resourceB));
        Assert.Equal(254, red.Pool.GetQuantity(resourceA));
        Assert.True(red.IsGlowing);
    }

    [Fact]
    public void RedMyco_OutgoingFeeAppliesRegardlessOfProposalDirection()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var red = new CellState("red", new GridPosition(0, 0), new SwapPoolState(), CellKind.RedMyco);

        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceB, PoolSlotRole.SourceOutput, quantity: 5);
        standardPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 50, capacity: 200);
        var standard = new CellState("standard", new GridPosition(1, 0), standardPool);

        var world = new GridWorld(2, 1);
        world.AddCell(red);
        world.AddCell(standard);
        var engine = new CellularEngine(world, new EngineOptions { MaxSwapQuantityPerEdge = 4 });

        engine.Tick();

        var swap = Assert.Single(engine.Events.OfType<SwapEvent>());
        var redIsInitiator = swap.InitiatorCellId == "red";
        Assert.Contains("red", new[] { swap.InitiatorCellId, swap.CounterpartyCellId });
        Assert.Contains("standard", new[] { swap.InitiatorCellId, swap.CounterpartyCellId });
        Assert.Equal(resourceA, redIsInitiator ? swap.InitiatorPaidResource : swap.CounterpartyPaidResource);
        Assert.Equal(resourceB, redIsInitiator ? swap.CounterpartyPaidResource : swap.InitiatorPaidResource);
        Assert.Equal(4, redIsInitiator ? swap.InitiatorPaidQuantity : swap.CounterpartyPaidQuantity);
        Assert.Equal(4, redIsInitiator ? swap.CounterpartyPaidQuantity : swap.InitiatorPaidQuantity);
        Assert.Equal(4, redIsInitiator ? swap.InitiatorReceivedQuantity : swap.CounterpartyReceivedQuantity);
        Assert.Equal(3, redIsInitiator ? swap.CounterpartyReceivedQuantity : swap.InitiatorReceivedQuantity);
        Assert.Equal(254, red.Pool.GetQuantity(resourceB));
        Assert.Equal(52, standardPool.GetQuantity(resourceA));
        Assert.True(red.IsGlowing);
    }

    [Fact]
    public void RedMyco_GrossOneCandidateDoesNotSwapOrFlow()
    {
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(new ResourceId(0), PoolSlotRole.SourceOutput, quantity: 2);
        standardPool.AddSlot(new ResourceId(1), PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var red = new CellState("red", new GridPosition(1, 0), new SwapPoolState(), CellKind.RedMyco);
        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(red);
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Empty(engine.Events.OfType<SwapEvent>());
        Assert.Empty(engine.Events.OfType<FlowEvent>());
    }

    private static void AssertSlotResources(CellState cell, int[] resourceValues)
    {
        Assert.Equal(resourceValues.Length, cell.Pool.Slots.Count);
        for (var i = 0; i < resourceValues.Length; i++)
        {
            Assert.Equal(new ResourceId(resourceValues[i]), cell.Pool.Slots[i].Resource);
        }
    }

    private static void AssertSlotResourceSet(CellState cell, int[] resourceValues)
    {
        var actual = cell.Pool.Slots.Select(slot => slot.Resource).ToHashSet();
        var expected = resourceValues.Select(value => new ResourceId(value)).ToHashSet();
        Assert.True(actual.SetEquals(expected));
    }
}
