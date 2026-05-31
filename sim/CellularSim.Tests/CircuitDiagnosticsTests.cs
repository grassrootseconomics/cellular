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
            "JHR.",
            "MKS.",
            "PCT.",
            "BAQ",
            "NEFO",
            "DGIL");
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
            "SKTCAE",
            "GILOFQ",
            "DNBPMJ",
            "....RH");
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
        foreach (var cellNode in cells)
        {
            var cell = cellNode!.AsObject();
            var id = cell["id"]!.GetValue<string>();
            var letter = id.StartsWith("cell-", StringComparison.Ordinal)
                ? id.Substring("cell-".Length).ToUpperInvariant()
                : id.ToUpperInvariant();
            if (!positions.TryGetValue(letter, out var position))
            {
                throw new InvalidOperationException($"Layout does not include cell '{letter}'.");
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
            for (var x = 0; x < rows[y].Length; x++)
            {
                var marker = rows[y][x];
                if (marker == '.')
                {
                    continue;
                }

                positions[marker.ToString().ToUpperInvariant()] = new GridPosition(x, y);
            }
        }

        return positions;
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
