using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace CellularSim;

public sealed record ShapeFirstExactConstructionProof(
    bool StaticProofPassed,
    bool TargetShapeConnected,
    int TargetCellCount,
    int TargetEdgeCount,
    int ReciprocalEdgeCount,
    int UsefulEdgeCount,
    int MissingProviderCount,
    int InvalidNeedCount,
    int DuplicateProducerConflictCount,
    string FailureCategory,
    string Diagnostics);

public static class ShapeFirstExactPuzzleLevelGenerator
{
    private const int MaxLetterResourceCount = 26;
    private const int DuplicateProducerInterval = 6;
    private const int RedMycoInterval = 5;
    private const int RockInterval = 3;
    private const int NormalNeedCount = 3;
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
        Validate(options);

        var requiredSustainedTicks = GetRequiredSustainedTicks(options);
        var effectiveTicks = Math.Max(options.TicksPerCandidate, requiredSustainedTicks + options.WinRecentFlowWindowTicks + 40);
        SearchResult? best = null;
        var normalCellCount = ComputeNormalCellCount(options.LevelNumber);
        var redMycoCount = ComputeRedMycoCount(normalCellCount);
        var rockCount = ComputeRockCount(normalCellCount + redMycoCount);
        var resources = BuildResourceNames(ComputeUniqueProducerResourceCount(normalCellCount));
        var totalCells = normalCellCount + redMycoCount;
        var (width, height) = ComputeBoardDimensions(totalCells + rockCount);
        var targetPositions = BuildCompactConnectedPositions(width, height, totalCells);

        ReportProgress(options, $"shape-first start level={options.LevelNumber} normal={normalCellCount} redMyco={redMycoCount} rocks={rockCount} grid={width}x{height} ticks={effectiveTicks}");

        var attempts = Math.Max(1, options.LayoutCandidateLimit);
        for (var attempt = 0; attempt < attempts; attempt++)
        {
            var candidate = BuildCandidate(options, resources, targetPositions, width, height, rockCount, normalCellCount, redMycoCount, attempt);
            for (var repairPass = 0; repairPass < 4; repairPass++)
            {
                var proof = BuildStaticProof(candidate.Cells, candidate.SolutionLayout);
                var evaluation = Evaluate(candidate.SolutionFixtureJson, options, effectiveTicks, attempt + 1, repairPass, attempts);
                var result = new SearchResult(candidate, proof, evaluation.Summary);
                if (best is null || IsBetter(result, best))
                {
                    best = result;
                    ReportProgress(options, $"new best attempt={attempt + 1}/{attempts} repairPass={repairPass} static={proof.StaticProofPassed} {DescribeSummary(evaluation.Summary)}");
                }

                if (proof.StaticProofPassed && MeetsAcceptance(evaluation.Summary, options))
                {
                    ReportProgress(options, $"accepted exact solution attempt={attempt + 1}/{attempts} repairPass={repairPass} {DescribeSummary(evaluation.Summary)}");
                    return candidate.ToGeneratedLevel(options, evaluation.Summary);
                }

                var repaired = TryBuildStressRepairedCandidate(candidate, evaluation, options);
                if (repaired is null)
                {
                    break;
                }

                candidate = repaired;
            }
        }

        if (best is not null && options.AllowNearWin)
        {
            return best.Candidate.ToGeneratedLevel(options, best.Summary with { AcceptedNearWin = true });
        }

        var bestDescription = best is null
            ? "no candidate evaluated"
            : $"{best.Proof.FailureCategory}; {DescribeSummary(best.Summary)}";
        throw new InvalidOperationException($"No shape-first exact winning layout found for puzzle level {options.LevelNumber}: {bestDescription}");
    }

    public static ShapeFirstExactConstructionProof BuildConstructionProof(GeneratedPuzzleLevel level) =>
        BuildStaticProof(level.Definition.Cells, level.Definition.SolutionLayout);

    public static string RenderConstructionProof(GeneratedPuzzleLevel level)
    {
        var proof = BuildConstructionProof(level);
        var builder = new StringBuilder();
        builder.AppendLine("Shape-first exact construction proof");
        builder.AppendLine($"  static proof passed: {proof.StaticProofPassed}");
        builder.AppendLine($"  target shape connected: {proof.TargetShapeConnected}");
        builder.AppendLine($"  target cells: {proof.TargetCellCount}");
        builder.AppendLine($"  target edges: {proof.TargetEdgeCount}");
        builder.AppendLine($"  reciprocal edges: {proof.ReciprocalEdgeCount}");
        builder.AppendLine($"  useful edges: {proof.UsefulEdgeCount}");
        builder.AppendLine($"  missing providers: {proof.MissingProviderCount}");
        builder.AppendLine($"  invalid needs: {proof.InvalidNeedCount}");
        builder.AppendLine($"  duplicate producer conflicts: {proof.DuplicateProducerConflictCount}");
        builder.AppendLine($"  repair edits: {level.RepairEditCount}");
        builder.AppendLine($"  producer edits: {level.ProducerEditCount}");
        builder.AppendLine($"  failure category: {proof.FailureCategory}");
        builder.AppendLine("  diagnostics:");
        foreach (var line in proof.Diagnostics.Split('\n', StringSplitOptions.RemoveEmptyEntries))
        {
            builder.Append("    ").AppendLine(line);
        }

        return builder.ToString();
    }

    public static IReadOnlyList<LevelCellDefinition> GenerateCellDefinitionsForTests(PuzzleLevelOptions options)
    {
        Validate(options);
        var normalCellCount = ComputeNormalCellCount(options.LevelNumber);
        var redMycoCount = ComputeRedMycoCount(normalCellCount);
        var rockCount = ComputeRockCount(normalCellCount + redMycoCount);
        var resources = BuildResourceNames(ComputeUniqueProducerResourceCount(normalCellCount));
        var totalCells = normalCellCount + redMycoCount;
        var (width, height) = ComputeBoardDimensions(totalCells + rockCount);
        var targetPositions = BuildCompactConnectedPositions(width, height, totalCells);
        return BuildCandidate(options, resources, targetPositions, width, height, rockCount, normalCellCount, redMycoCount, 0).Cells;
    }

    public static ShapeFirstExactConstructionProof BuildConstructionProofForTests(PuzzleLevelOptions options)
    {
        Validate(options);
        var normalCellCount = ComputeNormalCellCount(options.LevelNumber);
        var redMycoCount = ComputeRedMycoCount(normalCellCount);
        var rockCount = ComputeRockCount(normalCellCount + redMycoCount);
        var resources = BuildResourceNames(ComputeUniqueProducerResourceCount(normalCellCount));
        var totalCells = normalCellCount + redMycoCount;
        var (width, height) = ComputeBoardDimensions(totalCells + rockCount);
        var targetPositions = BuildCompactConnectedPositions(width, height, totalCells);
        var candidate = BuildCandidate(options, resources, targetPositions, width, height, rockCount, normalCellCount, redMycoCount, 0);
        return BuildStaticProof(candidate.Cells, candidate.SolutionLayout);
    }

    public static ShapeFirstExactConstructionProof BuildConstructionProofForTests(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout) =>
        BuildStaticProof(cells, layout);

    private static Candidate BuildCandidate(
        PuzzleLevelOptions options,
        IReadOnlyList<string> resources,
        IReadOnlyList<GridPosition> targetPositions,
        int width,
        int height,
        int rockCount,
        int normalCellCount,
        int redMycoCount,
        int attempt)
    {
        var random = new Random(ComputeAttemptSeed(options, attempt));
        var redPositionSet = ChooseRedMycoPositions(targetPositions, redMycoCount, attempt);
        var redPositions = targetPositions.Where(redPositionSet.Contains).ToArray();
        var standardPositions = targetPositions.Where(position => !redPositionSet.Contains(position)).ToArray();
        var producerResources = BuildProducerResources(normalCellCount, resources, attempt);
        var standardCells = BuildStandardCells(producerResources);
        var redCells = BuildRedMycoCells(redMycoCount);

        var placements = new List<LevelCellPlacement>(normalCellCount + redMycoCount);
        var positionByCellId = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
        for (var i = 0; i < standardCells.Count; i++)
        {
            var position = standardPositions[i];
            placements.Add(new LevelCellPlacement(standardCells[i].Id, position.X, position.Y));
            positionByCellId[standardCells[i].Id] = position;
        }

        for (var i = 0; i < redCells.Count; i++)
        {
            var position = redPositions[i];
            placements.Add(new LevelCellPlacement(redCells[i].Id, position.X, position.Y));
            positionByCellId[redCells[i].Id] = position;
        }

        var cells = AssignNeeds(standardCells, redCells, positionByCellId, random);
        EnsureEveryResourceIsNeeded(cells, resources, positionByCellId);
        EnsureDuplicateProducerNeedsDiffer(cells, resources, positionByCellId);

        var rocks = ChooseRocks(width, height, rockCount, targetPositions, random);
        var solutionLayout = new LevelLayout(
            width,
            height,
            placements.OrderBy(placement => placement.Y).ThenBy(placement => placement.X).ThenBy(placement => placement.CellId, StringComparer.Ordinal).ToArray(),
            rocks,
            RenderAnnotatedAscii(width, height, cells, placements, rocks));
        var startingLayout = BuildStartingLayout(cells, solutionLayout, rocks, options, attempt);
        var levelJson = JsonSerializer.Serialize(new PuzzleLevelDefinition(
            options.LevelNumber,
            LevelMode.Puzzle,
            $"Level {options.LevelNumber}: shape-first exact, {normalCellCount} producers",
            options.GenerationSeed,
            resources.ToArray(),
            cells.ToArray(),
            startingLayout,
            solutionLayout,
            new PuzzleSolverSummary(false, false, attempt + 1, 0, 1, options.TicksPerCandidate, 0, 0, 0, 0, 0, 0, CountAdjacentPairs(cells, solutionLayout), options.WinDurationTicks, GetRequiredSustainedTicks(options), 0, false)),
            JsonOptions);
        var startingFixtureJson = BuildFixtureJson(resources, cells, startingLayout, options);
        var solutionFixtureJson = BuildFixtureJson(resources, cells, solutionLayout, options);
        var startingLoaded = FixtureLoader.LoadFromJson(startingFixtureJson);
        startingLoaded.Options.EventCapacity = options.EventCapacity;
        var solutionLoaded = FixtureLoader.LoadFromJson(solutionFixtureJson);
        solutionLoaded.Options.EventCapacity = options.EventCapacity;
        return new Candidate(
            resources,
            cells,
            startingLayout,
            solutionLayout,
            levelJson,
            startingFixtureJson,
            solutionFixtureJson,
            startingLoaded,
            solutionLoaded,
            attempt + 1,
            0,
            0);
    }

    private static List<LevelCellDefinition> AssignNeeds(
        IReadOnlyList<LevelCellDefinition> standardCells,
        IReadOnlyList<LevelCellDefinition> redCells,
        IReadOnlyDictionary<string, GridPosition> positionByCellId,
        Random random)
    {
        var allCells = standardCells.Concat(redCells).ToArray();
        var cellById = allCells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var idByPosition = positionByCellId.ToDictionary(pair => pair.Value, pair => pair.Key);
        var needsByCellId = allCells.ToDictionary(cell => cell.Id, _ => new List<string>(), StringComparer.Ordinal);

        foreach (var pair in EnumerateAdjacentStandardPairs(standardCells, positionByCellId))
        {
            AddNeed(needsByCellId[pair.A.Id], pair.A.ProducedResource, pair.B.ProducedResource, NormalNeedCount);
            AddNeed(needsByCellId[pair.B.Id], pair.B.ProducedResource, pair.A.ProducedResource, NormalNeedCount);
        }

        foreach (var cell in standardCells)
        {
            var position = positionByCellId[cell.Id];
            FillNeeds(
                needsByCellId[cell.Id],
                cell.ProducedResource,
                NormalNeedCount,
                EnumerateLocalProducedResources(position, idByPosition, cellById, maxDistance: 3, random));
        }

        foreach (var cell in redCells)
        {
            var position = positionByCellId[cell.Id];
            FillNeeds(
                needsByCellId[cell.Id],
                "",
                MycoNeedCount,
                EnumerateLocalProducedResources(position, idByPosition, cellById, maxDistance: 4, random));
        }

        return allCells.Select(cell => cell with { Needs = needsByCellId[cell.Id].ToArray() }).ToList();
    }

    private static void EnsureEveryResourceIsNeeded(
        IList<LevelCellDefinition> cells,
        IReadOnlyList<string> resources,
        IReadOnlyDictionary<string, GridPosition> positionByCellId)
    {
        var needed = cells.SelectMany(cell => cell.Needs).ToHashSet(StringComparer.Ordinal);
        foreach (var resource in resources)
        {
            if (needed.Contains(resource))
            {
                continue;
            }

            var provider = cells.FirstOrDefault(cell => string.Equals(cell.ProducedResource, resource, StringComparison.Ordinal));
            if (provider is null)
            {
                continue;
            }

            var providerPosition = positionByCellId[provider.Id];
            var target = cells
                .Where(cell => cell.Needs.Count == (cell.Kind == CellKind.RedMyco ? MycoNeedCount : NormalNeedCount)
                    && !string.Equals(cell.ProducedResource, resource, StringComparison.Ordinal)
                    && !cell.Needs.Contains(resource, StringComparer.Ordinal))
                .OrderBy(cell => ManhattanDistance(providerPosition, positionByCellId[cell.Id]))
                .ThenBy(cell => cell.Id, StringComparer.Ordinal)
                .FirstOrDefault();
            if (target is null)
            {
                continue;
            }

            ReplaceWeakestNeed(cells, target.Id, resource, positionByCellId);
            needed.Add(resource);
        }
    }

    private static void EnsureDuplicateProducerNeedsDiffer(
        IList<LevelCellDefinition> cells,
        IReadOnlyList<string> resources,
        IReadOnlyDictionary<string, GridPosition> positionByCellId)
    {
        foreach (var group in cells.Where(cell => cell.Kind == CellKind.Standard).GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal))
        {
            var seen = new HashSet<string>(StringComparer.Ordinal);
            foreach (var cell in group.OrderBy(cell => cell.Id, StringComparer.Ordinal))
            {
                var key = string.Join("|", cell.Needs.OrderBy(need => need, StringComparer.Ordinal));
                if (seen.Add(key))
                {
                    continue;
                }

                var replacement = resources
                    .Where(resource => !string.Equals(resource, cell.ProducedResource, StringComparison.Ordinal)
                        && !cell.Needs.Contains(resource, StringComparer.Ordinal))
                    .OrderBy(resource => NearestProducerDistance(resource, positionByCellId[cell.Id], cells, positionByCellId))
                    .ThenBy(resource => resource, StringComparer.Ordinal)
                    .FirstOrDefault();
                if (replacement is not null)
                {
                    ReplaceWeakestNeed(cells, cell.Id, replacement, positionByCellId);
                    seen.Add(string.Join("|", cell.Needs.OrderBy(need => need, StringComparer.Ordinal)));
                }
            }
        }
    }

    private static void ReplaceWeakestNeed(
        IList<LevelCellDefinition> cells,
        string cellId,
        string replacement,
        IReadOnlyDictionary<string, GridPosition> positionByCellId)
    {
        for (var i = 0; i < cells.Count; i++)
        {
            if (!string.Equals(cells[i].Id, cellId, StringComparison.Ordinal))
            {
                continue;
            }

            var cell = cells[i];
            if (string.Equals(cell.ProducedResource, replacement, StringComparison.Ordinal)
                || cell.Needs.Contains(replacement, StringComparer.Ordinal))
            {
                return;
            }

            var position = positionByCellId[cell.Id];
            var replaceIndex = cell.Needs
                .Select((need, index) => (Need: need, Index: index, Distance: NearestProducerDistance(need, position, cells, positionByCellId)))
                .OrderByDescending(item => item.Distance)
                .ThenByDescending(item => item.Index)
                .First().Index;
            var needs = cell.Needs.ToArray();
            needs[replaceIndex] = replacement;
            cells[i] = cell with { Needs = needs };
            return;
        }
    }

    private static ShapeFirstExactConstructionProof BuildStaticProof(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout layout)
    {
        var builder = new StringBuilder();
        var placements = layout.Cells.ToDictionary(placement => placement.CellId, placement => new GridPosition(placement.X, placement.Y), StringComparer.Ordinal);
        var targetConnected = IsConnected(layout.Cells.Select(placement => new GridPosition(placement.X, placement.Y)).ToHashSet());
        var targetEdges = CountAdjacentPairs(cells, layout);
        var reciprocalEdges = CountReciprocalAdjacentPairs(cells, layout);
        var usefulEdges = CountUsefulAdjacentPairs(cells, layout);
        var missingProviders = 0;
        var invalidNeeds = 0;

        foreach (var cell in cells)
        {
            var expected = cell.Kind == CellKind.RedMyco ? MycoNeedCount : NormalNeedCount;
            if (cell.Needs.Count != expected || cell.Needs.Distinct(StringComparer.Ordinal).Count() != cell.Needs.Count)
            {
                invalidNeeds++;
                builder.AppendLine($"{cell.Id}: invalid need count or duplicate needs");
            }

            if (cell.Kind == CellKind.Standard && cell.Needs.Contains(cell.ProducedResource, StringComparer.Ordinal))
            {
                invalidNeeds++;
                builder.AppendLine($"{cell.Id}: self need {cell.ProducedResource}");
            }

            foreach (var need in cell.Needs)
            {
                var localProvider = cells.Any(provider => provider.Kind == CellKind.Standard
                    && string.Equals(provider.ProducedResource, need, StringComparison.Ordinal)
                    && placements.TryGetValue(provider.Id, out var providerPosition)
                    && placements.TryGetValue(cell.Id, out var cellPosition)
                    && ManhattanDistance(providerPosition, cellPosition) <= 3);
                if (!localProvider)
                {
                    missingProviders++;
                    builder.AppendLine($"{cell.Id}: need {need} has no provider within distance 3");
                }
            }
        }

        var duplicateConflicts = cells
            .Where(cell => cell.Kind == CellKind.Standard)
            .GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal)
            .Sum(group => Math.Max(0, group.Count() - group.Select(cell => string.Join("|", cell.Needs.OrderBy(need => need, StringComparer.Ordinal))).Distinct(StringComparer.Ordinal).Count()));

        var passed = targetConnected && invalidNeeds == 0 && missingProviders == 0 && duplicateConflicts == 0 && usefulEdges >= cells.Count - 1;
        var category = passed
            ? "passed"
            : !targetConnected
                ? "disconnected target shape"
                : invalidNeeds > 0
                    ? "invalid needs"
                    : missingProviders > 0
                        ? "missing local providers"
                        : duplicateConflicts > 0
                            ? "duplicate producer deadlock"
                            : "insufficient useful graph";
        if (builder.Length == 0)
        {
            builder.AppendLine("all static checks passed");
        }

        return new ShapeFirstExactConstructionProof(
            passed,
            targetConnected,
            cells.Count,
            targetEdges,
            reciprocalEdges,
            usefulEdges,
            missingProviders,
            invalidNeeds,
            duplicateConflicts,
            category,
            builder.ToString().TrimEnd());
    }

    private static EvaluationResult Evaluate(
        string fixtureJson,
        PuzzleLevelOptions options,
        int ticks,
        int needAttempt,
        int candidateIndex,
        int candidateCount)
    {
        var loaded = FixtureLoader.LoadFromJson(fixtureJson);
        loaded.Options.EventCapacity = options.EventCapacity;
        var engine = new CellularEngine(loaded.World, loaded.Options);
        var summary = SimulationSummaryRunner.Run(engine, ticks);
        var requiredSustainedTicks = GetRequiredSustainedTicks(options);
        var finalSustainedTicks = engine.Circuit.SustainedTicks;
        var stableAtEnd = engine.Circuit.IsWon
            && engine.Circuit.IsAliveThisTick
            && finalSustainedTicks >= requiredSustainedTicks;
        var solverSummary = new PuzzleSolverSummary(
            engine.Circuit.IsWon,
            false,
            needAttempt,
            candidateIndex,
            candidateCount,
            ticks,
            summary.GlowingCells,
            summary.TotalSwaps,
            summary.TotalReactions,
            summary.ActiveCellsInLastWindow,
            summary.StrainPenalty,
            summary.FinalScore,
            summary.AdjacentPairs,
            options.WinDurationTicks,
            requiredSustainedTicks,
            finalSustainedTicks,
            stableAtEnd);
        return new EvaluationResult(solverSummary, BuildStressSignals(loaded));
    }

    private static IReadOnlyList<StressSignal> BuildStressSignals(FixtureLoadResult loaded)
    {
        var signals = new List<StressSignal>();
        foreach (var cell in loaded.World.Cells)
        {
            foreach (var slot in cell.Pool.Slots)
            {
                if (slot.Role != PoolSlotRole.Need)
                {
                    continue;
                }

                var resource = loaded.Catalog.GetName(slot.Resource);
                if (slot.Quantity == 0)
                {
                    signals.Add(new StressSignal(cell.Id, resource, slot.Quantity, cell.Strain.Total, cell.IsGlowing));
                }
            }
        }

        return signals
            .OrderBy(signal => signal.IsGlowing)
            .ThenByDescending(signal => signal.Strain)
            .ThenBy(signal => signal.CellId, StringComparer.Ordinal)
            .ThenBy(signal => signal.Resource, StringComparer.Ordinal)
            .ToArray();
    }

    private static Candidate? TryBuildStressRepairedCandidate(
        Candidate candidate,
        EvaluationResult evaluation,
        PuzzleLevelOptions options)
    {
        if (evaluation.Summary.Won || evaluation.StressSignals.Count == 0)
        {
            return null;
        }

        var cells = candidate.Cells.ToList();
        var positionByCellId = candidate.SolutionLayout.Cells.ToDictionary(
            placement => placement.CellId,
            placement => new GridPosition(placement.X, placement.Y),
            StringComparer.Ordinal);
        var repairs = 0;
        var maxRepairs = Math.Max(2, Math.Min(10, cells.Count / 3));

        foreach (var signal in evaluation.StressSignals)
        {
            if (repairs >= maxRepairs)
            {
                break;
            }

            var replacement = BuildStressRepairCandidates(cells, positionByCellId, signal)
                .FirstOrDefault(resource => TryReplaceSpecificNeed(cells, signal.CellId, signal.Resource, resource));
            if (replacement is not null)
            {
                repairs++;
            }
        }

        var producerEdits = TryRepairDuplicateProducerBottlenecks(cells, positionByCellId, maxEdits: 2);
        if (repairs == 0 && producerEdits == 0)
        {
            return null;
        }

        EnsureDuplicateProducerNeedsDiffer(cells, candidate.Resources, positionByCellId);
        return RebuildCandidate(candidate, cells, options, repairs, producerEdits);
    }

    private static IEnumerable<string> BuildStressRepairCandidates(
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyDictionary<string, GridPosition> positionByCellId,
        StressSignal signal)
    {
        var cell = cells.FirstOrDefault(candidate => string.Equals(candidate.Id, signal.CellId, StringComparison.Ordinal));
        if (cell is null || !positionByCellId.TryGetValue(cell.Id, out var position))
        {
            yield break;
        }

        var yielded = new HashSet<string>(StringComparer.Ordinal);
        foreach (var neighbor in cells
            .Where(candidate => positionByCellId.TryGetValue(candidate.Id, out var neighborPosition)
                && ManhattanDistance(position, neighborPosition) == 1)
            .OrderBy(candidate => candidate.Id, StringComparer.Ordinal))
        {
            if (neighbor.Kind == CellKind.Standard
                && IsValidReplacementNeed(cell, neighbor.ProducedResource)
                && yielded.Add(neighbor.ProducedResource))
            {
                yield return neighbor.ProducedResource;
            }
        }

        foreach (var neighbor in cells
            .Where(candidate => positionByCellId.TryGetValue(candidate.Id, out var neighborPosition)
                && ManhattanDistance(position, neighborPosition) == 1)
            .OrderBy(candidate => candidate.Id, StringComparer.Ordinal))
        {
            foreach (var need in neighbor.Needs)
            {
                if (IsValidReplacementNeed(cell, need) && yielded.Add(need))
                {
                    yield return need;
                }
            }
        }

        foreach (var provider in cells
            .Where(candidate => candidate.Kind == CellKind.Standard
                && positionByCellId.TryGetValue(candidate.Id, out var providerPosition)
                && ManhattanDistance(position, providerPosition) <= 2)
            .OrderBy(candidate => ManhattanDistance(position, positionByCellId[candidate.Id]))
            .ThenBy(candidate => candidate.Id, StringComparer.Ordinal))
        {
            if (IsValidReplacementNeed(cell, provider.ProducedResource) && yielded.Add(provider.ProducedResource))
            {
                yield return provider.ProducedResource;
            }
        }
    }

    private static bool TryReplaceSpecificNeed(
        IList<LevelCellDefinition> cells,
        string cellId,
        string oldNeed,
        string newNeed)
    {
        for (var i = 0; i < cells.Count; i++)
        {
            var cell = cells[i];
            if (!string.Equals(cell.Id, cellId, StringComparison.Ordinal)
                || !cell.Needs.Contains(oldNeed, StringComparer.Ordinal)
                || !IsValidReplacementNeed(cell, newNeed))
            {
                continue;
            }

            var needs = cell.Needs.ToArray();
            for (var j = 0; j < needs.Length; j++)
            {
                if (string.Equals(needs[j], oldNeed, StringComparison.Ordinal))
                {
                    needs[j] = newNeed;
                    cells[i] = cell with { Needs = needs };
                    return true;
                }
            }
        }

        return false;
    }

    private static int TryRepairDuplicateProducerBottlenecks(
        IList<LevelCellDefinition> cells,
        IReadOnlyDictionary<string, GridPosition> positionByCellId,
        int maxEdits)
    {
        var edits = 0;
        var duplicateResources = cells
            .Where(cell => cell.Kind == CellKind.Standard)
            .GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal)
            .Where(group => group.Count() > 1)
            .Select(group => group.Key)
            .ToHashSet(StringComparer.Ordinal);
        if (duplicateResources.Count == 0)
        {
            return 0;
        }

        for (var i = 0; i < cells.Count && edits < maxEdits; i++)
        {
            var cell = cells[i];
            if (cell.Kind != CellKind.Standard
                || !duplicateResources.Contains(cell.ProducedResource)
                || !positionByCellId.TryGetValue(cell.Id, out var position))
            {
                continue;
            }

            var adjacentNeeds = cells
                .Where(other => !string.Equals(other.Id, cell.Id, StringComparison.Ordinal)
                    && positionByCellId.TryGetValue(other.Id, out var otherPosition)
                    && ManhattanDistance(position, otherPosition) == 1)
                .SelectMany(other => other.Needs)
                .Where(resource => !cell.Needs.Contains(resource, StringComparer.Ordinal)
                    && !string.Equals(resource, cell.ProducedResource, StringComparison.Ordinal))
                .GroupBy(resource => resource, StringComparer.Ordinal)
                .OrderByDescending(group => group.Count())
                .ThenBy(group => group.Key, StringComparer.Ordinal)
                .Select(group => group.Key)
                .FirstOrDefault();
            if (adjacentNeeds is null)
            {
                continue;
            }

            cells[i] = cell with { ProducedResource = adjacentNeeds };
            edits++;
        }

        return edits;
    }

    private static bool IsValidReplacementNeed(LevelCellDefinition cell, string resource) =>
        !string.IsNullOrWhiteSpace(resource)
        && !cell.Needs.Contains(resource, StringComparer.Ordinal)
        && (cell.Kind != CellKind.Standard || !string.Equals(cell.ProducedResource, resource, StringComparison.Ordinal));

    private static Candidate RebuildCandidate(
        Candidate candidate,
        IReadOnlyList<LevelCellDefinition> cells,
        PuzzleLevelOptions options,
        int repairEdits,
        int producerEdits)
    {
        var solutionLayout = candidate.SolutionLayout with
        {
            Ascii = RenderAnnotatedAscii(
                candidate.SolutionLayout.Width,
                candidate.SolutionLayout.Height,
                cells,
                candidate.SolutionLayout.Cells,
                candidate.SolutionLayout.Rocks)
        };
        var startingLayout = candidate.StartingLayout with
        {
            Ascii = RenderAnnotatedAscii(
                candidate.StartingLayout.Width,
                candidate.StartingLayout.Height,
                cells,
                candidate.StartingLayout.Cells,
                candidate.StartingLayout.Rocks)
        };
        var startingFixtureJson = BuildFixtureJson(candidate.Resources, cells, startingLayout, options);
        var solutionFixtureJson = BuildFixtureJson(candidate.Resources, cells, solutionLayout, options);
        var startingLoaded = FixtureLoader.LoadFromJson(startingFixtureJson);
        startingLoaded.Options.EventCapacity = options.EventCapacity;
        var solutionLoaded = FixtureLoader.LoadFromJson(solutionFixtureJson);
        solutionLoaded.Options.EventCapacity = options.EventCapacity;
        return new Candidate(
            candidate.Resources,
            cells.ToArray(),
            startingLayout,
            solutionLayout,
            candidate.LevelJson,
            startingFixtureJson,
            solutionFixtureJson,
            startingLoaded,
            solutionLoaded,
            candidate.Attempt,
            candidate.RepairEditCount + repairEdits,
            candidate.ProducerEditCount + producerEdits);
    }

    private static bool MeetsAcceptance(PuzzleSolverSummary summary, PuzzleLevelOptions options) =>
        options.ShapeFirstSustainedTicks > 0
            ? summary.Won && summary.StableAtEnd && summary.FinalSustainedTicks >= GetRequiredSustainedTicks(options)
            : summary.Won;

    private static int GetRequiredSustainedTicks(PuzzleLevelOptions options) =>
        options.ShapeFirstSustainedTicks > 0 ? options.ShapeFirstSustainedTicks : options.WinDurationTicks;

    private static bool IsBetter(SearchResult candidate, SearchResult best)
    {
        static long Rank(SearchResult result)
        {
            var summary = result.Summary;
            var proof = result.Proof;
            var rank = proof.StaticProofPassed ? 1_000_000_000_000L : 0;
            rank += summary.Won ? 500_000_000_000L : 0;
            rank += summary.FinalSustainedTicks * 2_000_000_000L;
            rank += summary.GlowingCells * 80_000_000L;
            rank += summary.ActiveCellsInLastWindow * 60_000_000L;
            rank += proof.ReciprocalEdgeCount * 4_000_000L;
            rank += proof.UsefulEdgeCount * 1_000_000L;
            rank += summary.TotalReactions * 20_000L;
            rank += summary.TotalSwaps;
            rank -= proof.MissingProviderCount * 100_000_000L;
            rank -= proof.DuplicateProducerConflictCount * 50_000_000L;
            rank -= summary.StrainPenalty;
            return rank;
        }

        return Rank(candidate) > Rank(best);
    }

    private static void Validate(PuzzleLevelOptions options)
    {
        if (options.LevelNumber <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Level number must be positive.");
        }

        if (options.NeedAttemptLimit <= 0 || options.LayoutCandidateLimit <= 0 || options.TicksPerCandidate <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Attempt, candidate, and tick counts must be positive.");
        }

        if (options.SourceQuantityPerTick <= 0 || options.SourceIntervalTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Source quantity and interval must be positive.");
        }

        if (options.ShapeFirstSustainedTicks < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Shape-first sustained ticks cannot be negative.");
        }
    }

    private static int ComputeNormalCellCount(int levelNumber) => levelNumber + 3;

    private static int ComputeRedMycoCount(int normalCellCount) => normalCellCount / RedMycoInterval;

    private static int ComputeRockCount(int normalCellCount) => normalCellCount / RockInterval;

    private static int ComputeUniqueProducerResourceCount(int normalCellCount)
    {
        var duplicateProducerCount = normalCellCount / DuplicateProducerInterval;
        return Math.Min(MaxLetterResourceCount, Math.Max(1, normalCellCount - duplicateProducerCount));
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

    private static IReadOnlyList<string> BuildProducerResources(
        int normalCellCount,
        IReadOnlyList<string> resources,
        int attempt)
    {
        var producerResources = new List<string>(normalCellCount);
        var uniqueProducerCount = Math.Min(resources.Count, normalCellCount);
        for (var i = 0; i < uniqueProducerCount; i++)
        {
            producerResources.Add(resources[i]);
        }

        var next = attempt;
        while (producerResources.Count < normalCellCount)
        {
            producerResources.Add(resources[next % resources.Count]);
            next += DuplicateProducerInterval - 1;
        }

        var rotated = producerResources
            .Select((resource, index) => (Resource: resource, Key: RotateTie(index, attempt)))
            .OrderBy(item => item.Key)
            .ThenBy(item => item.Resource, StringComparer.Ordinal)
            .Select(item => item.Resource)
            .ToArray();
        return rotated;
    }

    private static IReadOnlyList<LevelCellDefinition> BuildStandardCells(IReadOnlyList<string> producerResources)
    {
        var counts = new Dictionary<string, int>(StringComparer.Ordinal);
        var cells = new List<LevelCellDefinition>(producerResources.Count);
        foreach (var resource in producerResources)
        {
            counts.TryGetValue(resource, out var count);
            count++;
            counts[resource] = count;
            cells.Add(new LevelCellDefinition($"cell-{resource.ToLowerInvariant()}-{count:000}", CellKind.Standard, resource, Array.Empty<string>()));
        }

        return cells;
    }

    private static IReadOnlyList<LevelCellDefinition> BuildRedMycoCells(int count)
    {
        var cells = new List<LevelCellDefinition>(count);
        for (var i = 1; i <= count; i++)
        {
            cells.Add(new LevelCellDefinition($"red-myco-{i:000}", CellKind.RedMyco, "", Array.Empty<string>()));
        }

        return cells;
    }

    private static (int Width, int Height) ComputeBoardDimensions(int occupiedCount)
    {
        var width = Math.Max(2, (int)Math.Ceiling(Math.Sqrt(occupiedCount)));
        var height = Math.Max(2, (int)Math.Ceiling((double)occupiedCount / width));
        return (width + 2, height + 2);
    }

    private static IReadOnlyList<GridPosition> BuildCompactConnectedPositions(int width, int height, int count)
    {
        var center = new GridPosition(width / 2, height / 2);
        var selected = new HashSet<GridPosition> { center };
        var ordered = new List<GridPosition> { center };
        while (ordered.Count < count)
        {
            var next = selected
                .SelectMany(EnumerateOrthogonalNeighbors)
                .Where(position => position.X >= 0 && position.X < width && position.Y >= 0 && position.Y < height && !selected.Contains(position))
                .Distinct()
                .OrderBy(position => TileCenterDistanceScore(position, width, height))
                .ThenByDescending(position => TileDegree(position, width, height))
                .ThenBy(position => position.Y)
                .ThenBy(position => position.X)
                .FirstOrDefault();
            if (selected.Contains(next))
            {
                throw new InvalidOperationException("Could not build compact connected target shape.");
            }

            selected.Add(next);
            ordered.Add(next);
        }

        return ordered;
    }

    private static IReadOnlySet<GridPosition> ChooseRedMycoPositions(
        IReadOnlyList<GridPosition> targetPositions,
        int redMycoCount,
        int attempt)
    {
        var selected = new HashSet<GridPosition>();
        if (redMycoCount == 0)
        {
            return selected;
        }

        var targetSet = targetPositions.ToHashSet();
        var spacing = Math.Max(1, targetPositions.Count / redMycoCount);
        for (var i = 0; i < redMycoCount; i++)
        {
            var desired = (attempt * 3 + i * spacing) % targetPositions.Count;
            var chosen = targetPositions
                .Select((position, index) => (Position: position, Distance: CircularDistance(index, desired, targetPositions.Count)))
                .Where(item => !selected.Contains(item.Position))
                .OrderBy(item => item.Distance)
                .ThenByDescending(item => EnumerateOrthogonalNeighbors(item.Position).Count(targetSet.Contains))
                .ThenBy(item => item.Position.Y)
                .ThenBy(item => item.Position.X)
                .First().Position;
            selected.Add(chosen);
        }

        return selected;
    }

    private static IReadOnlyList<GridPosition> ChooseRocks(
        int width,
        int height,
        int rockCount,
        IReadOnlyList<GridPosition> targetPositions,
        Random random)
    {
        var target = targetPositions.ToHashSet();
        var candidates = new List<GridPosition>();
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                var position = new GridPosition(x, y);
                if (!target.Contains(position))
                {
                    candidates.Add(position);
                }
            }
        }

        Shuffle(candidates, random);
        return candidates.Take(rockCount).ToArray();
    }

    private static LevelLayout BuildStartingLayout(
        IReadOnlyList<LevelCellDefinition> cells,
        LevelLayout solutionLayout,
        IReadOnlyList<GridPosition> rocks,
        PuzzleLevelOptions options,
        int attempt)
    {
        var random = new Random(ComputeAttemptSeed(options, attempt) ^ 0x51A7);
        var rockSet = rocks.ToHashSet();
        var open = new List<GridPosition>();
        for (var y = 0; y < solutionLayout.Height; y++)
        {
            for (var x = 0; x < solutionLayout.Width; x++)
            {
                var position = new GridPosition(x, y);
                if (!rockSet.Contains(position))
                {
                    open.Add(position);
                }
            }
        }

        Shuffle(open, random);
        var shuffledCells = cells.ToArray();
        Shuffle(shuffledCells, random);
        var placements = shuffledCells
            .Select((cell, index) => new LevelCellPlacement(cell.Id, open[index].X, open[index].Y))
            .ToArray();
        return new LevelLayout(
            solutionLayout.Width,
            solutionLayout.Height,
            placements,
            rocks,
            RenderAnnotatedAscii(solutionLayout.Width, solutionLayout.Height, cells, placements, rocks));
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

    private static string RenderAnnotatedAscii(
        int width,
        int height,
        IReadOnlyList<LevelCellDefinition> cells,
        IReadOnlyList<LevelCellPlacement> placements,
        IReadOnlyList<GridPosition> rocks)
    {
        var labels = BuildCellLabels(cells);
        var tokenByPosition = new Dictionary<GridPosition, string>();
        foreach (var rock in rocks)
        {
            tokenByPosition[rock] = "##";
        }

        foreach (var placement in placements)
        {
            tokenByPosition[new GridPosition(placement.X, placement.Y)] = labels[placement.CellId];
        }

        var builder = new StringBuilder();
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                if (x > 0)
                {
                    builder.Append(' ');
                }

                builder.Append(tokenByPosition.TryGetValue(new GridPosition(x, y), out var token) ? token : "..");
            }

            builder.AppendLine();
        }

        builder.AppendLine();
        builder.AppendLine("Legend:");
        foreach (var cell in cells.OrderBy(cell => labels[cell.Id], StringComparer.Ordinal))
        {
            var label = labels[cell.Id];
            if (cell.Kind == CellKind.RedMyco)
            {
                builder.Append(label).Append(": ").Append(cell.Id).Append("; red-myco; needs ").AppendLine(string.Join(",", cell.Needs));
            }
            else
            {
                builder.Append(label).Append(": ").Append(cell.Id).Append("; produces ").Append(cell.ProducedResource).Append("; needs ").AppendLine(string.Join(",", cell.Needs));
            }
        }

        return builder.ToString().TrimEnd();
    }

    private static IReadOnlyDictionary<string, string> BuildCellLabels(IReadOnlyList<LevelCellDefinition> cells)
    {
        const string suffixes = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0";
        var labels = new Dictionary<string, string>(StringComparer.Ordinal);
        var counts = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var cell in cells)
        {
            var prefix = cell.Kind == CellKind.RedMyco ? "*" : cell.ProducedResource;
            counts.TryGetValue(prefix, out var count);
            count++;
            counts[prefix] = count;
            var suffix = count <= suffixes.Length ? suffixes[count - 1] : '?';
            labels[cell.Id] = $"{prefix}{suffix}";
        }

        return labels;
    }

    private static IEnumerable<(LevelCellDefinition A, LevelCellDefinition B)> EnumerateAdjacentStandardPairs(
        IReadOnlyList<LevelCellDefinition> standardCells,
        IReadOnlyDictionary<string, GridPosition> positionByCellId)
    {
        for (var i = 0; i < standardCells.Count; i++)
        {
            for (var j = i + 1; j < standardCells.Count; j++)
            {
                if (ManhattanDistance(positionByCellId[standardCells[i].Id], positionByCellId[standardCells[j].Id]) == 1)
                {
                    yield return (standardCells[i], standardCells[j]);
                }
            }
        }
    }

    private static IEnumerable<string> EnumerateLocalProducedResources(
        GridPosition source,
        IReadOnlyDictionary<GridPosition, string> idByPosition,
        IReadOnlyDictionary<string, LevelCellDefinition> cellById,
        int maxDistance,
        Random random)
    {
        return idByPosition
            .Select(pair => (pair.Value, Cell: cellById[pair.Value], Distance: ManhattanDistance(source, pair.Key), Tie: random.Next()))
            .Where(item => item.Distance > 0 && item.Distance <= maxDistance && item.Cell.Kind == CellKind.Standard)
            .OrderBy(item => item.Distance)
            .ThenBy(item => item.Tie)
            .Select(item => item.Cell.ProducedResource)
            .Where(resource => !string.IsNullOrEmpty(resource))
            .ToArray();
    }

    private static void FillNeeds(
        List<string> needs,
        string producedResource,
        int count,
        IEnumerable<string> candidates)
    {
        foreach (var candidate in candidates)
        {
            AddNeed(needs, producedResource, candidate, count);
            if (needs.Count == count)
            {
                return;
            }
        }

        throw new InvalidOperationException($"Could not fill {count} distinct local needs for producer '{producedResource}'.");
    }

    private static void AddNeed(List<string> needs, string producedResource, string target, int count)
    {
        if (needs.Count >= count
            || string.IsNullOrEmpty(target)
            || string.Equals(producedResource, target, StringComparison.Ordinal)
            || needs.Contains(target, StringComparer.Ordinal))
        {
            return;
        }

        needs.Add(target);
    }

    private static int NearestProducerDistance(
        string resource,
        GridPosition position,
        IEnumerable<LevelCellDefinition> cells,
        IReadOnlyDictionary<string, GridPosition> positionByCellId)
    {
        var best = int.MaxValue;
        foreach (var cell in cells)
        {
            if (cell.Kind != CellKind.Standard || !string.Equals(cell.ProducedResource, resource, StringComparison.Ordinal))
            {
                continue;
            }

            best = Math.Min(best, ManhattanDistance(position, positionByCellId[cell.Id]));
        }

        return best == int.MaxValue ? 999 : best;
    }

    private static bool IsConnected(IReadOnlySet<GridPosition> positions)
    {
        if (positions.Count == 0)
        {
            return true;
        }

        var seen = new HashSet<GridPosition>();
        var stack = new Stack<GridPosition>();
        stack.Push(positions.First());
        while (stack.Count > 0)
        {
            var current = stack.Pop();
            if (!seen.Add(current))
            {
                continue;
            }

            foreach (var neighbor in EnumerateOrthogonalNeighbors(current))
            {
                if (positions.Contains(neighbor))
                {
                    stack.Push(neighbor);
                }
            }
        }

        return seen.Count == positions.Count;
    }

    private static int CountAdjacentPairs(IReadOnlyList<LevelCellDefinition> cells, LevelLayout layout) =>
        EnumerateAdjacentCellPairs(cells, layout).Count();

    private static int CountUsefulAdjacentPairs(IReadOnlyList<LevelCellDefinition> cells, LevelLayout layout) =>
        EnumerateAdjacentCellPairs(cells, layout).Count(pair => CellsHaveUsefulEdge(pair.A, pair.B) || CellsHaveUsefulEdge(pair.B, pair.A));

    private static int CountReciprocalAdjacentPairs(IReadOnlyList<LevelCellDefinition> cells, LevelLayout layout) =>
        EnumerateAdjacentCellPairs(cells, layout).Count(pair => CellsHaveUsefulEdge(pair.A, pair.B) && CellsHaveUsefulEdge(pair.B, pair.A));

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
                if (ManhattanDistance(new GridPosition(placements[i].X, placements[i].Y), new GridPosition(placements[j].X, placements[j].Y)) == 1)
                {
                    yield return (cellById[placements[i].CellId], cellById[placements[j].CellId]);
                }
            }
        }
    }

    private static bool CellsHaveUsefulEdge(LevelCellDefinition source, LevelCellDefinition target)
    {
        if (target.Kind == CellKind.Standard)
        {
            return source.Needs.Contains(target.ProducedResource, StringComparer.Ordinal);
        }

        return source.Needs.Intersect(target.Needs, StringComparer.Ordinal).Any();
    }

    private static IEnumerable<GridPosition> EnumerateOrthogonalNeighbors(GridPosition position)
    {
        yield return new GridPosition(position.X + 1, position.Y);
        yield return new GridPosition(position.X - 1, position.Y);
        yield return new GridPosition(position.X, position.Y + 1);
        yield return new GridPosition(position.X, position.Y - 1);
    }

    private static int ManhattanDistance(GridPosition left, GridPosition right) =>
        Math.Abs(left.X - right.X) + Math.Abs(left.Y - right.Y);

    private static int TileDegree(GridPosition position, int width, int height)
    {
        var degree = 0;
        foreach (var neighbor in EnumerateOrthogonalNeighbors(position))
        {
            if (neighbor.X >= 0 && neighbor.X < width && neighbor.Y >= 0 && neighbor.Y < height)
            {
                degree++;
            }
        }

        return degree;
    }

    private static int TileCenterDistanceScore(GridPosition tile, int width, int height)
    {
        var dx = tile.X * 2 - (width - 1);
        var dy = tile.Y * 2 - (height - 1);
        return dx * dx + dy * dy;
    }

    private static int CircularDistance(int left, int right, int count)
    {
        var distance = Math.Abs(left - right);
        return Math.Min(distance, count - distance);
    }

    private static int RotateTie(int value, int variant)
    {
        unchecked
        {
            var mixed = value;
            mixed = mixed * 31 + variant * 1_103_515_245;
            mixed ^= mixed >> 16;
            return mixed & 0x7fffffff;
        }
    }

    private static int ComputeAttemptSeed(PuzzleLevelOptions options, int attempt)
    {
        unchecked
        {
            var seed = options.GenerationSeed;
            seed = seed * 31 + options.LevelNumber;
            seed = seed * 31 + attempt;
            seed = seed * 31 + 0x5EED;
            return seed;
        }
    }

    private static void Shuffle<T>(IList<T> values, Random random)
    {
        for (var i = values.Count - 1; i > 0; i--)
        {
            var swapIndex = random.Next(i + 1);
            (values[i], values[swapIndex]) = (values[swapIndex], values[i]);
        }
    }

    private static string DescribeSummary(PuzzleSolverSummary summary) =>
        $"won={summary.Won} sustained={summary.FinalSustainedTicks} stableAtEnd={summary.StableAtEnd} "
        + $"glowing={summary.GlowingCells} activeLast={summary.ActiveCellsInLastWindow} "
        + $"swaps={summary.TotalSwaps} reactions={summary.TotalReactions} score={summary.FinalScore}";

    private static void ReportProgress(PuzzleLevelOptions options, string message) =>
        options.ProgressLogger?.Invoke($"[level-{options.LevelNumber:000}] {DateTimeOffset.UtcNow:O} {message}");

    private sealed record Candidate(
        IReadOnlyList<string> Resources,
        IReadOnlyList<LevelCellDefinition> Cells,
        LevelLayout StartingLayout,
        LevelLayout SolutionLayout,
        string LevelJson,
        string StartingFixtureJson,
        string SolutionFixtureJson,
        FixtureLoadResult StartingLoaded,
        FixtureLoadResult SolutionLoaded,
        int Attempt,
        int RepairEditCount,
        int ProducerEditCount)
    {
        public GeneratedPuzzleLevel ToGeneratedLevel(PuzzleLevelOptions options, PuzzleSolverSummary summary)
        {
            var definition = new PuzzleLevelDefinition(
                options.LevelNumber,
                LevelMode.Puzzle,
                $"Level {options.LevelNumber}: shape-first exact, {Cells.Count(cell => cell.Kind == CellKind.Standard)} producers",
                options.GenerationSeed,
                Resources.ToArray(),
                Cells.ToArray(),
                StartingLayout,
                SolutionLayout,
                summary);
            var levelJson = JsonSerializer.Serialize(definition, JsonOptions);
            return new GeneratedPuzzleLevel(
                options,
                definition,
                levelJson,
                StartingFixtureJson,
                SolutionFixtureJson,
                StartingLoaded,
                SolutionLoaded,
                summary,
                RepairEditCount,
                ProducerEditCount);
        }
    }

    private sealed record SearchResult(Candidate Candidate, ShapeFirstExactConstructionProof Proof, PuzzleSolverSummary Summary);

    private sealed record EvaluationResult(PuzzleSolverSummary Summary, IReadOnlyList<StressSignal> StressSignals);

    private sealed record StressSignal(string CellId, string Resource, int Quantity, int Strain, bool IsGlowing);

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
