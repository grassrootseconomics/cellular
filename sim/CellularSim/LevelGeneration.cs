using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CellularSim;

public enum LevelMode
{
    Puzzle,
    Arcade
}

public sealed class PuzzleLevelOptions
{
    public int LevelNumber { get; set; } = 1;
    public int GenerationSeed { get; set; } = 1;
    public int NeedAttemptLimit { get; set; } = 64;
    public int LayoutCandidateLimit { get; set; } = 512;
    public int TicksPerCandidate { get; set; } = 100;
    public bool AllowNearWin { get; set; }
    public int SourceQuantityPerTick { get; set; } = 4;
    public int SourceIntervalTicks { get; set; } = 1;
    public int EventCapacity { get; set; } = 262_144;
}

public sealed record GeneratedPuzzleLevel(
    PuzzleLevelOptions Options,
    PuzzleLevelDefinition Definition,
    string LevelJson,
    string StartingFixtureJson,
    string SolutionFixtureJson,
    FixtureLoadResult StartingLoaded,
    FixtureLoadResult SolutionLoaded,
    PuzzleSolverSummary SolverSummary);

public sealed record PuzzleLevelDefinition(
    int LevelNumber,
    LevelMode Mode,
    string Difficulty,
    int GenerationSeed,
    IReadOnlyList<string> Resources,
    IReadOnlyList<LevelCellDefinition> Cells,
    LevelLayout StartingLayout,
    LevelLayout SolutionLayout,
    PuzzleSolverSummary SolverSummary);

public sealed record LevelCellDefinition(
    string Id,
    string ProducedResource,
    IReadOnlyList<string> Needs);

public sealed record LevelLayout(
    int Width,
    int Height,
    IReadOnlyList<LevelCellPlacement> Cells,
    IReadOnlyList<GridPosition> Rocks,
    string Ascii);

public sealed record LevelCellPlacement(string CellId, int X, int Y);

public sealed record PuzzleSolverSummary(
    bool Won,
    bool AcceptedNearWin,
    int NeedAttempt,
    int CandidateIndex,
    int CandidateCount,
    int TicksPerCandidate,
    int GlowingCells,
    int TotalSwaps,
    int TotalReactions,
    int ActiveCellsInLastWindow,
    int StrainPenalty,
    int FinalScore,
    int AdjacentPairs);

public static class PuzzleLevelGenerator
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter() }
    };

    public static GeneratedPuzzleLevel Generate(PuzzleLevelOptions options)
    {
        Validate(options);

        var resourceCount = options.LevelNumber + 3;
        var resources = BuildResourceNames(resourceCount);
        var random = new Random(options.GenerationSeed);
        SearchResult? bestOverall = null;

        for (var needAttempt = 1; needAttempt <= options.NeedAttemptLimit; needAttempt++)
        {
            var cells = BuildPuzzleCells(resources, random);
            var result = SearchBestLayout(cells, resources, options, random, needAttempt);
            if (bestOverall is null || IsBetter(result, bestOverall))
            {
                bestOverall = result;
            }

            if (result.Summary.Won && IsPreferredWinningLayout(result.Layout, cells.Count))
            {
                return BuildGeneratedLevel(options, resources, cells, result);
            }
        }

        if (bestOverall is not null && bestOverall.Summary.Won)
        {
            return BuildGeneratedLevel(options, resources, bestOverall.Cells, bestOverall);
        }

        if (bestOverall is not null && options.AllowNearWin)
        {
            return BuildGeneratedLevel(options, resources, bestOverall.Cells, bestOverall with
            {
                Summary = bestOverall.Summary with { AcceptedNearWin = true }
            });
        }

        throw new InvalidOperationException(
            $"No winning layout found for puzzle level {options.LevelNumber} after "
            + $"{options.NeedAttemptLimit} need attempts and {options.LayoutCandidateLimit} layout candidates per attempt.");
    }

    public static IReadOnlyList<LevelCellDefinition> GenerateCellDefinitions(PuzzleLevelOptions options)
    {
        Validate(options);

        var resources = BuildResourceNames(options.LevelNumber + 3);
        return BuildPuzzleCells(resources, new Random(options.GenerationSeed));
    }

    private static void Validate(PuzzleLevelOptions options)
    {
        if (options.LevelNumber <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Level number must be positive.");
        }

        if (options.NeedAttemptLimit <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Need attempt limit must be positive.");
        }

        if (options.LayoutCandidateLimit <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Layout candidate limit must be positive.");
        }

        if (options.TicksPerCandidate <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Ticks per candidate must be positive.");
        }

        if (options.SourceQuantityPerTick <= 0 || options.SourceIntervalTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Source quantity and interval must be positive.");
        }

        if (options.EventCapacity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Event capacity must be positive.");
        }
    }

    private static IReadOnlyList<LevelCellDefinition> BuildPuzzleCells(IReadOnlyList<string> resources, Random random)
    {
        if (resources.Count == 4)
        {
            return resources.Select((resource, index) =>
                new LevelCellDefinition(
                    $"cell-{resource.ToLowerInvariant()}",
                    resource,
                    resources.Where((_, resourceIndex) => resourceIndex != index).ToArray()))
                .ToArray();
        }

        var order = resources.ToArray();
        Shuffle(order, random);
        var needsByResource = new Dictionary<string, string[]>(StringComparer.Ordinal);
        for (var i = 0; i < order.Length; i++)
        {
            var needs = SelectNearestLineNeeds(order, i);
            Shuffle(needs, random);
            needsByResource[order[i]] = needs;
        }

        return order.Select(resource =>
            new LevelCellDefinition(
                $"cell-{resource.ToLowerInvariant()}",
                resource,
                needsByResource[resource]))
            .ToArray();
    }

    private static SearchResult SearchBestLayout(
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyList<string> resources,
        PuzzleLevelOptions options,
        Random random,
        int needAttempt)
    {
        SearchResult? best = null;
        for (var candidateIndex = 0; candidateIndex < options.LayoutCandidateLimit; candidateIndex++)
        {
            var layout = BuildSolutionLayoutCandidate(cells, random, candidateIndex);
            var fixtureJson = BuildFixtureJson(resources, cells, layout, options);
            var loaded = FixtureLoader.LoadFromJson(fixtureJson);
            loaded.Options.EventCapacity = options.EventCapacity;
            var engine = new CellularEngine(loaded.World, loaded.Options);
            var summary = SimulationSummaryRunner.Run(engine, options.TicksPerCandidate);
            var solverSummary = new PuzzleSolverSummary(
                engine.Circuit.IsWon,
                false,
                needAttempt,
                candidateIndex,
                candidateIndex + 1,
                options.TicksPerCandidate,
                summary.GlowingCells,
                summary.TotalSwaps,
                summary.TotalReactions,
                summary.ActiveCellsInLastWindow,
                summary.StrainPenalty,
                summary.FinalScore,
                summary.AdjacentPairs);
            var result = new SearchResult(cells, layout, fixtureJson, loaded, solverSummary);
            if (best is null || IsBetter(result, best))
            {
                best = result;
            }
        }

        if (best is null)
        {
            throw new InvalidOperationException("Layout search did not evaluate any candidates.");
        }

        return best with
        {
            Summary = best.Summary with { CandidateCount = options.LayoutCandidateLimit }
        };
    }

    private static bool IsBetter(SearchResult candidate, SearchResult currentBest)
    {
        static long Rank(SearchResult result)
        {
            var summary = result.Summary;
            var rank = summary.Won ? 100_000_000_000L : 0;
            rank += CountReciprocalAdjacentPairs(result.Cells, result.Layout) * 2_000_000_000L;
            rank += CountUsefulAdjacentPairs(result.Cells, result.Layout) * 150_000_000L;
            rank += summary.ActiveCellsInLastWindow * 60_000_000L;
            rank += summary.GlowingCells * 40_000_000L;
            rank += summary.TotalReactions * 200_000L;
            rank += summary.AdjacentPairs * 100_000L;
            rank += summary.TotalSwaps * 100L;
            rank += summary.FinalScore;
            rank -= summary.StrainPenalty;
            if (Math.Min(result.Layout.Width, result.Layout.Height) <= 1 && result.Cells.Count > 4)
            {
                rank -= 5_000_000_000L;
            }
            return rank;
        }

        return Rank(candidate) > Rank(currentBest);
    }

    private static bool IsPreferredWinningLayout(LevelLayout layout, int cellCount)
    {
        if (cellCount <= 4)
        {
            return true;
        }

        var (startWidth, startHeight) = ComputeStartingLayoutDimensions(cellCount);
        return Math.Min(layout.Width, layout.Height) > 1
            && layout.Width <= startWidth
            && layout.Height <= startHeight;
    }

    private static GeneratedPuzzleLevel BuildGeneratedLevel(
        PuzzleLevelOptions options,
        IReadOnlyList<string> resources,
        IReadOnlyList<LevelCellDefinition> cells,
        SearchResult solution)
    {
        var startingLayout = BuildStartingLayout(cells, solution.Layout, options);
        var startingFixtureJson = BuildFixtureJson(resources, cells, startingLayout, options);
        var startingLoaded = FixtureLoader.LoadFromJson(startingFixtureJson);
        startingLoaded.Options.EventCapacity = options.EventCapacity;

        var definition = new PuzzleLevelDefinition(
            options.LevelNumber,
            LevelMode.Puzzle,
            BuildDifficultyLabel(options.LevelNumber, cells.Count),
            options.GenerationSeed,
            resources.ToArray(),
            cells.ToArray(),
            startingLayout,
            solution.Layout,
            solution.Summary);
        var levelJson = JsonSerializer.Serialize(definition, JsonOptions);
        return new GeneratedPuzzleLevel(
            options,
            definition,
            levelJson,
            startingFixtureJson,
            solution.FixtureJson,
            startingLoaded,
            solution.Loaded,
            solution.Summary);
    }

    private static LevelLayout BuildStartingLayout(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout solutionLayout,
        PuzzleLevelOptions options)
    {
        var (width, height) = ComputeStartingLayoutDimensions(cells.Count);
        var random = new Random(ComputeStartingLayoutSeed(options));
        var positions = BuildSeparatedStartingPositions(width, height, cells.Count, random);
        var cellOrder = cells.ToArray();
        Shuffle(cellOrder, random);

        var placements = new List<LevelCellPlacement>(cells.Count);
        for (var i = 0; i < cellOrder.Length; i++)
        {
            placements.Add(new LevelCellPlacement(cellOrder[i].Id, positions[i].X, positions[i].Y));
        }

        return new LevelLayout(width, height, placements, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, placements));
    }

    private static int ComputeStartingLayoutSeed(PuzzleLevelOptions options)
    {
        unchecked
        {
            var seed = 17;
            seed = seed * 31 + options.GenerationSeed;
            seed = seed * 31 + options.LevelNumber;
            seed = seed * 31 + 0x51A7;
            return seed;
        }
    }

    private static (int Width, int Height) ComputeStartingLayoutDimensions(int cellCount)
    {
        var (compactWidth, compactHeight) = ComputeCompactDimensions(cellCount);
        return (compactWidth + 2, compactHeight + 2);
    }

    private static GridPosition[] BuildSeparatedStartingPositions(
        int width,
        int height,
        int cellCount,
        Random random)
    {
        var evenPositions = new List<GridPosition>((width * height + 1) / 2);
        var oddPositions = new List<GridPosition>((width * height + 1) / 2);
        var allPositions = new List<GridPosition>(width * height);
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var position = new GridPosition(x, y);
                allPositions.Add(position);
                if ((x + y) % 2 == 0)
                {
                    evenPositions.Add(position);
                }
                else
                {
                    oddPositions.Add(position);
                }
            }
        }

        var separated = evenPositions.Count >= oddPositions.Count ? evenPositions : oddPositions;
        if (separated.Count >= cellCount)
        {
            Shuffle(separated, random);
            return separated.Take(cellCount).ToArray();
        }

        Shuffle(allPositions, random);
        return allPositions.Take(cellCount).ToArray();
    }

    private static LevelLayout BuildCanonicalSolutionLayout(IReadOnlyList<LevelCellDefinition> cells)
    {
        var (width, height) = ComputeCompactDimensions(cells.Count);
        var positions = BuildCompactSolutionPositions(cells.Count).ToArray();
        var placements = cells
            .Select((cell, index) => new LevelCellPlacement(cell.Id, positions[index].X, positions[index].Y))
            .ToArray();
        return new LevelLayout(width, height, placements, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, placements));
    }

    private static LevelLayout BuildLineSolutionLayout(IReadOnlyList<LevelCellDefinition> cells)
    {
        var placements = cells
            .Select((cell, index) => new LevelCellPlacement(cell.Id, index, 0))
            .ToArray();
        return new LevelLayout(cells.Count, 1, placements, Array.Empty<GridPosition>(), RenderAscii(cells.Count, 1, cells, placements));
    }

    private static LevelLayout BuildSolutionLayoutCandidate(
        IReadOnlyList<LevelCellDefinition> cells,
        Random random,
        int candidateIndex)
    {
        if (candidateIndex == 0)
        {
            return BuildCanonicalSolutionLayout(cells);
        }

        var foldedWidths = BuildFoldedLineWidths(cells.Count);
        var foldedIndex = candidateIndex - 1;
        if (foldedIndex >= 0 && foldedIndex < foldedWidths.Count)
        {
            return BuildFoldedLineSolutionLayout(cells, foldedWidths[foldedIndex]);
        }

        if (foldedIndex == foldedWidths.Count)
        {
            return BuildLineSolutionLayout(cells);
        }

        return BuildRandomSolutionLayout(cells, random);
    }

    private static IReadOnlyList<int> BuildFoldedLineWidths(int cellCount)
    {
        var (compactWidth, _) = ComputeCompactDimensions(cellCount);
        var maxWidth = Math.Min(cellCount, Math.Max(compactWidth, (cellCount + 1) / 2));
        var preferredWidth = Math.Min(maxWidth, compactWidth + 2);
        var widths = new List<int> { preferredWidth };

        for (var width = compactWidth; width <= maxWidth; width++)
        {
            if (!widths.Contains(width))
            {
                widths.Add(width);
            }
        }

        return widths;
    }

    private static LevelLayout BuildFoldedLineSolutionLayout(
        IReadOnlyList<LevelCellDefinition> cells,
        int width)
    {
        width = Math.Clamp(width, 2, cells.Count);
        var height = (int)Math.Ceiling((double)cells.Count / width);
        var placements = new LevelCellPlacement[cells.Count];
        for (var i = 0; i < cells.Count; i++)
        {
            var y = i / width;
            var indexInRow = i % width;
            var x = y % 2 == 0 ? indexInRow : width - 1 - indexInRow;
            placements[i] = new LevelCellPlacement(cells[i].Id, x, y);
        }

        return new LevelLayout(width, height, placements, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, placements));
    }

    private static LevelLayout BuildRandomSolutionLayout(IReadOnlyList<LevelCellDefinition> cells, Random random)
    {
        var (width, height) = ComputeCompactDimensions(cells.Count);
        var positions = BuildSnakePositions(width, height).ToArray();
        Shuffle(positions, random);
        var cellOrder = cells.ToArray();
        Shuffle(cellOrder, random);

        var placements = new LevelCellPlacement[cells.Count];
        for (var i = 0; i < cellOrder.Length; i++)
        {
            placements[i] = new LevelCellPlacement(cellOrder[i].Id, positions[i].X, positions[i].Y);
        }

        return new LevelLayout(width, height, placements, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, placements));
    }

    private static (int Width, int Height) ComputeCompactDimensions(int cellCount)
    {
        var width = Math.Max(2, (int)Math.Ceiling(Math.Sqrt(cellCount)));
        var height = (int)Math.Ceiling((double)cellCount / width);
        return (width, height);
    }

    private static IEnumerable<GridPosition> BuildCompactSolutionPositions(int cellCount)
    {
        var (width, height) = ComputeCompactDimensions(cellCount);
        return BuildSnakePositions(width, height).Take(cellCount);
    }

    private static IEnumerable<GridPosition> BuildSnakePositions(int width, int height)
    {
        for (var y = 0; y < height; y++)
        {
            if (y % 2 == 0)
            {
                for (var x = 0; x < width; x++)
                {
                    yield return new GridPosition(x, y);
                }
            }
            else
            {
                for (var x = width - 1; x >= 0; x--)
                {
                    yield return new GridPosition(x, y);
                }
            }
        }
    }

    private static string BuildFixtureJson(
        IReadOnlyList<string> resources,
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout,
        PuzzleLevelOptions options)
    {
        var fixture = new LevelFixtureDocument
        {
            Resources = resources.ToList(),
            Grid = new LevelGridDocument
            {
                Width = layout.Width,
                Height = layout.Height,
                Rocks = layout.Rocks.Select(rock => new LevelPositionDocument { X = rock.X, Y = rock.Y }).ToList()
            },
            Win = new LevelWinDocument
            {
                RequiredCells = cells.Select(cell => cell.Id).ToList(),
                RequiredResources = resources.ToList(),
                DurationTicks = 3
            }
        };

        var placementByCellId = layout.Cells.ToDictionary(placement => placement.CellId, StringComparer.Ordinal);
        foreach (var cell in cells)
        {
            var placement = placementByCellId[cell.Id];
            var cellDocument = new LevelCellDocument
            {
                Id = cell.Id,
                X = placement.X,
                Y = placement.Y
            };
            cellDocument.Slots.Add(new LevelSlotDocument
            {
                Resource = cell.ProducedResource,
                Role = nameof(PoolSlotRole.SourceOutput),
                Quantity = 0
            });
            foreach (var need in cell.Needs)
            {
                cellDocument.Slots.Add(new LevelSlotDocument
                {
                    Resource = need,
                    Role = nameof(PoolSlotRole.Need),
                    Quantity = 0
                });
            }

            cellDocument.Sources.Add(new LevelSourceDocument
            {
                Resource = cell.ProducedResource,
                QuantityPerTick = options.SourceQuantityPerTick,
                IntervalTicks = options.SourceIntervalTicks
            });
            fixture.Cells.Add(cellDocument);
        }

        return JsonSerializer.Serialize(fixture, JsonOptions);
    }

    private static string RenderAscii(
        int width,
        int height,
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyList<LevelCellPlacement> placements)
    {
        var producedByCell = cells.ToDictionary(cell => cell.Id, cell => cell.ProducedResource, StringComparer.Ordinal);
        var symbols = new Dictionary<GridPosition, char>();
        foreach (var placement in placements)
        {
            symbols[new GridPosition(placement.X, placement.Y)] = producedByCell[placement.CellId][0];
        }

        var builder = new StringBuilder();
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                builder.Append(symbols.TryGetValue(new GridPosition(x, y), out var symbol) ? symbol : '.');
            }

            if (y + 1 < height)
            {
                builder.AppendLine();
            }
        }

        return builder.ToString();
    }

    private static List<string> BuildResourceNames(int count)
    {
        var resources = new List<string>(count);
        for (var i = 0; i < count; i++)
        {
            resources.Add(i < 26 ? ((char)('A' + i)).ToString() : $"R{i:00}");
        }

        return resources;
    }

    private static string[] SelectNearestLineNeeds(IReadOnlyList<string> order, int index)
    {
        return Enumerable.Range(0, order.Count)
            .Where(candidateIndex => candidateIndex != index)
            .OrderBy(candidateIndex => Math.Abs(candidateIndex - index))
            .ThenBy(candidateIndex => candidateIndex)
            .Take(3)
            .Select(candidateIndex => order[candidateIndex])
            .ToArray();
    }

    private static int CountUsefulAdjacentPairs(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout)
    {
        var count = 0;
        foreach (var pair in EnumerateAdjacentCellPairs(cells, layout))
        {
            if (CellsHaveUsefulEdge(pair.A, pair.B))
            {
                count++;
            }
        }

        return count;
    }

    private static int CountReciprocalAdjacentPairs(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout)
    {
        var count = 0;
        foreach (var pair in EnumerateAdjacentCellPairs(cells, layout))
        {
            if (CellsHaveReciprocalEdge(pair.A, pair.B))
            {
                count++;
            }
        }

        return count;
    }

    private static IEnumerable<(LevelCellDefinition A, LevelCellDefinition B)> EnumerateAdjacentCellPairs(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout)
    {
        var cellById = cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var placements = layout.Cells.ToArray();
        for (var i = 0; i < placements.Length; i++)
        {
            for (var j = i + 1; j < placements.Length; j++)
            {
                var distance = Math.Abs(placements[i].X - placements[j].X) + Math.Abs(placements[i].Y - placements[j].Y);
                if (distance == 1)
                {
                    yield return (cellById[placements[i].CellId], cellById[placements[j].CellId]);
                }
            }
        }
    }

    private static bool CellsHaveUsefulEdge(LevelCellDefinition a, LevelCellDefinition b) =>
        a.Needs.Contains(b.ProducedResource, StringComparer.Ordinal)
        || b.Needs.Contains(a.ProducedResource, StringComparer.Ordinal);

    private static bool CellsHaveReciprocalEdge(LevelCellDefinition a, LevelCellDefinition b) =>
        a.Needs.Contains(b.ProducedResource, StringComparer.Ordinal)
        && b.Needs.Contains(a.ProducedResource, StringComparer.Ordinal);

    private static string BuildDifficultyLabel(int levelNumber, int cellCount) =>
        $"Level {levelNumber}: {cellCount} producer cells, open board, no rocks";

    private static void Shuffle<T>(IList<T> values, Random random)
    {
        for (var i = values.Count - 1; i > 0; i--)
        {
            var swapIndex = random.Next(i + 1);
            (values[i], values[swapIndex]) = (values[swapIndex], values[i]);
        }
    }

    private sealed record SearchResult(
        IReadOnlyList<LevelCellDefinition> Cells,
        LevelLayout Layout,
        string FixtureJson,
        FixtureLoadResult Loaded,
        PuzzleSolverSummary Summary);

    private sealed class LevelFixtureDocument
    {
        [JsonPropertyName("resources")]
        public List<string> Resources { get; set; } = new();

        [JsonPropertyName("grid")]
        public LevelGridDocument Grid { get; set; } = new();

        [JsonPropertyName("cells")]
        public List<LevelCellDocument> Cells { get; set; } = new();

        [JsonPropertyName("win")]
        public LevelWinDocument Win { get; set; } = new();
    }

    private sealed class LevelGridDocument
    {
        [JsonPropertyName("width")]
        public int Width { get; set; }

        [JsonPropertyName("height")]
        public int Height { get; set; }

        [JsonPropertyName("rocks")]
        public List<LevelPositionDocument> Rocks { get; set; } = new();
    }

    private sealed class LevelPositionDocument
    {
        [JsonPropertyName("x")]
        public int X { get; set; }

        [JsonPropertyName("y")]
        public int Y { get; set; }
    }

    private sealed class LevelCellDocument
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("x")]
        public int X { get; set; }

        [JsonPropertyName("y")]
        public int Y { get; set; }

        [JsonPropertyName("slots")]
        public List<LevelSlotDocument> Slots { get; set; } = new();

        [JsonPropertyName("sources")]
        public List<LevelSourceDocument> Sources { get; set; } = new();
    }

    private sealed class LevelSlotDocument
    {
        [JsonPropertyName("resource")]
        public string Resource { get; set; } = "";

        [JsonPropertyName("role")]
        public string Role { get; set; } = "";

        [JsonPropertyName("quantity")]
        public int Quantity { get; set; }
    }

    private sealed class LevelSourceDocument
    {
        [JsonPropertyName("resource")]
        public string Resource { get; set; } = "";

        [JsonPropertyName("quantityPerTick")]
        public int QuantityPerTick { get; set; }

        [JsonPropertyName("intervalTicks")]
        public int IntervalTicks { get; set; }
    }

    private sealed class LevelWinDocument
    {
        [JsonPropertyName("requiredCells")]
        public List<string> RequiredCells { get; set; } = new();

        [JsonPropertyName("requiredResources")]
        public List<string> RequiredResources { get; set; } = new();

        [JsonPropertyName("durationTicks")]
        public int DurationTicks { get; set; }
    }
}
