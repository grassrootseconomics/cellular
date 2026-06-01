using System.Text.Json;

namespace CellularSim;

public sealed class InvalidFixtureException : Exception
{
    public InvalidFixtureException(string message)
        : base(message)
    {
    }
}

public sealed record FixtureLoadResult(ResourceCatalog Catalog, GridWorld World, EngineOptions Options);

public static class FixtureLoader
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true
    };

    public static FixtureLoadResult LoadFromFile(string path) => LoadFromJson(File.ReadAllText(path));

    public static FixtureLoadResult LoadFromJson(string json)
    {
        var fixture = JsonSerializer.Deserialize<FixtureDto>(json, JsonOptions)
            ?? throw new InvalidFixtureException("Fixture JSON is empty.");

        var catalog = BuildCatalog(fixture);
        var world = BuildWorld(fixture, catalog);
        var options = BuildOptions(fixture, catalog, world);
        return new FixtureLoadResult(catalog, world, options);
    }

    private static ResourceCatalog BuildCatalog(FixtureDto fixture)
    {
        if (fixture.Resources is null || fixture.Resources.Count == 0)
        {
            throw new InvalidFixtureException("Fixture must define resources.");
        }

        var catalog = new ResourceCatalog();
        var seen = new HashSet<string>(StringComparer.Ordinal);
        foreach (var resource in fixture.Resources)
        {
            if (string.IsNullOrWhiteSpace(resource))
            {
                throw new InvalidFixtureException("Resource names cannot be blank.");
            }

            if (!seen.Add(resource))
            {
                throw new InvalidFixtureException($"Duplicate resource '{resource}'.");
            }

            catalog.Register(resource);
        }

        return catalog;
    }

    private static GridWorld BuildWorld(FixtureDto fixture, ResourceCatalog catalog)
    {
        var grid = fixture.Grid ?? throw new InvalidFixtureException("Fixture must define a grid.");
        GridWorld world;
        try
        {
            world = new GridWorld(grid.Width, grid.Height);
        }
        catch (ArgumentOutOfRangeException ex)
        {
            throw new InvalidFixtureException($"Invalid grid dimensions: {ex.Message}");
        }

        foreach (var rock in grid.Rocks ?? [])
        {
            try
            {
                world.AddRock(new GridPosition(rock.X, rock.Y));
            }
            catch (Exception ex) when (ex is ArgumentOutOfRangeException or InvalidOperationException)
            {
                throw new InvalidFixtureException($"Invalid rock at ({rock.X}, {rock.Y}): {ex.Message}");
            }
        }

        if (fixture.Cells is null || fixture.Cells.Count == 0)
        {
            throw new InvalidFixtureException("Fixture must define cells.");
        }

        var cellIds = new HashSet<string>(StringComparer.Ordinal);
        foreach (var cellDto in fixture.Cells)
        {
            if (string.IsNullOrWhiteSpace(cellDto.Id))
            {
                throw new InvalidFixtureException("Cell ids cannot be blank.");
            }

            if (!cellIds.Add(cellDto.Id))
            {
                throw new InvalidFixtureException($"Duplicate cell id '{cellDto.Id}'.");
            }

            var pool = BuildPool(cellDto, catalog);
            var cell = new CellState(cellDto.Id, new GridPosition(cellDto.X, cellDto.Y), pool);

            foreach (var sourceDto in cellDto.Sources ?? [])
            {
                var sourceResource = RequireResource(catalog, sourceDto.Resource);
                if (pool.GetSlot(sourceResource) is null)
                {
                    throw new InvalidFixtureException(
                        $"Cell '{cellDto.Id}' source resource '{sourceDto.Resource}' does not have a pool slot.");
                }

                if (sourceDto.QuantityPerTick <= 0)
                {
                    throw new InvalidFixtureException($"Cell '{cellDto.Id}' source quantity must be positive.");
                }

                if (sourceDto.IntervalTicks <= 0)
                {
                    throw new InvalidFixtureException($"Cell '{cellDto.Id}' source interval must be positive.");
                }

                cell.AddSource(new CellSource(
                    sourceResource,
                    sourceDto.QuantityPerTick,
                    sourceDto.IntervalTicks));
            }

            try
            {
                world.AddCell(cell);
            }
            catch (Exception ex) when (ex is ArgumentOutOfRangeException or InvalidOperationException)
            {
                throw new InvalidFixtureException($"Invalid cell '{cellDto.Id}': {ex.Message}");
            }
        }

        return world;
    }

    private static SwapPoolState BuildPool(CellDto cellDto, ResourceCatalog catalog)
    {
        if (cellDto.Slots is null || cellDto.Slots.Count == 0)
        {
            throw new InvalidFixtureException($"Cell '{cellDto.Id}' must define at least one pool slot.");
        }

        if (cellDto.Slots.Count > SwapPoolState.MaxSlots)
        {
            throw new InvalidFixtureException($"Cell '{cellDto.Id}' has more than {SwapPoolState.MaxSlots} pool slots.");
        }

        var pool = new SwapPoolState();
        var slotResources = new HashSet<ResourceId>();
        foreach (var slotDto in cellDto.Slots)
        {
            var resource = RequireResource(catalog, slotDto.Resource);
            if (!slotResources.Add(resource))
            {
                throw new InvalidFixtureException($"Cell '{cellDto.Id}' has duplicate pool slot '{slotDto.Resource}'.");
            }

            if (!Enum.TryParse<PoolSlotRole>(slotDto.Role, true, out var role))
            {
                throw new InvalidFixtureException($"Cell '{cellDto.Id}' has invalid slot role '{slotDto.Role}'.");
            }

            var capacity = slotDto.Capacity <= 0 ? SwapPoolState.DefaultSlotCapacity : slotDto.Capacity;
            try
            {
                pool.AddSlot(resource, role, slotDto.Quantity, capacity);
            }
            catch (Exception ex) when (ex is ArgumentOutOfRangeException or InvalidOperationException)
            {
                throw new InvalidFixtureException($"Invalid slot '{slotDto.Resource}' on cell '{cellDto.Id}': {ex.Message}");
            }
        }

        return pool;
    }

    private static EngineOptions BuildOptions(FixtureDto fixture, ResourceCatalog catalog, GridWorld world)
    {
        var options = new EngineOptions();
        var engine = fixture.Engine;
        if (engine is not null)
        {
            if (engine.SwapRoundsPerTick > 0)
            {
                options.SwapRoundsPerTick = engine.SwapRoundsPerTick;
            }

            if (engine.NeedDesiredQuantity > 0)
            {
                options.NeedDesiredQuantity = engine.NeedDesiredQuantity;
            }

            if (engine.NeedOfferReserve > 0)
            {
                options.NeedOfferReserve = engine.NeedOfferReserve;
            }

            options.AllowNeedOverflowPayments = engine.AllowNeedOverflowPayments;
        }

        var win = fixture.Win;
        if (win is null)
        {
            return options;
        }

        if (win.DurationTicks > 0)
        {
            options.WinDurationTicks = win.DurationTicks;
        }

        foreach (var cellId in win.RequiredCells ?? [])
        {
            if (!world.TryGetCell(cellId, out _))
            {
                throw new InvalidFixtureException($"Required cell '{cellId}' does not exist.");
            }

            options.RequiredCellIds.Add(cellId);
        }

        foreach (var resourceName in win.RequiredResources ?? [])
        {
            options.RequiredResources.Add(RequireResource(catalog, resourceName));
        }

        return options;
    }

    private static ResourceId RequireResource(ResourceCatalog catalog, string? resourceName)
    {
        if (string.IsNullOrWhiteSpace(resourceName))
        {
            throw new InvalidFixtureException("Resource name cannot be blank.");
        }

        if (!catalog.TryGetId(resourceName, out var resource))
        {
            throw new InvalidFixtureException($"Unknown resource '{resourceName}'.");
        }

        return resource;
    }

    private sealed class FixtureDto
    {
        public List<string>? Resources { get; set; }
        public GridDto? Grid { get; set; }
        public EngineDto? Engine { get; set; }
        public List<CellDto>? Cells { get; set; }
        public WinDto? Win { get; set; }
    }

    private sealed class GridDto
    {
        public int Width { get; set; }
        public int Height { get; set; }
        public List<PositionDto>? Rocks { get; set; }
    }

    private sealed class PositionDto
    {
        public int X { get; set; }
        public int Y { get; set; }
    }

    private sealed class CellDto
    {
        public string Id { get; set; } = "";
        public int X { get; set; }
        public int Y { get; set; }
        public List<SlotDto>? Slots { get; set; }
        public List<SourceDto>? Sources { get; set; }
    }

    private sealed class SlotDto
    {
        public string Resource { get; set; } = "";
        public string Role { get; set; } = nameof(PoolSlotRole.AcceptOnly);
        public int Quantity { get; set; }
        public int Capacity { get; set; } = SwapPoolState.DefaultSlotCapacity;
    }

    private sealed class SourceDto
    {
        public string Resource { get; set; } = "";
        public int QuantityPerTick { get; set; } = 1;
        public int IntervalTicks { get; set; } = 1;
    }

    private sealed class EngineDto
    {
        public int SwapRoundsPerTick { get; set; }
        public int NeedDesiredQuantity { get; set; }
        public int NeedOfferReserve { get; set; }
        public bool AllowNeedOverflowPayments { get; set; }
    }

    private sealed class WinDto
    {
        public List<string>? RequiredCells { get; set; }
        public List<string>? RequiredResources { get; set; }
        public int DurationTicks { get; set; }
    }
}
