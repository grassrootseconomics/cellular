using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CellularSim;

public enum LevelMode
{
    Puzzle,
    Arcade
}

public enum PuzzleGenerationStrategy
{
    Search,
    ShapeFirstExact
}

public sealed class PuzzleLevelOptions
{
    public int StartLevel { get; set; }
    public int EndLevel { get; set; }
    public int LevelNumber { get; set; } = 1;
    public int GenerationSeed { get; set; } = 1;
    public int GenerationSeedBase { get; set; } = 1000;
    public PuzzleGenerationStrategy GenerationStrategy { get; set; } = PuzzleGenerationStrategy.Search;
    public int NeedAttemptLimit { get; set; } = 64;
    public int LayoutCandidateLimit { get; set; } = 512;
    public int TicksPerCandidate { get; set; } = 100;
    public bool AllowNearWin { get; set; }
    public int SourceQuantityPerTick { get; set; } = 32;
    public int SourceIntervalTicks { get; set; } = 1;
    public int EventCapacity { get; set; } = 262_144;
    public int GlowTtlTicks { get; set; } = 200;
    public int WinRecentFlowWindowTicks { get; set; } = 200;
    public int SwapRoundsPerTick { get; set; } = 4;
    public int NeedDesiredQuantity { get; set; } = 16;
    public int NeedOfferReserve { get; set; } = 4;
    public bool AllowNeedOverflowPayments { get; set; } = true;
    public int MaxSwapQuantityPerEdge { get; set; } = 8;
    public int WinDurationTicks { get; set; } = 3;
    public int RequiredAliveTicksAtEnd { get; set; }
    public int ShapeFirstSustainedTicks { get; set; }
    public int ProgressStride { get; set; }
    public bool PlayableOnly { get; set; }
    public string ShipDirectory { get; set; } = Path.Combine("levels", "puzzle");
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
    PuzzleSolverSummary SolverSummary,
    int RepairEditCount = 0,
    int ProducerEditCount = 0);

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
    CellKind Kind,
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
    private const int MaxLetterResourceCount = 26;
    private const int DuplicateProducerInterval = 6;
    private const int RedMycoInterval = 5;
    private const int RockInterval = 3;
    private const int MycoNeedCount = 4;
    private const int MycoStartingQuantity = 250;
    private const int MycoCapacity = 500;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Converters = { new JsonStringEnumConverter() }
    };

    public static GeneratedPuzzleLevel Generate(PuzzleLevelOptions options)
    {
        if (options.GenerationStrategy == PuzzleGenerationStrategy.ShapeFirstExact)
        {
            return ShapeFirstExactPuzzleLevelGenerator.Generate(options);
        }

        Validate(options);

        if (options.PlayableOnly)
        {
            return GeneratePlayableOnly(options);
        }

        var normalCellCount = ComputeNormalCellCount(options);
        var resourceCount = ComputeUniqueProducerResourceCount(normalCellCount);
        var resources = BuildResourceNames(resourceCount);
        var random = new Random(options.GenerationSeed);
        SearchResult? bestOverall = null;
        ReportProgress(
            options,
            $"search start level={options.LevelNumber} normalCells={normalCellCount} resources={resourceCount} "
            + $"needAttempts={options.NeedAttemptLimit} layoutCandidates={GetEffectiveLayoutCandidateLimit(options)} "
            + $"ticksPerCandidate={options.TicksPerCandidate} winDuration={options.WinDurationTicks} "
            + $"requiredAliveAtEnd={options.RequiredAliveTicksAtEnd}");

        for (var needAttempt = 1; needAttempt <= options.NeedAttemptLimit; needAttempt++)
        {
            ReportProgress(options, $"needAttempt={needAttempt}/{options.NeedAttemptLimit} start");
            var cells = BuildPuzzleCells(normalCellCount, resources, random);
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

    private static GeneratedPuzzleLevel GeneratePlayableOnly(PuzzleLevelOptions options)
    {
        var normalCellCount = ComputeNormalCellCount(options);
        var resourceCount = ComputeUniqueProducerResourceCount(normalCellCount);
        var resources = BuildResourceNames(resourceCount);
        var cells = BuildPuzzleCells(normalCellCount, resources, new Random(options.GenerationSeed));
        var candidateLayout = BuildCanonicalSolutionLayout(cells);
        var startingLayout = BuildStartingLayout(cells, candidateLayout, options);
        var startingFixtureJson = BuildFixtureJson(resources, cells, startingLayout, options);
        var startingLoaded = FixtureLoader.LoadFromJson(startingFixtureJson);
        startingLoaded.Options.EventCapacity = options.EventCapacity;

        var candidateFixtureJson = BuildFixtureJson(resources, cells, candidateLayout, options);
        var candidateLoaded = FixtureLoader.LoadFromJson(candidateFixtureJson);
        candidateLoaded.Options.EventCapacity = options.EventCapacity;

        var summary = new PuzzleSolverSummary(
            false,
            false,
            0,
            -1,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            CountAdjacentPairs(cells, candidateLayout),
            options.WinDurationTicks,
            options.RequiredAliveTicksAtEnd,
            0,
            false);
        var definition = new PuzzleLevelDefinition(
            options.LevelNumber,
            LevelMode.Puzzle,
            BuildDifficultyLabel(options.LevelNumber, cells.Count),
            options.GenerationSeed,
            resources.ToArray(),
            cells.ToArray(),
            startingLayout,
            candidateLayout,
            summary);
        var levelJson = JsonSerializer.Serialize(definition, JsonOptions);
        return new GeneratedPuzzleLevel(
            options,
            definition,
            levelJson,
            startingFixtureJson,
            candidateFixtureJson,
            startingLoaded,
            candidateLoaded,
            summary);
    }

    public static IReadOnlyList<LevelCellDefinition> GenerateCellDefinitions(PuzzleLevelOptions options)
    {
        Validate(options);

        var resources = BuildResourceNames(ComputeUniqueProducerResourceCount(ComputeNormalCellCount(options)));
        return BuildPuzzleCells(ComputeNormalCellCount(options), resources, new Random(options.GenerationSeed));
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

        if (options.GlowTtlTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Glow TTL must be positive.");
        }

        if (options.WinRecentFlowWindowTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Win recent-flow window must be positive.");
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

    private static int ComputeNormalCellCount(PuzzleLevelOptions options) => options.LevelNumber + 3;

    private static int ComputeRedMycoCount(int normalCellCount) => normalCellCount / RedMycoInterval;

    private static int ComputeRockCount(int normalCellCount) => normalCellCount / RockInterval;

    private static int ComputeUniqueProducerResourceCount(int normalCellCount)
    {
        var duplicateProducerCount = normalCellCount / DuplicateProducerInterval;
        return Math.Min(MaxLetterResourceCount, Math.Max(1, normalCellCount - duplicateProducerCount));
    }

    private static IReadOnlyList<LevelCellDefinition> BuildPuzzleCells(
        int normalCellCount,
        IReadOnlyList<string> resources,
        Random random)
    {
        if (normalCellCount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(normalCellCount), "Puzzle levels need at least one normal cell.");
        }

        if (resources.Count == 0)
        {
            throw new ArgumentException("Puzzle levels need at least one resource.", nameof(resources));
        }

        var producerResources = BuildProducerResources(normalCellCount, resources, random);
        var normalCells = new List<LevelCellDefinition>(normalCellCount);
        var resourceInstanceCounts = new Dictionary<string, int>(StringComparer.Ordinal);
        for (var i = 0; i < producerResources.Count; i++)
        {
            var resource = producerResources[i];
            resourceInstanceCounts.TryGetValue(resource, out var instance);
            instance++;
            resourceInstanceCounts[resource] = instance;
            normalCells.Add(new LevelCellDefinition(
                $"cell-{resource.ToLowerInvariant()}-{instance:000}",
                CellKind.Standard,
                resource,
                Array.Empty<string>()));
        }

        var orderedCells = InsertRedMycoCells(normalCells, resources, random);
        var cellsWithNeeds = AssignGeneratedNeeds(orderedCells, resources, random);
        return cellsWithNeeds;
    }

    private static IReadOnlyList<string> BuildProducerResources(
        int normalCellCount,
        IReadOnlyList<string> resources,
        Random random)
    {
        var producerResources = new List<string>(normalCellCount);
        var uniqueProducerCount = Math.Min(resources.Count, normalCellCount);
        for (var i = 0; i < uniqueProducerCount; i++)
        {
            producerResources.Add(resources[i]);
        }

        while (producerResources.Count < normalCellCount)
        {
            producerResources.Add(resources[random.Next(resources.Count)]);
        }

        Shuffle(producerResources, random);
        return producerResources;
    }

    private static IReadOnlyList<LevelCellDefinition> InsertRedMycoCells(
        IReadOnlyList<LevelCellDefinition> normalCells,
        IReadOnlyList<string> resources,
        Random random)
    {
        var mycoCount = ComputeRedMycoCount(normalCells.Count);
        var cells = new List<LevelCellDefinition>(normalCells.Count + mycoCount);
        var nextNormal = 0;
        var nextMyco = 1;
        while (nextNormal < normalCells.Count)
        {
            var blockEnd = Math.Min(normalCells.Count, nextNormal + RedMycoInterval);
            for (; nextNormal < blockEnd; nextNormal++)
            {
                cells.Add(normalCells[nextNormal]);
            }

            if (nextMyco <= mycoCount)
            {
                cells.Add(new LevelCellDefinition(
                    $"red-myco-{nextMyco:000}",
                    CellKind.RedMyco,
                    "",
                    ChooseRandomNeeds(resources, "", MycoNeedCount, random)));
                nextMyco++;
            }
        }

        return cells;
    }

    private static IReadOnlyList<LevelCellDefinition> AssignGeneratedNeeds(
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyList<string> resources,
        Random random)
    {
        var result = cells.ToArray();
        for (var i = 0; i < result.Length; i++)
        {
            var cell = result[i];
            if (cell.Kind == CellKind.RedMyco)
            {
                var mycoNeeds = new List<string>(cell.Needs);
                AddNeighborOfferNeeds(mycoNeeds, cell, result, i, random);
                FillNeeds(mycoNeeds, resources, "", MycoNeedCount, random);
                result[i] = cell with { Needs = mycoNeeds.Take(MycoNeedCount).ToArray() };
                continue;
            }

            var needs = new List<string>(3);
            AddNeighborOfferNeeds(needs, cell, result, i, random);
            FillNeeds(needs, resources, cell.ProducedResource, 3, random);
            result[i] = cell with { Needs = needs.Take(3).ToArray() };
        }

        EnsureEveryResourceIsNeeded(result, resources, random);
        EnsureDuplicateProducerNeedsDiffer(result, resources, random);
        return result;
    }

    private static void AddNeighborOfferNeeds(
        List<string> needs,
        LevelCellDefinition cell,
        IReadOnlyList<LevelCellDefinition> cells,
        int index,
        Random random)
    {
        var offsets = new[] { -1, 1, -2, 2 };
        foreach (var offset in offsets)
        {
            if (needs.Count >= (cell.Kind == CellKind.RedMyco ? MycoNeedCount : 3))
            {
                return;
            }

            var neighbor = cells[WrapIndex(index + offset, cells.Count)];
            var offered = GetOfferResources(neighbor)
                .Where(resource => cell.Kind == CellKind.RedMyco || resource != cell.ProducedResource)
                .ToArray();
            if (offered.Length == 0)
            {
                continue;
            }

            Shuffle(offered, random);
            AddUniqueNeed(needs, offered[0]);
        }
    }

    private static int WrapIndex(int index, int count)
    {
        var wrapped = index % count;
        return wrapped < 0 ? wrapped + count : wrapped;
    }

    private static string[] ChooseRandomNeeds(
        IReadOnlyList<string> resources,
        string excludedResource,
        int count,
        Random random)
    {
        var needs = new List<string>(count);
        FillNeeds(needs, resources, excludedResource, count, random);
        return needs.ToArray();
    }

    private static void FillNeeds(
        List<string> needs,
        IReadOnlyList<string> resources,
        string excludedResource,
        int count,
        Random random)
    {
        var candidates = resources
            .Where(resource => !string.Equals(resource, excludedResource, StringComparison.Ordinal))
            .ToArray();
        Shuffle(candidates, random);
        foreach (var candidate in candidates)
        {
            AddUniqueNeed(needs, candidate);
            if (needs.Count >= count)
            {
                return;
            }
        }

        foreach (var resource in resources)
        {
            AddUniqueNeed(needs, resource);
            if (needs.Count >= count)
            {
                return;
            }
        }
    }

    private static void AddUniqueNeed(List<string> needs, string resource)
    {
        if (!string.IsNullOrEmpty(resource) && !needs.Contains(resource, StringComparer.Ordinal))
        {
            needs.Add(resource);
        }
    }

    private static void EnsureEveryResourceIsNeeded(
        LevelCellDefinition[] cells,
        IReadOnlyList<string> resources,
        Random random)
    {
        var needed = new HashSet<string>(cells.SelectMany(cell => cell.Needs), StringComparer.Ordinal);
        foreach (var resource in resources)
        {
            if (needed.Contains(resource))
            {
                continue;
            }

            var candidates = cells
                .Select((cell, index) => (Cell: cell, Index: index, TieBreak: random.Next()))
                .Where(item => item.Cell.Kind != CellKind.Standard
                    || !string.Equals(item.Cell.ProducedResource, resource, StringComparison.Ordinal))
                .OrderBy(item => item.TieBreak)
                .ToArray();
            foreach (var candidate in candidates)
            {
                var targetCount = candidate.Cell.Kind == CellKind.RedMyco ? MycoNeedCount : 3;
                var needs = candidate.Cell.Needs.ToList();
                if (needs.Contains(resource, StringComparer.Ordinal))
                {
                    needed.Add(resource);
                    break;
                }

                if (needs.Count < targetCount)
                {
                    needs.Add(resource);
                }
                else
                {
                    needs[^1] = resource;
                }

                cells[candidate.Index] = candidate.Cell with { Needs = needs.ToArray() };
                needed.Add(resource);
                break;
            }
        }
    }

    private static void EnsureDuplicateProducerNeedsDiffer(
        LevelCellDefinition[] cells,
        IReadOnlyList<string> resources,
        Random random)
    {
        var groups = cells
            .Select((cell, index) => (Cell: cell, Index: index))
            .Where(item => item.Cell.Kind == CellKind.Standard)
            .GroupBy(item => item.Cell.ProducedResource, StringComparer.Ordinal);
        foreach (var group in groups)
        {
            var seenNeeds = new HashSet<string>(StringComparer.Ordinal);
            foreach (var item in group)
            {
                var key = string.Join("|", item.Cell.Needs.OrderBy(resource => resource, StringComparer.Ordinal));
                if (seenNeeds.Add(key))
                {
                    continue;
                }

                var needs = item.Cell.Needs.ToList();
                var candidates = resources
                    .Where(resource => !string.Equals(resource, item.Cell.ProducedResource, StringComparison.Ordinal)
                        && !needs.Contains(resource, StringComparer.Ordinal))
                    .ToArray();
                if (candidates.Length == 0)
                {
                    continue;
                }

                Shuffle(candidates, random);
                needs[^1] = candidates[0];
                cells[item.Index] = item.Cell with { Needs = needs.ToArray() };
                seenNeeds.Add(string.Join("|", needs.OrderBy(resource => resource, StringComparer.Ordinal)));
            }
        }
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
        $"stableAtEnd={summary.StableAtEnd} won={summary.Won} finalSustained={summary.FinalSustainedTicks} "
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
        var rockCount = ComputeRockCount(cells.Count);
        var (width, height) = ComputeStartingLayoutDimensions(cells.Count + rockCount);
        var random = new Random(ComputeStartingLayoutSeed(options));
        var allPositions = BuildAllPositions(width, height);
        Shuffle(allPositions, random);
        var rocks = allPositions.Take(rockCount).ToArray();
        var rockSet = rocks.ToHashSet();
        var positions = allPositions
            .Where(position => !rockSet.Contains(position))
            .Take(cells.Count)
            .ToArray();
        if (positions.Length < cells.Count)
        {
            throw new InvalidOperationException("Generated starting layout does not have enough open positions.");
        }

        var cellOrder = cells.ToArray();
        Shuffle(cellOrder, random);

        var placements = new List<LevelCellPlacement>(cells.Count);
        for (var i = 0; i < cellOrder.Length; i++)
        {
            placements.Add(new LevelCellPlacement(cellOrder[i].Id, positions[i].X, positions[i].Y));
        }

        return new LevelLayout(width, height, placements, rocks, RenderAscii(width, height, cells, placements, rocks));
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
        var width = Math.Max(2, (int)Math.Ceiling(Math.Sqrt(cellCount)));
        var height = Math.Max(2, (int)Math.Ceiling((double)cellCount / width));
        return (width + 2, height + 2);
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

    private static List<GridPosition> BuildAllPositions(int width, int height)
    {
        var positions = new List<GridPosition>(width * height);
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                positions.Add(new GridPosition(x, y));
            }
        }

        return positions;
    }

    private static LevelLayout BuildCanonicalSolutionLayout(IReadOnlyList<LevelCellDefinition> cells)
    {
        var positions = BuildCompactSolutionPositions(cells.Count).ToArray();
        var width = positions.Max(position => position.X) + 1;
        var height = positions.Max(position => position.Y) + 1;
        var placements = cells
            .Select((cell, index) => new LevelCellPlacement(cell.Id, positions[index].X, positions[index].Y))
            .ToArray();
        return new LevelLayout(width, height, placements, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, placements, Array.Empty<GridPosition>()));
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
        var aNeedsB = a.Needs.Intersect(GetOfferResources(b), StringComparer.Ordinal).Any();
        var bNeedsA = b.Needs.Intersect(GetOfferResources(a), StringComparer.Ordinal).Any();
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
        return new LevelLayout(width, height, normalized, Array.Empty<GridPosition>(), RenderAscii(width, height, cells, normalized, Array.Empty<GridPosition>()));
    }

    private static (int Width, int Height) ComputeCompactDimensions(int cellCount)
    {
        var exact = FindExactCompactDimensions(cellCount);
        if (exact is not null)
        {
            return exact.Value;
        }

        var width = Math.Max(2, (int)Math.Ceiling(Math.Sqrt(cellCount)));
        var height = (int)Math.Ceiling((double)cellCount / width);
        return (width, height);
    }

    private static (int Width, int Height)? FindExactCompactDimensions(int cellCount)
    {
        (int Width, int Height)? best = null;
        var bestScore = int.MaxValue;
        for (var height = 2; height <= Math.Sqrt(cellCount); height++)
        {
            if (cellCount % height != 0)
            {
                continue;
            }

            var width = cellCount / height;
            var score = (width - height) * (width - height);
            if (width % 2 == 0 || height % 2 == 0)
            {
                score -= 1_000;
            }

            if (score < bestScore)
            {
                bestScore = score;
                best = (width, height);
            }
        }

        return best;
    }

    private static IEnumerable<GridPosition> BuildCompactSolutionPositions(int cellCount)
    {
        if (TryBuildOddCycleWithLeafPositions(cellCount, out var oddPositions))
        {
            return oddPositions;
        }

        var (width, height) = ComputeCompactDimensions(cellCount);
        if (width * height == cellCount && TryBuildHamiltonianCyclePositions(width, height, out var cyclePositions))
        {
            return cyclePositions;
        }

        return BuildSnakePositions(width, height).Take(cellCount);
    }

    private static bool TryBuildOddCycleWithLeafPositions(int cellCount, out GridPosition[] positions)
    {
        positions = [];
        if (cellCount <= 5 || cellCount % 2 == 0)
        {
            return false;
        }

        var cycleCellCount = cellCount - 1;
        var exactCycleDimensions = FindExactCompactDimensions(cycleCellCount);
        if (exactCycleDimensions is null)
        {
            return false;
        }

        var (cycleWidth, cycleHeight) = exactCycleDimensions.Value;
        if (!TryBuildHamiltonianCyclePositions(cycleWidth, cycleHeight, out var cyclePositions))
        {
            return false;
        }

        positions = new GridPosition[cellCount];
        positions[0] = new GridPosition(0, 0);
        for (var i = 0; i < cyclePositions.Length; i++)
        {
            positions[i + 1] = new GridPosition(cyclePositions[i].X, cyclePositions[i].Y + 1);
        }

        return true;
    }

    private static bool TryBuildHamiltonianCyclePositions(
        int width,
        int height,
        out GridPosition[] positions)
    {
        if (width <= 1 || height <= 1 || width % 2 != 0 && height % 2 != 0)
        {
            positions = [];
            return false;
        }

        if (height % 2 == 0)
        {
            positions = BuildEvenHeightCyclePositions(width, height).ToArray();
            return true;
        }

        positions = BuildEvenHeightCyclePositions(height, width)
            .Select(position => new GridPosition(position.Y, position.X))
            .ToArray();
        return true;
    }

    private static IEnumerable<GridPosition> BuildEvenHeightCyclePositions(int width, int height)
    {
        for (var x = 0; x < width; x++)
        {
            yield return new GridPosition(x, 0);
        }

        for (var y = 1; y < height; y++)
        {
            if (y % 2 == 1)
            {
                for (var x = width - 1; x >= 1; x--)
                {
                    yield return new GridPosition(x, y);
                }
            }
            else
            {
                for (var x = 1; x < width; x++)
                {
                    yield return new GridPosition(x, y);
                }
            }
        }

        for (var y = height - 1; y >= 1; y--)
        {
            yield return new GridPosition(0, y);
        }
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
                GlowTtlTicks = options.GlowTtlTicks,
                WinRecentFlowWindowTicks = options.WinRecentFlowWindowTicks,
                SwapRoundsPerTick = options.SwapRoundsPerTick,
                MaxSwapQuantityPerEdge = options.MaxSwapQuantityPerEdge,
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
                Y = placement.Y,
                Kind = cell.Kind == CellKind.Standard ? null : cell.Kind.ToString()
            };

            if (cell.Kind == CellKind.Standard)
            {
                cellDocument.Slots.Add(new LevelSlotDocument
                {
                    Resource = cell.ProducedResource,
                    Role = nameof(PoolSlotRole.SourceOutput),
                    Quantity = 0
                });
            }

            foreach (var need in cell.Needs)
            {
                cellDocument.Slots.Add(new LevelSlotDocument
                {
                    Resource = need,
                    Role = nameof(PoolSlotRole.Need),
                    Quantity = cell.Kind == CellKind.RedMyco ? MycoStartingQuantity : 0,
                    Capacity = cell.Kind == CellKind.RedMyco ? MycoCapacity : null
                });
            }

            if (cell.Kind == CellKind.Standard)
            {
                cellDocument.Sources.Add(new LevelSourceDocument
                {
                    Resource = cell.ProducedResource,
                    QuantityPerTick = options.SourceQuantityPerTick,
                    IntervalTicks = options.SourceIntervalTicks
                });
            }

            fixture.Cells.Add(cellDocument);
        }

        return JsonSerializer.Serialize(fixture, JsonOptions);
    }

    private static string RenderAscii(
        int width,
        int height,
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyList<LevelCellPlacement> placements,
        IReadOnlyList<GridPosition> rocks)
    {
        var symbolByCell = cells.ToDictionary(cell => cell.Id, GetSetupMapSymbol, StringComparer.Ordinal);
        var symbols = new Dictionary<GridPosition, char>();
        foreach (var rock in rocks)
        {
            symbols[rock] = '#';
        }

        foreach (var placement in placements)
        {
            symbols[new GridPosition(placement.X, placement.Y)] = symbolByCell[placement.CellId];
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
        if (count <= 0 || count > MaxLetterResourceCount)
        {
            throw new ArgumentOutOfRangeException(nameof(count), $"Puzzle resources must be between 1 and {MaxLetterResourceCount}.");
        }

        var resources = new List<string>(count);
        for (var i = 0; i < count; i++)
        {
            resources.Add(((char)('A' + i)).ToString());
        }

        return resources;
    }

    private static Dictionary<string, string[]> BuildBackboneGridNeeds(
        IReadOnlyList<string> order,
        IReadOnlyList<GridPosition> positions,
        Random random)
    {
        if (IsClosedOrthogonalCycle(positions))
        {
            return BuildCycleNeeds(order, positions, random);
        }

        for (var attempt = 0; attempt < 64; attempt++)
        {
            var incoming = order.ToDictionary(resource => resource, _ => 0, StringComparer.Ordinal);
            var needs = order.ToDictionary(resource => resource, _ => new List<string>(3), StringComparer.Ordinal);
            var positionByResource = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
            for (var i = 0; i < order.Count; i++)
            {
                positionByResource[order[i]] = positions[i];
            }

            for (var i = 0; i < order.Count; i++)
            {
                var source = order[i];
                if (i > 0)
                {
                    AddBalancedNeed(needs[source], incoming, source, order[i - 1]);
                }

                if (i + 1 < order.Count)
                {
                    AddBalancedNeed(needs[source], incoming, source, order[i + 1]);
                }
            }

            var filled = true;
            while (needs.Values.Any(resourceNeeds => resourceNeeds.Count < 3))
            {
                var progressed = false;
                var sources = order.Where(resource => needs[resource].Count < 3).ToArray();
                Shuffle(sources, random);
                foreach (var source in sources)
                {
                    var target = ChooseBalancedBackboneNeedTarget(
                        source,
                        order,
                        needs,
                        incoming,
                        positionByResource,
                        random);
                    if (target is null)
                    {
                        continue;
                    }

                    progressed |= AddBalancedNeed(needs[source], incoming, source, target);
                }

                if (!progressed)
                {
                    filled = false;
                    break;
                }
            }

            if (filled
                && needs.Values.All(resourceNeeds => resourceNeeds.Count == 3)
                && incoming.Values.All(count => count == 3))
            {
                return needs.ToDictionary(
                    pair => pair.Key,
                    pair =>
                    {
                        var values = pair.Value.ToArray();
                        Shuffle(values, random);
                        return values;
                    },
                    StringComparer.Ordinal);
            }
        }

        throw new InvalidOperationException("Could not build balanced local backbone needs.");
    }

    private static bool IsClosedOrthogonalCycle(IReadOnlyList<GridPosition> positions)
    {
        if (positions.Count <= 4)
        {
            return false;
        }

        for (var i = 0; i < positions.Count; i++)
        {
            var next = positions[(i + 1) % positions.Count];
            if (ManhattanDistance(positions[i], next) != 1)
            {
                return false;
            }
        }

        return true;
    }

    private static int ManhattanDistance(GridPosition left, GridPosition right) =>
        Math.Abs(left.X - right.X) + Math.Abs(left.Y - right.Y);

    private static Dictionary<string, string[]> BuildCycleNeeds(
        IReadOnlyList<string> order,
        IReadOnlyList<GridPosition> positions,
        Random random)
    {
        var needs = new Dictionary<string, string[]>(StringComparer.Ordinal);
        for (var i = 0; i < order.Count; i++)
        {
            var values = new[]
            {
                order[(i - 1 + order.Count) % order.Count],
                order[(i + 1) % order.Count],
                order[(i + 2) % order.Count]
            };
            Shuffle(values, random);
            needs[order[i]] = values;
        }

        return needs;
    }

    private static Dictionary<string, string[]> BuildOddCycleWithLeafNeeds(
        IReadOnlyList<string> order,
        Random random)
    {
        if (order.Count <= 5 || order.Count % 2 == 0)
        {
            throw new ArgumentException("Odd cycle-with-leaf needs require an odd cell count greater than five.", nameof(order));
        }

        var leaf = order[0];
        var cycle = order.Skip(1).ToArray();
        var needs = new Dictionary<string, string[]>(StringComparer.Ordinal);

        var leafNeeds = new[] { cycle[0], cycle[1], cycle[^1] };
        Shuffle(leafNeeds, random);
        needs[leaf] = leafNeeds;

        for (var i = 0; i < cycle.Length; i++)
        {
            var values = i == 0
                ? new[] { leaf, cycle[1], cycle[^1] }
                : new[]
                {
                    cycle[(i - 1 + cycle.Length) % cycle.Length],
                    cycle[(i + 1) % cycle.Length],
                    cycle[(i + 2) % cycle.Length]
                };
            Shuffle(values, random);
            needs[cycle[i]] = values;
        }

        return needs;
    }

    private static bool AddBalancedNeed(
        List<string> needs,
        Dictionary<string, int> incoming,
        string source,
        string target)
    {
        if (target == source
            || needs.Count >= 3
            || incoming[target] >= 3
            || needs.Contains(target, StringComparer.Ordinal))
        {
            return false;
        }

        needs.Add(target);
        incoming[target]++;
        return true;
    }

    private static void AddNeed(List<string> needs, string source, string target)
    {
        if (target == source || needs.Count >= 3 || needs.Contains(target, StringComparer.Ordinal))
        {
            return;
        }

        needs.Add(target);
    }

    private static string? ChooseBalancedBackboneNeedTarget(
        string source,
        IReadOnlyList<string> order,
        IReadOnlyDictionary<string, List<string>> needs,
        IReadOnlyDictionary<string, int> incoming,
        IReadOnlyDictionary<string, GridPosition> positionByResource,
        Random random)
    {
        var bestScore = int.MinValue;
        string? bestTarget = null;
        var sourcePosition = positionByResource[source];
        foreach (var target in order)
        {
            if (target == source
                || needs[source].Contains(target, StringComparer.Ordinal)
                || incoming[target] >= 3)
            {
                continue;
            }

            var targetPosition = positionByResource[target];
            var distance = Math.Abs(sourcePosition.X - targetPosition.X) + Math.Abs(sourcePosition.Y - targetPosition.Y);
            var score = -distance * 200;
            if (distance == 1)
            {
                score += 500;
            }
            else if (distance == 2)
            {
                score += 220;
            }

            if (needs[target].Contains(source, StringComparer.Ordinal))
            {
                score += 80;
            }

            score -= incoming[target] * 60;
            score += random.Next(40);
            if (score > bestScore)
            {
                bestScore = score;
                bestTarget = target;
            }
        }

        return bestTarget;
    }

    private static void FillNeedsFromCandidates(
        string source,
        List<string> needs,
        IEnumerable<string> candidates)
    {
        foreach (var candidate in candidates)
        {
            AddNeed(needs, source, candidate);
            if (needs.Count == 3)
            {
                return;
            }
        }
    }

    private static IEnumerable<string> GetOrthogonalResourceCandidates(
        GridPosition sourcePosition,
        IReadOnlyDictionary<GridPosition, string> resourceByPosition,
        Random random)
    {
        var candidates = new List<string>(4);
        foreach (var neighbor in EnumerateOrthogonalNeighbors(sourcePosition))
        {
            if (resourceByPosition.TryGetValue(neighbor, out var resource))
            {
                candidates.Add(resource);
            }
        }

        Shuffle(candidates, random);
        return candidates;
    }

    private static IEnumerable<string> GetDiagonalResourceCandidates(
        GridPosition sourcePosition,
        IReadOnlyDictionary<GridPosition, string> resourceByPosition,
        Random random)
    {
        var candidates = new List<string>(4);
        foreach (var diagonal in EnumerateDiagonalNeighbors(sourcePosition))
        {
            if (resourceByPosition.TryGetValue(diagonal, out var resource))
            {
                candidates.Add(resource);
            }
        }

        Shuffle(candidates, random);
        return candidates;
    }

    private static IEnumerable<GridPosition> EnumerateDiagonalNeighbors(GridPosition position)
    {
        yield return new GridPosition(position.X + 1, position.Y + 1);
        yield return new GridPosition(position.X - 1, position.Y + 1);
        yield return new GridPosition(position.X + 1, position.Y - 1);
        yield return new GridPosition(position.X - 1, position.Y - 1);
    }

    private static IEnumerable<string> GetNearestResourceCandidates(
        string source,
        GridPosition sourcePosition,
        IReadOnlyList<string> order,
        IReadOnlyDictionary<string, GridPosition> positionByResource,
        Random random)
    {
        return order
            .Where(target => target != source)
            .Select(target =>
            {
                var targetPosition = positionByResource[target];
                var distance = Math.Abs(sourcePosition.X - targetPosition.X)
                    + Math.Abs(sourcePosition.Y - targetPosition.Y);
                return (Target: target, Distance: distance, TieBreak: random.Next());
            })
            .OrderBy(item => item.Distance)
            .ThenBy(item => item.TieBreak)
            .Select(item => item.Target)
            .ToArray();
    }

    private static Dictionary<string, string[]> BuildBalancedGridNeeds(
        IReadOnlyList<string> order,
        IReadOnlyList<GridPosition> positions,
        Random random)
    {
        for (var attempt = 0; attempt < 64; attempt++)
        {
            var incoming = order.ToDictionary(resource => resource, _ => 0, StringComparer.Ordinal);
            var needs = order.ToDictionary(resource => resource, _ => new List<string>(3), StringComparer.Ordinal);
            var positionByResource = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
            for (var i = 0; i < order.Count; i++)
            {
                positionByResource[order[i]] = positions[i];
            }

            var filled = true;
            for (var round = 0; round < 3 && filled; round++)
            {
                var sources = order.ToArray();
                Shuffle(sources, random);
                foreach (var source in sources)
                {
                    var target = ChooseGridNeedTarget(source, order, needs, incoming, positionByResource, random);
                    if (target is null)
                    {
                        filled = false;
                        break;
                    }

                    needs[source].Add(target);
                    incoming[target]++;
                }
            }

            if (filled
                && needs.Values.All(resourceNeeds => resourceNeeds.Count == 3)
                && incoming.Values.All(count => count == 3))
            {
                return needs.ToDictionary(
                    pair => pair.Key,
                    pair =>
                    {
                        var values = pair.Value.ToArray();
                        Shuffle(values, random);
                        return values;
                    },
                    StringComparer.Ordinal);
            }
        }

        throw new InvalidOperationException("Could not build balanced grid-aware needs.");
    }

    private static string? ChooseGridNeedTarget(
        string source,
        IReadOnlyList<string> order,
        IReadOnlyDictionary<string, List<string>> needs,
        IReadOnlyDictionary<string, int> incoming,
        IReadOnlyDictionary<string, GridPosition> positionByResource,
        Random random)
    {
        var bestScore = int.MinValue;
        string? bestTarget = null;
        foreach (var target in order)
        {
            if (target == source
                || needs[source].Contains(target, StringComparer.Ordinal)
                || incoming[target] >= 3)
            {
                continue;
            }

            var sourcePosition = positionByResource[source];
            var targetPosition = positionByResource[target];
            var distance = Math.Abs(sourcePosition.X - targetPosition.X) + Math.Abs(sourcePosition.Y - targetPosition.Y);
            var score = -distance * 100;
            if (needs[target].Contains(source, StringComparer.Ordinal))
            {
                score += 90;
            }

            score -= incoming[target] * 20;
            score += random.Next(30);
            if (score > bestScore)
            {
                bestScore = score;
                bestTarget = target;
            }
        }

        return bestTarget;
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

    private static int CountAdjacentPairs(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout)
    {
        var count = 0;
        foreach (var _ in EnumerateAdjacentCellPairs(cells, layout))
        {
            count++;
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
        a.Needs.Intersect(GetOfferResources(b), StringComparer.Ordinal).Any()
        || b.Needs.Intersect(GetOfferResources(a), StringComparer.Ordinal).Any();

    private static bool CellsHaveReciprocalEdge(LevelCellDefinition a, LevelCellDefinition b) =>
        a.Needs.Intersect(GetOfferResources(b), StringComparer.Ordinal).Any()
        && b.Needs.Intersect(GetOfferResources(a), StringComparer.Ordinal).Any();

    private static string BuildDifficultyLabel(int levelNumber, int cellCount) =>
        $"Level {levelNumber}: {cellCount} cells, duplicate producers, red myco, rocks";

    private static IEnumerable<string> GetOfferResources(LevelCellDefinition cell)
    {
        if (cell.Kind == CellKind.Standard)
        {
            return string.IsNullOrEmpty(cell.ProducedResource)
                ? Array.Empty<string>()
                : new[] { cell.ProducedResource };
        }

        return cell.Needs;
    }

    private static char GetSetupMapSymbol(LevelCellDefinition cell) =>
        cell.Kind == CellKind.RedMyco
            ? '*'
            : string.IsNullOrEmpty(cell.ProducedResource) ? '?' : cell.ProducedResource[0];

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
        [JsonPropertyName("glowTtlTicks")]
        public int GlowTtlTicks { get; set; }

        [JsonPropertyName("winRecentFlowWindowTicks")]
        public int WinRecentFlowWindowTicks { get; set; }

        [JsonPropertyName("swapRoundsPerTick")]
        public int SwapRoundsPerTick { get; set; }

        [JsonPropertyName("maxSwapQuantityPerEdge")]
        public int MaxSwapQuantityPerEdge { get; set; }

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

        [JsonPropertyName("kind")]
        public string? Kind { get; set; }

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

        [JsonPropertyName("capacity")]
        public int? Capacity { get; set; }
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
