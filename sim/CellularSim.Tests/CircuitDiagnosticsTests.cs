using System.Text.Json.Nodes;
using CellularSim;

namespace CellularSim.Tests;

public sealed class CircuitDiagnosticsTests
{
    [Fact]
    public void DirectReciprocity_ReportsOneStrongRequiredGroup()
    {
        var loaded = TestSupport.LoadFixture("direct-reciprocity.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.Tick();

        var diagnostics = CircuitDiagnostics.Build(engine);
        Assert.Equal(engine.Circuit.IsAliveThisTick, diagnostics.IsAlive);
        Assert.Empty(diagnostics.NonGlowingRequiredCells);
        Assert.Empty(diagnostics.MissingRequiredResources);
        Assert.Contains(diagnostics.StrongGroups, group => HasExactly(group, "cell-a", "cell-b"));
    }

    [Fact]
    public void OneWayFlow_ReportsWeakGroupButNotStrongGroup()
    {
        var resource = new ResourceId(0);
        var world = new GridWorld(3, 1);
        world.AddCell(new CellState("cell-a", new GridPosition(0, 0)));
        world.AddCell(new CellState("cell-b", new GridPosition(1, 0)));
        world.AddCell(new CellState("cell-c", new GridPosition(2, 0)));
        var options = new EngineOptions();
        options.RequiredCellIds.AddRange(new[] { "cell-a", "cell-b", "cell-c" });
        options.RequiredResources.Add(resource);
        SimEvent[] events =
        [
            new FlowEvent(10, "cell-a", "cell-b", resource, 1, FlowKind.OneWay),
            new FlowEvent(10, "cell-b", "cell-c", resource, 1, FlowKind.OneWay)
        ];

        var diagnostics = CircuitDiagnostics.Build(world, options, events, 10, false, false, 0);

        Assert.Contains(diagnostics.WeakGroups, group => HasExactly(group, "cell-a", "cell-b", "cell-c"));
        Assert.DoesNotContain(diagnostics.StrongGroups, group => HasExactly(group, "cell-a", "cell-b", "cell-c"));
    }

    [Fact]
    public void NoFlow_ReportsMissingResourcesAndNonGlowingRequiredCells()
    {
        var loaded = TestSupport.LoadFixture("direct-reciprocity.json");
        var engine = new CellularEngine(loaded.World, loaded.Options);

        var diagnostics = CircuitDiagnostics.Build(engine);

        Assert.Contains("cell-a", diagnostics.NonGlowingRequiredCells);
        Assert.Contains("cell-b", diagnostics.NonGlowingRequiredCells);
        Assert.Contains(loaded.Catalog.GetId("A"), diagnostics.MissingRequiredResources);
        Assert.Contains(loaded.Catalog.GetId("B"), diagnostics.MissingRequiredResources);
    }

    [Fact]
    public void LevelSeventeenFailedLayout_DoesNotReportOneStrongCircuitGroup()
    {
        var loaded = LoadLevelSeventeenLayout(
            "M1 B1 .. .. .. D2 .. ..",
            "## .. .. ## G1 .. L1 ##",
            "*4 .. .. F1 J1 .. C1 ..",
            "K1 H1 O1 *1 ## .. .. ..",
            ".. A1 K2 E1 ## .. .. ..",
            "## .. Q1 D1 .. .. ## ..",
            "N1 .. .. .. *2 .. I1 P1",
            ".. A2 .. .. .. *3 ## ..");
        loaded.Options.EventCapacity = 65_536;
        var engine = new CellularEngine(loaded.World, loaded.Options);

        engine.RunTicks(160);

        var diagnostics = CircuitDiagnostics.Build(engine);
        Assert.False(engine.Circuit.IsWon);
        Assert.DoesNotContain(diagnostics.StrongGroups, group => ContainsAllRequired(group, loaded.Options.RequiredCellIds));
    }

    [Fact]
    public void LevelSeventeenWinningLayout_ReportsOneStrongCircuitGroup()
    {
        var loaded = LoadLevelSeventeenLayout(
            ".. .. .. .. .. .. .. ..",
            "## N1 Q1 ## .. .. .. ##",
            ".. B1 D1 P1 .. .. .. ..",
            "L1 C1 D2 A1 ## .. .. ..",
            "E1 H1 A2 I1 ## .. .. ..",
            "## K1 F1 G1 *1 .. ## ..",
            ".. O1 J1 M1 *3 .. .. ..",
            ".. *2 K2 *4 .. .. ## ..");
        loaded.Options.EventCapacity = 65_536;
        var engine = new CellularEngine(loaded.World, loaded.Options);

        for (var tick = 0; tick < 500 && !engine.Circuit.IsWon; tick++)
        {
            engine.Tick();
        }

        var diagnostics = CircuitDiagnostics.Build(engine);
        Assert.True(engine.Circuit.IsWon);
        Assert.True(diagnostics.IsWon);
        Assert.Contains(diagnostics.StrongGroups, group => ContainsAllRequired(group, loaded.Options.RequiredCellIds));
    }

    private static bool HasExactly(CircuitDiagnosticGroup group, params string[] expected)
    {
        var actual = group.CellIds.ToHashSet(StringComparer.Ordinal);
        return actual.SetEquals(expected);
    }

    private static bool ContainsAllRequired(CircuitDiagnosticGroup group, IReadOnlyList<string> requiredCells)
    {
        var actual = group.CellIds.ToHashSet(StringComparer.Ordinal);
        return requiredCells.All(actual.Contains);
    }

    private static FixtureLoadResult LoadLevelSeventeenLayout(params string[] rows)
    {
        var root = JsonNode.Parse(File.ReadAllText(RepoFile("levels", "puzzle", "level-017.json")))!.AsObject();
        var positions = ParseLayout(rows);
        var cells = root["cells"]!.AsArray();
        var labelsByCellId = BuildCellLabels(cells);
        foreach (var cellNode in cells)
        {
            var cell = cellNode!.AsObject();
            var id = cell["id"]!.GetValue<string>();
            var label = labelsByCellId[id];
            if (!positions.TryGetValue(label, out var position))
            {
                throw new InvalidOperationException($"Layout does not include cell '{label}'.");
            }

            cell["x"] = position.X;
            cell["y"] = position.Y;
        }

        return FixtureLoader.LoadFromJson(root.ToJsonString());
    }

    private static Dictionary<string, GridPosition> ParseLayout(IReadOnlyList<string> rows)
    {
        var positions = new Dictionary<string, GridPosition>(StringComparer.Ordinal);
        for (var y = 0; y < rows.Count; y++)
        {
            var tokens = rows[y].Contains(' ', StringComparison.Ordinal)
                ? rows[y].Split(' ', StringSplitOptions.RemoveEmptyEntries)
                : rows[y].Select(character => character.ToString()).ToArray();
            for (var x = 0; x < tokens.Length; x++)
            {
                var marker = tokens[x];
                if (marker is "." or ".." or "#" or "##")
                {
                    continue;
                }

                positions[marker.ToUpperInvariant()] = new GridPosition(x, y);
            }
        }

        return positions;
    }

    private static Dictionary<string, string> BuildCellLabels(JsonArray cells)
    {
        var labels = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var group in cells
            .Select(cellNode => cellNode!.AsObject())
            .GroupBy(GetMapMarker, StringComparer.Ordinal)
            .OrderBy(group => group.Key == "*" ? "ZZZ*" : group.Key, StringComparer.Ordinal))
        {
            var index = 1;
            foreach (var cell in group.OrderBy(cell => cell["id"]!.GetValue<string>(), StringComparer.Ordinal))
            {
                labels[cell["id"]!.GetValue<string>()] = $"{group.Key}{index}";
                index++;
            }
        }

        return labels;
    }

    private static string GetMapMarker(JsonObject cell)
    {
        var kind = cell["kind"]?.GetValue<string>();
        if (string.Equals(kind, nameof(CellKind.WhiteMyco), StringComparison.Ordinal))
        {
            return "0";
        }

        if (string.Equals(kind, nameof(CellKind.RedMyco), StringComparison.Ordinal)
            || cell["id"]!.GetValue<string>().StartsWith("red-myco-", StringComparison.Ordinal))
        {
            return "*";
        }

        var sourceSlot = cell["slots"]!.AsArray()
            .Select(slotNode => slotNode!.AsObject())
            .First(slot => string.Equals(slot["role"]!.GetValue<string>(), nameof(PoolSlotRole.SourceOutput), StringComparison.Ordinal));
        return sourceSlot["resource"]!.GetValue<string>();
    }

    private static string RepoFile(params string[] parts)
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null && !File.Exists(Path.Combine(directory.FullName, "Cellular.csproj")))
        {
            directory = directory.Parent;
        }

        if (directory is null)
        {
            throw new DirectoryNotFoundException("Could not find Cellular repo root.");
        }

        return Path.Combine(new[] { directory.FullName }.Concat(parts).ToArray());
    }
}
