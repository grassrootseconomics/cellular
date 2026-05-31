using CellularSim;

namespace CellularSim.Tests;

public sealed class ProofTests
{
    [Fact]
    public void Proof_UnpairedResourcesDoNotMoveWithoutASwap()
    {
        var loaded = TestSupport.LoadFixture("proof-one-way-flow.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);
        var resource = loaded.Catalog.GetId("A");

        engine.Tick();

        Assert.Equal(1, loaded.World.GetCell("sender").Pool.GetQuantity(resource));
        Assert.Equal(0, loaded.World.GetCell("receiver").Pool.GetQuantity(resource));
        Assert.Empty(engine.Events.OfType<SwapEvent>());
        Assert.Empty(engine.Events.OfType<FlowEvent>());
    }

    [Fact]
    public void Proof_DiagonalCellsDoNotExchange()
    {
        var loaded = TestSupport.LoadFixture("proof-no-diagonal-flow.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);
        var resource = loaded.Catalog.GetId("A");

        engine.Tick();

        Assert.Empty(engine.Events.OfType<FlowEvent>());
        Assert.Equal(1, loaded.World.GetCell("diagonal-sender").Pool.GetQuantity(resource));
        Assert.Equal(0, loaded.World.GetCell("diagonal-receiver").Pool.GetQuantity(resource));
    }

    [Fact]
    public void Proof_SourceOutputAndNeededInputAreBothConsumedByReaction()
    {
        var loaded = TestSupport.LoadFixture("proof-source-output-needs-input.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);
        var resource = loaded.Catalog.GetId("A");
        var needed = loaded.Catalog.GetId("B");

        engine.Tick();

        Assert.True(loaded.World.GetCell("producer").IsGlowing);
        Assert.Equal(0, loaded.World.GetCell("producer").Pool.GetQuantity(resource));
        Assert.Equal(0, loaded.World.GetCell("producer").Pool.GetQuantity(needed));
        Assert.Contains(engine.Events.OfType<ReactionEvent>(), reaction => reaction.CellId == "producer");
    }

    [Fact]
    public void Proof_EdgeThroughputLimitsEachDirectionToOneResourcePerTick()
    {
        var loaded = TestSupport.LoadFixture("proof-edge-throughput.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);
        var resourceA = loaded.Catalog.GetId("A");
        var resourceB = loaded.Catalog.GetId("B");
        var resourceC = loaded.Catalog.GetId("C");
        var resourceD = loaded.Catalog.GetId("D");

        engine.Tick();

        Assert.Equal(1, loaded.World.GetCell("multi-receiver").Pool.GetQuantity(resourceA));
        Assert.Equal(0, loaded.World.GetCell("multi-receiver").Pool.GetQuantity(resourceB));
        Assert.Equal(1, loaded.World.GetCell("multi-sender").Pool.GetQuantity(resourceC));
        Assert.Equal(0, loaded.World.GetCell("multi-sender").Pool.GetQuantity(resourceD));
        Assert.Single(engine.Events.OfType<SwapEvent>());
        Assert.Equal(2, engine.Events.OfType<FlowEvent>().Count());
    }

    [Fact]
    public void Proof_LivingCircuitWinsOnlyAfterSustainedGlowAndRecentBidirectionalFlow()
    {
        var loaded = TestSupport.LoadFixture("direct-reciprocity.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.RunTicks(2);

        Assert.True(engine.Circuit.IsAliveThisTick);
        Assert.False(engine.Circuit.IsWon);

        engine.Tick();

        Assert.True(engine.Circuit.IsWon);
        Assert.Contains(engine.Events.OfType<WinStateChangedEvent>(), win => win.IsWon);
    }
}
