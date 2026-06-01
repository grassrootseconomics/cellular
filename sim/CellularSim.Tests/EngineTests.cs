using CellularSim;

namespace CellularSim.Tests;

public sealed class EngineTests
{
    [Fact]
    public void Source_ReplenishesMatchingSlot()
    {
        var resource = new ResourceId(0);
        var pool = new SwapPoolState();
        pool.AddSlot(resource, PoolSlotRole.SourceOutput);
        var cell = new CellState("source", new GridPosition(0, 0), pool);
        cell.AddSource(new CellSource(resource));
        var world = new GridWorld(1, 1);
        world.AddCell(cell);

        var engine = new CellularEngine(world);
        engine.Tick();

        Assert.Equal(1, pool.GetQuantity(resource));
    }

    [Fact]
    public void Source_ReplenishesAtConfiguredRateWithoutExceedingCap()
    {
        var resource = new ResourceId(0);
        var pool = new SwapPoolState();
        pool.AddSlot(resource, PoolSlotRole.SourceOutput, quantity: 98);
        var cell = new CellState("source", new GridPosition(0, 0), pool);
        cell.AddSource(new CellSource(resource, quantityPerTick: 4));
        var world = new GridWorld(1, 1);
        world.AddCell(cell);

        var engine = new CellularEngine(world);
        engine.Tick();

        Assert.Equal(100, pool.GetQuantity(resource));
        Assert.Contains(engine.Events.OfType<OverflowEvent>(), overflow =>
            overflow.CellId == "source"
            && overflow.Resource == resource
            && overflow.Quantity == 2);
    }

    [Fact]
    public void SourceBlockedByCap_EmitsOverflow()
    {
        var loaded = TestSupport.LoadFixture("limits.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.Tick();

        Assert.Contains(engine.Events.OfType<OverflowEvent>(), overflow => overflow.CellId == "source-cell");
        Assert.Contains(engine.Events.OfType<StrainEvent>(), strain => strain.Reason == StrainReason.OverCapacityPressure);
    }

    [Fact]
    public void AdjacentCells_SwapReciprocallyAndReact()
    {
        var loaded = TestSupport.LoadFixture("direct-reciprocity.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.Tick();

        Assert.True(loaded.World.GetCell("cell-a").IsGlowing);
        Assert.True(loaded.World.GetCell("cell-b").IsGlowing);
        Assert.Equal(20, engine.Score.ReactionScore);
        Assert.Single(engine.Events.OfType<SwapEvent>());
        Assert.Equal(2, engine.Events.OfType<FlowEvent>().Count(flow => flow.Kind == FlowKind.Reciprocal));
        Assert.Equal(2, engine.Events.OfType<ReactionEvent>().Count());
    }

    [Fact]
    public void Rocks_BlockEdges()
    {
        var resource = new ResourceId(0);
        var leftPool = new SwapPoolState();
        leftPool.AddSlot(resource, PoolSlotRole.AcceptOnly, quantity: 1);
        var rightPool = new SwapPoolState();
        rightPool.AddSlot(resource, PoolSlotRole.AcceptOnly);

        var world = new GridWorld(3, 1);
        world.AddRock(new GridPosition(1, 0));
        world.AddCell(new CellState("left", new GridPosition(0, 0), leftPool));
        world.AddCell(new CellState("right", new GridPosition(2, 0), rightPool));
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Empty(engine.Events.OfType<FlowEvent>());
        Assert.Equal(0, rightPool.GetQuantity(resource));
    }

    [Fact]
    public void ThreePoolFixture_SourceOutputsFeedNeighborNeeds()
    {
        var loaded = TestSupport.LoadFixture("routing.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.Tick();

        Assert.True(loaded.World.GetCell("cell-a").IsGlowing);
        Assert.True(loaded.World.GetCell("cell-c").IsGlowing);
        Assert.True(loaded.World.GetCell("cell-b").IsGlowing);
        Assert.Equal(2, engine.Events.OfType<SwapEvent>().Count());
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow => flow.SourceCellId == "cell-a" && flow.TargetCellId == "cell-c");
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow => flow.SourceCellId == "cell-c" && flow.TargetCellId == "cell-a");
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow => flow.SourceCellId == "cell-c" && flow.TargetCellId == "cell-b");
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow => flow.SourceCellId == "cell-b" && flow.TargetCellId == "cell-c");
        Assert.Contains(engine.Events.OfType<ReactionEvent>(), reaction => reaction.CellId == "cell-c");
    }

    [Fact]
    public void FourCellLine_PrioritizesMissingNeedsOverRepeatedLocalTopUps()
    {
        var loaded = TestSupport.LoadFixture("four-cell-line.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.RunTicks(3);

        Assert.True(loaded.World.GetCell("cell-c").IsGlowing);
        Assert.Contains(engine.Events.OfType<SwapEvent>(), swap =>
            swap.InitiatorCellId == "cell-b" && swap.CounterpartyCellId == "cell-c"
            || swap.InitiatorCellId == "cell-c" && swap.CounterpartyCellId == "cell-b");
    }

    [Fact]
    public void TwoRowFixture_UsesOrthogonalTouchingPairs()
    {
        var loaded = TestSupport.LoadFixture("six-cell-two-row-glow.json");

        var touchingPairs = loaded.World.AdjacentEdges
            .Select(edge =>
            {
                var left = loaded.World.Cells[edge.A].Id;
                var right = loaded.World.Cells[edge.B].Id;
                return string.CompareOrdinal(left, right) < 0 ? $"{left}:{right}" : $"{right}:{left}";
            })
            .ToHashSet(StringComparer.Ordinal);

        Assert.Equal(
            new HashSet<string>(StringComparer.Ordinal)
            {
                "cell-a:cell-b",
                "cell-a:cell-f",
                "cell-b:cell-c",
                "cell-b:cell-e",
                "cell-c:cell-d",
                "cell-d:cell-e",
                "cell-e:cell-f"
            },
            touchingPairs);
        Assert.DoesNotContain("cell-a:cell-c", touchingPairs);
    }

    [Fact]
    public void TwelveCellGrid_CellGTouchesCfhk()
    {
        var loaded = TestSupport.LoadFixture("twelve-cell-grid-seed-12003.json");
        var gIndex = loaded.World.GetCell("cell-g").Index;

        var neighbors = loaded.World.AdjacentEdges
            .Where(edge => edge.A == gIndex || edge.B == gIndex)
            .Select(edge => loaded.World.Cells[edge.A == gIndex ? edge.B : edge.A].Id)
            .ToHashSet(StringComparer.Ordinal);

        Assert.Equal(
            new HashSet<string>(StringComparer.Ordinal)
            {
                "cell-c",
                "cell-f",
                "cell-h",
                "cell-k"
            },
            neighbors);
    }

    [Fact]
    public void AdjacentEdges_AreStableAcrossFixtureCellOrder()
    {
        const string ordered = """
        {
          "resources": ["A"],
          "grid": { "width": 2, "height": 2, "rocks": [] },
          "cells": [
            { "id": "cell-a", "x": 0, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "cell-b", "x": 1, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "cell-c", "x": 0, "y": 1, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "cell-d", "x": 1, "y": 1, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] }
          ]
        }
        """;
        const string reversed = """
        {
          "resources": ["A"],
          "grid": { "width": 2, "height": 2, "rocks": [] },
          "cells": [
            { "id": "cell-d", "x": 1, "y": 1, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "cell-c", "x": 0, "y": 1, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "cell-b", "x": 1, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "cell-a", "x": 0, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] }
          ]
        }
        """;

        static string[] EdgeSequence(string json)
        {
            var loaded = FixtureLoader.LoadFromJson(json);
            return loaded.World.AdjacentEdges
                .Select(edge => $"{loaded.World.Cells[edge.A].Id}:{loaded.World.Cells[edge.B].Id}")
                .ToArray();
        }

        var expected = new[] { "cell-a:cell-b", "cell-a:cell-c", "cell-b:cell-d", "cell-c:cell-d" };

        Assert.Equal(expected, EdgeSequence(ordered));
        Assert.Equal(expected, EdgeSequence(reversed));
    }

    [Fact]
    public void SourceOutput_CanReceiveReturnedOutputEvenWhenFull()
    {
        var c = new ResourceId(0);
        var d = new ResourceId(1);
        var f = new ResourceId(2);
        var cellCPool = new SwapPoolState();
        cellCPool.AddSlot(c, PoolSlotRole.SourceOutput);
        cellCPool.AddSlot(d, PoolSlotRole.Need);
        cellCPool.AddSlot(f, PoolSlotRole.Need, quantity: 2);
        var cellFPool = new SwapPoolState();
        cellFPool.AddSlot(f, PoolSlotRole.SourceOutput, quantity: 100);
        cellFPool.AddSlot(d, PoolSlotRole.AcceptOnly, quantity: 2);
        var world = new GridWorld(2, 1);
        world.AddCell(new CellState("cell-c", new GridPosition(0, 0), cellCPool));
        world.AddCell(new CellState("cell-f", new GridPosition(1, 0), cellFPool));
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Contains(engine.Events.OfType<SwapEvent>(), swap =>
            swap.InitiatorCellId == "cell-c"
            && swap.CounterpartyCellId == "cell-f"
            && swap.InitiatorPaidResource == f
            && swap.CounterpartyPaidResource == d);
        Assert.Equal(1, cellCPool.GetQuantity(d));
        Assert.Equal(1, cellCPool.GetQuantity(f));
        Assert.Equal(100, cellFPool.GetQuantity(f));
        Assert.Equal(1, cellFPool.GetQuantity(d));
    }

    [Fact]
    public void LowerRequestedBalance_WinsSharedResourceClaim()
    {
        var d = new ResourceId(0);
        var f = new ResourceId(1);
        var g = new ResourceId(2);
        var cellGPool = new SwapPoolState();
        cellGPool.AddSlot(g, PoolSlotRole.SourceOutput, quantity: 1);
        cellGPool.AddSlot(d, PoolSlotRole.Need, quantity: 1);
        var cellFPool = new SwapPoolState();
        cellFPool.AddSlot(f, PoolSlotRole.SourceOutput, quantity: 100);
        cellFPool.AddSlot(d, PoolSlotRole.AcceptOnly, quantity: 1);
        cellFPool.AddSlot(g, PoolSlotRole.Need);
        var cellCPool = new SwapPoolState();
        cellCPool.AddSlot(new ResourceId(3), PoolSlotRole.SourceOutput);
        cellCPool.AddSlot(d, PoolSlotRole.Need);
        cellCPool.AddSlot(f, PoolSlotRole.Need, quantity: 2);
        var world = new GridWorld(2, 2);
        world.AddCell(new CellState("cell-g", new GridPosition(0, 0), cellGPool));
        world.AddCell(new CellState("cell-f", new GridPosition(1, 0), cellFPool));
        world.AddCell(new CellState("cell-c", new GridPosition(1, 1), cellCPool));
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Contains(engine.Events.OfType<SwapEvent>(), swap =>
            swap.InitiatorCellId == "cell-c"
            && swap.CounterpartyCellId == "cell-f"
            && swap.InitiatorPaidResource == f
            && swap.CounterpartyPaidResource == d);
        Assert.Equal(1, cellCPool.GetQuantity(d));
        Assert.Equal(0, cellFPool.GetQuantity(d));
        Assert.DoesNotContain(engine.Events.OfType<FlowEvent>(), flow =>
            flow.SourceCellId == "cell-f"
            && flow.TargetCellId == "cell-g"
            && flow.Resource == d);
    }

    [Fact]
    public void FullNeedSlot_StillBlocksIncomingSwapPayment()
    {
        var a = new ResourceId(0);
        var b = new ResourceId(1);
        var c = new ResourceId(2);
        var cellAPool = new SwapPoolState();
        cellAPool.AddSlot(a, PoolSlotRole.SourceOutput, quantity: 1);
        cellAPool.AddSlot(b, PoolSlotRole.Need);
        var cellBPool = new SwapPoolState();
        cellBPool.AddSlot(c, PoolSlotRole.SourceOutput);
        cellBPool.AddSlot(a, PoolSlotRole.Need, quantity: 100);
        cellBPool.AddSlot(b, PoolSlotRole.AcceptOnly, quantity: 1);
        var world = new GridWorld(2, 1);
        world.AddCell(new CellState("cell-a", new GridPosition(0, 0), cellAPool));
        world.AddCell(new CellState("cell-b", new GridPosition(1, 0), cellBPool));
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Empty(engine.Events.OfType<SwapEvent>());
        Assert.Equal(0, cellAPool.GetQuantity(b));
        Assert.Equal(100, cellBPool.GetQuantity(a));
    }

    [Fact]
    public void RelayCell_ReceivesBundleAndKeepsSurplusAfterReaction()
    {
        var b = new ResourceId(0);
        var c = new ResourceId(1);
        var d = new ResourceId(2);
        var f = new ResourceId(3);
        var cellCPool = new SwapPoolState();
        cellCPool.AddSlot(c, PoolSlotRole.SourceOutput, quantity: 1);
        cellCPool.AddSlot(b, PoolSlotRole.Need, quantity: 1);
        cellCPool.AddSlot(d, PoolSlotRole.Need);
        cellCPool.AddSlot(f, PoolSlotRole.Need, quantity: 5);
        var cellFPool = new SwapPoolState();
        cellFPool.AddSlot(f, PoolSlotRole.SourceOutput, quantity: 100);
        cellFPool.AddSlot(d, PoolSlotRole.AcceptOnly, quantity: 4);
        var world = new GridWorld(2, 1);
        world.AddCell(new CellState("cell-c", new GridPosition(0, 0), cellCPool));
        world.AddCell(new CellState("cell-f", new GridPosition(1, 0), cellFPool));
        var engine = new CellularEngine(world);

        engine.Tick();

        Assert.Contains(engine.Events.OfType<SwapEvent>(), swap =>
            swap.InitiatorCellId == "cell-c"
            && swap.CounterpartyCellId == "cell-f"
            && swap.InitiatorPaidResource == f
            && swap.CounterpartyPaidResource == d
            && swap.InitiatorPaidQuantity == 4
            && swap.CounterpartyPaidQuantity == 4);
        Assert.Contains(engine.Events.OfType<ReactionEvent>(), reaction => reaction.CellId == "cell-c");
        Assert.Equal(3, cellCPool.GetQuantity(d));
        Assert.Equal(100, cellFPool.GetQuantity(f));
    }

    [Fact]
    public void LevelFourSourceReturnGridlockLayout_WinsWithBundledSwaps()
    {
        var loaded = TestSupport.LoadFixture("level-four-source-return-gridlock.json");
        loaded.Options.EventCapacity = 20_000;
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.RunTicks(200);

        Assert.True(engine.Circuit.IsWon);
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow =>
            flow.SourceCellId == "cell-f"
            && flow.TargetCellId == "cell-c"
            && flow.Resource == loaded.Catalog.GetId("D"));
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow =>
            flow.SourceCellId == "cell-c"
            && flow.TargetCellId == "cell-b"
            && flow.Resource == loaded.Catalog.GetId("D"));
    }

    [Fact]
    public void LevelFourCompactSolution_WinsWithBundledSwaps()
    {
        var loaded = TestSupport.LoadFixture("level-four-source-return-gridlock.json");
        loaded.Options.EventCapacity = 20_000;
        loaded.World.MoveCell("cell-d", new GridPosition(2, 0));
        loaded.World.MoveCell("cell-e", new GridPosition(1, 0));
        loaded.World.MoveCell("cell-a", new GridPosition(0, 0));
        loaded.World.MoveCell("cell-d", new GridPosition(2, 1));
        loaded.World.MoveCell("cell-g", new GridPosition(2, 0));
        loaded.World.MoveCell("cell-c", new GridPosition(0, 1));
        loaded.World.MoveCell("cell-b", new GridPosition(0, 2));
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.RunTicks(200);

        Assert.True(engine.Circuit.IsWon);
        Assert.Contains(engine.Events.OfType<FlowEvent>(), flow =>
            flow.SourceCellId == "cell-f"
            && flow.TargetCellId == "cell-c"
            && flow.Resource == loaded.Catalog.GetId("D"));
    }

    [Fact]
    public void LevelThreeCeaFbd_StaysAliveForFiveHundredTicksAfterWarmup()
    {
        var loaded = TestSupport.LoadFixture("level-three-cea-fbd-stable.json");
        loaded.Options.EventCapacity = 80_000;
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.RunTicks(650);

        Assert.True(engine.Circuit.IsWon);
        Assert.True(engine.Circuit.IsAliveThisTick);
        Assert.True(engine.Circuit.SustainedTicks >= 500);
        Assert.All(loaded.World.Cells, cell => Assert.True(cell.IsGlowing, cell.Id));
    }

    [Fact]
    public void RepeatedRuns_ProduceIdenticalEventSequence()
    {
        static string[] Run()
        {
            var loaded = TestSupport.LoadFixture("direct-reciprocity.json");
            var engine = new CellularEngine(loaded.World, loaded.Options);
            engine.RunTicks(5);
            return engine.Events.Select(TestSupport.FormatEvent).ToArray();
        }

        Assert.Equal(Run(), Run());
    }
}
