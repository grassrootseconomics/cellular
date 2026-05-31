using CellularSim;

namespace CellularSim.Tests;

public sealed class PerformanceShapeTests
{
    [Fact]
    public void DenseGrid_CanRunThousandsOfCellsWithBoundedEvents()
    {
        var catalog = new ResourceCatalog();
        var resourceA = catalog.Register("A");
        var resourceB = catalog.Register("B");
        var world = new GridWorld(width: 64, height: 32);

        for (var y = 0; y < 32; y++)
        {
            for (var x = 0; x < 64; x++)
            {
                var pool = new SwapPoolState();
                if ((x + y) % 2 == 0)
                {
                    pool.AddSlot(resourceA, PoolSlotRole.SourceOutput, quantity: 0);
                    pool.AddSlot(resourceB, PoolSlotRole.Need, quantity: 0);
                    var cell = new CellState($"cell-{x}-{y}", new GridPosition(x, y), pool);
                    cell.AddSource(new CellSource(resourceA, quantityPerTick: 5));
                    world.AddCell(cell);
                }
                else
                {
                    pool.AddSlot(resourceB, PoolSlotRole.SourceOutput, quantity: 0);
                    pool.AddSlot(resourceA, PoolSlotRole.Need, quantity: 0);
                    var cell = new CellState($"cell-{x}-{y}", new GridPosition(x, y), pool);
                    cell.AddSource(new CellSource(resourceB, quantityPerTick: 5));
                    world.AddCell(cell);
                }
            }
        }

        var engine = new CellularEngine(world, new EngineOptions { EventCapacity = 32768 });

        engine.RunTicks(5);

        Assert.Equal(2048, world.Cells.Count);
        Assert.True(engine.Score.ReactionScore > 0);
        Assert.True(engine.Events.Count <= 32768);
        Assert.Contains(engine.Events.OfType<SwapEvent>(), swap => swap.InitiatorReceivedBalanceAfterSwap <= swap.InitiatorReceivedCapacity);
        Assert.Contains(engine.Events.OfType<SwapEvent>(), swap => swap.CounterpartyReceivedBalanceAfterSwap <= swap.CounterpartyReceivedCapacity);
    }
}
