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
    public int SwapRoundsPerTick { get; set; } = 4;
    public int NeedDesiredQuantity { get; set; } = 16;
    public int NeedOfferReserve { get; set; } = 4;
    public bool AllowNeedOverflowPayments { get; set; } = true;
    public int WinDurationTicks { get; set; } = 3;
    public int RequiredAliveTicksAtEnd { get; set; }
    public int ProgressStride { get; set; }
    public Action<string>? ProgressLogger { get; set; }
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
    int AdjacentPairs,
    int WinDurationTicks,
    int RequiredAliveTicksAtEnd,
    int FinalSustainedTicks,
    bool StableAtEnd);

public static class PuzzleLevelGenerator
{
    private const int MatchAwareCandidateCount = 10;
    private const int MaxSolutionCandidateCount = 1 + MatchAwareCandidateCount;

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
        ReportProgress(
            options,
            $"search start level={options.LevelNumber} resources={resourceCount} "
            + $"needAttempts={options.NeedAttemptLimit} layoutCandidates={GetEffectiveLayoutCandidateLimit(options)} "
            + $"ticksPerCandidate={options.TicksPerCandidate} winDuration={options.WinDurationTicks} "
            + $"requiredAliveAtEnd={options.RequiredAliveTicksAtEnd}");

        for (var needAttempt = 1; needAttempt <= options.NeedAttemptLimit; needAttempt++)
        {
            ReportProgress(options, $"needAttempt={needAttempt}/{options.NeedAttemptLimit} start");
            var cells = BuildPuzzleCells(resources, random);
            var result = SearchBestLayout(cells, resources, options, random, needAttempt);
            if (bestOverall is null || IsBetter(result, bestOverall))
            {
                bestOverall = result;
                ReportProgress(options, $"new overall best {DescribeSummary(result.Summary)} layout={result.Layout.Width}x{result.Layout.Height}");
            }

            if (MeetsWinRequirements(result.Summary) && IsPreferredWinningLayout(result.Layout, cells.Count))
            {
                ReportProgress(options, $"accepted preferred solution {DescribeSummary(result.Summary)}");
                return BuildGeneratedLevel(options, resources, cells, result);
            }

            ReportProgress(options, $"needAttempt={needAttempt}/{options.NeedAttemptLimit} best {DescribeSummary(result.Summary)}");
        }

        if (bestOverall is not null && MeetsWinRequirements(bestOverall.Summary))
        {
            ReportProgress(options, $"accepted best overall solution {DescribeSummary(bestOverall.Summary)}");
            return BuildGeneratedLevel(options, resources, bestOverall.Cells, bestOverall);
        }

        if (bestOverall is not null && options.AllowNearWin)
        {
            ReportProgress(options, $"accepted near win {DescribeSummary(bestOverall.Summary)}");
            return BuildGeneratedLevel(options, resources, bestOverall.Cells, bestOverall with
            {
                Summary = bestOverall.Summary with { AcceptedNearWin = true }
            });
        }

        throw new InvalidOperationException(
            $"No winning layout found for puzzle level {options.LevelNumber} after "
            + $"{options.NeedAttemptLimit} need attempts and {options.LayoutCandidateLimit} layout candidates per attempt "
            + $"with winDurationTicks={options.WinDurationTicks} and requiredAliveTicksAtEnd={options.RequiredAliveTicksAtEnd}.");
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

        if (options.SwapRoundsPerTick <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Swap rounds per tick must be positive.");
        }

        if (options.NeedDesiredQuantity <= 0 || options.NeedOfferReserve <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Need intent quantities must be positive.");
        }

        if (options.EventCapacity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Event capacity must be positive.");
        }

        if (options.WinDurationTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Win duration ticks must be positive.");
        }

        if (options.RequiredAliveTicksAtEnd < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Required alive ticks at end cannot be negative.");
        }

        if (options.ProgressStride < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Progress stride cannot be negative.");
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
            var needs = SelectBalancedRingNeeds(order, i);
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
        var layoutCandidateLimit = GetEffectiveLayoutCandidateLimit(options);
        for (var candidateIndex = 0; candidateIndex < layoutCandidateLimit; candidateIndex++)
        {
            var layout = BuildSolutionLayoutCandidate(cells, random, candidateIndex);
            var fixtureJson = BuildFixtureJson(resources, cells, layout, options);
            var loaded = FixtureLoader.LoadFromJson(fixtureJson);
            loaded.Options.EventCapacity = options.EventCapacity;
            var engine = new CellularEngine(loaded.World, loaded.Options);
            var summary = SimulationSummaryRunner.Run(engine, options.TicksPerCandidate);
            var finalSustainedTicks = engine.Circuit.SustainedTicks;
            var stableAtEnd = engine.Circuit.IsWon
                && engine.Circuit.IsAliveThisTick
                && finalSustainedTicks >= options.RequiredAliveTicksAtEnd;
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
                summary.AdjacentPairs,
                options.WinDurationTicks,
                options.RequiredAliveTicksAtEnd,
                finalSustainedTicks,
                stableAtEnd);
            var result = new SearchResult(cells, layout, fixtureJson, loaded, solverSummary);
            if (best is null || IsBetter(result, best))
            {
                best = result;
            }

            var evaluated = candidateIndex + 1;
            if (MeetsWinRequirements(solverSummary) && IsPreferredWinningLayout(layout, cells.Count))
            {
                ReportProgress(
                    options,
                    $"early accepted preferred layout candidate={evaluated}/{layoutCandidateLimit} "
                    + DescribeSummary(solverSummary));
                return result;
            }

            if (ShouldReportCandidateProgress(options, evaluated))
            {
                var totalEvaluated = ((needAttempt - 1) * layoutCandidateLimit) + evaluated;
                var totalCandidates = options.NeedAttemptLimit * layoutCandidateLimit;
                var percent = totalCandidates == 0 ? 0 : totalEvaluated * 100.0 / totalCandidates;
                ReportProgress(
                    options,
                    $"progress needAttempt={needAttempt}/{options.NeedAttemptLimit} "
                    + $"candidate={evaluated}/{layoutCandidateLimit} "
                    + $"overall={totalEvaluated}/{totalCandidates} ({percent:F1}%) "
                    + $"best={DescribeSummary(best.Summary)}");
            }
        }

        if (best is null)
        {
            throw new InvalidOperationException("Layout search did not evaluate any candidates.");
        }

        return best with
        {
            Summary = best.Summary with { CandidateCount = layoutCandidateLimit }
        };
    }

    private static int GetEffectiveLayoutCandidateLimit(PuzzleLevelOptions options) =>
        Math.Min(options.LayoutCandidateLimit, MaxSolutionCandidateCount);

    private static bool IsBetter(SearchResult candidate, SearchResult currentBest)
    {
        static long Rank(SearchResult result)
        {
            var summary = result.Summary;
            var rank = summary.StableAtEnd ? 250_000_000_000L : 0;
            rank += summary.Won ? 100_000_000_000L : 0;
            rank += summary.FinalSustainedTicks * 3_000_000_000L;
            rank += summary.ActiveCellsInLastWindow * 250_000_000L;
            rank += summary.GlowingCells * 150_000_000L;
            rank += CountReciprocalAdjacentPairs(result.Cells, result.Layout) * 40_000_000L;
            rank += CountUsefulAdjacentPairs(result.Cells, result.Layout) * 10_000_000L;
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

    private static bool MeetsWinRequirements(PuzzleSolverSummary summary) =>
        summary.Won
        && (summary.RequiredAliveTicksAtEnd <= 0 || summary.StableAtEnd);

    private static bool ShouldReportCandidateProgress(PuzzleLevelOptions options, int evaluated) =>
        options.ProgressStride > 0
        && (evaluated == 1
            || evaluated % options.ProgressStride == 0
            || evaluated == options.LayoutCandidateLimit);

    private static void ReportProgress(PuzzleLevelOptions options, string message)
    {
        options.ProgressLogger?.Invoke($"[level-{options.LevelNumber:000}] {DateTimeOffset.UtcNow:O} {message}");
    }

    private static string DescribeSummary(PuzzleSolverSummary summary) =>
        $"stable={summary.StableAtEnd} won={summary.Won} finalSustained={summary.FinalSustainedTicks} "
        + $"glowing={summary.GlowingCells} activeLast={summary.ActiveCellsInLastWindow} "
        + $"swaps={summary.TotalSwaps} reactions={summary.TotalReactions} score={summary.FinalScore} "
        + $"candidate={summary.CandidateIndex}";

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

    private static LevelLayout BuildSolutionLayoutCandidate(
        IReadOnlyList<LevelCellDefinition> cells,
        Random random,
        int candidateIndex)
    {
        if (candidateIndex == 0)
        {
            return BuildCanonicalSolutionLayout(cells);
        }

        if (candidateIndex <= MatchAwareCandidateCount)
        {
            return BuildMatchAwareSolutionLayout(cells, random, candidateIndex);
        }

        throw new ArgumentOutOfRangeException(nameof(candidateIndex), "Only canonical plus match-aware solution candidates are supported.");
    }

    private static LevelLayout BuildMatchAwareSolutionLayout(
        IReadOnlyList<LevelCellDefinition> cells,
        Random random,
        int candidateIndex)
    {
        var (width, height) = ComputeStartingLayoutDimensions(cells.Count);
        var center = new GridPosition(width / 2, height / 2);
        var placedByPosition = new Dictionary<GridPosition, LevelCellDefinition>();
        var placementsByCellId = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
        var unplaced = cells.ToList();

        var strictness = candidateIndex % 3;
        var startCell = PickMatchAwareStartCell(unplaced, cells, random, candidateIndex);
        placedByPosition[center] = startCell;
        placementsByCellId[startCell.Id] = center;
        unplaced.Remove(startCell);

        while (unplaced.Count > 0)
        {
            var bestScore = int.MinValue;
            LevelCellDefinition? bestCell = null;
            GridPosition bestPosition = default;

            foreach (var cell in unplaced)
            {
                foreach (var position in EnumerateOpenNeighborPositions(placedByPosition, width, height))
                {
                    var score = ScoreMatchAwarePlacement(cell, position, placedByPosition, strictness);
                    score += random.Next(8);
                    if (score > bestScore)
                    {
                        bestScore = score;
                        bestCell = cell;
                        bestPosition = position;
                    }
                }
            }

            if (bestCell is null)
            {
                bestCell = unplaced[0];
                bestPosition = FindFirstOpenPosition(width, height, placedByPosition);
            }

            placedByPosition[bestPosition] = bestCell;
            placementsByCellId[bestCell.Id] = bestPosition;
            unplaced.Remove(bestCell);
        }

        var placements = cells
            .Select(cell =>
            {
                var position = placementsByCellId[cell.Id];
                return new LevelCellPlacement(cell.Id, position.X, position.Y);
            })
            .ToArray();
        return NormalizeLayout(cells, placements);
    }

    private static LevelCellDefinition PickMatchAwareStartCell(
        IReadOnlyList<LevelCellDefinition> candidates,
        IReadOnlyList<LevelCellDefinition> allCells,
        Random random,
        int candidateIndex)
    {
        var ranked = candidates
            .Select(cell => (Cell: cell, Degree: allCells.Where(other => !ReferenceEquals(cell, other)).Sum(other => GetCellMatchScore(cell, other))))
            .OrderByDescending(item => item.Degree)
            .ThenBy(item => item.Cell.Id, StringComparer.Ordinal)
            .ToArray();
        if (ranked.Length == 0)
        {
            throw new InvalidOperationException("Cannot build a match-aware layout with no cells.");
        }

        if (candidateIndex <= 3)
        {
            return ranked[0].Cell;
        }

        var topCount = Math.Min(ranked.Length, Math.Max(1, ranked.Length / 3));
        return ranked[random.Next(topCount)].Cell;
    }

    private static IEnumerable<GridPosition> EnumerateOpenNeighborPositions(
        Dictionary<GridPosition, LevelCellDefinition> placedByPosition,
        int width,
        int height)
    {
        var seen = new HashSet<GridPosition>();
        foreach (var position in placedByPosition.Keys)
        {
            foreach (var neighbor in EnumerateOrthogonalNeighbors(position))
            {
                if (neighbor.X < 0
                    || neighbor.Y < 0
                    || neighbor.X >= width
                    || neighbor.Y >= height
                    || placedByPosition.ContainsKey(neighbor)
                    || !seen.Add(neighbor))
                {
                    continue;
                }

                yield return neighbor;
            }
        }
    }

    private static int ScoreMatchAwarePlacement(
        LevelCellDefinition cell,
        GridPosition position,
        IReadOnlyDictionary<GridPosition, LevelCellDefinition> placedByPosition,
        int strictness)
    {
        var score = 0;
        var matchedNeighbors = 0;
        var unmatchedNeighbors = 0;
        var neighborCount = 0;

        foreach (var neighborPosition in EnumerateOrthogonalNeighbors(position))
        {
            if (!placedByPosition.TryGetValue(neighborPosition, out var neighbor))
            {
                continue;
            }

            neighborCount++;
            var matchScore = GetCellMatchScore(cell, neighbor);
            if (matchScore > 0)
            {
                matchedNeighbors++;
                score += matchScore * 120;
            }
            else
            {
                unmatchedNeighbors++;
            }
        }

        var unmatchedPenalty = strictness switch
        {
            0 => 220,
            1 => 120,
            _ => 60
        };
        score += matchedNeighbors * 40;
        score += neighborCount * 4;
        score -= unmatchedNeighbors * unmatchedPenalty;
        return score;
    }

    private static IEnumerable<GridPosition> EnumerateOrthogonalNeighbors(GridPosition position)
    {
        yield return new GridPosition(position.X + 1, position.Y);
        yield return new GridPosition(position.X - 1, position.Y);
        yield return new GridPosition(position.X, position.Y + 1);
        yield return new GridPosition(position.X, position.Y - 1);
    }

    private static int GetCellMatchScore(LevelCellDefinition a, LevelCellDefinition b)
    {
        var aNeedsB = a.Needs.Contains(b.ProducedResource, StringComparer.Ordinal);
        var bNeedsA = b.Needs.Contains(a.ProducedResource, StringComparer.Ordinal);
        return (aNeedsB, bNeedsA) switch
        {
            (true, true) => 6,
            (true, false) => 2,
            (false, true) => 2,
            _ => 0
        };
    }

    private static GridPosition FindFirstOpenPosition(
        int width,
        int height,
        IReadOnlyDictionary<GridPosition, LevelCellDefinition> placedByPosition)
    {
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var position = new GridPosition(x, y);
                if (!placedByPosition.ContainsKey(position))
                {
                    return position;
                }
            }
        }

        throw new InvalidOperationException("No open position remains in the generated solution layout.");
    }

    private static LevelLayout NormalizeLayout(
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyList<LevelCellPlacement> placements)
    {
        var minX = placements.Min(placement => placement.X);
        var minY = placements.Min(placement => placement.Y);
        var normalized = placements
            .Select(placement => new LevelCellPlacement(placement.CellId, placement.X - minX, placement.Y - minY))
            .ToArray();
        var width = normalized.Max(placement => placement.X) + 1;
        var height = normalized.Max(placement => placement.Y) + 1;
        return new LevelLayout(width, height, normalized, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, normalized));
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
            Engine = new LevelEngineDocument
            {
                SwapRoundsPerTick = options.SwapRoundsPerTick,
                NeedDesiredQuantity = options.NeedDesiredQuantity,
                NeedOfferReserve = options.NeedOfferReserve,
                AllowNeedOverflowPayments = options.AllowNeedOverflowPayments
            },
            Win = new LevelWinDocument
            {
                RequiredCells = cells.Select(cell => cell.Id).ToList(),
                RequiredResources = resources.ToList(),
                DurationTicks = options.WinDurationTicks
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

    private static string[] SelectBalancedRingNeeds(IReadOnlyList<string> order, int index)
    {
        if (order.Count <= 4)
        {
            return Enumerable.Range(0, order.Count)
                .Where(candidateIndex => candidateIndex != index)
                .Select(candidateIndex => order[candidateIndex])
                .ToArray();
        }

        var previous = (index + order.Count - 1) % order.Count;
        var next = (index + 1) % order.Count;
        var nextRelay = (index + 2) % order.Count;
        return
        [
            order[previous],
            order[next],
            order[nextRelay]
        ];
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

        [JsonPropertyName("engine")]
        public LevelEngineDocument Engine { get; set; } = new();

        [JsonPropertyName("cells")]
        public List<LevelCellDocument> Cells { get; set; } = new();

        [JsonPropertyName("win")]
        public LevelWinDocument Win { get; set; } = new();
    }

    private sealed class LevelEngineDocument
    {
        [JsonPropertyName("swapRoundsPerTick")]
        public int SwapRoundsPerTick { get; set; }

        [JsonPropertyName("needDesiredQuantity")]
        public int NeedDesiredQuantity { get; set; }

        [JsonPropertyName("needOfferReserve")]
        public int NeedOfferReserve { get; set; }

        [JsonPropertyName("allowNeedOverflowPayments")]
        public bool AllowNeedOverflowPayments { get; set; }
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
