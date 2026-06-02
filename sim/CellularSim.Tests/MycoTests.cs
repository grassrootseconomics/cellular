using CellularSim;

namespace CellularSim.Tests;

public sealed class MycoTests
{
    [Fact]
    public void FixtureLoader_LoadsCellKind()
    {
        const string json = """
        {
          "resources": ["A", "B", "C", "D"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "white",
              "kind": "WhiteMyco",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "Need", "quantity": 250, "capacity": 500 },
                { "resource": "B", "role": "Need", "quantity": 250, "capacity": 500 },
                { "resource": "C", "role": "Need", "quantity": 250, "capacity": 500 },
                { "resource": "D", "role": "Need", "quantity": 250, "capacity": 500 }
              ]
            }
          ]
        }
        """;

        var loaded = FixtureLoader.LoadFromJson(json);

        Assert.Equal(CellKind.WhiteMyco, loaded.World.GetCell("white").Kind);
        Assert.True(loaded.World.GetCell("white").IsGlowing);
    }

    [Fact]
    public void WhiteMyco_StaysGlowingAndDoesNotReactOrConsume()
    {
        var resource = new ResourceId(0);
        var pool = new SwapPoolState();
        pool.AddSlot(resource, PoolSlotRole.Need, quantity: 250, capacity: 500);
        var myco = new CellState("white", new GridPosition(0, 0), pool, CellKind.WhiteMyco);
        var world = new GridWorld(1, 1);
        world.AddCell(myco);
        var engine = new CellularEngine(world);

        engine.RunTicks(3);

        Assert.True(myco.IsGlowing);
        Assert.Equal(250, pool.GetQuantity(resource));
        Assert.Empty(engine.Events.OfType<ReactionEvent>());
    }

    [Fact]
    public void MycoNeedSlot_CanTradeDownToZero()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var mycoPool = new SwapPoolState();
        mycoPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 1, capacity: 500);
        mycoPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 0, capacity: 500);
        var myco = new CellState("white", new GridPosition(1, 0), mycoPool, CellKind.WhiteMyco);

        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.Need);
        standardPool.AddSlot(resourceB, PoolSlotRole.AcceptOnly, quantity: 1);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(myco);
        var engine = new CellularEngine(world);

        engine.Tick();

        var swap = Assert.Single(engine.Events.OfType<SwapEvent>());
        var participants = new[] { swap.InitiatorCellId, swap.CounterpartyCellId };
        Assert.Contains("standard", participants);
        Assert.Contains("white", participants);
        Assert.Equal(0, mycoPool.GetQuantity(resourceA));
        Assert.Equal(1, mycoPool.GetQuantity(resourceB));
    }

    [Fact]
    public void MycoNeedSlot_DoesNotAcceptOverflowWhenNeedOverflowPaymentsAreAllowed()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var mycoPool = new SwapPoolState();
        mycoPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 1, capacity: 500);
        mycoPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 500, capacity: 500);
        var myco = new CellState("white", new GridPosition(1, 0), mycoPool, CellKind.WhiteMyco);

        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.Need);
        standardPool.AddSlot(resourceB, PoolSlotRole.AcceptOnly, quantity: 1);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(myco);
        var engine = new CellularEngine(world, new EngineOptions { AllowNeedOverflowPayments = true });

        engine.Tick();

        Assert.Empty(engine.Events.OfType<SwapEvent>());
        Assert.Equal(1, mycoPool.GetQuantity(resourceA));
        Assert.Equal(500, mycoPool.GetQuantity(resourceB));
    }

    [Fact]
    public void RedMyco_AsCounterparty_GrossFourRedOutgoingDeliversThree()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.AcceptOnly, quantity: 4);
        standardPool.AddSlot(resourceB, PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var redPool = new SwapPoolState();
        redPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 496, capacity: 500);
        redPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 4, capacity: 500);
        var red = new CellState("red", new GridPosition(1, 0), redPool, CellKind.RedMyco);

        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(red);
        var engine = new CellularEngine(world);

        engine.Tick();

        var swap = Assert.Single(engine.Events.OfType<SwapEvent>());
        Assert.Equal("standard", swap.InitiatorCellId);
        Assert.Equal("red", swap.CounterpartyCellId);
        Assert.Equal(resourceA, swap.InitiatorPaidResource);
        Assert.Equal(4, swap.InitiatorPaidQuantity);
        Assert.Equal(resourceB, swap.CounterpartyPaidResource);
        Assert.Equal(4, swap.CounterpartyPaidQuantity);
        Assert.Equal(3, swap.InitiatorReceivedQuantity);
        Assert.Equal(4, swap.CounterpartyReceivedQuantity);
        Assert.Equal(2, standardPool.GetQuantity(resourceB));
        Assert.Equal(500, redPool.GetQuantity(resourceA));
        Assert.True(red.IsGlowing);
    }

    [Fact]
    public void RedMyco_AsInitiator_GrossFourRedOutgoingDeliversThree()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var redPool = new SwapPoolState();
        redPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 4, capacity: 500);
        redPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 496, capacity: 500);
        var red = new CellState("red", new GridPosition(0, 0), redPool, CellKind.RedMyco);

        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.AcceptOnly);
        standardPool.AddSlot(resourceB, PoolSlotRole.AcceptOnly, quantity: 4);
        var standard = new CellState("standard", new GridPosition(1, 0), standardPool);

        var world = new GridWorld(2, 1);
        world.AddCell(red);
        world.AddCell(standard);
        var engine = new CellularEngine(world);

        engine.Tick();

        var swap = Assert.Single(engine.Events.OfType<SwapEvent>());
        Assert.Equal("red", swap.InitiatorCellId);
        Assert.Equal("standard", swap.CounterpartyCellId);
        Assert.Equal(resourceA, swap.InitiatorPaidResource);
        Assert.Equal(4, swap.InitiatorPaidQuantity);
        Assert.Equal(resourceB, swap.CounterpartyPaidResource);
        Assert.Equal(4, swap.CounterpartyPaidQuantity);
        Assert.Equal(4, swap.InitiatorReceivedQuantity);
        Assert.Equal(3, swap.CounterpartyReceivedQuantity);
        Assert.Equal(500, redPool.GetQuantity(resourceB));
        Assert.Equal(3, standardPool.GetQuantity(resourceA));
        Assert.True(red.IsGlowing);
    }

    [Fact]
    public void RedMyco_GrossOneCandidateDoesNotSwapOrFlow()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var standardPool = new SwapPoolState();
        standardPool.AddSlot(resourceA, PoolSlotRole.AcceptOnly, quantity: 1);
        standardPool.AddSlot(resourceB, PoolSlotRole.Need);
        var standard = new CellState("standard", new GridPosition(0, 0), standardPool);

        var redPool = new SwapPoolState();
        redPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 498, capacity: 500);
        redPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 1, capacity: 500);
        var red = new CellState("red", new GridPosition(1, 0), redPool, CellKind.RedMyco);

        var world = new GridWorld(2, 1);
        world.AddCell(standard);
        world.AddCell(red);
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Empty(engine.Events.OfType<SwapEvent>());
        Assert.Empty(engine.Events.OfType<FlowEvent>());
        Assert.Equal(1, standardPool.GetQuantity(resourceA));
        Assert.Equal(1, redPool.GetQuantity(resourceB));
    }

    [Fact]
    public void RedMyco_ToRedMyco_UsesGrossTwoEnvelopeAndStillConnects()
    {
        var resourceA = new ResourceId(0);
        var resourceB = new ResourceId(1);
        var leftPool = new SwapPoolState();
        leftPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 2, capacity: 500);
        leftPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 498, capacity: 500);
        var left = new CellState("left-red", new GridPosition(0, 0), leftPool, CellKind.RedMyco);

        var rightPool = new SwapPoolState();
        rightPool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 498, capacity: 500);
        rightPool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 2, capacity: 500);
        var right = new CellState("right-red", new GridPosition(1, 0), rightPool, CellKind.RedMyco);

        var world = new GridWorld(2, 1);
        world.AddCell(left);
        world.AddCell(right);
        var engine = new CellularEngine(world, new EngineOptions { MaxSwapQuantityPerEdge = 2 });
        engine.Options.RequiredCellIds.Add("left-red");
        engine.Options.RequiredCellIds.Add("right-red");

        engine.Tick();

        var swap = Assert.Single(engine.Events.OfType<SwapEvent>());
        Assert.Contains(swap.InitiatorCellId, new[] { "left-red", "right-red" });
        Assert.Contains(swap.CounterpartyCellId, new[] { "left-red", "right-red" });
        Assert.NotEqual(swap.InitiatorCellId, swap.CounterpartyCellId);
        Assert.Equal(2, swap.InitiatorPaidQuantity);
        Assert.Equal(2, swap.CounterpartyPaidQuantity);
        Assert.Equal(1, swap.InitiatorReceivedQuantity);
        Assert.Equal(1, swap.CounterpartyReceivedQuantity);
        Assert.Contains(swap.InitiatorPaidResource, new[] { resourceA, resourceB });
        Assert.Contains(swap.CounterpartyPaidResource, new[] { resourceA, resourceB });
        Assert.NotEqual(swap.InitiatorPaidResource, swap.CounterpartyPaidResource);
        Assert.All(engine.Events.OfType<FlowEvent>(), flow => Assert.Equal(1, flow.Quantity));
        Assert.True(left.IsGlowing);
        Assert.True(right.IsGlowing);
        Assert.True(engine.Circuit.IsAliveThisTick);

        var diagnostics = CircuitDiagnostics.Build(engine);
        Assert.Contains(
            diagnostics.StrongGroups,
            group => group.CellIds.Contains("left-red") && group.CellIds.Contains("right-red"));
    }
}
