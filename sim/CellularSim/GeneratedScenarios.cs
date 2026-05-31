using System.Text.Json;
using System.Text.Json.Serialization;

namespace CellularSim;

public sealed class RandomScenarioOptions
{
    public int Seed { get; set; } = 1;
    public int Width { get; set; } = 16;
    public int Height { get; set; } = 16;
    public int CellCount { get; set; } = 100;
    public int ResourceCount { get; set; } = 6;
    public int RockCount { get; set; } = 20;
    public int MinNeeds { get; set; } = 3;
    public int MaxNeeds { get; set; } = 3;
    public int SourceQuantityPerTick { get; set; } = 2;
    public int SourceIntervalTicks { get; set; } = 1;
    public int EventCapacity { get; set; } = 262_144;
}

public sealed record GeneratedScenario(RandomScenarioOptions Options, FixtureLoadResult Loaded, string FixtureJson);

public static class RandomScenarioGenerator
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true
    };

    public static GeneratedScenario Generate(RandomScenarioOptions options)
    {
        Validate(options);

        var random = new Random(options.Seed);
        var resources = BuildResourceNames(options.ResourceCount);
        var positions = BuildShuffledPositions(options.Width, options.Height, random);
        var document = new GeneratedFixtureDocument
        {
            Resources = resources,
            Grid = new GeneratedGridDocument
            {
                Width = options.Width,
                Height = options.Height
            }
        };

        for (var i = 0; i < options.RockCount; i++)
        {
            var position = positions[i];
            document.Grid.Rocks.Add(new GeneratedPositionDocument { X = position.X, Y = position.Y });
        }

        var firstCellPosition = options.RockCount;
        for (var i = 0; i < options.CellCount; i++)
        {
            var position = positions[firstCellPosition + i];
            var producedIndex = random.Next(resources.Count);
            var needCount = random.Next(options.MinNeeds, options.MaxNeeds + 1);
            var needs = PickNeeds(resources.Count, producedIndex, needCount, random);

            var cell = new GeneratedCellDocument
            {
                Id = $"cell-{i:000}",
                X = position.X,
                Y = position.Y
            };

            cell.Slots.Add(new GeneratedSlotDocument
            {
                Resource = resources[producedIndex],
                Role = nameof(PoolSlotRole.SourceOutput),
                Quantity = 0
            });

            for (var needIndex = 0; needIndex < needs.Count; needIndex++)
            {
                cell.Slots.Add(new GeneratedSlotDocument
                {
                    Resource = resources[needs[needIndex]],
                    Role = nameof(PoolSlotRole.Need),
                    Quantity = 0
                });
            }

            cell.Sources.Add(new GeneratedSourceDocument
            {
                Resource = resources[producedIndex],
                QuantityPerTick = options.SourceQuantityPerTick,
                IntervalTicks = options.SourceIntervalTicks
            });

            document.Cells.Add(cell);
        }

        var json = JsonSerializer.Serialize(document, JsonOptions);
        var loaded = FixtureLoader.LoadFromJson(json);
        loaded.Options.EventCapacity = options.EventCapacity;
        return new GeneratedScenario(options, loaded, json);
    }

    private static void Validate(RandomScenarioOptions options)
    {
        if (options.Width <= 0 || options.Height <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Generated maps need positive dimensions.");
        }

        if (options.CellCount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Generated scenarios need at least one cell.");
        }

        if (options.ResourceCount < 4)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Generated scenarios need at least four resources.");
        }

        if (options.MinNeeds != 3 || options.MaxNeeds != 3)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Generated cells currently use exactly three needs, for four pool slots total.");
        }

        if (options.ResourceCount <= options.MaxNeeds)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Resource count must be greater than max needs.");
        }

        if (options.RockCount < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Rock count cannot be negative.");
        }

        if (options.CellCount + options.RockCount > options.Width * options.Height)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Cells and rocks cannot exceed map tiles.");
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

    private static List<string> BuildResourceNames(int count)
    {
        var resources = new List<string>(count);
        for (var i = 0; i < count; i++)
        {
            resources.Add(i < 26 ? ((char)('A' + i)).ToString() : $"R{i:00}");
        }

        return resources;
    }

    private static List<GridPosition> BuildShuffledPositions(int width, int height, Random random)
    {
        var positions = new List<GridPosition>(width * height);
        for (var y = 0; y < height; y++)
        {
            for (var x = 0; x < width; x++)
            {
                positions.Add(new GridPosition(x, y));
            }
        }

        for (var i = positions.Count - 1; i > 0; i--)
        {
            var swapIndex = random.Next(i + 1);
            (positions[i], positions[swapIndex]) = (positions[swapIndex], positions[i]);
        }

        return positions;
    }

    private static List<int> PickNeeds(int resourceCount, int producedIndex, int needCount, Random random)
    {
        var candidates = new List<int>(resourceCount - 1);
        for (var i = 0; i < resourceCount; i++)
        {
            if (i != producedIndex)
            {
                candidates.Add(i);
            }
        }

        for (var i = candidates.Count - 1; i > 0; i--)
        {
            var swapIndex = random.Next(i + 1);
            (candidates[i], candidates[swapIndex]) = (candidates[swapIndex], candidates[i]);
        }

        candidates.RemoveRange(needCount, candidates.Count - needCount);
        return candidates;
    }

    private sealed class GeneratedFixtureDocument
    {
        [JsonPropertyName("resources")]
        public List<string> Resources { get; set; } = new();

        [JsonPropertyName("grid")]
        public GeneratedGridDocument Grid { get; set; } = new();

        [JsonPropertyName("cells")]
        public List<GeneratedCellDocument> Cells { get; set; } = new();
    }

    private sealed class GeneratedGridDocument
    {
        [JsonPropertyName("width")]
        public int Width { get; set; }

        [JsonPropertyName("height")]
        public int Height { get; set; }

        [JsonPropertyName("rocks")]
        public List<GeneratedPositionDocument> Rocks { get; set; } = new();
    }

    private sealed class GeneratedPositionDocument
    {
        [JsonPropertyName("x")]
        public int X { get; set; }

        [JsonPropertyName("y")]
        public int Y { get; set; }
    }

    private sealed class GeneratedCellDocument
    {
        [JsonPropertyName("id")]
        public string Id { get; set; } = "";

        [JsonPropertyName("x")]
        public int X { get; set; }

        [JsonPropertyName("y")]
        public int Y { get; set; }

        [JsonPropertyName("slots")]
        public List<GeneratedSlotDocument> Slots { get; set; } = new();

        [JsonPropertyName("sources")]
        public List<GeneratedSourceDocument> Sources { get; set; } = new();
    }

    private sealed class GeneratedSlotDocument
    {
        [JsonPropertyName("resource")]
        public string Resource { get; set; } = "";

        [JsonPropertyName("role")]
        public string Role { get; set; } = "";

        [JsonPropertyName("quantity")]
        public int Quantity { get; set; }
    }

    private sealed class GeneratedSourceDocument
    {
        [JsonPropertyName("resource")]
        public string Resource { get; set; } = "";

        [JsonPropertyName("quantityPerTick")]
        public int QuantityPerTick { get; set; }

        [JsonPropertyName("intervalTicks")]
        public int IntervalTicks { get; set; }
    }
}
