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
