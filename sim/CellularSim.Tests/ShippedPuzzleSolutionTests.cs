using CellularSim;

namespace CellularSim.Tests;

public sealed class ShippedPuzzleSolutionTests
{
    private const int FirstLevel = 1;
    private const int LastLevel = 44;
    private const int MaxValidationTicks = 1_000;

    [Fact]
    public void AllShippedPuzzleSolutions_WinUnderCurrentEngine()
    {
        var failures = new List<string>();
        for (var level = FirstLevel; level <= LastLevel; level++)
        {
            var path = RepoFile("levels", "puzzle", $"level-{level:000}-solution.json");
            if (!File.Exists(path))
            {
                failures.Add($"level {level:000}: missing solution fixture");
                continue;
            }

            var loaded = FixtureLoader.LoadFromFile(path);
            loaded.Options.EventCapacity = Math.Max(loaded.Options.EventCapacity, 262_144);
            var engine = new CellularEngine(loaded.World, loaded.Options);
            for (var tick = 0; tick < MaxValidationTicks && !engine.Circuit.IsWon; tick++)
            {
                engine.Tick();
            }

            if (!engine.Circuit.IsWon)
            {
                failures.Add($"level {level:000}: not won after {MaxValidationTicks} ticks; sustained={engine.Circuit.SustainedTicks}");
            }
        }

        Assert.True(failures.Count == 0, string.Join(Environment.NewLine, failures));
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
