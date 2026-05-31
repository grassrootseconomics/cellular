using CellularSim;

namespace CellularSim.Tests;

public sealed class GeneratedScenarioTests
{
    [Fact]
    public void RandomScenarioGenerator_IsDeterministicForSameSeed()
    {
        var options = new RandomScenarioOptions
        {
            Seed = 12345,
            Width = 12,
            Height = 12,
            CellCount = 40,
            ResourceCount = 6,
            RockCount = 12
        };

        var first = RandomScenarioGenerator.Generate(options);
        var second = RandomScenarioGenerator.Generate(options);

        Assert.Equal(first.FixtureJson, second.FixtureJson);
    }

    [Fact]
    public void RandomScenarioGenerator_RespectsPoolAndPlacementRules()
    {
        var generated = RandomScenarioGenerator.Generate(new RandomScenarioOptions
        {
            Seed = 99,
            Width = 16,
            Height = 16,
            CellCount = 100,
            ResourceCount = 6,
            RockCount = 20
        });

        Assert.Equal(100, generated.Loaded.World.Cells.Count);
        Assert.Equal(20, generated.Loaded.World.Rocks.Count);
        foreach (var cell in generated.Loaded.World.Cells)
        {
            Assert.Equal(SwapPoolState.MaxSlots, cell.Pool.Slots.Count);
            Assert.Single(cell.Pool.Slots.Where(slot => slot.Role == PoolSlotRole.SourceOutput));
            Assert.Equal(3, cell.Pool.Slots.Count(slot => slot.Role == PoolSlotRole.Need));
            Assert.Single(cell.Sources);
            Assert.False(generated.Loaded.World.HasRockAt(cell.Position));
        }
    }

    [Fact]
    public void SimulationSummaryRunner_CanInspectGeneratedScenario()
    {
        var generated = RandomScenarioGenerator.Generate(new RandomScenarioOptions
        {
            Seed = 7,
            Width = 10,
            Height = 10,
            CellCount = 50,
            ResourceCount = 5,
            RockCount = 10
        });
        var engine = new CellularEngine(generated.Loaded.World, generated.Loaded.Options);

        var summary = SimulationSummaryRunner.Run(engine, ticks: 10);

        Assert.Equal(10, summary.Ticks);
        Assert.Equal(50, summary.Cells);
        Assert.Equal(10, summary.Rocks);
        Assert.True(summary.AdjacentPairs >= 0);
        Assert.True(summary.TotalSwaps >= 0);
        Assert.True(summary.TotalReactions >= 0);
    }
}
