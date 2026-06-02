using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace CellularSim;

public sealed class PuzzleSolutionSearchOptions
{
    public int StartLevel { get; set; } = 1;
    public int EndLevel { get; set; } = 22;
    public string LevelsDirectory { get; set; } = Path.Combine("levels", "puzzle");
    public string OutputDirectory { get; set; } = Path.Combine("sim", "solutions", "puzzle");
    public int TicksPerCandidate { get; set; } = 900;
    public int CandidateLimit { get; set; } = 10_000;
    public int BeamSize { get; set; } = 512;
    public int? SourceQuantityPerTick { get; set; }
    public int EventCapacity { get; set; } = 262_144;
    public int ProgressStride { get; set; } = 250;
    public bool StopOnFailure { get; set; } = true;
    public Action<string>? ProgressLogger { get; set; }
}

public sealed record PuzzleSolutionSearchBatchResult(IReadOnlyList<PuzzleSolutionSearchResult> Results);

public sealed record PuzzleSolutionSearchResult(
    int LevelNumber,
    string LevelName,
    string FixturePath,
    bool Won,
    bool UsesNeedsRepair,
    int CandidatesEvaluated,
    int CandidateLimit,
    int FirstWinTick,
    double BestTenTickFlow,
    int BestTenTickSwaps,
    int TotalSwaps,
    int TotalReactions,
    int SustainedTicks,
    int ActiveCellsInLastWindow,
    int GlowingCells,
    int FinalScore,
    int BestConnectedCells,
    int OpenTiles,
    int LargestOpenTileComponent,
    int UsefulEdgeCount,
    int ReciprocalEdgeCount,
    string FailureCategory,
    string Diagnostics,
    string ResourceGraphDiagnostics,
    string NeedsSuggestionDiagnostics,
    string? RepairedLevelFixtureJson,
    string? SolutionFixtureJson,
    string? SolutionMapText,
    IReadOnlyList<PuzzleSolutionCandidateReport> CandidateReports);

public sealed record PuzzleSolutionCandidateReport(
    int CandidateIndex,
    bool Won,
    int FirstWinTick,
    double BestTenTickFlow,
    int BestTenTickSwaps,
    int TotalSwaps,
    int TotalReactions,
    int SustainedTicks,
    int ActiveCellsInLastWindow,
    int GlowingCells,
    int NonGlowingRequiredCellCount,
    int MissingRequiredResourceCount,
    string NonGlowingRequiredCells,
    string EmptyNeedsByCell,
    int FinalScore,
    int ConnectedCells,
    long LayoutScore,
    string Diagnostics);

public sealed record PuzzleSolutionCandidateLayout(
    int CandidateIndex,
    IReadOnlyDictionary<string, GridPosition> Placements,
    int ConnectedCells,
    long LayoutScore);

public static class PuzzleSolutionSearcher
{
    private const int FlowWindowTicks = 10;
    private const int MaxTileExpansionsPerState = 16;
    private const double MinimumStressRepairFlowThreshold = 14.0;
    private const string MapLabelSuffixes = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0abcdefghijklmnopqrstuvwxyz!$%&()+,-;=@[]^_{}~";
    private const int MaxStressNeedRepairChainEdits = 8;

    private static readonly JsonSerializerOptions WriteJsonOptions = new()
    {
        WriteIndented = true
    };

    public static PuzzleSolutionSearchBatchResult SearchRange(PuzzleSolutionSearchOptions options)
    {
        ValidateOptions(options);
        Directory.CreateDirectory(options.OutputDirectory);

        var results = new List<PuzzleSolutionSearchResult>();
        for (var level = options.StartLevel; level <= options.EndLevel; level++)
        {
            var levelName = $"level-{level:000}";
            var fixturePath = Path.Combine(options.LevelsDirectory, $"{levelName}.json");
            PuzzleSolutionSearchResult result;
            if (!File.Exists(fixturePath))
            {
                result = BuildMissingFixtureResult(level, levelName, fixturePath, options.CandidateLimit);
            }
            else
            {
                ReportProgress(options, level, $"search start fixture={fixturePath}");
                result = SearchFixture(
                    level,
                    levelName,
                    fixturePath,
                    File.ReadAllText(fixturePath),
                    options,
                    LoadSidecarFixtureSeeds(options.LevelsDirectory, levelName),
                    LoadSidecarAsciiSeeds(options.LevelsDirectory, levelName));
                ReportProgress(options, level, result.Won
                    ? $"won candidates={result.CandidatesEvaluated} firstWinTick={result.FirstWinTick} bestFlow={result.BestTenTickFlow:F2}{(result.UsesNeedsRepair ? " needsRepair=true" : "")}"
                    : $"failed candidates={result.CandidatesEvaluated} category={result.FailureCategory} bestFlow={result.BestTenTickFlow:F2}");
            }

            SaveLevelResult(options.OutputDirectory, result);
            if (result.Won && result.UsesNeedsRepair && result.RepairedLevelFixtureJson is not null)
            {
                File.WriteAllText(fixturePath, result.RepairedLevelFixtureJson);
            }

            if (result.Won && result.SolutionMapText is not null)
            {
                File.WriteAllText(Path.Combine(options.LevelsDirectory, $"{levelName}-solution.txt"), result.SolutionMapText);
            }

            if (result.Won && result.SolutionFixtureJson is not null)
            {
                File.WriteAllText(Path.Combine(options.LevelsDirectory, $"{levelName}-solution.json"), result.SolutionFixtureJson);
            }

            results.Add(result);
            if (options.StopOnFailure && !result.Won)
            {
                ReportProgress(options, level, "stopping after unsolved level");
                break;
            }
        }

        SaveBatchSummary(options.OutputDirectory, results);
        return new PuzzleSolutionSearchBatchResult(results);
    }

    public static PuzzleSolutionSearchResult SearchFixture(
        int levelNumber,
        string levelName,
        string fixturePath,
        string fixtureJson,
        PuzzleSolutionSearchOptions options,
        IReadOnlyList<string>? seededFixtureJsons = null,
        IReadOnlyList<string>? seededAsciiLayouts = null)
    {
        ValidateOptions(options);
        var document = PuzzleFixtureDocument.Parse(fixtureJson, options.SourceQuantityPerTick);
        var graph = BuildCellGraph(document.Cells);
        var spatial = BuildSpatialInfo(document);
        var resourceGraphDiagnostics = BuildResourceGraphDiagnostics(document, graph);
        var bestReport = default(PuzzleSolutionCandidateReport);
        var bestDiagnostics = "";
        var bestPlacements = default(IReadOnlyDictionary<string, GridPosition>);
        var bestFlowReport = default(PuzzleSolutionCandidateReport);
        var bestFlowPlacements = default(IReadOnlyDictionary<string, GridPosition>);
        string? bestFixtureJson = null;
        string? bestMapText = null;
        var reports = new List<PuzzleSolutionCandidateReport>(Math.Min(options.CandidateLimit, 10_000));
        var repairSeeds = new List<CandidateRepairSeed>();
        var evaluatedLayouts = new HashSet<string>(StringComparer.Ordinal);
        var candidateIndex = 0;
        var lastImprovedCandidate = 0;
        var noImprovementLimit = Math.Max(128, Math.Min(options.BeamSize, 256));
        var focusedSingleLevel = options.StartLevel == options.EndLevel;
        var repairBudget = options.CandidateLimit < 16
            ? 0
            : focusedSingleLevel
                ? Math.Min(options.CandidateLimit - 1, Math.Max(2_048, options.CandidateLimit / 2))
                : Math.Min(options.CandidateLimit / 4, Math.Max(64, Math.Min(options.BeamSize * 2, 1_024)));
        var needsRepairBudget = options.CandidateLimit < 32
            ? 0
            : focusedSingleLevel
                ? Math.Min(repairBudget, Math.Max(512, Math.Min(options.CandidateLimit / 2, options.BeamSize * 4)))
                : Math.Min(options.CandidateLimit / 8, Math.Max(16, Math.Min(options.BeamSize / 2, 128)));
        var layoutRepairBudget = Math.Max(0, repairBudget - needsRepairBudget);
        var baseBudget = focusedSingleLevel
            ? Math.Max(1, options.CandidateLimit - repairBudget)
            : options.CandidateLimit;

        foreach (var layout in GenerateCandidateLayouts(
            document,
            graph,
            spatial,
            options.CandidateLimit,
            options.BeamSize,
            seededFixtureJsons,
            seededAsciiLayouts))
        {
            if (candidateIndex >= baseBudget && repairSeeds.Count > 0)
            {
                break;
            }

            if (!TryEvaluateLayout(layout, repairSeeds, out var wonResult))
            {
                continue;
            }

            if (wonResult is not null)
            {
                return wonResult;
            }

            var strongFlowReport = bestFlowReport;
            if (strongFlowReport is not null && IsStrongStressRepairSeed(document, strongFlowReport))
            {
                ReportProgress(
                    options,
                    levelNumber,
                    $"high-flow repair threshold candidates={candidateIndex}/{options.CandidateLimit} flow={strongFlowReport.BestTenTickFlow:F2}/{GetStressRepairFlowThreshold(document):F2} blockers={strongFlowReport.NonGlowingRequiredCellCount} connected={strongFlowReport.ConnectedCells}/{document.Cells.Count}");
                break;
            }

            if (bestReport is not null
                && !focusedSingleLevel
                && candidateIndex >= noImprovementLimit
                && candidateIndex - lastImprovedCandidate >= noImprovementLimit)
            {
                ReportProgress(
                    options,
                    levelNumber,
                    $"early stop candidates={candidateIndex}/{options.CandidateLimit} noImprovement={candidateIndex - lastImprovedCandidate} bestFlow={bestReport.BestTenTickFlow:F2}");
                break;
            }
        }

        var layoutRepairLimit = Math.Min(layoutRepairBudget, options.CandidateLimit - candidateIndex);
        if (bestReport is not null && !bestReport.Won && layoutRepairLimit > 0 && repairSeeds.Count > 0)
        {
            ReportProgress(
                options,
                levelNumber,
                $"repair start seeds={repairSeeds.Count} remaining={layoutRepairLimit}");
            foreach (var layout in GenerateRepairLayouts(document, graph, spatial, repairSeeds, layoutRepairLimit))
            {
                if (candidateIndex >= options.CandidateLimit || candidateIndex >= baseBudget + layoutRepairLimit)
                {
                    break;
                }

                if (!TryEvaluateLayout(layout, repairSeedTarget: null, out var wonResult))
                {
                    continue;
                }

                if (wonResult is not null)
                {
                    return wonResult;
                }
            }
        }

        var stressRepairLimit = Math.Min(needsRepairBudget, options.CandidateLimit - candidateIndex);
        var stressRepairSeeds = BuildStressNeedRepairSeeds(bestReport, bestPlacements, bestFlowReport, bestFlowPlacements)
            .Where(seed => IsStrongStressRepairSeed(document, seed.Report))
            .ToArray();
        if (bestReport is not null && !bestReport.Won && stressRepairLimit > 0 && stressRepairSeeds.Length > 0)
        {
            ReportProgress(
                options,
                levelNumber,
                $"needs repair start seeds={stressRepairSeeds.Length} remaining={stressRepairLimit} threshold={GetStressRepairFlowThreshold(document):F2}");
            foreach (var variant in GenerateStressNeedRepairVariants(
                document,
                spatial,
                stressRepairSeeds,
                stressRepairLimit))
            {
                if (candidateIndex >= options.CandidateLimit)
                {
                    break;
                }

                if (!TryEvaluateNeedsRepairVariant(variant, out var wonResult))
                {
                    continue;
                }

                if (wonResult is not null)
                {
                    return wonResult;
                }
            }
        }

        if (bestReport is null)
        {
            bestReport = new PuzzleSolutionCandidateReport(0, false, -1, 0, 0, 0, 0, 0, 0, 0, int.MaxValue, int.MaxValue, "", "", 0, 0, 0, "no candidates generated");
            bestDiagnostics = "no candidates generated";
        }

        var failureCategory = ClassifyFailure(document, graph, spatial, bestReport);
        return BuildResult(
            levelNumber,
            levelName,
            fixturePath,
            false,
            candidateIndex,
            options.CandidateLimit,
            bestReport,
            false,
            graph,
            spatial,
            failureCategory,
            bestDiagnostics,
            resourceGraphDiagnostics,
            (bestFlowPlacements ?? bestPlacements) is { } suggestionPlacements
                ? BuildShapeFirstNeedsSuggestion(document, suggestionPlacements, bestFlowReport ?? bestReport)
                : "",
            null,
            bestFixtureJson,
            bestMapText,
            reports);

        bool TryEvaluateLayout(
            PuzzleSolutionCandidateLayout layout,
            List<CandidateRepairSeed>? repairSeedTarget,
            out PuzzleSolutionSearchResult? wonResult)
        {
            wonResult = null;
            var layoutKey = BuildPlacementKey(document.Cells, layout.Placements);
            if (!evaluatedLayouts.Add(layoutKey))
            {
                return false;
            }

            var candidateFixtureJson = document.BuildFixtureJson(layout.Placements);
            var loaded = FixtureLoader.LoadFromJson(candidateFixtureJson);
            loaded.Options.EventCapacity = ComputeCandidateEventCapacity(loaded, options.EventCapacity);
            var evaluation = EvaluateCandidate(loaded, options.TicksPerCandidate);
            var report = new PuzzleSolutionCandidateReport(
                candidateIndex,
                evaluation.Won,
                evaluation.FirstWinTick,
                evaluation.BestTenTickFlow,
                evaluation.BestTenTickSwaps,
                evaluation.TotalSwaps,
                evaluation.TotalReactions,
                evaluation.SustainedTicks,
                evaluation.ActiveCellsInLastWindow,
                evaluation.GlowingCells,
                evaluation.NonGlowingRequiredCells.Count,
                evaluation.MissingRequiredResourceCount,
                string.Join("|", evaluation.NonGlowingRequiredCells),
                SerializeNeedsByCell(evaluation.EmptyNeedsByCell),
                evaluation.FinalScore,
                layout.ConnectedCells,
                layout.LayoutScore,
                evaluation.SummaryDiagnostics);
            reports.Add(report);
            candidateIndex++;

            if (bestReport is null || IsBetterCandidateReport(report, bestReport))
            {
                bestReport = report;
                bestDiagnostics = evaluation.DetailedDiagnostics;
                bestPlacements = layout.Placements;
                bestFixtureJson = candidateFixtureJson;
                bestMapText = RenderSolutionMap(document, layout.Placements);
                lastImprovedCandidate = candidateIndex;
            }

            if (bestFlowReport is null || IsBetterShapeFirstCandidate(report, bestFlowReport))
            {
                bestFlowReport = report;
                bestFlowPlacements = layout.Placements;
            }

            if (!evaluation.Won && repairSeedTarget is not null && IsRepairSeedCandidate(document, report))
            {
                repairSeedTarget.Add(new CandidateRepairSeed(layout, report));
                repairSeedTarget.Sort((left, right) => IsBetterCandidateReport(left.Report, right.Report) ? -1 : IsBetterCandidateReport(right.Report, left.Report) ? 1 : 0);
                if (repairSeedTarget.Count > Math.Max(32, Math.Min(options.BeamSize, 128)))
                {
                    repairSeedTarget.RemoveAt(repairSeedTarget.Count - 1);
                }
            }

            if (options.ProgressStride > 0 && candidateIndex % options.ProgressStride == 0)
            {
                ReportProgress(
                    options,
                    levelNumber,
                    $"progress candidates={candidateIndex}/{options.CandidateLimit} bestWon={bestReport.Won} bestBlockers={bestReport.NonGlowingRequiredCellCount} bestFlow={bestReport.BestTenTickFlow:F2}");
            }

            if (!evaluation.Won)
            {
                return true;
            }

            wonResult = BuildResult(
                levelNumber,
                levelName,
                fixturePath,
                true,
                candidateIndex,
                options.CandidateLimit,
                report,
                false,
                graph,
                spatial,
                "won",
                evaluation.DetailedDiagnostics,
                resourceGraphDiagnostics,
                "",
                null,
                candidateFixtureJson,
                RenderSolutionMap(document, layout.Placements),
                reports);
            return true;
        }

        bool TryEvaluateNeedsRepairVariant(
            StressNeedRepairVariant variant,
            out PuzzleSolutionSearchResult? wonResult)
        {
            wonResult = null;
            var variantKey = $"{BuildPlacementKey(variant.Document.Cells, variant.Placements)}needs:{variant.EditKey}";
            if (!evaluatedLayouts.Add(variantKey))
            {
                return false;
            }

            var candidateFixtureJson = variant.Document.BuildFixtureJson(variant.Placements);
            var loaded = FixtureLoader.LoadFromJson(candidateFixtureJson);
            loaded.Options.EventCapacity = ComputeCandidateEventCapacity(loaded, options.EventCapacity);
            var evaluation = EvaluateCandidate(loaded, options.TicksPerCandidate);
            var report = new PuzzleSolutionCandidateReport(
                candidateIndex,
                evaluation.Won,
                evaluation.FirstWinTick,
                evaluation.BestTenTickFlow,
                evaluation.BestTenTickSwaps,
                evaluation.TotalSwaps,
                evaluation.TotalReactions,
                evaluation.SustainedTicks,
                evaluation.ActiveCellsInLastWindow,
                evaluation.GlowingCells,
                evaluation.NonGlowingRequiredCells.Count,
                evaluation.MissingRequiredResourceCount,
                string.Join("|", evaluation.NonGlowingRequiredCells),
                SerializeNeedsByCell(evaluation.EmptyNeedsByCell),
                evaluation.FinalScore,
                variant.ConnectedCells,
                variant.LayoutScore,
                $"needs-repair {variant.EditSummary}; {evaluation.SummaryDiagnostics}");
            reports.Add(report);
            candidateIndex++;

            if (bestReport is null || IsBetterCandidateReport(report, bestReport))
            {
                bestReport = report;
                bestDiagnostics = evaluation.DetailedDiagnostics;
                bestPlacements = variant.Placements;
                bestFixtureJson = candidateFixtureJson;
                bestMapText = RenderSolutionMap(variant.Document, variant.Placements);
                lastImprovedCandidate = candidateIndex;
            }

            if (options.ProgressStride > 0 && candidateIndex % options.ProgressStride == 0)
            {
                ReportProgress(
                    options,
                    levelNumber,
                    $"progress candidates={candidateIndex}/{options.CandidateLimit} bestWon={bestReport.Won} bestBlockers={bestReport.NonGlowingRequiredCellCount} bestFlow={bestReport.BestTenTickFlow:F2}");
            }

            if (!evaluation.Won)
            {
                return true;
            }

            var variantGraph = BuildCellGraph(variant.Document.Cells);
            wonResult = BuildResult(
                levelNumber,
                levelName,
                fixturePath,
                true,
                candidateIndex,
                options.CandidateLimit,
                report,
                true,
                variantGraph,
                BuildSpatialInfo(variant.Document),
                "won after needs repair",
                evaluation.DetailedDiagnostics,
                BuildResourceGraphDiagnostics(variant.Document, variantGraph),
                BuildNeedsRepairAppliedDiagnostics(variant),
                variant.Document.ToFixtureJson(),
                candidateFixtureJson,
                RenderSolutionMap(variant.Document, variant.Placements),
                reports);
            return true;
        }
    }

    public static int ScoreCellMatchForTests(
        string aProducedResource,
        IReadOnlyList<string> aNeeds,
        CellKind aKind,
        string bProducedResource,
        IReadOnlyList<string> bNeeds,
        CellKind bKind)
    {
        var a = new SearchCell("a", aKind, aProducedResource, aNeeds.ToArray(), BuildOfferResources(aProducedResource, aNeeds, aKind, hasStoredNeedQuantity: false));
        var b = new SearchCell("b", bKind, bProducedResource, bNeeds.ToArray(), BuildOfferResources(bProducedResource, bNeeds, bKind, hasStoredNeedQuantity: false));
        return ScoreCellMatch(a, b);
    }

    public static IReadOnlyList<PuzzleSolutionCandidateLayout> GenerateCandidateLayoutsForTests(
        string fixtureJson,
        int candidateLimit = 128,
        int beamSize = 32)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        var graph = BuildCellGraph(document.Cells);
        var spatial = BuildSpatialInfo(document);
        return GenerateCandidateLayouts(document, graph, spatial, candidateLimit, beamSize, null, null).ToArray();
    }

    public static int CountAsciiSeedCandidatesForTests(string fixtureJson, string ascii)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        var spatial = BuildSpatialInfo(document);
        return BuildPlacementsFromAscii(document, spatial, ascii).Count();
    }

    public static string RenderCandidateMapForTests(
        string fixtureJson,
        IReadOnlyDictionary<string, GridPosition> placements)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        return RenderCompactSolutionMap(document, placements);
    }

    public static string RenderAnnotatedCandidateMapForTests(
        string fixtureJson,
        IReadOnlyDictionary<string, GridPosition> placements)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        return RenderSolutionMap(document, placements);
    }

    public static string BuildNonGlowingHistogramForTests(IReadOnlyList<PuzzleSolutionCandidateReport> reports) =>
        BuildNonGlowingHistogram(reports);

    public static string BuildShapeFirstNeedsSuggestionForTests(
        string fixtureJson,
        IReadOnlyDictionary<string, GridPosition> placements,
        IReadOnlyDictionary<string, string[]>? emptyNeedsByCell = null,
        IReadOnlyList<string>? nonGlowingRequiredCells = null)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        var report = new PuzzleSolutionCandidateReport(
            0,
            false,
            -1,
            1,
            10,
            10,
            0,
            0,
            placements.Count,
            0,
            0,
            0,
            nonGlowingRequiredCells is null ? "" : string.Join("|", nonGlowingRequiredCells),
            emptyNeedsByCell is null ? "" : SerializeNeedsByCell(emptyNeedsByCell),
            0,
            placements.Count,
            0,
            "");
        return BuildShapeFirstNeedsSuggestion(document, placements, report);
    }

    public static IReadOnlyList<string> GenerateStressNeedRepairFixtureJsonsForTests(
        string fixtureJson,
        IReadOnlyDictionary<string, GridPosition> placements,
        IReadOnlyDictionary<string, string[]> emptyNeedsByCell,
        IReadOnlyList<string> nonGlowingRequiredCells,
        int candidateLimit = 16)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        var graph = BuildCellGraph(document.Cells);
        var spatial = BuildSpatialInfo(document);
        var state = LayoutState.TryCreate(placements, document, graph, spatial, variant: -1)
            ?? throw new ArgumentException("Placement is invalid for the fixture.", nameof(placements));
        var report = new PuzzleSolutionCandidateReport(
            0,
            false,
            -1,
            1,
            10,
            10,
            0,
            0,
            placements.Count,
            0,
            nonGlowingRequiredCells.Count,
            0,
            string.Join("|", nonGlowingRequiredCells),
            SerializeNeedsByCell(emptyNeedsByCell),
            0,
            state.ConnectedCells,
            state.Score,
            "");

        return GenerateStressNeedRepairVariants(
                document,
                spatial,
                [new CandidateRepairSeed(new PuzzleSolutionCandidateLayout(0, placements, state.ConnectedCells, state.Score), report)],
                candidateLimit)
            .Select(variant => variant.Document.BuildFixtureJson(placements))
            .ToArray();
    }

    public static IReadOnlyList<PuzzleSolutionCandidateLayout> GenerateRepairLayoutsForTests(
        string fixtureJson,
        IReadOnlyDictionary<string, GridPosition> placements,
        IReadOnlyList<string> nonGlowingRequiredCells,
        int candidateLimit = 16)
    {
        var document = PuzzleFixtureDocument.Parse(fixtureJson, null);
        var graph = BuildCellGraph(document.Cells);
        var spatial = BuildSpatialInfo(document);
        var state = LayoutState.TryCreate(placements, document, graph, spatial, variant: -1)
            ?? throw new ArgumentException("Placement is invalid for the fixture.", nameof(placements));
        var report = new PuzzleSolutionCandidateReport(
            0,
            false,
            -1,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            nonGlowingRequiredCells.Count,
            0,
            string.Join("|", nonGlowingRequiredCells),
            "",
            0,
            state.ConnectedCells,
            state.Score,
            "");
        return GenerateRepairLayouts(
                document,
                graph,
                spatial,
                [new CandidateRepairSeed(new PuzzleSolutionCandidateLayout(0, placements, state.ConnectedCells, state.Score), report)],
                candidateLimit)
            .ToArray();
    }

    private static PuzzleSolutionSearchResult BuildResult(
        int levelNumber,
        string levelName,
        string fixturePath,
        bool won,
        int candidatesEvaluated,
        int candidateLimit,
        PuzzleSolutionCandidateReport best,
        bool usesNeedsRepair,
        CellGraphInfo graph,
        SpatialInfo spatial,
        string failureCategory,
        string diagnostics,
        string resourceGraphDiagnostics,
        string needsSuggestionDiagnostics,
        string? repairedLevelFixtureJson,
        string? solutionFixtureJson,
        string? solutionMapText,
        IReadOnlyList<PuzzleSolutionCandidateReport> reports) =>
        new(
            levelNumber,
            levelName,
            fixturePath,
            won,
            usesNeedsRepair,
            candidatesEvaluated,
            candidateLimit,
            best.FirstWinTick,
            best.BestTenTickFlow,
            best.BestTenTickSwaps,
            best.TotalSwaps,
            best.TotalReactions,
            best.SustainedTicks,
            best.ActiveCellsInLastWindow,
            best.GlowingCells,
            best.FinalScore,
            best.ConnectedCells,
            spatial.OpenTiles.Count,
            spatial.LargestComponentSize,
            graph.UsefulEdgeCount,
            graph.ReciprocalEdgeCount,
            failureCategory,
            diagnostics,
            resourceGraphDiagnostics,
            needsSuggestionDiagnostics,
            repairedLevelFixtureJson,
            solutionFixtureJson,
            solutionMapText,
            reports);

    private static PuzzleSolutionSearchResult BuildMissingFixtureResult(
        int level,
        string levelName,
        string fixturePath,
        int candidateLimit) =>
        new(
            level,
            levelName,
            fixturePath,
            false,
            false,
            0,
            candidateLimit,
            -1,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            "missing fixture",
            $"Fixture not found: {fixturePath}",
            "",
            "",
            null,
            null,
            null,
            Array.Empty<PuzzleSolutionCandidateReport>());

    private static bool IsBetterCandidateReport(PuzzleSolutionCandidateReport candidate, PuzzleSolutionCandidateReport best)
    {
        static long Rank(PuzzleSolutionCandidateReport report)
        {
            var rank = report.Won ? 1_000_000_000_000L : 0;
            var blockerScore = report.NonGlowingRequiredCellCount == int.MaxValue
                ? 0
                : 128 - Math.Min(report.NonGlowingRequiredCellCount, 128);
            var missingResourceScore = report.MissingRequiredResourceCount == int.MaxValue
                ? 0
                : 128 - Math.Min(report.MissingRequiredResourceCount, 128);
            rank += blockerScore * 100_000_000_000L;
            rank += missingResourceScore * 50_000_000_000L;
            rank += report.SustainedTicks * 10_000_000_000L;
            rank += report.ActiveCellsInLastWindow * 100_000_000L;
            rank += report.GlowingCells * 50_000_000L;
            rank += report.BestTenTickSwaps * 2_000_000L;
            rank += report.TotalReactions * 2_000L;
            rank += report.TotalSwaps * 100L;
            rank += report.FinalScore;
            rank += report.ConnectedCells * 10_000L;
            rank += Math.Min(report.LayoutScore, 1_000_000L);
            return rank;
        }

        return Rank(candidate) > Rank(best);
    }

    private static bool IsBetterShapeFirstCandidate(PuzzleSolutionCandidateReport candidate, PuzzleSolutionCandidateReport best)
    {
        static long Rank(PuzzleSolutionCandidateReport report)
        {
            var rank = (long)Math.Round(report.BestTenTickFlow * 1_000, MidpointRounding.AwayFromZero) * 1_000_000_000L;
            rank += report.BestTenTickSwaps * 100_000_000L;
            rank += report.TotalSwaps * 1_000_000L;
            rank += report.TotalReactions * 10_000L;
            rank += report.ActiveCellsInLastWindow * 1_000L;
            rank += report.GlowingCells * 100L;
            rank += Math.Min(report.LayoutScore, 99L);
            return rank;
        }

        return Rank(candidate) > Rank(best);
    }

    private static IEnumerable<PuzzleSolutionCandidateLayout> GenerateCandidateLayouts(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        int candidateLimit,
        int beamSize,
        IReadOnlyList<string>? seededFixtureJsons,
        IReadOnlyList<string>? seededAsciiLayouts)
    {
        if (document.Cells.Count == 0 || spatial.OpenTiles.Count < document.Cells.Count)
        {
            yield break;
        }

        var emitted = 0;
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var state in GenerateSeededLayouts(document, graph, spatial, seededFixtureJsons, seededAsciiLayouts))
        {
            var key = state.BuildKey(document.Cells);
            if (!seen.Add(key))
            {
                continue;
            }

            yield return new PuzzleSolutionCandidateLayout(emitted, state.ToPlacementDictionary(document.Cells), state.ConnectedCells, state.Score);
            emitted++;
            if (emitted >= candidateLimit)
            {
                yield break;
            }
        }

        var greedyLimit = Math.Min(candidateLimit - emitted, Math.Max(beamSize, document.Cells.Count * 32));
        foreach (var state in GenerateBottleneckSeedLayouts(document, graph, spatial, Math.Min(greedyLimit, Math.Max(beamSize, 64))))
        {
            var key = state.BuildKey(document.Cells);
            if (!seen.Add(key))
            {
                continue;
            }

            yield return new PuzzleSolutionCandidateLayout(emitted, state.ToPlacementDictionary(document.Cells), state.ConnectedCells, state.Score);
            emitted++;
            if (emitted >= candidateLimit)
            {
                yield break;
            }
        }

        foreach (var state in GenerateGreedyLayouts(document, graph, spatial, greedyLimit))
        {
            var key = state.BuildKey(document.Cells);
            if (!seen.Add(key))
            {
                continue;
            }

            yield return new PuzzleSolutionCandidateLayout(emitted, state.ToPlacementDictionary(document.Cells), state.ConnectedCells, state.Score);
            emitted++;
            if (emitted >= candidateLimit)
            {
                yield break;
            }
        }

        var variant = 0;
        while (emitted < candidateLimit)
        {
            var order = BuildCellOrder(document.Cells, graph, variant);
            var layouts = BuildBeamLayouts(document, graph, spatial, order, beamSize, variant);
            var emittedThisVariant = 0;
            foreach (var state in layouts)
            {
                var key = state.BuildKey(document.Cells);
                if (!seen.Add(key))
                {
                    continue;
                }

                yield return new PuzzleSolutionCandidateLayout(emitted, state.ToPlacementDictionary(document.Cells), state.ConnectedCells, state.Score);
                emitted++;
                emittedThisVariant++;
                if (emitted >= candidateLimit)
                {
                    yield break;
                }
            }

            variant++;
            if (emittedThisVariant == 0 && variant > Math.Max(8, document.Cells.Count * 4))
            {
                yield break;
            }
        }
    }

    private static IEnumerable<LayoutState> GenerateGreedyLayouts(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        int candidateLimit)
    {
        if (candidateLimit <= 0)
        {
            yield break;
        }

        var emitted = 0;
        var startTiles = spatial.OpenTiles
            .OrderByDescending(tile => spatial.TileDegrees[tile])
            .ThenBy(tile => TileCenterDistanceScore(tile, document.Width, document.Height))
            .ThenBy(tile => tile.Y)
            .ThenBy(tile => tile.X)
            .ToArray();

        for (var variant = 0; emitted < candidateLimit; variant++)
        {
            var order = BuildCellOrder(document.Cells, graph, variant);
            var firstCell = order[0];
            var startTile = startTiles[variant % startTiles.Length];
            var state = LayoutState.Create(document.Cells.Count, firstCell, startTile, spatial);
            var valid = true;
            for (var orderIndex = 1; orderIndex < order.Length; orderIndex++)
            {
                var cellIndex = order[orderIndex];
                var best = EnumeratePlacementTiles(state, spatial, variant)
                    .Take(MaxTileExpansionsPerState * 2)
                    .Select(tile => state.Place(cellIndex, tile, document, graph, spatial, variant))
                    .OrderByDescending(candidate => candidate.Score)
                    .ThenByDescending(candidate => candidate.ConnectedCells)
                    .ThenBy(candidate => candidate.BuildKey(document.Cells), StringComparer.Ordinal)
                    .FirstOrDefault();
                if (best is null)
                {
                    valid = false;
                    break;
                }

                state = best;
            }

            if (valid && state.PlacedCount == document.Cells.Count)
            {
                yield return state;
                emitted++;
            }

            if (variant > Math.Max(candidateLimit * 4, spatial.OpenTiles.Count * document.Cells.Count * 4))
            {
                yield break;
            }
        }
    }

    private static IEnumerable<LayoutState> GenerateBottleneckSeedLayouts(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        int candidateLimit)
    {
        if (candidateLimit <= 0)
        {
            yield break;
        }

        var emitted = 0;
        var bottleneckIndexes = Enumerable.Range(0, document.Cells.Count)
            .Where(index => !document.Cells[index].IsMyco && document.Cells[index].Needs.Length > 0)
            .OrderByDescending(index => ComputeCellBottleneckScore(document.Cells[index], document.Cells))
            .ThenByDescending(index => graph.WeightedDegrees[index])
            .ThenBy(index => document.Cells[index].Id, StringComparer.Ordinal)
            .Take(Math.Min(document.Cells.Count, 8))
            .ToArray();

        foreach (var bottleneckIndex in bottleneckIndexes)
        {
            var providerIndexes = BuildProviderIndexesForNeeds(document.Cells, bottleneckIndex)
                .Take(4)
                .ToArray();
            if (providerIndexes.Length == 0)
            {
                continue;
            }

            foreach (var center in spatial.OpenTiles
                .Where(tile => spatial.Neighbors[tile].Length >= Math.Min(providerIndexes.Length, 2))
                .OrderByDescending(tile => spatial.Neighbors[tile].Length)
                .ThenBy(tile => TileCenterDistanceScore(tile, document.Width, document.Height))
                .ThenBy(tile => tile.Y)
                .ThenBy(tile => tile.X)
                .Take(Math.Min(16, spatial.OpenTiles.Count)))
            {
                var neighbors = spatial.Neighbors[center]
                    .OrderByDescending(tile => spatial.TileDegrees[tile])
                    .ThenBy(tile => TileCenterDistanceScore(tile, document.Width, document.Height))
                    .ThenBy(tile => tile.Y)
                    .ThenBy(tile => tile.X)
                    .ToArray();

                for (var variant = 0; variant < Math.Min(8, providerIndexes.Length * Math.Max(1, neighbors.Length)); variant++)
                {
                    var placements = new Dictionary<string, GridPosition>(StringComparer.Ordinal)
                    {
                        [document.Cells[bottleneckIndex].Id] = center
                    };
                    var usedTiles = new HashSet<GridPosition> { center };
                    var placedProviders = 0;
                    for (var i = 0; i < providerIndexes.Length && placedProviders < neighbors.Length; i++)
                    {
                        var providerIndex = providerIndexes[(i + variant) % providerIndexes.Length];
                        var tile = neighbors[(placedProviders + variant) % neighbors.Length];
                        if (!usedTiles.Add(tile))
                        {
                            continue;
                        }

                        placements[document.Cells[providerIndex].Id] = tile;
                        placedProviders++;
                    }

                    if (placedProviders == 0)
                    {
                        continue;
                    }

                    if (CompleteSeedPlacement(document, graph, spatial, placements, variant) is { } state)
                    {
                        yield return state;
                        emitted++;
                        if (emitted >= candidateLimit)
                        {
                            yield break;
                        }
                    }
                }
            }
        }
    }

    private static IEnumerable<PuzzleSolutionCandidateLayout> GenerateRepairLayouts(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        IReadOnlyList<CandidateRepairSeed> repairSeeds,
        int candidateLimit)
    {
        if (candidateLimit <= 0)
        {
            yield break;
        }

        var emitted = 0;
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var seed in repairSeeds
            .OrderBy(seed => seed.Report.NonGlowingRequiredCellCount)
            .ThenByDescending(seed => seed.Report.GlowingCells)
            .ThenByDescending(seed => seed.Report.BestTenTickSwaps)
            .ThenBy(seed => seed.Layout.CandidateIndex))
        {
            var blockers = ParseCellIdList(seed.Report.NonGlowingRequiredCells);
            if (blockers.Count == 0)
            {
                continue;
            }

            foreach (var placements in GenerateSwapRepairPlacements(document, graph, seed.Layout.Placements, blockers))
            {
                var key = BuildPlacementKey(document.Cells, placements);
                if (!seen.Add(key))
                {
                    continue;
                }

                if (LayoutState.TryCreate(placements, document, graph, spatial, variant: seed.Layout.CandidateIndex) is not { } state)
                {
                    continue;
                }

                yield return new PuzzleSolutionCandidateLayout(emitted, placements, state.ConnectedCells, state.Score);
                emitted++;
                if (emitted >= candidateLimit)
                {
                    yield break;
                }
            }
        }
    }

    private static IEnumerable<IReadOnlyDictionary<string, GridPosition>> GenerateSwapRepairPlacements(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        IReadOnlyDictionary<string, GridPosition> basePlacements,
        IReadOnlyList<string> blockerIds)
    {
        var cellsById = document.Cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        foreach (var blockerId in blockerIds)
        {
            if (!cellsById.ContainsKey(blockerId) || !basePlacements.TryGetValue(blockerId, out _))
            {
                continue;
            }

            var baseScore = ScoreCellAdjacentProviders(document, graph, basePlacements, blockerId);
            foreach (var other in document.Cells.OrderBy(cell => cell.Id, StringComparer.Ordinal))
            {
                if (other.Id == blockerId)
                {
                    continue;
                }

                var swapped = SwapPlacements(basePlacements, blockerId, other.Id);
                if (ScoreCellAdjacentProviders(document, graph, swapped, blockerId) > baseScore)
                {
                    yield return swapped;
                }

                foreach (var third in document.Cells.OrderBy(cell => cell.Id, StringComparer.Ordinal))
                {
                    if (third.Id == blockerId || third.Id == other.Id)
                    {
                        continue;
                    }

                    var rotated = RotateThreePlacements(basePlacements, blockerId, other.Id, third.Id);
                    if (ScoreCellAdjacentProviders(document, graph, rotated, blockerId) > baseScore)
                    {
                        yield return rotated;
                    }
                }
            }
        }
    }

    private static LayoutState? CompleteSeedPlacement(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        Dictionary<string, GridPosition> placements,
        int variant)
    {
        if (!TryCreatePartialState(document, graph, spatial, placements, variant, out var state))
        {
            return null;
        }

        foreach (var cellIndex in BuildCellOrder(document.Cells, graph, variant))
        {
            if (placements.ContainsKey(document.Cells[cellIndex].Id))
            {
                continue;
            }

            var best = EnumeratePlacementTiles(state, spatial, variant)
                .Take(MaxTileExpansionsPerState * 2)
                .Select(tile => state.Place(cellIndex, tile, document, graph, spatial, variant))
                .OrderByDescending(candidate => candidate.Score)
                .ThenByDescending(candidate => candidate.ConnectedCells)
                .ThenBy(candidate => candidate.BuildKey(document.Cells), StringComparer.Ordinal)
                .FirstOrDefault();
            if (best is null)
            {
                return null;
            }

            state = best;
            placements[document.Cells[cellIndex].Id] = state.ToPlacementDictionary(document.Cells)[document.Cells[cellIndex].Id];
        }

        return state.PlacedCount == document.Cells.Count ? state : null;
    }

    private static bool TryCreatePartialState(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        IReadOnlyDictionary<string, GridPosition> placements,
        int variant,
        out LayoutState state)
    {
        state = null!;
        var open = spatial.OpenTiles.ToHashSet();
        var occupied = new HashSet<GridPosition>();
        var ordered = placements
            .OrderByDescending(pair => graph.WeightedDegrees[CellIndexOf(document.Cells, pair.Key)])
            .ThenBy(pair => pair.Key, StringComparer.Ordinal)
            .ToArray();
        for (var i = 0; i < ordered.Length; i++)
        {
            if (!open.Contains(ordered[i].Value) || !occupied.Add(ordered[i].Value))
            {
                return false;
            }

            var cellIndex = CellIndexOf(document.Cells, ordered[i].Key);
            state = i == 0
                ? LayoutState.Create(document.Cells.Count, cellIndex, ordered[i].Value, spatial)
                : state.Place(cellIndex, ordered[i].Value, document, graph, spatial, variant);
        }

        return ordered.Length > 0;
    }

    private static int ComputeCellBottleneckScore(SearchCell cell, IReadOnlyList<SearchCell> cells)
    {
        var score = 0;
        foreach (var need in cell.Needs)
        {
            if (string.Equals(need, cell.ProducedResource, StringComparison.Ordinal))
            {
                score -= 2_000;
                continue;
            }

            var providers = cells.Count(other => !string.IsNullOrEmpty(other.ProducedResource)
                && !string.Equals(other.Id, cell.Id, StringComparison.Ordinal)
                && string.Equals(other.ProducedResource, need, StringComparison.Ordinal));
            score += providers switch
            {
                0 => 4_000,
                1 => 1_000,
                2 => 300,
                _ => 100
            };
        }

        var duplicateProducerCount = string.IsNullOrEmpty(cell.ProducedResource)
            ? 0
            : cells.Count(other => string.Equals(other.ProducedResource, cell.ProducedResource, StringComparison.Ordinal));
        if (duplicateProducerCount > 1)
        {
            score += 700;
        }

        return score;
    }

    private static IEnumerable<int> BuildProviderIndexesForNeeds(IReadOnlyList<SearchCell> cells, int cellIndex)
    {
        var cell = cells[cellIndex];
        return Enumerable.Range(0, cells.Count)
            .Where(index => index != cellIndex
                && !string.IsNullOrEmpty(cells[index].ProducedResource)
                && cell.Needs.Contains(cells[index].ProducedResource, StringComparer.Ordinal)
                && !string.Equals(cells[index].ProducedResource, cell.ProducedResource, StringComparison.Ordinal))
            .OrderByDescending(index => cell.Needs.Count(need => string.Equals(need, cells[index].ProducedResource, StringComparison.Ordinal)))
            .ThenByDescending(index => cells[index].Needs.Contains(cell.ProducedResource, StringComparer.Ordinal))
            .ThenBy(index => cells[index].Id, StringComparer.Ordinal);
    }

    private static int ScoreCellAdjacentProviders(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        IReadOnlyDictionary<string, GridPosition> placements,
        string cellId)
    {
        var index = CellIndexOf(document.Cells, cellId);
        var cell = document.Cells[index];
        if (!placements.TryGetValue(cellId, out var position))
        {
            return 0;
        }

        var score = 0;
        for (var otherIndex = 0; otherIndex < document.Cells.Count; otherIndex++)
        {
            var other = document.Cells[otherIndex];
            if (other.Id == cellId || !placements.TryGetValue(other.Id, out var otherPosition))
            {
                continue;
            }

            if (Math.Abs(position.X - otherPosition.X) + Math.Abs(position.Y - otherPosition.Y) != 1)
            {
                continue;
            }

            if (!string.IsNullOrEmpty(other.ProducedResource) && cell.Needs.Contains(other.ProducedResource, StringComparer.Ordinal))
            {
                score += 10_000;
            }

            score += graph.Weights[index, otherIndex];
        }

        return score;
    }

    private static IReadOnlyList<string> ParseCellIdList(string text) =>
        string.IsNullOrWhiteSpace(text)
            ? Array.Empty<string>()
            : text.Split('|', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static IReadOnlyDictionary<string, GridPosition> SwapPlacements(
        IReadOnlyDictionary<string, GridPosition> placements,
        string first,
        string second)
    {
        var result = new Dictionary<string, GridPosition>(placements, StringComparer.Ordinal);
        (result[first], result[second]) = (result[second], result[first]);
        return result;
    }

    private static IReadOnlyDictionary<string, GridPosition> RotateThreePlacements(
        IReadOnlyDictionary<string, GridPosition> placements,
        string first,
        string second,
        string third)
    {
        var result = new Dictionary<string, GridPosition>(placements, StringComparer.Ordinal);
        var firstPosition = result[first];
        result[first] = result[second];
        result[second] = result[third];
        result[third] = firstPosition;
        return result;
    }

    private static string BuildPlacementKey(
        IReadOnlyList<SearchCell> cells,
        IReadOnlyDictionary<string, GridPosition> placements)
    {
        var builder = new StringBuilder();
        foreach (var cell in cells.OrderBy(cell => cell.Id, StringComparer.Ordinal))
        {
            builder.Append(cell.Id).Append('@');
            if (placements.TryGetValue(cell.Id, out var position))
            {
                builder.Append(position.X).Append(':').Append(position.Y);
            }
            else
            {
                builder.Append("?,?");
            }

            builder.Append(';');
        }

        return builder.ToString();
    }

    private static int CellIndexOf(IReadOnlyList<SearchCell> cells, string cellId)
    {
        for (var i = 0; i < cells.Count; i++)
        {
            if (string.Equals(cells[i].Id, cellId, StringComparison.Ordinal))
            {
                return i;
            }
        }

        throw new KeyNotFoundException($"Unknown cell '{cellId}'.");
    }

    private static IReadOnlyList<string> LoadSidecarFixtureSeeds(string levelsDirectory, string levelName)
    {
        var path = Path.Combine(levelsDirectory, $"{levelName}-solution.json");
        return File.Exists(path) ? [File.ReadAllText(path)] : Array.Empty<string>();
    }

    private static IReadOnlyList<string> LoadSidecarAsciiSeeds(string levelsDirectory, string levelName)
    {
        var path = Path.Combine(levelsDirectory, $"{levelName}-solution.txt");
        return File.Exists(path) ? [File.ReadAllText(path)] : Array.Empty<string>();
    }

    private static IEnumerable<LayoutState> GenerateSeededLayouts(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        IReadOnlyList<string>? seededFixtureJsons,
        IReadOnlyList<string>? seededAsciiLayouts)
    {
        var states = new List<LayoutState>();
        if (seededFixtureJsons is not null)
        {
            foreach (var fixtureJson in seededFixtureJsons)
            {
                if (TryReadPlacementsFromFixtureJson(document, spatial, fixtureJson, out var placements)
                    && LayoutState.TryCreate(placements, document, graph, spatial, variant: -1) is { } state)
                {
                    states.Add(state);
                }
            }
        }

        if (seededAsciiLayouts is not null)
        {
            foreach (var ascii in seededAsciiLayouts)
            {
                foreach (var placements in BuildPlacementsFromAscii(document, spatial, ascii))
                {
                    if (LayoutState.TryCreate(placements, document, graph, spatial, variant: -1) is { } state)
                    {
                        states.Add(state);
                    }
                }
            }
        }

        foreach (var state in states
            .OrderByDescending(state => state.Score)
            .ThenByDescending(state => state.ConnectedCells)
            .ThenBy(state => state.BuildKey(document.Cells), StringComparer.Ordinal))
        {
            yield return state;
        }
    }

    private static bool TryReadPlacementsFromFixtureJson(
        PuzzleFixtureDocument document,
        SpatialInfo spatial,
        string fixtureJson,
        out IReadOnlyDictionary<string, GridPosition> placements)
    {
        placements = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
        JsonObject root;
        try
        {
            root = JsonNode.Parse(fixtureJson)?.AsObject()
                ?? throw new InvalidFixtureException("Fixture JSON is empty.");
        }
        catch (JsonException)
        {
            return false;
        }

        if (root["cells"] is not JsonArray cellsArray)
        {
            return false;
        }

        var requiredIds = document.Cells.Select(cell => cell.Id).ToHashSet(StringComparer.Ordinal);
        var result = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
        var occupied = new HashSet<GridPosition>();
        var open = spatial.OpenTiles.ToHashSet();
        foreach (var cellNode in cellsArray)
        {
            if (cellNode is not JsonObject cell)
            {
                return false;
            }

            var id = cell["id"]?.GetValue<string>() ?? "";
            if (!requiredIds.Contains(id))
            {
                return false;
            }

            var position = new GridPosition(cell["x"]?.GetValue<int>() ?? 0, cell["y"]?.GetValue<int>() ?? 0);
            if (!open.Contains(position) || !occupied.Add(position))
            {
                return false;
            }

            result[id] = position;
        }

        if (result.Count != requiredIds.Count)
        {
            return false;
        }

        placements = result;
        return true;
    }

    private static IEnumerable<IReadOnlyDictionary<string, GridPosition>> BuildPlacementsFromAscii(
        PuzzleFixtureDocument document,
        SpatialInfo spatial,
        string ascii)
    {
        var slots = ParseAsciiSlots(ascii);
        if (slots.Count == 0 || slots.Count != document.Cells.Count)
        {
            yield break;
        }

        var assignmentBuffer = new string[slots.Count];
        foreach (var assignedIds in AssignAsciiSlots(document, slots, 0, assignmentBuffer, new HashSet<string>(StringComparer.Ordinal)))
        {
            foreach (var placements in TranslateAsciiAssignment(document, spatial, slots, assignedIds))
            {
                yield return placements;
            }
        }
    }

    private static IReadOnlyList<AsciiSlot> ParseAsciiSlots(string ascii)
    {
        var slots = new List<AsciiSlot>();
        var lines = new List<string>();
        foreach (var rawLine in ascii.Replace("\r", "", StringComparison.Ordinal).Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0 || string.Equals(line, "Map:", StringComparison.OrdinalIgnoreCase))
            {
                continue;
            }

            if (line.StartsWith("Legend:", StringComparison.OrdinalIgnoreCase))
            {
                break;
            }

            lines.Add(line);
        }

        for (var y = 0; y < lines.Count; y++)
        {
            if (lines[y].Contains(' ', StringComparison.Ordinal))
            {
                var tokens = lines[y].Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
                for (var x = 0; x < tokens.Length; x++)
                {
                    if (tokens[x].All(character => character is '.' or '#'))
                    {
                        continue;
                    }

                    slots.Add(new AsciiSlot(char.ToUpperInvariant(tokens[x][0]), x, y));
                }

                continue;
            }

            for (var x = 0; x < lines[y].Length; x++)
            {
                var marker = lines[y][x];
                if (marker is '.' or ' ' or '#')
                {
                    continue;
                }

                slots.Add(new AsciiSlot(char.ToUpperInvariant(marker), x, y));
            }
        }

        return slots;
    }

    private static IEnumerable<string[]> AssignAsciiSlots(
        PuzzleFixtureDocument document,
        IReadOnlyList<AsciiSlot> slots,
        int slotIndex,
        string[] assignedIds,
        HashSet<string> usedIds)
    {
        if (slotIndex == slots.Count)
        {
            yield return assignedIds.ToArray();
            yield break;
        }

        foreach (var cell in CandidateCellsForAsciiMarker(document.Cells, slots[slotIndex].Marker))
        {
            if (!usedIds.Add(cell.Id))
            {
                continue;
            }

            assignedIds[slotIndex] = cell.Id;
            foreach (var assignment in AssignAsciiSlots(document, slots, slotIndex + 1, assignedIds, usedIds))
            {
                yield return assignment;
            }

            usedIds.Remove(cell.Id);
        }
    }

    private static IEnumerable<SearchCell> CandidateCellsForAsciiMarker(IReadOnlyList<SearchCell> cells, char marker)
    {
        return cells
            .Where(cell => marker switch
            {
                '0' => cell.Kind == CellKind.WhiteMyco,
                '*' => cell.Kind == CellKind.RedMyco,
                _ => !string.IsNullOrEmpty(cell.ProducedResource)
                    && char.ToUpperInvariant(cell.ProducedResource[0]) == marker
            })
            .OrderBy(cell => cell.Id, StringComparer.Ordinal);
    }

    private static IEnumerable<IReadOnlyDictionary<string, GridPosition>> TranslateAsciiAssignment(
        PuzzleFixtureDocument document,
        SpatialInfo spatial,
        IReadOnlyList<AsciiSlot> slots,
        IReadOnlyList<string> assignedIds)
    {
        var minX = slots.Min(slot => slot.X);
        var minY = slots.Min(slot => slot.Y);
        var maxX = slots.Max(slot => slot.X);
        var maxY = slots.Max(slot => slot.Y);
        var open = spatial.OpenTiles.ToHashSet();
        var translations = new List<(int X, int Y)>();
        for (var dy = -minY; dy <= document.Height - 1 - maxY; dy++)
        {
            for (var dx = -minX; dx <= document.Width - 1 - maxX; dx++)
            {
                translations.Add((dx, dy));
            }
        }

        foreach (var translation in translations
            .OrderBy(item => TemplateCenterDistanceScore(slots, item.X, item.Y, document.Width, document.Height))
            .ThenBy(item => item.Y)
            .ThenBy(item => item.X))
        {
            var placements = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
            var occupied = new HashSet<GridPosition>();
            var valid = true;
            for (var i = 0; i < slots.Count; i++)
            {
                var position = new GridPosition(slots[i].X + translation.X, slots[i].Y + translation.Y);
                if (!open.Contains(position) || !occupied.Add(position))
                {
                    valid = false;
                    break;
                }

                placements[assignedIds[i]] = position;
            }

            if (valid)
            {
                yield return placements;
            }
        }
    }

    private static int TemplateCenterDistanceScore(
        IReadOnlyList<AsciiSlot> slots,
        int offsetX,
        int offsetY,
        int width,
        int height)
    {
        var minX = slots.Min(slot => slot.X + offsetX);
        var minY = slots.Min(slot => slot.Y + offsetY);
        var maxX = slots.Max(slot => slot.X + offsetX);
        var maxY = slots.Max(slot => slot.Y + offsetY);
        var centerX = minX + maxX;
        var centerY = minY + maxY;
        var dx = centerX - (width - 1);
        var dy = centerY - (height - 1);
        return dx * dx + dy * dy;
    }

    private static IReadOnlyList<LayoutState> BuildBeamLayouts(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        int[] order,
        int beamSize,
        int variant)
    {
        var firstCell = order[0];
        var initialTiles = spatial.OpenTiles
            .OrderByDescending(tile => spatial.TileDegrees[tile])
            .ThenBy(tile => TileCenterDistanceScore(tile, document.Width, document.Height))
            .ThenBy(tile => RotateTie(tile.X * 397 + tile.Y * 97, variant))
            .Take(Math.Max(1, Math.Min(beamSize, spatial.OpenTiles.Count)))
            .Select(tile => LayoutState.Create(document.Cells.Count, firstCell, tile, spatial))
            .ToList();
        var beam = initialTiles;

        for (var orderIndex = 1; orderIndex < order.Length; orderIndex++)
        {
            var cellIndex = order[orderIndex];
            var next = new List<LayoutState>(beam.Count * 4);
            foreach (var state in beam)
            {
                foreach (var tile in EnumeratePlacementTiles(state, spatial, variant).Take(MaxTileExpansionsPerState))
                {
                    var placed = state.Place(cellIndex, tile, document, graph, spatial, variant);
                    next.Add(placed);
                }
            }

            beam = next
                .OrderByDescending(state => state.Score)
                .ThenBy(state => state.BuildKey(document.Cells), StringComparer.Ordinal)
                .Take(Math.Max(1, beamSize))
                .ToList();
            if (beam.Count == 0)
            {
                break;
            }
        }

        return beam
            .Where(state => state.PlacedCount == document.Cells.Count)
            .OrderByDescending(state => state.Score)
            .ThenByDescending(state => state.ConnectedCells)
            .ToArray();
    }

    private static IEnumerable<GridPosition> EnumeratePlacementTiles(LayoutState state, SpatialInfo spatial, int variant)
    {
        var adjacent = new HashSet<GridPosition>();
        foreach (var tile in state.PlacedTiles)
        {
            foreach (var neighbor in spatial.Neighbors[tile])
            {
                if (!state.IsOccupied(neighbor))
                {
                    adjacent.Add(neighbor);
                }
            }
        }

        var preferred = adjacent.Count > 0 ? adjacent : spatial.OpenTiles.Where(tile => !state.IsOccupied(tile));
        return preferred
            .OrderByDescending(tile => CountPlacedNeighbors(tile, state, spatial))
            .ThenByDescending(tile => spatial.TileDegrees[tile])
            .ThenBy(tile => RotateTie(tile.X * 521 + tile.Y * 131, variant));
    }

    private static int CountPlacedNeighbors(GridPosition tile, LayoutState state, SpatialInfo spatial) =>
        spatial.Neighbors[tile].Count(state.IsOccupied);

    private static int[] BuildCellOrder(IReadOnlyList<SearchCell> cells, CellGraphInfo graph, int variant)
    {
        var ranked = Enumerable.Range(0, cells.Count)
            .OrderByDescending(index => graph.WeightedDegrees[index])
            .ThenBy(index => cells[index].Id, StringComparer.Ordinal)
            .ToArray();
        if (ranked.Length <= 1)
        {
            return ranked;
        }

        var startWindow = Math.Min(ranked.Length, Math.Max(1, ranked.Length / 3));
        var startOffset = variant % startWindow;
        if (startOffset == 0)
        {
            return ranked;
        }

        var selectedStart = ranked[startOffset];
        var order = new int[ranked.Length];
        order[0] = selectedStart;
        var write = 1;
        foreach (var index in ranked)
        {
            if (index != selectedStart)
            {
                order[write++] = index;
            }
        }

        return order;
    }

    private static CellGraphInfo BuildCellGraph(IReadOnlyList<SearchCell> cells)
    {
        var weights = new int[cells.Count, cells.Count];
        var weightedDegrees = new int[cells.Count];
        var usefulEdges = 0;
        var reciprocalEdges = 0;
        for (var i = 0; i < cells.Count; i++)
        {
            for (var j = i + 1; j < cells.Count; j++)
            {
                var weight = ScoreCellMatch(cells[i], cells[j]);
                if (weight <= 0)
                {
                    continue;
                }

                weights[i, j] = weight;
                weights[j, i] = weight;
                weightedDegrees[i] += weight;
                weightedDegrees[j] += weight;
                usefulEdges++;
                if (HasReciprocalMainNeed(cells[i], cells[j]))
                {
                    reciprocalEdges++;
                }
            }
        }

        return new CellGraphInfo(weights, weightedDegrees, usefulEdges, reciprocalEdges);
    }

    private static int ScoreCellMatch(SearchCell a, SearchCell b)
    {
        var score = 0;
        var aMainNeedsB = !string.IsNullOrEmpty(b.ProducedResource) && a.Needs.Contains(b.ProducedResource, StringComparer.Ordinal);
        var bMainNeedsA = !string.IsNullOrEmpty(a.ProducedResource) && b.Needs.Contains(a.ProducedResource, StringComparer.Ordinal);
        if (aMainNeedsB && bMainNeedsA)
        {
            score += 1_000;
        }
        else
        {
            if (aMainNeedsB)
            {
                score += 300;
            }

            if (bMainNeedsA)
            {
                score += 300;
            }
        }

        score += a.Needs.Intersect(b.Offers, StringComparer.Ordinal).Count() * 150;
        score += b.Needs.Intersect(a.Offers, StringComparer.Ordinal).Count() * 150;

        if (!string.IsNullOrEmpty(a.ProducedResource)
            && string.Equals(a.ProducedResource, b.ProducedResource, StringComparison.Ordinal))
        {
            score -= 420;
        }

        if (a.IsMyco && b.IsMyco)
        {
            score -= 320;
        }
        else if (a.IsMyco || b.IsMyco)
        {
            score -= 110;
        }

        if (!aMainNeedsB && !bMainNeedsA)
        {
            score -= 180;
        }

        return Math.Max(0, score);
    }

    private static bool HasReciprocalMainNeed(SearchCell a, SearchCell b) =>
        !string.IsNullOrEmpty(a.ProducedResource)
        && !string.IsNullOrEmpty(b.ProducedResource)
        && a.Needs.Contains(b.ProducedResource, StringComparer.Ordinal)
        && b.Needs.Contains(a.ProducedResource, StringComparer.Ordinal);

    private static SpatialInfo BuildSpatialInfo(PuzzleFixtureDocument document)
    {
        var rocks = document.Rocks.ToHashSet();
        var openTiles = new List<GridPosition>(document.Width * document.Height - rocks.Count);
        for (var y = 0; y < document.Height; y++)
        {
            for (var x = 0; x < document.Width; x++)
            {
                var tile = new GridPosition(x, y);
                if (!rocks.Contains(tile))
                {
                    openTiles.Add(tile);
                }
            }
        }

        var openSet = openTiles.ToHashSet();
        var neighbors = new Dictionary<GridPosition, GridPosition[]>();
        var degrees = new Dictionary<GridPosition, int>();
        foreach (var tile in openTiles)
        {
            var tileNeighbors = EnumerateOrthogonalNeighbors(tile)
                .Where(openSet.Contains)
                .ToArray();
            neighbors[tile] = tileNeighbors;
            degrees[tile] = tileNeighbors.Length;
        }

        return new SpatialInfo(openTiles, neighbors, degrees, ComputeLargestOpenComponent(openTiles, neighbors));
    }

    private static int ComputeLargestOpenComponent(
        IReadOnlyList<GridPosition> openTiles,
        IReadOnlyDictionary<GridPosition, GridPosition[]> neighbors)
    {
        var seen = new HashSet<GridPosition>();
        var best = 0;
        var queue = new Queue<GridPosition>();
        foreach (var start in openTiles)
        {
            if (!seen.Add(start))
            {
                continue;
            }

            var count = 0;
            queue.Enqueue(start);
            while (queue.Count > 0)
            {
                var tile = queue.Dequeue();
                count++;
                foreach (var neighbor in neighbors[tile])
                {
                    if (seen.Add(neighbor))
                    {
                        queue.Enqueue(neighbor);
                    }
                }
            }

            best = Math.Max(best, count);
        }

        return best;
    }

    private static CandidateEvaluation EvaluateCandidate(FixtureLoadResult loaded, int ticks)
    {
        var engine = new CellularEngine(loaded.World, loaded.Options);
        var perTickSwaps = new Queue<int>(FlowWindowTicks);
        var rollingSwaps = 0;
        var bestTenTickSwaps = 0;
        var totalSwaps = 0;
        var totalReactions = 0;
        var activeCells = new HashSet<string>(StringComparer.Ordinal);
        var firstWinTick = -1;
        for (var i = 0; i < ticks; i++)
        {
            engine.Tick();
            var tickSwaps = 0;
            var events = engine.Events;
            for (var eventIndex = events.Count - 1; eventIndex >= 0; eventIndex--)
            {
                var simEvent = events[eventIndex];
                if (simEvent.Tick < engine.CurrentTick)
                {
                    break;
                }

                if (simEvent.Tick != engine.CurrentTick)
                {
                    continue;
                }

                switch (simEvent)
                {
                    case SwapEvent swap:
                        tickSwaps++;
                        totalSwaps++;
                        activeCells.Add(swap.InitiatorCellId);
                        activeCells.Add(swap.CounterpartyCellId);
                        break;
                    case ReactionEvent reaction:
                        totalReactions++;
                        activeCells.Add(reaction.CellId);
                        break;
                }
            }

            rollingSwaps += tickSwaps;
            perTickSwaps.Enqueue(tickSwaps);
            if (perTickSwaps.Count > FlowWindowTicks)
            {
                rollingSwaps -= perTickSwaps.Dequeue();
            }

            bestTenTickSwaps = Math.Max(bestTenTickSwaps, rollingSwaps);
            if (engine.Circuit.IsWon)
            {
                firstWinTick = (int)engine.CurrentTick;
                break;
            }
        }

        var glowing = engine.World.Cells.Count(cell => cell.IsGlowing);
        var diagnostics = CircuitDiagnostics.Build(engine);
        var emptyNeedsByCell = BuildEmptyNeedsByCell(loaded, engine);
        var lastReactionTicks = BuildLastReactionTicks(engine.Events);
        var recentFlows = BuildRecentFlowSummary(loaded, engine);
        var summaryDiagnostics = BuildDiagnosticsText(loaded, diagnostics);
        var detailedDiagnostics = BuildDetailedDiagnostics(loaded, engine, diagnostics, lastReactionTicks, recentFlows);
        return new CandidateEvaluation(
            firstWinTick >= 0,
            firstWinTick,
            bestTenTickSwaps / (double)FlowWindowTicks,
            bestTenTickSwaps,
            totalSwaps,
            totalReactions,
            engine.Circuit.SustainedTicks,
            activeCells.Count,
            glowing,
            engine.Score.TotalScore,
            diagnostics.NonGlowingRequiredCells,
            diagnostics.MissingRequiredResources.Count,
            emptyNeedsByCell,
            summaryDiagnostics,
            detailedDiagnostics);
    }

    private static Dictionary<string, string[]> BuildEmptyNeedsByCell(FixtureLoadResult loaded, CellularEngine engine)
    {
        var result = new Dictionary<string, string[]>(StringComparer.Ordinal);
        foreach (var cell in engine.World.Cells)
        {
            var emptyNeeds = cell.Pool.Slots
                .Where(slot => slot.Role == PoolSlotRole.Need && slot.Quantity <= 0)
                .Select(slot => loaded.Catalog.GetName(slot.Resource))
                .Distinct(StringComparer.Ordinal)
                .OrderBy(name => name, StringComparer.Ordinal)
                .ToArray();
            if (emptyNeeds.Length > 0)
            {
                result[cell.Id] = emptyNeeds;
            }
        }

        return result;
    }

    private static string SerializeNeedsByCell(IReadOnlyDictionary<string, string[]> needsByCell)
    {
        if (needsByCell.Count == 0)
        {
            return "";
        }

        return string.Join(";", needsByCell
            .OrderBy(pair => pair.Key, StringComparer.Ordinal)
            .Select(pair => $"{pair.Key}:{string.Join("|", pair.Value.OrderBy(name => name, StringComparer.Ordinal))}"));
    }

    private static Dictionary<string, string[]> ParseNeedsByCell(string text)
    {
        var result = new Dictionary<string, string[]>(StringComparer.Ordinal);
        if (string.IsNullOrWhiteSpace(text))
        {
            return result;
        }

        foreach (var entry in text.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            var splitAt = entry.IndexOf(':', StringComparison.Ordinal);
            if (splitAt <= 0 || splitAt >= entry.Length - 1)
            {
                continue;
            }

            var cellId = entry[..splitAt];
            var needs = entry[(splitAt + 1)..]
                .Split('|', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                .Distinct(StringComparer.Ordinal)
                .OrderBy(name => name, StringComparer.Ordinal)
                .ToArray();
            if (needs.Length > 0)
            {
                result[cellId] = needs;
            }
        }

        return result;
    }

    private static Dictionary<string, long> BuildLastReactionTicks(IEnumerable<SimEvent> events)
    {
        var result = new Dictionary<string, long>(StringComparer.Ordinal);
        foreach (var simEvent in events)
        {
            if (simEvent is ReactionEvent reaction)
            {
                result[reaction.CellId] = Math.Max(result.GetValueOrDefault(reaction.CellId, -1), reaction.Tick);
            }
        }

        return result;
    }

    private static Dictionary<string, RecentFlowAccumulator> BuildRecentFlowSummary(FixtureLoadResult loaded, CellularEngine engine)
    {
        var sinceTick = engine.CurrentTick - loaded.Options.WinRecentFlowWindowTicks;
        var result = new Dictionary<string, RecentFlowAccumulator>(StringComparer.Ordinal);
        foreach (var cell in engine.World.Cells)
        {
            result[cell.Id] = new RecentFlowAccumulator();
        }

        foreach (var simEvent in engine.Events)
        {
            if (simEvent is not FlowEvent flow || flow.Tick < sinceTick)
            {
                continue;
            }

            if (!result.TryGetValue(flow.SourceCellId, out var source))
            {
                source = new RecentFlowAccumulator();
                result.Add(flow.SourceCellId, source);
            }

            if (!result.TryGetValue(flow.TargetCellId, out var target))
            {
                target = new RecentFlowAccumulator();
                result.Add(flow.TargetCellId, target);
            }

            var resource = loaded.Catalog.GetName(flow.Resource);
            source.Out.Add(resource);
            target.In.Add(resource);
        }

        return result;
    }

    private static string BuildDetailedDiagnostics(
        FixtureLoadResult loaded,
        CellularEngine engine,
        CircuitDiagnosticsSnapshot diagnostics,
        IReadOnlyDictionary<string, long> lastReactionTicks,
        IReadOnlyDictionary<string, RecentFlowAccumulator> recentFlows)
    {
        var builder = new StringBuilder();
        builder.Append(BuildDiagnosticsText(loaded, diagnostics));
        builder.AppendLine();
        builder.AppendLine("required cell details:");
        IReadOnlyList<string> requiredCells = loaded.Options.RequiredCellIds.Count > 0
            ? loaded.Options.RequiredCellIds
            : engine.World.Cells.Select(cell => cell.Id).ToArray();
        foreach (var cellId in requiredCells.OrderBy(id => id, StringComparer.Ordinal))
        {
            if (!engine.World.TryGetCell(cellId, out var cell) || cell is null)
            {
                builder.AppendLine($"  {cellId}: missing");
                continue;
            }

            var adjacent = engine.World.AdjacentEdges
                .Where(edge => engine.World.Cells[edge.A].Id == cellId || engine.World.Cells[edge.B].Id == cellId)
                .Select(edge => engine.World.Cells[edge.A].Id == cellId ? engine.World.Cells[edge.B].Id : engine.World.Cells[edge.A].Id)
                .OrderBy(id => id, StringComparer.Ordinal)
                .ToArray();
            var needs = cell.Pool.Slots
                .Where(slot => slot.Role == PoolSlotRole.Need)
                .Select(slot => $"{loaded.Catalog.GetName(slot.Resource)}={slot.Quantity}/{slot.Capacity}")
                .ToArray();
            recentFlows.TryGetValue(cellId, out var flow);
            var lastReaction = lastReactionTicks.TryGetValue(cellId, out var tick)
                ? tick.ToString(CultureInfo.InvariantCulture)
                : "none";
            builder.Append("  ").Append(cellId)
                .Append(": glowing=").Append(cell.IsGlowing ? "yes" : "no")
                .Append(" lastReaction=").Append(lastReaction)
                .Append(" adjacent=").Append(adjacent.Length == 0 ? "none" : string.Join("|", adjacent))
                .Append(" needs=").Append(needs.Length == 0 ? "none" : string.Join("|", needs))
                .Append(" stress=").Append(cell.Strain.Total.ToString(CultureInfo.InvariantCulture))
                .Append("(unmet=").Append(cell.Strain.UnmetNeedTicks.ToString(CultureInfo.InvariantCulture))
                .Append(",sourceBlocked=").Append(cell.Strain.SourceBlockedTicks.ToString(CultureInfo.InvariantCulture))
                .Append(",overCapacity=").Append(cell.Strain.OverCapacityPressureTicks.ToString(CultureInfo.InvariantCulture))
                .Append(",failedSwap=").Append(cell.Strain.FailedSwapCount.ToString(CultureInfo.InvariantCulture))
                .Append(')')
                .Append(" recentIn=").Append(flow is null || flow.In.Count == 0 ? "none" : string.Join("|", flow.In.OrderBy(name => name, StringComparer.Ordinal)))
                .Append(" recentOut=").Append(flow is null || flow.Out.Count == 0 ? "none" : string.Join("|", flow.Out.OrderBy(name => name, StringComparer.Ordinal)))
                .AppendLine();
        }

        return builder.ToString().TrimEnd();
    }

    private static int ComputeCandidateEventCapacity(FixtureLoadResult loaded, int requestedCapacity)
    {
        var cells = Math.Max(1, loaded.World.Cells.Count);
        var recentWindow = Math.Max(loaded.Options.WinRecentFlowWindowTicks, FlowWindowTicks);
        var perTickBudget = Math.Max(64, cells * Math.Max(1, loaded.Options.SwapRoundsPerTick) * 8);
        var needed = Math.Max(4096, perTickBudget * (recentWindow + loaded.Options.WinDurationTicks + 4));
        return Math.Min(requestedCapacity, needed);
    }

    private static string BuildDiagnosticsText(FixtureLoadResult loaded, CircuitDiagnosticsSnapshot diagnostics)
    {
        static string Groups(IReadOnlyList<CircuitDiagnosticGroup> groups) =>
            groups.Count == 0
                ? "none"
                : string.Join("|", groups.Select(group => $"[{string.Join(",", group.CellIds)}]"));

        var missingResources = diagnostics.MissingRequiredResources.Count == 0
            ? "none"
            : string.Join(",", diagnostics.MissingRequiredResources.Select(loaded.Catalog.GetName));
        var nonGlowing = diagnostics.NonGlowingRequiredCells.Count == 0
            ? "none"
            : string.Join(",", diagnostics.NonGlowingRequiredCells);
        return $"alive={diagnostics.IsAlive};won={diagnostics.IsWon};sustained={diagnostics.SustainedTicks};"
            + $"nonGlowing={nonGlowing};missingResources={missingResources};"
            + $"strong={Groups(diagnostics.StrongGroups)};weak={Groups(diagnostics.WeakGroups)}";
    }

    private static string BuildResourceGraphDiagnostics(PuzzleFixtureDocument document, CellGraphInfo graph)
    {
        var builder = new StringBuilder();
        builder.AppendLine("resource graph:");
        var providerCounts = document.Cells
            .Where(cell => !string.IsNullOrEmpty(cell.ProducedResource))
            .GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal)
            .OrderBy(group => group.Key, StringComparer.Ordinal)
            .Select(group => $"{group.Key}={group.Count()}")
            .ToArray();
        builder.AppendLine($"  provider counts: {(providerCounts.Length == 0 ? "none" : string.Join(", ", providerCounts))}");

        var duplicates = document.Cells
            .Where(cell => !string.IsNullOrEmpty(cell.ProducedResource))
            .GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal)
            .Where(group => group.Count() > 1)
            .OrderBy(group => group.Key, StringComparer.Ordinal)
            .Select(group => $"{group.Key}:[{string.Join("|", group.Select(cell => cell.Id).OrderBy(id => id, StringComparer.Ordinal))}]")
            .ToArray();
        builder.AppendLine($"  duplicate producers: {(duplicates.Length == 0 ? "none" : string.Join(", ", duplicates))}");

        var reciprocalPairs = new List<string>();
        for (var i = 0; i < document.Cells.Count; i++)
        {
            for (var j = i + 1; j < document.Cells.Count; j++)
            {
                if (HasReciprocalMainNeed(document.Cells[i], document.Cells[j]))
                {
                    reciprocalPairs.Add($"{document.Cells[i].Id}<->{document.Cells[j].Id}");
                }
            }
        }

        builder.AppendLine($"  reciprocal pairs: {(reciprocalPairs.Count == 0 ? "none" : string.Join(", ", reciprocalPairs.OrderBy(pair => pair, StringComparer.Ordinal)))}");

        var bottlenecks = Enumerable.Range(0, document.Cells.Count)
            .Select(index => (Cell: document.Cells[index], Score: ComputeCellBottleneckScore(document.Cells[index], document.Cells), Degree: graph.WeightedDegrees[index]))
            .Where(item => item.Score > 0)
            .OrderByDescending(item => item.Score)
            .ThenByDescending(item => item.Degree)
            .ThenBy(item => item.Cell.Id, StringComparer.Ordinal)
            .Take(8)
            .Select(item => $"{item.Cell.Id}(produces={EmptyToNone(item.Cell.ProducedResource)},needs={string.Join("|", item.Cell.Needs)},score={item.Score})")
            .ToArray();
        builder.AppendLine($"  bottleneck cells: {(bottlenecks.Length == 0 ? "none" : string.Join(", ", bottlenecks))}");

        return builder.ToString().TrimEnd();
    }

    private static IReadOnlyList<CandidateRepairSeed> BuildStressNeedRepairSeeds(
        PuzzleSolutionCandidateReport? bestReport,
        IReadOnlyDictionary<string, GridPosition>? bestPlacements,
        PuzzleSolutionCandidateReport? bestFlowReport,
        IReadOnlyDictionary<string, GridPosition>? bestFlowPlacements)
    {
        var seeds = new List<CandidateRepairSeed>(2);
        var seen = new HashSet<string>(StringComparer.Ordinal);
        AddSeed(bestFlowReport, bestFlowPlacements);
        AddSeed(bestReport, bestPlacements);
        return seeds;

        void AddSeed(PuzzleSolutionCandidateReport? report, IReadOnlyDictionary<string, GridPosition>? placements)
        {
            if (report is null || placements is null)
            {
                return;
            }

            var key = BuildPlacementKeyFromPairs(placements);
            if (!seen.Add(key))
            {
                return;
            }

            seeds.Add(new CandidateRepairSeed(
                new PuzzleSolutionCandidateLayout(report.CandidateIndex, placements, report.ConnectedCells, report.LayoutScore),
                report));
        }
    }

    private static IEnumerable<StressNeedRepairVariant> GenerateStressNeedRepairVariants(
        PuzzleFixtureDocument document,
        SpatialInfo spatial,
        IReadOnlyList<CandidateRepairSeed> seeds,
        int candidateLimit)
    {
        if (candidateLimit <= 0)
        {
            yield break;
        }

        var emitted = 0;
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var seed in seeds
            .OrderByDescending(seed => seed.Report.BestTenTickFlow)
            .ThenBy(seed => seed.Report.NonGlowingRequiredCellCount)
            .ThenByDescending(seed => seed.Report.GlowingCells)
            .ThenBy(seed => seed.Layout.CandidateIndex))
        {
            var edits = GenerateStressNeedRepairEdits(document, seed.Layout.Placements, seed.Report)
                .OrderByDescending(edit => edit.Score)
                .ThenBy(edit => edit.CellId, StringComparer.Ordinal)
                .ThenBy(edit => edit.NeedIndex)
                .ThenBy(edit => edit.NewNeed, StringComparer.Ordinal)
                .Take(32)
                .ToArray();
            if (edits.Length == 0)
            {
                continue;
            }

            foreach (var editSet in GenerateNeedEditSets(edits, candidateLimit - emitted))
            {
                var editKey = BuildNeedEditKey(editSet);
                if (!seen.Add($"{BuildPlacementKeyFromPairs(seed.Layout.Placements)}|{editKey}"))
                {
                    continue;
                }

                if (!TryBuildNeedRepairedDocument(document, editSet, out var repaired))
                {
                    continue;
                }

                var repairedGraph = BuildCellGraph(repaired.Cells);
                if (LayoutState.TryCreate(seed.Layout.Placements, repaired, repairedGraph, spatial, variant: seed.Layout.CandidateIndex) is not { } state)
                {
                    continue;
                }

                yield return new StressNeedRepairVariant(
                    repaired,
                    seed.Layout.Placements,
                    editKey,
                    string.Join("; ", editSet.Select(edit => edit.Reason)),
                    state.ConnectedCells,
                    state.Score);
                emitted++;
                if (emitted >= candidateLimit)
                {
                    yield break;
                }
            }
        }
    }

    private static IEnumerable<NeedEdit> GenerateStressNeedRepairEdits(
        PuzzleFixtureDocument document,
        IReadOnlyDictionary<string, GridPosition> placements,
        PuzzleSolutionCandidateReport report)
    {
        var byPosition = placements.ToDictionary(pair => pair.Value, pair => pair.Key);
        var cellsById = document.Cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var emptyNeedsByCell = ParseNeedsByCell(report.EmptyNeedsByCell);
        var blockerIds = ParseCellIdList(report.NonGlowingRequiredCells).ToHashSet(StringComparer.Ordinal);
        var focusIds = blockerIds
            .Concat(emptyNeedsByCell.Keys)
            .Distinct(StringComparer.Ordinal)
            .OrderBy(id => id, StringComparer.Ordinal)
            .ToArray();
        if (focusIds.Length == 0)
        {
            focusIds = document.Cells
                .Where(cell => cell.Needs.Length > 0)
                .OrderBy(cell => cell.Id, StringComparer.Ordinal)
                .Select(cell => cell.Id)
                .ToArray();
        }

        foreach (var focusId in focusIds)
        {
            if (!cellsById.TryGetValue(focusId, out var focus) || !placements.TryGetValue(focusId, out var focusPosition))
            {
                continue;
            }

            emptyNeedsByCell.TryGetValue(focusId, out var focusEmptyNeeds);
            foreach (var edit in GenerateCellLocalNeedEdits(
                focus,
                focusPosition,
                byPosition,
                cellsById,
                emptyNeedsByCell,
                focusEmptyNeeds ?? Array.Empty<string>(),
                blockerIds.Contains(focus.Id)))
            {
                yield return edit;
            }

            foreach (var neighbor in AdjacentCells(focusPosition, byPosition, cellsById)
                .Where(neighbor => neighbor.Needs.Length > 0)
                .OrderBy(neighbor => neighbor.Id, StringComparer.Ordinal))
            {
                if (string.IsNullOrEmpty(focus.ProducedResource)
                    || neighbor.Needs.Contains(focus.ProducedResource, StringComparer.Ordinal)
                    || string.Equals(neighbor.ProducedResource, focus.ProducedResource, StringComparison.Ordinal))
                {
                    continue;
                }

                if (!placements.TryGetValue(neighbor.Id, out var neighborPosition))
                {
                    continue;
                }

                var neighborLocalResources = AdjacentCells(neighborPosition, byPosition, cellsById)
                    .Where(cell => !string.IsNullOrEmpty(cell.ProducedResource))
                    .Select(cell => cell.ProducedResource)
                    .ToHashSet(StringComparer.Ordinal);
                emptyNeedsByCell.TryGetValue(neighbor.Id, out var neighborEmptyNeeds);
                var replaceableNeeds = SelectReplaceableNeeds(neighbor, neighborLocalResources, neighborEmptyNeeds ?? Array.Empty<string>());
                foreach (var (needIndex, oldNeed) in replaceableNeeds)
                {
                    if (!CanReplaceNeed(neighbor, needIndex, focus.ProducedResource))
                    {
                        continue;
                    }

                    var focusEmptyNeedSet = (focusEmptyNeeds ?? Array.Empty<string>()).ToHashSet(StringComparer.Ordinal);
                    var focusNeedsNeighbor = !string.IsNullOrEmpty(neighbor.ProducedResource)
                        && focus.Needs.Contains(neighbor.ProducedResource, StringComparer.Ordinal);
                    var focusMissingNeighbor = !string.IsNullOrEmpty(neighbor.ProducedResource)
                        && focusEmptyNeedSet.Contains(neighbor.ProducedResource);
                    var reciprocalBonus = focusNeedsNeighbor ? 18_000 : 0;
                    var stressedPairBonus = focusMissingNeighbor ? 35_000 : 0;
                    var emptyBonus = (neighborEmptyNeeds ?? Array.Empty<string>()).Contains(oldNeed, StringComparer.Ordinal) ? 60_000 : 0;
                    yield return new NeedEdit(
                        neighbor.Id,
                        needIndex,
                        oldNeed,
                        focus.ProducedResource,
                        45_000 + emptyBonus + reciprocalBonus + stressedPairBonus,
                        $"{neighbor.Id}: neighbor repair {oldNeed}->{focus.ProducedResource} so adjacent {focus.Id} can trade its {focus.ProducedResource}");
                }
            }
        }
    }

    private static IEnumerable<NeedEdit> GenerateCellLocalNeedEdits(
        SearchCell cell,
        GridPosition position,
        IReadOnlyDictionary<GridPosition, string> byPosition,
        IReadOnlyDictionary<string, SearchCell> cellsById,
        IReadOnlyDictionary<string, string[]> emptyNeedsByCell,
        IReadOnlyList<string> emptyNeeds,
        bool isNonGlowingFocus)
    {
        var adjacentOptions = BuildAdjacentResourceOptions(cell, position, byPosition, cellsById, emptyNeedsByCell)
            .OrderByDescending(option => option.IsProduced)
            .ThenByDescending(option => option.IsOffered)
            .ThenByDescending(option => option.IsNonEmptyNeed)
            .ThenByDescending(option => option.IsReciprocal)
            .ThenBy(option => option.ProviderId, StringComparer.Ordinal)
            .ThenBy(option => option.Resource, StringComparer.Ordinal)
            .ToArray();
        if (adjacentOptions.Length == 0)
        {
            yield break;
        }

        var adjacentResources = adjacentOptions
            .Select(option => option.Resource)
            .ToHashSet(StringComparer.Ordinal);
        var replaceableNeeds = SelectReplaceableNeeds(cell, adjacentResources, emptyNeeds);
        foreach (var (needIndex, oldNeed) in replaceableNeeds)
        {
            var yieldedReplacements = new HashSet<string>(StringComparer.Ordinal);
            foreach (var option in adjacentOptions)
            {
                var replacement = option.Resource;
                if (!CanReplaceNeed(cell, needIndex, replacement))
                {
                    continue;
                }

                if (!yieldedReplacements.Add(replacement))
                {
                    continue;
                }

                var emptyBonus = emptyNeeds.Contains(oldNeed, StringComparer.Ordinal) ? 80_000 : 0;
                var blockerBonus = isNonGlowingFocus ? 25_000 : 0;
                var reciprocalBonus = option.IsReciprocal ? 16_000 : 0;
                var unsupportedBonus = adjacentResources.Contains(oldNeed) ? 0 : 6_000;
                var sourceBonus = option.IsProduced
                    ? 22_000
                    : option.IsOffered
                        ? 14_000
                        : option.IsNonEmptyNeed
                            ? 10_000
                            : 2_000;
                var liveNeedBonus = option.IsCarriedNeed && option.IsNonEmptyNeed ? 12_000 : 0;
                yield return new NeedEdit(
                    cell.Id,
                    needIndex,
                    oldNeed,
                    replacement,
                    50_000 + sourceBonus + liveNeedBonus + emptyBonus + blockerBonus + reciprocalBonus + unsupportedBonus,
                    $"{cell.Id}: empty/local stress {oldNeed}->{replacement} from adjacent {option.ProviderId} ({option.SourceLabel})");
            }
        }
    }

    private static IEnumerable<AdjacentResourceOption> BuildAdjacentResourceOptions(
        SearchCell cell,
        GridPosition position,
        IReadOnlyDictionary<GridPosition, string> byPosition,
        IReadOnlyDictionary<string, SearchCell> cellsById,
        IReadOnlyDictionary<string, string[]>? emptyNeedsByCell = null)
    {
        foreach (var neighbor in AdjacentCells(position, byPosition, cellsById)
            .OrderBy(neighbor => neighbor.Id, StringComparer.Ordinal))
        {
            string[]? neighborEmptyNeeds = null;
            emptyNeedsByCell?.TryGetValue(neighbor.Id, out neighborEmptyNeeds);
            var neighborEmptyNeedSet = (neighborEmptyNeeds ?? Array.Empty<string>()).ToHashSet(StringComparer.Ordinal);
            var reciprocal = !string.IsNullOrEmpty(cell.ProducedResource)
                && neighbor.Needs.Contains(cell.ProducedResource, StringComparer.Ordinal);
            if (!string.IsNullOrEmpty(neighbor.ProducedResource))
            {
                yield return new AdjacentResourceOption(
                    neighbor.ProducedResource,
                    neighbor.Id,
                    IsProduced: true,
                    IsOffered: true,
                    IsCarriedNeed: false,
                    IsNonEmptyNeed: true,
                    reciprocal,
                    "produced");
            }

            foreach (var offer in neighbor.Offers.OrderBy(resource => resource, StringComparer.Ordinal))
            {
                if (string.Equals(offer, neighbor.ProducedResource, StringComparison.Ordinal))
                {
                    continue;
                }

                yield return new AdjacentResourceOption(
                    offer,
                    neighbor.Id,
                    IsProduced: false,
                    IsOffered: true,
                    IsCarriedNeed: false,
                    IsNonEmptyNeed: true,
                    reciprocal,
                    "offered");
            }

            foreach (var need in neighbor.Needs.OrderBy(resource => resource, StringComparer.Ordinal))
            {
                if (neighbor.Offers.Contains(need, StringComparer.Ordinal)
                    || string.Equals(need, neighbor.ProducedResource, StringComparison.Ordinal))
                {
                    continue;
                }

                var isNonEmptyNeed = emptyNeedsByCell is null || !neighborEmptyNeedSet.Contains(need);
                if (!isNonEmptyNeed && emptyNeedsByCell is not null)
                {
                    continue;
                }

                yield return new AdjacentResourceOption(
                    need,
                    neighbor.Id,
                    IsProduced: false,
                    IsOffered: false,
                    IsCarriedNeed: true,
                    isNonEmptyNeed,
                    reciprocal,
                    "nonzero carried need");
            }
        }
    }

    private static IEnumerable<(int NeedIndex, string OldNeed)> SelectReplaceableNeeds(
        SearchCell cell,
        IReadOnlySet<string> adjacentResources,
        IReadOnlyList<string> emptyNeeds)
    {
        var emptySet = emptyNeeds.ToHashSet(StringComparer.Ordinal);
        var yielded = new HashSet<int>();
        for (var index = 0; index < cell.Needs.Length; index++)
        {
            if (emptySet.Contains(cell.Needs[index]))
            {
                yielded.Add(index);
                yield return (index, cell.Needs[index]);
            }
        }

        for (var index = 0; index < cell.Needs.Length; index++)
        {
            if (!yielded.Contains(index) && !adjacentResources.Contains(cell.Needs[index]))
            {
                yielded.Add(index);
                yield return (index, cell.Needs[index]);
            }
        }
    }

    private static bool CanReplaceNeed(SearchCell cell, int needIndex, string replacement)
    {
        if (string.IsNullOrEmpty(replacement)
            || needIndex < 0
            || needIndex >= cell.Needs.Length
            || string.Equals(cell.Needs[needIndex], replacement, StringComparison.Ordinal)
            || string.Equals(cell.ProducedResource, replacement, StringComparison.Ordinal))
        {
            return false;
        }

        for (var index = 0; index < cell.Needs.Length; index++)
        {
            if (index != needIndex && string.Equals(cell.Needs[index], replacement, StringComparison.Ordinal))
            {
                return false;
            }
        }

        return true;
    }

    private static IEnumerable<SearchCell> AdjacentCells(
        GridPosition position,
        IReadOnlyDictionary<GridPosition, string> byPosition,
        IReadOnlyDictionary<string, SearchCell> cellsById)
    {
        foreach (var neighborPosition in EnumerateOrthogonalNeighbors(position))
        {
            if (byPosition.TryGetValue(neighborPosition, out var neighborId)
                && cellsById.TryGetValue(neighborId, out var neighbor))
            {
                yield return neighbor;
            }
        }
    }

    private static IEnumerable<IReadOnlyList<NeedEdit>> GenerateNeedEditSets(IReadOnlyList<NeedEdit> edits, int candidateLimit)
    {
        var emitted = 0;
        for (var i = 0; i < edits.Count && emitted < candidateLimit; i++)
        {
            if (IsValidNeedEditSet([edits[i]]))
            {
                yield return [edits[i]];
                emitted++;
            }
        }

        var chain = new List<NeedEdit>(MaxStressNeedRepairChainEdits);
        for (var i = 0; i < edits.Count && emitted < candidateLimit && chain.Count < MaxStressNeedRepairChainEdits; i++)
        {
            var next = chain.Concat([edits[i]]).ToArray();
            if (!IsValidNeedEditSet(next))
            {
                continue;
            }

            chain.Clear();
            chain.AddRange(next);
            if (chain.Count > 1)
            {
                yield return chain.ToArray();
                emitted++;
            }
        }

        for (var i = 0; i < edits.Count && emitted < candidateLimit; i++)
        {
            for (var j = i + 1; j < edits.Count && emitted < candidateLimit; j++)
            {
                var set = new[] { edits[i], edits[j] };
                if (!IsValidNeedEditSet(set))
                {
                    continue;
                }

                yield return set;
                emitted++;
            }
        }

        for (var i = 0; i < edits.Count && emitted < candidateLimit; i++)
        {
            for (var j = i + 1; j < edits.Count && emitted < candidateLimit; j++)
            {
                for (var k = j + 1; k < edits.Count && emitted < candidateLimit; k++)
                {
                    var set = new[] { edits[i], edits[j], edits[k] };
                    if (!IsValidNeedEditSet(set))
                    {
                        continue;
                    }

                    yield return set;
                    emitted++;
                }
            }
        }
    }

    private static bool IsValidNeedEditSet(IReadOnlyList<NeedEdit> edits)
    {
        var touchedSlots = new HashSet<string>(StringComparer.Ordinal);
        foreach (var edit in edits)
        {
            if (!touchedSlots.Add($"{edit.CellId}\0{edit.NeedIndex}"))
            {
                return false;
            }
        }

        return true;
    }

    private static bool TryBuildNeedRepairedDocument(
        PuzzleFixtureDocument document,
        IReadOnlyList<NeedEdit> edits,
        out PuzzleFixtureDocument repaired)
    {
        repaired = null!;
        if (edits.Count == 0)
        {
            return false;
        }

        var cellsById = document.Cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var needsByCell = new Dictionary<string, string[]>(StringComparer.Ordinal);
        foreach (var cell in document.Cells)
        {
            needsByCell[cell.Id] = cell.Needs.ToArray();
        }

        foreach (var edit in edits)
        {
            if (!cellsById.TryGetValue(edit.CellId, out var cell) || !CanReplaceNeed(cell, edit.NeedIndex, edit.NewNeed))
            {
                return false;
            }

            needsByCell[edit.CellId][edit.NeedIndex] = edit.NewNeed;
        }

        foreach (var pair in needsByCell)
        {
            var cell = cellsById[pair.Key];
            if (!cell.IsMyco
                && pair.Value.Any(need => string.Equals(need, cell.ProducedResource, StringComparison.Ordinal)))
            {
                return false;
            }

            if (pair.Value.Distinct(StringComparer.Ordinal).Count() != pair.Value.Length)
            {
                return false;
            }
        }

        repaired = document.WithNeedEdits(edits);
        return true;
    }

    private static string BuildNeedEditKey(IReadOnlyList<NeedEdit> edits) =>
        string.Join("|", edits
            .OrderBy(edit => edit.CellId, StringComparer.Ordinal)
            .ThenBy(edit => edit.NeedIndex)
            .Select(edit => $"{edit.CellId}:{edit.NeedIndex}:{edit.OldNeed}>{edit.NewNeed}"));

    private static string BuildPlacementKeyFromPairs(IReadOnlyDictionary<string, GridPosition> placements) =>
        string.Join(";", placements
            .OrderBy(pair => pair.Key, StringComparer.Ordinal)
            .Select(pair => $"{pair.Key}@{pair.Value.X}:{pair.Value.Y}"));

    private static string BuildNeedsRepairAppliedDiagnostics(StressNeedRepairVariant variant)
    {
        var builder = new StringBuilder();
        builder.AppendLine("stress-guided needs repair applied:");
        builder.AppendLine($"  edits: {variant.EditSummary}");
        builder.AppendLine("  note: repaired-level-fixture.json contains the patched start fixture; solution-fixture.json contains the solved layout.");
        return builder.ToString().TrimEnd();
    }

    private static string BuildShapeFirstNeedsSuggestion(
        PuzzleFixtureDocument document,
        IReadOnlyDictionary<string, GridPosition> placements,
        PuzzleSolutionCandidateReport baseReport)
    {
        var byPosition = placements.ToDictionary(pair => pair.Value, pair => pair.Key);
        var cellsById = document.Cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var blockerIds = ParseCellIdList(baseReport.NonGlowingRequiredCells).ToHashSet(StringComparer.Ordinal);
        var emptyNeedsByCell = ParseNeedsByCell(baseReport.EmptyNeedsByCell);
        var suggestions = new List<string>();
        var stressActions = new List<string>();
        foreach (var cell in document.Cells.OrderBy(cell => cell.Id, StringComparer.Ordinal))
        {
            if (!placements.TryGetValue(cell.Id, out var position) || cell.Needs.Length == 0)
            {
                continue;
            }

            if (blockerIds.Count > 0 && !blockerIds.Contains(cell.Id))
            {
                continue;
            }

            var adjacentOptions = BuildAdjacentResourceOptions(cell, position, byPosition, cellsById, emptyNeedsByCell)
                .OrderByDescending(option => option.IsProduced)
                .ThenByDescending(option => option.IsOffered)
                .ThenByDescending(option => option.IsNonEmptyNeed)
                .ThenByDescending(option => option.IsReciprocal)
                .ThenBy(option => option.ProviderId, StringComparer.Ordinal)
                .ThenBy(option => option.Resource, StringComparer.Ordinal)
                .ToArray();

            var adjacentResources = adjacentOptions
                .Select(option => option.Resource)
                .Distinct(StringComparer.Ordinal)
                .ToArray();
            if (adjacentResources.Length == 0)
            {
                continue;
            }

            var adjacentResourceSet = adjacentResources.ToHashSet(StringComparer.Ordinal);
            var adjacentProviderIdsByResource = adjacentOptions
                .GroupBy(option => option.Resource, StringComparer.Ordinal)
                .ToDictionary(
                    group => group.Key,
                    group => string.Join("|", group
                        .Select(option => $"{option.ProviderId} {option.SourceLabel}")
                        .Distinct(StringComparer.Ordinal)
                        .OrderBy(text => text, StringComparer.Ordinal)),
                    StringComparer.Ordinal);
            emptyNeedsByCell.TryGetValue(cell.Id, out var emptyNeeds);
            var emptyNeedSet = (emptyNeeds ?? Array.Empty<string>()).ToHashSet(StringComparer.Ordinal);
            var proposed = cell.Needs.ToArray();
            var changedNeeds = new List<string>();
            var localStressActions = new List<string>();
            for (var needIndex = 0; needIndex < proposed.Length; needIndex++)
            {
                var oldNeed = proposed[needIndex];
                if (emptyNeedSet.Count > 0 && !emptyNeedSet.Contains(oldNeed))
                {
                    continue;
                }

                var replacement = adjacentResources.FirstOrDefault(resource =>
                    !string.Equals(resource, cell.ProducedResource, StringComparison.Ordinal)
                    && !string.Equals(resource, oldNeed, StringComparison.Ordinal)
                    && !proposed.Where((_, index) => index != needIndex).Contains(resource, StringComparer.Ordinal));
                if (!string.IsNullOrEmpty(replacement))
                {
                    proposed[needIndex] = replacement;
                    changedNeeds.Add($"{oldNeed}->{replacement}");
                    if (emptyNeedSet.Contains(oldNeed))
                    {
                        localStressActions.Add(
                            $"{cell.Id}: empty {oldNeed}; adjacent {replacement} from {adjacentProviderIdsByResource[replacement]}; edit {oldNeed}->{replacement} and keep {cell.Needs.Length} needs");
                    }
                }
                else if (emptyNeedSet.Contains(oldNeed) && !adjacentResourceSet.Contains(oldNeed))
                {
                    var providerIds = document.Cells
                        .Where(candidate => string.Equals(candidate.ProducedResource, oldNeed, StringComparison.Ordinal))
                        .Select(candidate => candidate.Id)
                        .OrderBy(id => id, StringComparer.Ordinal)
                        .ToArray();
                    var providerText = providerIds.Length == 0 ? "no provider exists" : $"move {string.Join("|", providerIds)} adjacent";
                    localStressActions.Add($"{cell.Id}: empty {oldNeed}; no adjacent provider; {providerText} or replace with an adjacent resource");
                }
            }

            if (changedNeeds.Count == 0 || proposed.SequenceEqual(cell.Needs, StringComparer.Ordinal))
            {
                stressActions.AddRange(localStressActions);
                continue;
            }

            stressActions.AddRange(localStressActions);
            suggestions.Add($"{cell.Id}: {string.Join("|", cell.Needs)} -> {string.Join("|", proposed)} ({string.Join(", ", changedNeeds)})");
        }

        var prefix = new StringBuilder();
        prefix.AppendLine("shape-first needs suggestion:");
        prefix.AppendLine("  near-miss rule: for high-flow misses, inspect stressed empty needs on non-glowing cells, then change that need to a resource produced, offered, or carried by an adjacent cell; keep distinct non-self needs.");
        prefix.AppendLine(
            $"  base candidate: {baseReport.CandidateIndex}; flow={baseReport.BestTenTickFlow:F2}; swaps={baseReport.TotalSwaps}; glowing={baseReport.GlowingCells}; active={baseReport.ActiveCellsInLastWindow}");
        prefix.AppendLine($"  need edit focus: {(blockerIds.Count == 0 ? "none; layout already has no non-glowing blockers" : string.Join("|", blockerIds.OrderBy(id => id, StringComparer.Ordinal)))}");
        prefix.AppendLine($"  empty stressed needs: {(emptyNeedsByCell.Count == 0 ? "none" : SerializeNeedsByCell(emptyNeedsByCell))}");
        prefix.AppendLine("  stress-guided actions:");
        if (stressActions.Count == 0)
        {
            prefix.AppendLine("    none");
        }
        else
        {
            foreach (var action in stressActions.Distinct(StringComparer.Ordinal))
            {
                prefix.AppendLine($"    {action}");
            }
        }

        prefix.AppendLine("  base shape:");
        foreach (var line in RenderCompactSolutionMap(document, placements).Replace("\r", "", StringComparison.Ordinal).Split('\n'))
        {
            if (line.Length > 0)
            {
                prefix.AppendLine($"    {line}");
            }
        }

        if (suggestions.Count == 0)
        {
            prefix.AppendLine("  proposed need edits: none");
            return prefix.ToString().TrimEnd();
        }

        prefix.AppendLine("  proposed need edits:");
        foreach (var suggestion in suggestions)
        {
            prefix.AppendLine($"    {suggestion}");
        }

        return prefix.ToString().TrimEnd();
    }

    private static string BuildNonGlowingHistogram(IReadOnlyList<PuzzleSolutionCandidateReport> reports)
    {
        var counts = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var report in reports)
        {
            foreach (var cellId in ParseCellIdList(report.NonGlowingRequiredCells))
            {
                counts[cellId] = counts.GetValueOrDefault(cellId) + 1;
            }
        }

        if (counts.Count == 0)
        {
            return "none";
        }

        return string.Join(", ", counts
            .OrderByDescending(pair => pair.Value)
            .ThenBy(pair => pair.Key, StringComparer.Ordinal)
            .Select(pair => $"{pair.Key}={pair.Value}"));
    }

    private static bool IsRepairSeedCandidate(PuzzleFixtureDocument document, PuzzleSolutionCandidateReport report) =>
        report.NonGlowingRequiredCellCount > 0
        && report.NonGlowingRequiredCellCount <= Math.Max(3, document.Cells.Count / 3)
        && report.ActiveCellsInLastWindow >= Math.Max(1, document.Cells.Count / 2);

    private static bool IsStrongStressRepairSeed(PuzzleFixtureDocument document, PuzzleSolutionCandidateReport? report) =>
        report is not null
        && !report.Won
        && report.ConnectedCells >= document.Cells.Count
        && report.BestTenTickFlow >= GetStressRepairFlowThreshold(document);

    private static double GetStressRepairFlowThreshold(PuzzleFixtureDocument document)
    {
        if (document.Cells.Count < 18)
        {
            return MinimumStressRepairFlowThreshold;
        }

        return Math.Max(MinimumStressRepairFlowThreshold, document.Cells.Count - 1.0);
    }

    private static string EmptyToNone(string value) => string.IsNullOrEmpty(value) ? "none" : value;

    private static string ClassifyFailure(
        PuzzleFixtureDocument document,
        CellGraphInfo graph,
        SpatialInfo spatial,
        PuzzleSolutionCandidateReport best)
    {
        if (spatial.OpenTiles.Count < document.Cells.Count || spatial.LargestComponentSize < document.Cells.Count)
        {
            return "spatial blockage";
        }

        if (graph.UsefulEdgeCount == 0 || graph.ReciprocalEdgeCount == 0)
        {
            return "resource graph";
        }

        if (document.Cells.GroupBy(cell => cell.ProducedResource, StringComparer.Ordinal)
                .Any(group => !string.IsNullOrEmpty(group.Key) && group.Count() > 1)
            && best.ActiveCellsInLastWindow < document.Cells.Count)
        {
            return "duplicate producer deadlock";
        }

        if (best.TotalSwaps > 0 || best.ActiveCellsInLastWindow >= Math.Max(1, document.Cells.Count / 2))
        {
            return "insufficient source/engine settings";
        }

        return "resource graph";
    }

    private static string RenderSolutionMap(
        PuzzleFixtureDocument document,
        IReadOnlyDictionary<string, GridPosition> placements)
    {
        var byPosition = placements.ToDictionary(pair => pair.Value, pair => pair.Key);
        var cellById = document.Cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var labelsByCellId = BuildCellMapLabels(document);
        var labelWidth = Math.Max(2, labelsByCellId.Values.Max(label => label.Length));
        var emptyToken = new string('.', labelWidth);
        var rockToken = new string('#', labelWidth);
        var builder = new StringBuilder();
        for (var y = 0; y < document.Height; y++)
        {
            for (var x = 0; x < document.Width; x++)
            {
                if (x > 0)
                {
                    builder.Append(' ');
                }

                var position = new GridPosition(x, y);
                if (byPosition.TryGetValue(position, out var cellId))
                {
                    builder.Append(labelsByCellId[cellId].PadRight(labelWidth));
                }
                else if (document.Rocks.Contains(position))
                {
                    builder.Append(rockToken);
                }
                else
                {
                    builder.Append(emptyToken);
                }
            }

            builder.AppendLine();
        }

        builder.AppendLine();
        builder.AppendLine("Legend:");
        foreach (var cell in document.Cells
            .OrderBy(cell => labelsByCellId[cell.Id], StringComparer.Ordinal))
        {
            var label = labelsByCellId[cell.Id];
            var kind = cell.Kind switch
            {
                CellKind.RedMyco => "red-myco",
                CellKind.WhiteMyco => "white-myco",
                _ => $"produces {cell.ProducedResource}"
            };
            var needs = cell.Needs.Length == 0 ? "none" : string.Join(",", cell.Needs);
            builder.Append(label)
                .Append(": ")
                .Append(cell.Id)
                .Append("; ")
                .Append(kind)
                .Append("; needs ")
                .Append(needs)
                .AppendLine();
        }

        return builder.ToString();
    }

    private static string RenderCompactSolutionMap(
        PuzzleFixtureDocument document,
        IReadOnlyDictionary<string, GridPosition> placements)
    {
        var byPosition = placements.ToDictionary(pair => pair.Value, pair => pair.Key);
        var cellById = document.Cells.ToDictionary(cell => cell.Id, StringComparer.Ordinal);
        var builder = new StringBuilder();
        for (var y = 0; y < document.Height; y++)
        {
            for (var x = 0; x < document.Width; x++)
            {
                var position = new GridPosition(x, y);
                if (byPosition.TryGetValue(position, out var cellId))
                {
                    var cell = cellById[cellId];
                    builder.Append(RenderCellMapMarker(cell));
                }
                else if (document.Rocks.Contains(position))
                {
                    builder.Append('#');
                }
                else
                {
                    builder.Append('.');
                }
            }

            builder.AppendLine();
        }

        return builder.ToString();
    }

    private static IReadOnlyDictionary<string, string> BuildCellMapLabels(PuzzleFixtureDocument document)
    {
        var labels = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var group in document.Cells
            .GroupBy(RenderCellMapMarker)
            .OrderBy(group => group.Key == '*' ? "ZZZ*" : group.Key.ToString(), StringComparer.Ordinal))
        {
            var index = 1;
            foreach (var cell in group.OrderBy(cell => cell.Id, StringComparer.Ordinal))
            {
                var suffix = index <= MapLabelSuffixes.Length
                    ? MapLabelSuffixes[index - 1]
                    : '?';
                labels[cell.Id] = $"{group.Key}{suffix}";
                index++;
            }
        }

        return labels;
    }

    private static char RenderCellMapMarker(SearchCell cell)
    {
        if (cell.Kind == CellKind.WhiteMyco)
        {
            return '0';
        }

        if (cell.Kind == CellKind.RedMyco)
        {
            return '*';
        }

        return string.IsNullOrEmpty(cell.ProducedResource) ? '0' : cell.ProducedResource[0];
    }

    private static void SaveLevelResult(string outputRoot, PuzzleSolutionSearchResult result)
    {
        var directory = Path.Combine(outputRoot, result.LevelName);
        Directory.CreateDirectory(directory);
        if (result.RepairedLevelFixtureJson is not null)
        {
            File.WriteAllText(Path.Combine(directory, "repaired-level-fixture.json"), result.RepairedLevelFixtureJson);
        }

        if (result.SolutionFixtureJson is not null)
        {
            File.WriteAllText(Path.Combine(directory, "best-fixture.json"), result.SolutionFixtureJson);
        }

        if (result.Won && result.SolutionFixtureJson is not null)
        {
            File.WriteAllText(Path.Combine(directory, "solution-fixture.json"), result.SolutionFixtureJson);
        }

        if (result.SolutionMapText is not null)
        {
            File.WriteAllText(Path.Combine(directory, "solution-map.txt"), result.SolutionMapText);
        }

        File.WriteAllText(Path.Combine(directory, "results.txt"), RenderResultsText(result));
        File.WriteAllText(Path.Combine(directory, "candidates.csv"), RenderCandidatesCsv(result.CandidateReports));
    }

    private static void SaveBatchSummary(string outputRoot, IReadOnlyList<PuzzleSolutionSearchResult> results)
    {
        var builder = new StringBuilder();
        builder.AppendLine("level,status,uses_needs_repair,candidates_evaluated,first_win_tick,best_10_tick_flow,total_swaps,total_reactions,sustained_ticks,failure_category,output");
        foreach (var result in results)
        {
            builder.Append(result.LevelNumber.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(result.Won ? "pass" : "fail").Append(',')
                .Append(result.UsesNeedsRepair ? "true" : "false").Append(',')
                .Append(result.CandidatesEvaluated.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(result.FirstWinTick.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(result.BestTenTickFlow.ToString("F2", CultureInfo.InvariantCulture)).Append(',')
                .Append(result.TotalSwaps.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(result.TotalReactions.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(result.SustainedTicks.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(EscapeCsv(result.FailureCategory)).Append(',')
                .Append(EscapeCsv(Path.Combine(outputRoot, result.LevelName)))
                .AppendLine();
        }

        File.WriteAllText(Path.Combine(outputRoot, "summary.csv"), builder.ToString());
    }

    private static string RenderResultsText(PuzzleSolutionSearchResult result)
    {
        var builder = new StringBuilder();
        builder.AppendLine("Puzzle solution search");
        builder.AppendLine($"  level: {result.LevelNumber}");
        builder.AppendLine($"  status: {(result.Won ? "pass" : "fail")}");
        builder.AppendLine($"  uses needs repair: {(result.UsesNeedsRepair ? "yes" : "no")}");
        builder.AppendLine($"  fixture: {result.FixturePath}");
        builder.AppendLine($"  candidates evaluated: {result.CandidatesEvaluated}/{result.CandidateLimit}");
        builder.AppendLine($"  first win tick: {result.FirstWinTick}");
        builder.AppendLine($"  best 10-tick flow: {result.BestTenTickFlow:F2}");
        builder.AppendLine($"  best 10-tick swaps: {result.BestTenTickSwaps}");
        builder.AppendLine($"  total swaps: {result.TotalSwaps}");
        builder.AppendLine($"  total reactions: {result.TotalReactions}");
        builder.AppendLine($"  sustained ticks: {result.SustainedTicks}");
        builder.AppendLine($"  active cells: {result.ActiveCellsInLastWindow}");
        builder.AppendLine($"  glowing cells: {result.GlowingCells}");
        builder.AppendLine($"  final score: {result.FinalScore}");
        builder.AppendLine($"  best connected cells: {result.BestConnectedCells}");
        builder.AppendLine($"  open tiles: {result.OpenTiles}");
        builder.AppendLine($"  largest open-tile component: {result.LargestOpenTileComponent}");
        builder.AppendLine($"  useful graph edges: {result.UsefulEdgeCount}");
        builder.AppendLine($"  reciprocal graph edges: {result.ReciprocalEdgeCount}");
        builder.AppendLine($"  non-glowing histogram: {BuildNonGlowingHistogram(result.CandidateReports)}");
        if (!result.Won)
        {
            builder.AppendLine($"  failure category: {result.FailureCategory}");
        }

        builder.AppendLine($"  diagnostics: {result.Diagnostics}");
        if (!string.IsNullOrWhiteSpace(result.ResourceGraphDiagnostics))
        {
            builder.AppendLine(result.ResourceGraphDiagnostics);
        }

        if (!string.IsNullOrWhiteSpace(result.NeedsSuggestionDiagnostics))
        {
            builder.AppendLine(result.NeedsSuggestionDiagnostics);
        }

        return builder.ToString();
    }

    private static string RenderCandidatesCsv(IReadOnlyList<PuzzleSolutionCandidateReport> reports)
    {
        var builder = new StringBuilder();
        builder.AppendLine("candidate,won,first_win_tick,best_10_tick_flow,best_10_tick_swaps,total_swaps,total_reactions,sustained_ticks,active_cells,glowing_cells,non_glowing_required_cells,missing_required_resources,non_glowing_cell_ids,final_score,connected_cells,layout_score,diagnostics");
        foreach (var report in reports)
        {
            builder.Append(report.CandidateIndex.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.Won ? "true" : "false").Append(',')
                .Append(report.FirstWinTick.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.BestTenTickFlow.ToString("F2", CultureInfo.InvariantCulture)).Append(',')
                .Append(report.BestTenTickSwaps.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.TotalSwaps.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.TotalReactions.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.SustainedTicks.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.ActiveCellsInLastWindow.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.GlowingCells.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.NonGlowingRequiredCellCount.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.MissingRequiredResourceCount.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(EscapeCsv(report.NonGlowingRequiredCells)).Append(',')
                .Append(report.FinalScore.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.ConnectedCells.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(report.LayoutScore.ToString(CultureInfo.InvariantCulture)).Append(',')
                .Append(EscapeCsv(report.Diagnostics))
                .AppendLine();
        }

        return builder.ToString();
    }

    private static string EscapeCsv(string value)
    {
        if (!value.Contains(',') && !value.Contains('"') && !value.Contains('\n'))
        {
            return value;
        }

        return $"\"{value.Replace("\"", "\"\"", StringComparison.Ordinal)}\"";
    }

    private static IEnumerable<GridPosition> EnumerateOrthogonalNeighbors(GridPosition position)
    {
        yield return new GridPosition(position.X + 1, position.Y);
        yield return new GridPosition(position.X - 1, position.Y);
        yield return new GridPosition(position.X, position.Y + 1);
        yield return new GridPosition(position.X, position.Y - 1);
    }

    private static int TileCenterDistanceScore(GridPosition tile, int width, int height)
    {
        var dx = tile.X * 2 - (width - 1);
        var dy = tile.Y * 2 - (height - 1);
        return dx * dx + dy * dy;
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

    private static string[] BuildOfferResources(
        string producedResource,
        IReadOnlyList<string> needs,
        CellKind kind,
        bool hasStoredNeedQuantity)
    {
        var offers = new HashSet<string>(StringComparer.Ordinal);
        if (!string.IsNullOrEmpty(producedResource))
        {
            offers.Add(producedResource);
        }

        if (kind is CellKind.WhiteMyco or CellKind.RedMyco || hasStoredNeedQuantity)
        {
            foreach (var need in needs)
            {
                offers.Add(need);
            }
        }

        return offers.ToArray();
    }

    private static void ValidateOptions(PuzzleSolutionSearchOptions options)
    {
        if (options.StartLevel <= 0 || options.EndLevel < options.StartLevel)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Level range must be positive and ordered.");
        }

        if (options.TicksPerCandidate <= 0 || options.CandidateLimit <= 0 || options.BeamSize <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Ticks, candidate limit, and beam size must be positive.");
        }

        if (options.EventCapacity <= 0 || options.ProgressStride < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Event capacity must be positive and progress stride cannot be negative.");
        }
    }

    private static void ReportProgress(PuzzleSolutionSearchOptions options, int level, string message) =>
        options.ProgressLogger?.Invoke($"[level-{level:000}] {DateTimeOffset.UtcNow:O} {message}");

    private sealed record SearchCell(
        string Id,
        CellKind Kind,
        string ProducedResource,
        string[] Needs,
        string[] Offers)
    {
        public bool IsMyco => Kind is CellKind.WhiteMyco or CellKind.RedMyco;
    }

    private sealed record AsciiSlot(char Marker, int X, int Y);

    private sealed record CellGraphInfo(int[,] Weights, int[] WeightedDegrees, int UsefulEdgeCount, int ReciprocalEdgeCount);

    private sealed record SpatialInfo(
        IReadOnlyList<GridPosition> OpenTiles,
        IReadOnlyDictionary<GridPosition, GridPosition[]> Neighbors,
        IReadOnlyDictionary<GridPosition, int> TileDegrees,
        int LargestComponentSize);

    private sealed record CandidateEvaluation(
        bool Won,
        int FirstWinTick,
        double BestTenTickFlow,
        int BestTenTickSwaps,
        int TotalSwaps,
        int TotalReactions,
        int SustainedTicks,
        int ActiveCellsInLastWindow,
        int GlowingCells,
        int FinalScore,
        IReadOnlyList<string> NonGlowingRequiredCells,
        int MissingRequiredResourceCount,
        IReadOnlyDictionary<string, string[]> EmptyNeedsByCell,
        string SummaryDiagnostics,
        string DetailedDiagnostics);

    private sealed class RecentFlowAccumulator
    {
        public HashSet<string> In { get; } = new(StringComparer.Ordinal);
        public HashSet<string> Out { get; } = new(StringComparer.Ordinal);
    }

    private sealed record CandidateRepairSeed(PuzzleSolutionCandidateLayout Layout, PuzzleSolutionCandidateReport Report);

    private sealed record NeedEdit(
        string CellId,
        int NeedIndex,
        string OldNeed,
        string NewNeed,
        int Score,
        string Reason);

    private sealed record AdjacentResourceOption(
        string Resource,
        string ProviderId,
        bool IsProduced,
        bool IsOffered,
        bool IsCarriedNeed,
        bool IsNonEmptyNeed,
        bool IsReciprocal,
        string SourceLabel);

    private sealed record StressNeedRepairVariant(
        PuzzleFixtureDocument Document,
        IReadOnlyDictionary<string, GridPosition> Placements,
        string EditKey,
        string EditSummary,
        int ConnectedCells,
        long LayoutScore);

    private sealed class LayoutState
    {
        private readonly GridPosition?[] _positionsByCell;
        private readonly bool[] _occupiedByOpenTileIndex;
        private readonly Dictionary<GridPosition, int> _openTileIndexes;
        private readonly List<GridPosition> _placedTiles;

        private LayoutState(
            GridPosition?[] positionsByCell,
            bool[] occupiedByOpenTileIndex,
            Dictionary<GridPosition, int> openTileIndexes,
            List<GridPosition> placedTiles,
            int placedCount,
            long score,
            int connectedCells)
        {
            _positionsByCell = positionsByCell;
            _occupiedByOpenTileIndex = occupiedByOpenTileIndex;
            _openTileIndexes = openTileIndexes;
            _placedTiles = placedTiles;
            PlacedCount = placedCount;
            Score = score;
            ConnectedCells = connectedCells;
        }

        public int PlacedCount { get; }
        public long Score { get; }
        public int ConnectedCells { get; }
        public IReadOnlyList<GridPosition> PlacedTiles => _placedTiles;

        public static LayoutState Create(int cellCount, int cellIndex, GridPosition tile, SpatialInfo spatial)
        {
            var openTileIndexes = spatial.OpenTiles
                .Select((openTile, index) => (openTile, index))
                .ToDictionary(item => item.openTile, item => item.index);
            var positions = new GridPosition?[cellCount];
            var occupied = new bool[spatial.OpenTiles.Count];
            positions[cellIndex] = tile;
            occupied[openTileIndexes[tile]] = true;
            return new LayoutState(positions, occupied, openTileIndexes, [tile], 1, 0, 1);
        }

        public static LayoutState? TryCreate(
            IReadOnlyDictionary<string, GridPosition> placements,
            PuzzleFixtureDocument document,
            CellGraphInfo graph,
            SpatialInfo spatial,
            int variant)
        {
            if (placements.Count != document.Cells.Count)
            {
                return null;
            }

            var openTileIndexes = spatial.OpenTiles
                .Select((openTile, index) => (openTile, index))
                .ToDictionary(item => item.openTile, item => item.index);
            var positions = new GridPosition?[document.Cells.Count];
            var occupied = new bool[spatial.OpenTiles.Count];
            var placedTiles = new List<GridPosition>(document.Cells.Count);
            for (var i = 0; i < document.Cells.Count; i++)
            {
                if (!placements.TryGetValue(document.Cells[i].Id, out var position)
                    || !openTileIndexes.TryGetValue(position, out var openTileIndex)
                    || occupied[openTileIndex])
                {
                    return null;
                }

                positions[i] = position;
                occupied[openTileIndex] = true;
                placedTiles.Add(position);
            }

            long score = 0;
            for (var i = 0; i < positions.Length; i++)
            {
                var position = positions[i]!.Value;
                score += spatial.TileDegrees[position] * 8L - TileCenterDistanceScore(position, document.Width, document.Height);
                score += RotateTie(position.X * 67 + position.Y * 991 + i * 17, variant) % 17;
            }

            for (var i = 0; i < positions.Length; i++)
            {
                var a = positions[i]!.Value;
                for (var j = i + 1; j < positions.Length; j++)
                {
                    var b = positions[j]!.Value;
                    var distance = Math.Abs(a.X - b.X) + Math.Abs(a.Y - b.Y);
                    var weight = graph.Weights[i, j];
                    if (distance == 1)
                    {
                        score += weight * 100L;
                        score += weight > 0 ? 1_000L : -400L;
                    }
                    else if (weight > 0)
                    {
                        score -= Math.Min(distance, 8) * weight;
                    }
                }
            }

            return new LayoutState(
                positions,
                occupied,
                openTileIndexes,
                placedTiles,
                document.Cells.Count,
                score,
                CountConnectedPlacedCells(placedTiles, spatial));
        }

        public bool IsOccupied(GridPosition tile) =>
            _openTileIndexes.TryGetValue(tile, out var index) && _occupiedByOpenTileIndex[index];

        public LayoutState Place(
            int cellIndex,
            GridPosition tile,
            PuzzleFixtureDocument document,
            CellGraphInfo graph,
            SpatialInfo spatial,
            int variant)
        {
            var positions = (GridPosition?[])_positionsByCell.Clone();
            var occupied = (bool[])_occupiedByOpenTileIndex.Clone();
            var placedTiles = new List<GridPosition>(_placedTiles.Count + 1);
            placedTiles.AddRange(_placedTiles);
            positions[cellIndex] = tile;
            occupied[_openTileIndexes[tile]] = true;
            placedTiles.Add(tile);

            long delta = spatial.TileDegrees[tile] * 8L - TileCenterDistanceScore(tile, document.Width, document.Height);
            var connected = ConnectedCells;
            var hasPlacedNeighbor = false;
            for (var otherIndex = 0; otherIndex < positions.Length; otherIndex++)
            {
                var other = positions[otherIndex];
                if (other is null || otherIndex == cellIndex)
                {
                    continue;
                }

                var distance = Math.Abs(other.Value.X - tile.X) + Math.Abs(other.Value.Y - tile.Y);
                if (distance == 1)
                {
                    hasPlacedNeighbor = true;
                    var weight = graph.Weights[cellIndex, otherIndex];
                    delta += weight * 100L;
                    delta += weight > 0 ? 1_000L : -400L;
                }
                else if (graph.Weights[cellIndex, otherIndex] > 0)
                {
                    delta -= Math.Min(distance, 8) * graph.Weights[cellIndex, otherIndex];
                }
            }

            if (hasPlacedNeighbor)
            {
                connected++;
            }

            delta += RotateTie(tile.X * 67 + tile.Y * 991 + cellIndex * 17, variant) % 17;
            return new LayoutState(positions, occupied, _openTileIndexes, placedTiles, PlacedCount + 1, Score + delta, connected);
        }

        public IReadOnlyDictionary<string, GridPosition> ToPlacementDictionary(IReadOnlyList<SearchCell> cells)
        {
            var placements = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
            for (var i = 0; i < cells.Count; i++)
            {
                if (_positionsByCell[i] is { } position)
                {
                    placements[cells[i].Id] = position;
                }
            }

            return placements;
        }

        public string BuildKey(IReadOnlyList<SearchCell> cells)
        {
            var builder = new StringBuilder();
            for (var i = 0; i < cells.Count; i++)
            {
                var position = _positionsByCell[i];
                builder.Append(cells[i].Id).Append('@');
                if (position is null)
                {
                    builder.Append("?,?");
                }
                else
                {
                    builder.Append(position.Value.X).Append(':').Append(position.Value.Y);
                }

                builder.Append(';');
            }

            return builder.ToString();
        }

        private static int CountConnectedPlacedCells(IReadOnlyList<GridPosition> placedTiles, SpatialInfo spatial)
        {
            if (placedTiles.Count == 0)
            {
                return 0;
            }

            var placed = placedTiles.ToHashSet();
            var seen = new HashSet<GridPosition>();
            var queue = new Queue<GridPosition>();
            var best = 0;
            foreach (var start in placedTiles)
            {
                if (!seen.Add(start))
                {
                    continue;
                }

                var count = 0;
                queue.Enqueue(start);
                while (queue.Count > 0)
                {
                    var tile = queue.Dequeue();
                    count++;
                    foreach (var neighbor in spatial.Neighbors[tile])
                    {
                        if (placed.Contains(neighbor) && seen.Add(neighbor))
                        {
                            queue.Enqueue(neighbor);
                        }
                    }
                }

                best = Math.Max(best, count);
            }

            return best;
        }
    }

    private sealed class PuzzleFixtureDocument
    {
        private PuzzleFixtureDocument(
            JsonObject root,
            IReadOnlyList<SearchCell> cells,
            int width,
            int height,
            IReadOnlyList<GridPosition> rocks)
        {
            Root = root;
            Cells = cells;
            Width = width;
            Height = height;
            Rocks = rocks;
        }

        public JsonObject Root { get; }
        public IReadOnlyList<SearchCell> Cells { get; }
        public int Width { get; }
        public int Height { get; }
        public IReadOnlyList<GridPosition> Rocks { get; }

        public string ToFixtureJson() => Root.DeepClone().AsObject().ToJsonString(WriteJsonOptions);

        public static PuzzleFixtureDocument Parse(string fixtureJson, int? sourceQuantityPerTick)
        {
            var root = JsonNode.Parse(fixtureJson)?.AsObject()
                ?? throw new InvalidFixtureException("Fixture JSON is empty.");
            if (sourceQuantityPerTick is not null)
            {
                ApplySourceQuantityOverride(root, sourceQuantityPerTick.Value);
            }

            var grid = root["grid"]?.AsObject()
                ?? throw new InvalidFixtureException("Fixture must define a grid.");
            var width = ReadRequiredInt(grid, "width");
            var height = ReadRequiredInt(grid, "height");
            var rocks = new List<GridPosition>();
            if (grid["rocks"] is JsonArray rocksArray)
            {
                foreach (var rockNode in rocksArray)
                {
                    var rock = rockNode?.AsObject()
                        ?? throw new InvalidFixtureException("Rock entry must be an object.");
                    rocks.Add(new GridPosition(ReadRequiredInt(rock, "x"), ReadRequiredInt(rock, "y")));
                }
            }

            var cellsArray = root["cells"] as JsonArray
                ?? throw new InvalidFixtureException("Fixture must define cells.");
            var cells = new List<SearchCell>(cellsArray.Count);
            foreach (var cellNode in cellsArray)
            {
                var cell = cellNode?.AsObject()
                    ?? throw new InvalidFixtureException("Cell entry must be an object.");
                cells.Add(ParseCell(cell));
            }

            return new PuzzleFixtureDocument(root, cells, width, height, rocks);
        }

        public string BuildFixtureJson(IReadOnlyDictionary<string, GridPosition> placements)
        {
            var clone = Root.DeepClone().AsObject();
            var cellsArray = clone["cells"] as JsonArray
                ?? throw new InvalidFixtureException("Fixture must define cells.");
            foreach (var cellNode in cellsArray)
            {
                var cell = cellNode?.AsObject()
                    ?? throw new InvalidFixtureException("Cell entry must be an object.");
                var id = ReadRequiredString(cell, "id");
                if (!placements.TryGetValue(id, out var placement))
                {
                    throw new InvalidOperationException($"Candidate layout did not place cell '{id}'.");
                }

                cell["x"] = JsonValue.Create(placement.X);
                cell["y"] = JsonValue.Create(placement.Y);
            }

            return clone.ToJsonString(WriteJsonOptions);
        }

        public PuzzleFixtureDocument WithNeedEdits(IReadOnlyList<NeedEdit> edits)
        {
            var editsByCell = edits
                .GroupBy(edit => edit.CellId, StringComparer.Ordinal)
                .ToDictionary(group => group.Key, group => group.ToArray(), StringComparer.Ordinal);
            var clone = Root.DeepClone().AsObject();
            var cellsArray = clone["cells"] as JsonArray
                ?? throw new InvalidFixtureException("Fixture must define cells.");
            foreach (var cellNode in cellsArray)
            {
                var cell = cellNode?.AsObject()
                    ?? throw new InvalidFixtureException("Cell entry must be an object.");
                var id = ReadRequiredString(cell, "id");
                if (!editsByCell.TryGetValue(id, out var cellEdits))
                {
                    continue;
                }

                var editsByNeedIndex = cellEdits.ToDictionary(edit => edit.NeedIndex);
                var slots = cell["slots"] as JsonArray
                    ?? throw new InvalidFixtureException($"Cell '{id}' must define slots.");
                var needIndex = 0;
                foreach (var slotNode in slots)
                {
                    var slot = slotNode?.AsObject()
                        ?? throw new InvalidFixtureException($"Cell '{id}' slot must be an object.");
                    var role = ReadOptionalString(slot, "role");
                    if (!string.Equals(role, nameof(PoolSlotRole.Need), StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    if (editsByNeedIndex.TryGetValue(needIndex, out var edit))
                    {
                        slot["resource"] = JsonValue.Create(edit.NewNeed);
                    }

                    needIndex++;
                }
            }

            return Parse(clone.ToJsonString(WriteJsonOptions), null);
        }

        private static SearchCell ParseCell(JsonObject cell)
        {
            var id = ReadRequiredString(cell, "id");
            var kindText = ReadOptionalString(cell, "kind");
            var kind = Enum.TryParse<CellKind>(kindText, true, out var parsedKind) ? parsedKind : CellKind.Standard;
            var slots = cell["slots"] as JsonArray
                ?? throw new InvalidFixtureException($"Cell '{id}' must define slots.");
            var needs = new List<string>();
            var offers = new HashSet<string>(StringComparer.Ordinal);
            var produced = "";
            var hasStoredNeedQuantity = false;
            foreach (var slotNode in slots)
            {
                var slot = slotNode?.AsObject()
                    ?? throw new InvalidFixtureException($"Cell '{id}' slot must be an object.");
                var resource = ReadRequiredString(slot, "resource");
                var role = ReadOptionalString(slot, "role");
                if (string.Equals(role, nameof(PoolSlotRole.SourceOutput), StringComparison.OrdinalIgnoreCase))
                {
                    produced = resource;
                    offers.Add(resource);
                }
                else if (string.Equals(role, nameof(PoolSlotRole.Need), StringComparison.OrdinalIgnoreCase))
                {
                    needs.Add(resource);
                    if (ReadOptionalInt(slot, "quantity") > 0)
                    {
                        hasStoredNeedQuantity = true;
                        offers.Add(resource);
                    }
                }
                else if (ReadOptionalInt(slot, "quantity") > 0)
                {
                    offers.Add(resource);
                }
            }

            foreach (var offer in BuildOfferResources(produced, needs, kind, hasStoredNeedQuantity))
            {
                offers.Add(offer);
            }

            if (kind is CellKind.WhiteMyco or CellKind.RedMyco)
            {
                produced = "";
            }

            return new SearchCell(id, kind, produced, needs.ToArray(), offers.ToArray());
        }

        private static void ApplySourceQuantityOverride(JsonObject root, int quantityPerTick)
        {
            if (quantityPerTick <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(quantityPerTick), "Source quantity must be positive.");
            }

            if (root["cells"] is not JsonArray cells)
            {
                return;
            }

            foreach (var cellNode in cells)
            {
                if (cellNode is not JsonObject cell || cell["sources"] is not JsonArray sources)
                {
                    continue;
                }

                foreach (var sourceNode in sources)
                {
                    if (sourceNode is JsonObject source)
                    {
                        source["quantityPerTick"] = JsonValue.Create(quantityPerTick);
                    }
                }
            }
        }

        private static int ReadRequiredInt(JsonObject obj, string propertyName) =>
            obj[propertyName]?.GetValue<int>()
            ?? throw new InvalidFixtureException($"Missing integer property '{propertyName}'.");

        private static int ReadOptionalInt(JsonObject obj, string propertyName) =>
            obj[propertyName]?.GetValue<int>() ?? 0;

        private static string ReadRequiredString(JsonObject obj, string propertyName) =>
            obj[propertyName]?.GetValue<string>()
            ?? throw new InvalidFixtureException($"Missing string property '{propertyName}'.");

        private static string ReadOptionalString(JsonObject obj, string propertyName) =>
            obj[propertyName]?.GetValue<string>() ?? "";
    }
}
