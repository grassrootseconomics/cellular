using CellularSim;

namespace CellularSim.Tests;

public sealed class ShapeFirstExactPuzzleLevelGeneratorTests
{
    [Fact]
    public void ShapeFirstExact_ConstructedCellsNeverHaveDuplicateNeedsOrSelfNeeds()
    {
        var cells = ShapeFirstExactPuzzleLevelGenerator.GenerateCellDefinitionsForTests(TestOptions(levelNumber: 19));

        foreach (var cell in cells)
        {
            var expectedNeedCount = cell.Kind == CellKind.RedMyco ? 4 : 3;
            Assert.Equal(expectedNeedCount, cell.Needs.Count);
            Assert.Equal(cell.Needs.Count, cell.Needs.Distinct(StringComparer.Ordinal).Count());
            if (cell.Kind == CellKind.Standard)
            {
                Assert.DoesNotContain(cell.ProducedResource, cell.Needs);
            }
        }
    }

    [Fact]
    public void ShapeFirstExact_TargetShapeIsConnectedAndNeverPlacesCellsOnRocks()
    {
        var options = TestOptions(levelNumber: 19);
        options.AllowNearWin = true;
        var level = PuzzleLevelGenerator.Generate(options);
        var proof = ShapeFirstExactPuzzleLevelGenerator.BuildConstructionProof(level);
        var rocks = level.Definition.SolutionLayout.Rocks.ToHashSet();
        var occupied = new HashSet<GridPosition>();

        Assert.True(proof.TargetShapeConnected);
        foreach (var placement in level.Definition.SolutionLayout.Cells)
        {
            var position = new GridPosition(placement.X, placement.Y);
            Assert.DoesNotContain(position, rocks);
            Assert.True(occupied.Add(position));
        }
    }

    [Fact]
    public void ShapeFirstExact_StaticProofDetectsDisconnectedMissingProviderGraph()
    {
        var cells = new[]
        {
            new LevelCellDefinition("cell-a-001", CellKind.Standard, "A", new[] { "B", "C", "D" }),
            new LevelCellDefinition("cell-b-001", CellKind.Standard, "B", new[] { "A", "C", "D" })
        };
        var layout = new LevelLayout(
            3,
            1,
            new[]
            {
                new LevelCellPlacement("cell-a-001", 0, 0),
                new LevelCellPlacement("cell-b-001", 2, 0)
            },
            Array.Empty<GridPosition>(),
            "");

        var proof = ShapeFirstExactPuzzleLevelGenerator.BuildConstructionProofForTests(cells, layout);

        Assert.False(proof.StaticProofPassed);
        Assert.False(proof.TargetShapeConnected);
        Assert.True(proof.MissingProviderCount > 0);
    }

    [Fact]
    public void ShapeFirstExact_StaticProofDetectsDuplicateAndSelfNeeds()
    {
        var cells = new[]
        {
            new LevelCellDefinition("cell-a-001", CellKind.Standard, "A", new[] { "A", "B", "B" }),
            new LevelCellDefinition("cell-b-001", CellKind.Standard, "B", new[] { "A", "C", "D" })
        };
        var layout = new LevelLayout(
            2,
            1,
            new[]
            {
                new LevelCellPlacement("cell-a-001", 0, 0),
                new LevelCellPlacement("cell-b-001", 1, 0)
            },
            Array.Empty<GridPosition>(),
            "");

        var proof = ShapeFirstExactPuzzleLevelGenerator.BuildConstructionProofForTests(cells, layout);

        Assert.False(proof.StaticProofPassed);
        Assert.True(proof.InvalidNeedCount > 0);
    }

    [Fact]
    public void ShapeFirstExact_DuplicateProducerNeedsDiffer()
    {
        var cells = ShapeFirstExactPuzzleLevelGenerator.GenerateCellDefinitionsForTests(TestOptions(levelNumber: 25));

        foreach (var group in cells.Where(cell => cell.Kind == CellKind.Standard).GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal))
        {
            var needSets = group
                .Select(cell => string.Join("|", cell.Needs.OrderBy(need => need, StringComparer.Ordinal)))
                .Distinct(StringComparer.Ordinal)
                .Count();
            Assert.Equal(group.Count(), needSets);
        }
    }

    [Fact]
    public void ShapeFirstExact_AnnotatedAsciiUsesTwoCharacterMapTokens()
    {
        var options = TestOptions(levelNumber: 19);
        options.AllowNearWin = true;
        var level = PuzzleLevelGenerator.Generate(options);
        var mapLines = level.Definition.SolutionLayout.Ascii
            .Split('\n')
            .TakeWhile(line => line.Length > 0)
            .ToArray();

        foreach (var token in mapLines.SelectMany(line => line.Split(' ', StringSplitOptions.RemoveEmptyEntries)))
        {
            Assert.Equal(2, token.Length);
        }
    }

    private static PuzzleLevelOptions TestOptions(int levelNumber) => new()
    {
        LevelNumber = levelNumber,
        GenerationSeed = 8000 + levelNumber,
        GenerationStrategy = PuzzleGenerationStrategy.ShapeFirstExact,
        LayoutCandidateLimit = 1,
        NeedAttemptLimit = 1,
        TicksPerCandidate = 10,
        WinRecentFlowWindowTicks = 5,
        ShapeFirstSustainedTicks = 1
    };
}
