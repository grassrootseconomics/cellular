using CellularSim;

namespace CellularSim.Tests;

public sealed class LevelGenerationTests
{
    [Fact]
    public void PuzzleLevelGenerator_LevelOneUsesFourUniqueResourcesAndAllOtherNeeds()
    {
        var level = PuzzleLevelGenerator.Generate(new PuzzleLevelOptions
        {
            LevelNumber = 1,
            GenerationSeed = 10,
            LayoutCandidateLimit = 128,
            TicksPerCandidate = 80
        });

        Assert.Equal(1, level.Definition.LevelNumber);
        Assert.Equal(LevelMode.Puzzle, level.Definition.Mode);
        Assert.Equal(4, level.Definition.Resources.Count);
        Assert.True(level.SolverSummary.Won);

        foreach (var cell in level.Definition.Cells)
        {
            Assert.Equal(3, cell.Needs.Count);
            Assert.DoesNotContain(cell.ProducedResource, cell.Needs);
            Assert.Equal(
                level.Definition.Resources.Where(resource => resource != cell.ProducedResource).OrderBy(resource => resource),
                cell.Needs.OrderBy(resource => resource));
        }
    }

    [Fact]
    public void PuzzleLevelGenerator_LevelNUsesUniqueProducerAndThreeNeedSlots()
    {
        var cells = PuzzleLevelGenerator.GenerateCellDefinitions(new PuzzleLevelOptions
        {
            LevelNumber = 5,
            GenerationSeed = 22
        });

        Assert.Equal(8, cells.Count);
        Assert.Equal(cells.Count, cells.Select(cell => cell.ProducedResource).Distinct(StringComparer.Ordinal).Count());
        foreach (var cell in cells)
        {
            Assert.Equal(3, cell.Needs.Count);
            Assert.Equal(3, cell.Needs.Distinct(StringComparer.Ordinal).Count());
            Assert.DoesNotContain(cell.ProducedResource, cell.Needs);
        }
    }

    [Fact]
    public void PuzzleLevelGenerator_LevelNBalancesResourceNeedPressure()
    {
        var cells = PuzzleLevelGenerator.GenerateCellDefinitions(new PuzzleLevelOptions
        {
            LevelNumber = 3,
            GenerationSeed = 1003
        });

        var needCounts = cells
            .SelectMany(cell => cell.Needs)
            .GroupBy(resource => resource, StringComparer.Ordinal)
            .ToDictionary(group => group.Key, group => group.Count(), StringComparer.Ordinal);

        foreach (var cell in cells)
        {
            Assert.Equal(3, needCounts[cell.ProducedResource]);
        }
    }

    [Fact]
    public void PuzzleLevelGenerator_RecordsStartingAndSolutionLayouts()
    {
        var level = PuzzleLevelGenerator.Generate(new PuzzleLevelOptions
        {
            LevelNumber = 1,
            GenerationSeed = 11,
            LayoutCandidateLimit = 128,
            TicksPerCandidate = 80
        });

        Assert.NotEqual(level.Definition.StartingLayout.Ascii, level.Definition.SolutionLayout.Ascii);
        Assert.Contains("\"startingLayout\"", level.LevelJson);
        Assert.Contains("\"solutionLayout\"", level.LevelJson);
        Assert.Contains("\"solverSummary\"", level.LevelJson);
        Assert.Equal(level.Definition.Cells.Count, level.StartingLoaded.World.Cells.Count);
        Assert.Equal(level.Definition.Cells.Count, level.SolutionLoaded.World.Cells.Count);
        var compactWidth = Math.Max(2, (int)Math.Ceiling(Math.Sqrt(level.Definition.Cells.Count)));
        var compactHeight = (int)Math.Ceiling((double)level.Definition.Cells.Count / compactWidth);
        Assert.Equal(compactWidth + 2, level.Definition.StartingLayout.Width);
        Assert.Equal(compactHeight + 2, level.Definition.StartingLayout.Height);
    }

    [Fact]
    public void PuzzleLevelGenerator_RejectsUnsolvedLevelUnlessNearWinIsAllowed()
    {
        var strictOptions = new PuzzleLevelOptions
        {
            LevelNumber = 9,
            GenerationSeed = 123,
            NeedAttemptLimit = 1,
            LayoutCandidateLimit = 1,
            TicksPerCandidate = 1
        };

        Assert.Throws<InvalidOperationException>(() => PuzzleLevelGenerator.Generate(strictOptions));

        var allowed = PuzzleLevelGenerator.Generate(new PuzzleLevelOptions
        {
            LevelNumber = strictOptions.LevelNumber,
            GenerationSeed = strictOptions.GenerationSeed,
            NeedAttemptLimit = strictOptions.NeedAttemptLimit,
            LayoutCandidateLimit = strictOptions.LayoutCandidateLimit,
            TicksPerCandidate = strictOptions.TicksPerCandidate,
            AllowNearWin = true
        });

        Assert.True(allowed.SolverSummary.AcceptedNearWin);
        Assert.False(allowed.SolverSummary.Won);
    }

    [Fact]
    public void PuzzleLevelGenerator_StartingLayoutIsSeparatedBeforePlayerMovesCells()
    {
        var level = PuzzleLevelGenerator.Generate(new PuzzleLevelOptions
        {
            LevelNumber = 1,
            GenerationSeed = 12,
            LayoutCandidateLimit = 128,
            TicksPerCandidate = 80
        });
        var engine = new CellularEngine(level.StartingLoaded.World, level.StartingLoaded.Options);

        engine.RunTicks(3);

        Assert.Empty(level.StartingLoaded.World.AdjacentEdges);
        Assert.Empty(engine.Events.OfType<SwapEvent>());
        Assert.Empty(engine.Events.OfType<ReactionEvent>());
        Assert.False(engine.Circuit.IsWon);
    }

    [Fact]
    public void PuzzleLevelGenerator_LevelTwoAndThreeCanRecordApprovedLayouts()
    {
        foreach (var levelNumber in new[] { 2, 3 })
        {
            var level = PuzzleLevelGenerator.Generate(new PuzzleLevelOptions
            {
                LevelNumber = levelNumber,
                GenerationSeed = 30 + levelNumber,
                NeedAttemptLimit = 8,
                LayoutCandidateLimit = 64,
                TicksPerCandidate = 60,
                AllowNearWin = true
            });

            Assert.Equal(levelNumber + 3, level.Definition.Cells.Count);
            Assert.True(level.SolverSummary.Won || level.SolverSummary.AcceptedNearWin);
            Assert.NotEqual("", level.Definition.SolutionLayout.Ascii);
        }
    }
}
