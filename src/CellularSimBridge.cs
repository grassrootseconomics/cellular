using Godot;
using CellularSim;
using System.Text.Json;
using GdArray = Godot.Collections.Array;
using GdDictionary = Godot.Collections.Dictionary;

[GlobalClass]
public partial class CellularSimBridge : Node
{
    private const long RecentEventWindowTicks = 12;
    private const int PossibleSwapSnapshotLimit = 4096;
    private const int StandardMinimumGrossSwapQuantity = 1;
    private const int RedMycoOutwardFeeQuantity = 1;
    private const int RedMycoMinimumGrossSwapQuantity = RedMycoOutwardFeeQuantity + 1;

    private FixtureLoadResult? _loaded;
    private CellularEngine? _engine;
    private string _lastError = "";

    public string GetLastError() => _lastError;

    public bool IsLoaded() => _engine is not null && _loaded is not null;

    public string get_last_error() => GetLastError();

    public bool is_loaded() => IsLoaded();

    public bool load_fixture_file(string path) => LoadFixtureFile(path);

    public bool load_fixture_json(string json) => LoadFixtureJson(json);

    public bool can_move_cell(string cellId, int x, int y) => CanMoveCell(cellId, x, y);

    public bool move_cell(string cellId, int x, int y) => MoveCell(cellId, x, y);

    public bool reset_with_current_layout() => ResetWithCurrentLayout();

    public bool add_myco_cell(string kind, string id, int x, int y, GdArray needs) =>
        AddMycoCell(kind, id, x, y, needs);

    public void tick_many(int count) => TickMany(count);

    public GdDictionary get_snapshot() => GetSnapshot();

    public bool LoadFixtureFile(string path)
    {
        if (!Godot.FileAccess.FileExists(path))
        {
            _lastError = $"Fixture file does not exist: {path}";
            return false;
        }

        using var file = Godot.FileAccess.Open(path, Godot.FileAccess.ModeFlags.Read);
        if (file is null)
        {
            _lastError = $"Could not open fixture file: {path}";
            return false;
        }

        return LoadFixtureJson(file.GetAsText());
    }

    public bool LoadFixtureJson(string json)
    {
        try
        {
            _loaded = FixtureLoader.LoadFromJson(json);
            _loaded.Options.EventCapacity = Math.Max(_loaded.Options.EventCapacity, 65_536);
            _engine = new CellularEngine(_loaded.World, _loaded.Options);
            _lastError = "";
            return true;
        }
        catch (Exception ex)
        {
            _loaded = null;
            _engine = null;
            _lastError = ex.Message;
            return false;
        }
    }

    public bool CanMoveCell(string cellId, int x, int y)
    {
        return _engine?.World.CanMoveCell(cellId, new GridPosition(x, y)) ?? false;
    }

    public bool MoveCell(string cellId, int x, int y)
    {
        if (_engine is null)
        {
            return false;
        }

        var moved = _engine.World.MoveCell(cellId, new GridPosition(x, y));
        if (moved)
        {
            _engine.RefreshAdaptiveMyco();
        }

        return moved;
    }

    public bool ResetWithCurrentLayout()
    {
        if (_engine is null || _loaded is null)
        {
            _lastError = "No loaded Cellular fixture to reset.";
            return false;
        }

        try
        {
            _engine.ResetStateWithCurrentLayout();
            _lastError = "";
            return true;
        }
        catch (Exception ex)
        {
            _lastError = ex.Message;
            return false;
        }
    }

    public bool AddMycoCell(string kind, string id, int x, int y, GdArray needs)
    {
        if (_engine is null || _loaded is null)
        {
            _lastError = "No loaded Cellular fixture to add a myco cell to.";
            return false;
        }

        if (!Enum.TryParse<CellKind>(kind, true, out var cellKind)
            || cellKind is not (CellKind.WhiteMyco or CellKind.RedMyco))
        {
            _lastError = $"Unknown myco kind '{kind}'.";
            return false;
        }

        if (string.IsNullOrWhiteSpace(id))
        {
            _lastError = "Myco cell id cannot be blank.";
            return false;
        }

        if (_engine.World.TryGetCell(id, out _))
        {
            _lastError = $"Cell id '{id}' already exists.";
            return false;
        }

        var position = new GridPosition(x, y);
        if (!_engine.World.InBounds(position))
        {
            _lastError = $"Myco position ({x}, {y}) is outside the grid.";
            return false;
        }

        if (_engine.World.HasRockAt(position) || _engine.World.TryGetCellAt(position, out _))
        {
            _lastError = $"Myco position ({x}, {y}) is not empty.";
            return false;
        }

        try
        {
            var pool = new SwapPoolState();
            _engine.World.AddCell(new CellState(id, position, pool, cellKind));
            AddRequiredCell(_engine.Options, id);
            _engine.ResetStateWithCurrentLayout();
            _lastError = "";
            return true;
        }
        catch (Exception ex)
        {
            _lastError = ex.Message;
            return false;
        }
    }

    private static void AddRequiredCell(EngineOptions options, string cellId)
    {
        foreach (var existing in options.RequiredCellIds)
        {
            if (string.Equals(existing, cellId, StringComparison.Ordinal))
            {
                return;
            }
        }

        options.RequiredCellIds.Add(cellId);
    }

    public void TickMany(int count)
    {
        if (_engine is null || count <= 0)
        {
            return;
        }

        _engine.RunTicks(Math.Min(count, 512));
    }

    public GdDictionary GetSnapshot()
    {
        var snapshot = new GdDictionary();
        if (_engine is null || _loaded is null)
        {
            snapshot["loaded"] = false;
            snapshot["lastError"] = _lastError;
            return snapshot;
        }

        snapshot["loaded"] = true;
        snapshot["tick"] = _engine.CurrentTick;
        snapshot["won"] = _engine.Circuit.IsWon;
        snapshot["alive"] = _engine.Circuit.IsAliveThisTick;
        snapshot["sustainedTicks"] = _engine.Circuit.SustainedTicks;
        snapshot["score"] = _engine.Score.TotalScore;
        snapshot["width"] = _engine.World.Width;
        snapshot["height"] = _engine.World.Height;
        var events = _engine.Events;
        snapshot["rocks"] = BuildRocksSnapshot(_engine);
        snapshot["cells"] = BuildCellsSnapshot(_loaded, _engine);
        snapshot["swaps"] = BuildRecentSwapsSnapshot(_loaded, _engine, events);
        snapshot["flows"] = BuildRecentFlowsSnapshot(_loaded, _engine, events);
        snapshot["reactions"] = BuildRecentReactionsSnapshot(_engine, events);
        snapshot["possibleSwaps"] = BuildPossibleSwapsSnapshot(_loaded, _engine);
        snapshot["circuitDiagnostics"] = BuildCircuitDiagnosticsSnapshot(_loaded, _engine, events);
        return snapshot;
    }

    private static GdArray BuildCellsSnapshot(FixtureLoadResult loaded, CellularEngine engine)
    {
        var cells = new GdArray();
        foreach (var cell in engine.World.Cells)
        {
            var cellData = new GdDictionary
            {
                ["id"] = cell.Id,
                ["x"] = cell.Position.X,
                ["y"] = cell.Position.Y,
                ["kind"] = cell.Kind.ToString(),
                ["glowing"] = cell.IsGlowing,
                ["glowTicks"] = cell.GlowTicksRemaining,
                ["mycoWaiting"] = cell.IsMyco && cell.Pool.Slots.Count == 0,
                ["strain"] = cell.Strain.Total,
                ["producedResource"] = ProducedResourceName(loaded, cell),
                ["slots"] = BuildSlotsSnapshot(loaded, cell)
            };
            cells.Add(cellData);
        }

        return cells;
    }

    private static GdArray BuildSlotsSnapshot(FixtureLoadResult loaded, CellState cell)
    {
        var slots = new GdArray();
        foreach (var slot in cell.Pool.Slots)
        {
            var slotData = new GdDictionary
            {
                ["resource"] = loaded.Catalog.GetName(slot.Resource),
                ["role"] = slot.Role.ToString(),
                ["quantity"] = slot.Quantity,
                ["capacity"] = slot.Capacity,
                ["fullness"] = slot.Capacity <= 0 ? 0.0 : (double)slot.Quantity / slot.Capacity
            };
            slots.Add(slotData);
        }

        return slots;
    }

    private static GdArray BuildRecentSwapsSnapshot(
        FixtureLoadResult loaded,
        CellularEngine engine,
        IReadOnlyList<SimEvent> events)
    {
        var swaps = new GdArray();
        var minTick = engine.CurrentTick - RecentEventWindowTicks;
        for (var i = RecentStartIndex(events, minTick); i < events.Count; i++)
        {
            var simEvent = events[i];
            if (simEvent is not SwapEvent swap || swap.Tick < minTick)
            {
                continue;
            }

            swaps.Add(new GdDictionary
            {
                ["tick"] = swap.Tick,
                ["initiator"] = swap.InitiatorCellId,
                ["counterparty"] = swap.CounterpartyCellId,
                ["initiatorPaidResource"] = loaded.Catalog.GetName(swap.InitiatorPaidResource),
                ["counterpartyPaidResource"] = loaded.Catalog.GetName(swap.CounterpartyPaidResource),
                ["initiatorPaidQuantity"] = swap.InitiatorPaidQuantity,
                ["counterpartyPaidQuantity"] = swap.CounterpartyPaidQuantity,
                ["initiatorReceivedQuantity"] = swap.InitiatorReceivedQuantity,
                ["counterpartyReceivedQuantity"] = swap.CounterpartyReceivedQuantity,
                ["initiatorReceivedBalance"] = swap.InitiatorReceivedBalanceAfterSwap,
                ["initiatorReceivedCapacity"] = swap.InitiatorReceivedCapacity,
                ["counterpartyReceivedBalance"] = swap.CounterpartyReceivedBalanceAfterSwap,
                ["counterpartyReceivedCapacity"] = swap.CounterpartyReceivedCapacity
            });
        }

        return swaps;
    }

    private static GdArray BuildRecentReactionsSnapshot(CellularEngine engine, IReadOnlyList<SimEvent> events)
    {
        var reactions = new GdArray();
        var minTick = engine.CurrentTick - RecentEventWindowTicks;
        for (var i = RecentStartIndex(events, minTick); i < events.Count; i++)
        {
            var simEvent = events[i];
            if (simEvent is ReactionEvent reaction && reaction.Tick >= minTick)
            {
                reactions.Add(new GdDictionary
                {
                    ["tick"] = reaction.Tick,
                    ["cellId"] = reaction.CellId
                });
            }
        }

        return reactions;
    }

    private static GdArray BuildRecentFlowsSnapshot(
        FixtureLoadResult loaded,
        CellularEngine engine,
        IReadOnlyList<SimEvent> events)
    {
        var flows = new GdArray();
        var minTick = engine.CurrentTick - RecentEventWindowTicks;
        for (var i = RecentStartIndex(events, minTick); i < events.Count; i++)
        {
            var simEvent = events[i];
            if (simEvent is not FlowEvent flow || flow.Tick < minTick)
            {
                continue;
            }

            flows.Add(new GdDictionary
            {
                ["tick"] = flow.Tick,
                ["sourceCellId"] = flow.SourceCellId,
                ["targetCellId"] = flow.TargetCellId,
                ["resource"] = loaded.Catalog.GetName(flow.Resource),
                ["quantity"] = flow.Quantity,
                ["kind"] = flow.Kind.ToString()
            });
        }

        return flows;
    }

    private static int RecentStartIndex(IReadOnlyList<SimEvent> events, long minTick)
    {
        for (var i = events.Count - 1; i >= 0; i--)
        {
            if (events[i].Tick < minTick)
            {
                return i + 1;
            }
        }

        return 0;
    }

    private static GdDictionary BuildCircuitDiagnosticsSnapshot(
        FixtureLoadResult loaded,
        CellularEngine engine,
        IReadOnlyList<SimEvent> events)
    {
        var diagnostics = CircuitDiagnostics.Build(
            engine.World,
            engine.Options,
            events,
            engine.CurrentTick,
            engine.Circuit.IsAliveThisTick,
            engine.Circuit.IsWon,
            engine.Circuit.SustainedTicks);
        return new GdDictionary
        {
            ["alive"] = diagnostics.IsAlive,
            ["won"] = diagnostics.IsWon,
            ["sustainedTicks"] = diagnostics.SustainedTicks,
            ["sinceTick"] = diagnostics.SinceTick,
            ["directedEdges"] = BuildCircuitEdgesSnapshot(loaded, diagnostics, engine.CurrentTick),
            ["strongGroups"] = BuildCircuitGroupsSnapshot(diagnostics.StrongGroups),
            ["weakGroups"] = BuildCircuitGroupsSnapshot(diagnostics.WeakGroups),
            ["nonGlowingRequiredCells"] = BuildStringArray(diagnostics.NonGlowingRequiredCells),
            ["missingRequiredResources"] = BuildResourceArray(loaded, diagnostics.MissingRequiredResources)
        };
    }

    private static GdArray BuildCircuitEdgesSnapshot(FixtureLoadResult loaded, CircuitDiagnosticsSnapshot diagnostics, long currentTick)
    {
        var edges = new GdArray();
        foreach (var edge in diagnostics.DirectedEdges)
        {
            edges.Add(new GdDictionary
            {
                ["sourceCellId"] = edge.SourceCellId,
                ["targetCellId"] = edge.TargetCellId,
                ["latestTick"] = edge.LatestTick,
                ["ageTicks"] = Math.Max(0, currentTick - edge.LatestTick),
                ["quantity"] = edge.Quantity,
                ["resources"] = BuildResourceArray(loaded, edge.Resources)
            });
        }

        return edges;
    }

    private static GdArray BuildCircuitGroupsSnapshot(IReadOnlyList<CircuitDiagnosticGroup> groups)
    {
        var groupArray = new GdArray();
        foreach (var group in groups)
        {
            groupArray.Add(BuildStringArray(group.CellIds));
        }

        return groupArray;
    }

    private static GdArray BuildStringArray(IReadOnlyList<string> values)
    {
        var array = new GdArray();
        foreach (var value in values)
        {
            array.Add(value);
        }

        return array;
    }

    private static GdArray BuildRocksSnapshot(CellularEngine engine)
    {
        var rocks = new GdArray();
        foreach (var rock in engine.World.Rocks)
        {
            rocks.Add(new GdDictionary
            {
                ["x"] = rock.X,
                ["y"] = rock.Y
            });
        }

        return rocks;
    }

    private static GdArray BuildResourceArray(FixtureLoadResult loaded, IReadOnlyList<ResourceId> resources)
    {
        var array = new GdArray();
        foreach (var resource in resources)
        {
            array.Add(loaded.Catalog.GetName(resource));
        }

        return array;
    }

    private static GdArray BuildPossibleSwapsSnapshot(FixtureLoadResult loaded, CellularEngine engine)
    {
        var possibleSwaps = new GdArray();
        foreach (var edge in engine.World.AdjacentEdges)
        {
            AddPossibleSwapDirection(loaded, engine, edge.A, edge.B, possibleSwaps);
            if (possibleSwaps.Count >= PossibleSwapSnapshotLimit)
            {
                break;
            }

            AddPossibleSwapDirection(loaded, engine, edge.B, edge.A, possibleSwaps);
            if (possibleSwaps.Count >= PossibleSwapSnapshotLimit)
            {
                break;
            }
        }

        return possibleSwaps;
    }

    private static void AddPossibleSwapDirection(
        FixtureLoadResult loaded,
        CellularEngine engine,
        int initiatorIndex,
        int counterpartyIndex,
        GdArray possibleSwaps)
    {
        if (possibleSwaps.Count >= PossibleSwapSnapshotLimit)
        {
            return;
        }

        var initiator = engine.World.Cells[initiatorIndex];
        var counterparty = engine.World.Cells[counterpartyIndex];
        var initiatorSlots = initiator.Pool.Slots;

        foreach (var requestedSlot in initiatorSlots)
        {
            if (requestedSlot.Role != PoolSlotRole.Need)
            {
                continue;
            }

            var requestedResource = requestedSlot.Resource;
            var requestedOfferable = GetVisualOfferableQuantity(engine, counterparty, requestedResource);
            var requestedReceivable = GetVisualRequestedReceivableQuantity(engine, initiator, requestedResource);
            if (requestedOfferable <= 0 || requestedReceivable <= 0)
            {
                continue;
            }

            foreach (var offeredSlot in initiatorSlots)
            {
                if (offeredSlot.Resource == requestedResource)
                {
                    continue;
                }

                var offeredResource = offeredSlot.Resource;
                var offeredQuantity = GetVisualOfferableQuantity(engine, initiator, offeredResource);
                var counterpartyReceivable = GetVisualReceivableQuantity(engine, counterparty, offeredResource);
                var quantities = GetVisualSwapQuantities(
                    engine,
                    initiator,
                    counterparty,
                    offeredQuantity,
                    requestedOfferable,
                    requestedReceivable,
                    counterpartyReceivable);
                if (quantities is null)
                {
                    continue;
                }

                possibleSwaps.Add(new GdDictionary
                {
                    ["initiator"] = initiator.Id,
                    ["counterparty"] = counterparty.Id,
                    ["initiatorPaidResource"] = loaded.Catalog.GetName(offeredResource),
                    ["counterpartyPaidResource"] = loaded.Catalog.GetName(requestedResource),
                    ["quantity"] = Math.Max(quantities.Value.InitiatorPaidQuantity, quantities.Value.CounterpartyPaidQuantity),
                    ["initiatorPaidQuantity"] = quantities.Value.InitiatorPaidQuantity,
                    ["counterpartyPaidQuantity"] = quantities.Value.CounterpartyPaidQuantity,
                    ["initiatorReceivedQuantity"] = quantities.Value.InitiatorReceivedQuantity,
                    ["counterpartyReceivedQuantity"] = quantities.Value.CounterpartyReceivedQuantity
                });

                if (possibleSwaps.Count >= PossibleSwapSnapshotLimit)
                {
                    return;
                }
            }
        }
    }

    private static VisualSwapQuantities? GetVisualSwapQuantities(
        CellularEngine engine,
        CellState initiator,
        CellState counterparty,
        int initiatorPaidOfferable,
        int counterpartyPaidOfferable,
        int initiatorReceivable,
        int counterpartyReceivable)
    {
        var initiatorOutwardFee = GetRedMycoOutwardFee(initiator);
        var counterpartyOutwardFee = GetRedMycoOutwardFee(counterparty);
        // Keep visual possible-swaps aligned with the engine: red myco requires
        // a gross exchange envelope of at least two, otherwise it is not a swap.
        var minimumGrossQuantity = GetMinimumGrossSwapQuantity(initiatorOutwardFee, counterpartyOutwardFee);
        var grossQuantity = Math.Min(
            engine.Options.MaxSwapQuantityPerEdge,
            Math.Min(
                Math.Min(
                    initiatorPaidOfferable,
                    counterpartyPaidOfferable),
                Math.Min(
                    IncreaseLimit(initiatorReceivable, counterpartyOutwardFee),
                    IncreaseLimit(counterpartyReceivable, initiatorOutwardFee))));
        return grossQuantity >= minimumGrossQuantity
            ? new VisualSwapQuantities(
                grossQuantity,
                grossQuantity,
                grossQuantity - counterpartyOutwardFee,
                grossQuantity - initiatorOutwardFee)
            : null;
    }

    private static int GetVisualRequestedReceivableQuantity(CellularEngine engine, CellState cell, ResourceId resource)
    {
        var slot = cell.Pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        if (cell.IsMyco)
        {
            return Math.Max(0, slot.Capacity - slot.Quantity);
        }

        if (slot.Role == PoolSlotRole.Need)
        {
            var target = Math.Min(slot.Capacity, engine.Options.NeedDesiredQuantity);
            return Math.Max(0, target - slot.Quantity);
        }

        return GetVisualReceivableQuantity(engine, cell, resource);
    }

    private static int GetVisualReceivableQuantity(CellularEngine engine, CellState cell, ResourceId resource)
    {
        var pool = cell.Pool;
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        if (cell.IsMyco)
        {
            return Math.Max(0, slot.Capacity - slot.Quantity);
        }

        return slot.Role == PoolSlotRole.SourceOutput
            || slot.Role == PoolSlotRole.Need && engine.Options.AllowNeedOverflowPayments
            ? int.MaxValue
            : Math.Max(0, slot.Capacity - slot.Quantity);
    }

    private static int GetVisualOfferableQuantity(CellularEngine engine, CellState cell, ResourceId resource)
    {
        var pool = cell.Pool;
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        var available = slot.Quantity;
        if (cell.IsMyco)
        {
            return Math.Max(0, available);
        }

        if (slot.Role == PoolSlotRole.Need)
        {
            available -= engine.Options.NeedOfferReserve;
        }
        else if (slot.Role == PoolSlotRole.SourceOutput && HasNeedSlot(pool))
        {
            available--;
        }

        return Math.Max(0, available);
    }

    private static bool HasNeedSlot(SwapPoolState pool)
    {
        foreach (var slot in pool.Slots)
        {
            if (slot.Role == PoolSlotRole.Need)
            {
                return true;
            }
        }

        return false;
    }

    private static int IncreaseLimit(int value, int increase)
    {
        if (increase <= 0 || value == int.MaxValue)
        {
            return value;
        }

        return value > int.MaxValue - increase ? int.MaxValue : value + increase;
    }

    private static int GetRedMycoOutwardFee(CellState cell) => cell.IsRedMyco ? RedMycoOutwardFeeQuantity : 0;

    private static int GetMinimumGrossSwapQuantity(int initiatorOutwardFee, int counterpartyOutwardFee) =>
        initiatorOutwardFee > 0 || counterpartyOutwardFee > 0
            ? RedMycoMinimumGrossSwapQuantity
            : StandardMinimumGrossSwapQuantity;

    private static string ProducedResourceName(FixtureLoadResult loaded, CellState cell)
    {
        if (cell.IsMyco)
        {
            return "";
        }

        foreach (var source in cell.Sources)
        {
            return loaded.Catalog.GetName(source.Resource);
        }

        foreach (var slot in cell.Pool.Slots)
        {
            if (slot.Role == PoolSlotRole.SourceOutput)
            {
                return loaded.Catalog.GetName(slot.Resource);
            }
        }

        return "";
    }

    private static string BuildCleanFixtureJson(FixtureLoadResult loaded, CellularEngine engine)
    {
        var resources = new List<string>(loaded.Catalog.Count);
        for (var i = 0; i < loaded.Catalog.Count; i++)
        {
            resources.Add(loaded.Catalog.GetName(new ResourceId(i)));
        }

        var rocks = new List<object>(engine.World.Rocks.Count);
        foreach (var rock in engine.World.Rocks)
        {
            rocks.Add(new Dictionary<string, object>
            {
                ["x"] = rock.X,
                ["y"] = rock.Y
            });
        }

        var cells = new List<object>(engine.World.Cells.Count);
        foreach (var cell in engine.World.Cells)
        {
            var slots = new List<object>(cell.Pool.Slots.Count);
            if (!cell.IsMyco)
            {
                foreach (var slot in cell.Pool.Slots)
                {
                    slots.Add(new Dictionary<string, object>
                    {
                        ["resource"] = loaded.Catalog.GetName(slot.Resource),
                        ["role"] = slot.Role.ToString(),
                        ["quantity"] = 0,
                        ["capacity"] = slot.Capacity
                    });
                }
            }

            var sources = new List<object>(cell.Sources.Count);
            foreach (var source in cell.Sources)
            {
                sources.Add(new Dictionary<string, object>
                {
                    ["resource"] = loaded.Catalog.GetName(source.Resource),
                    ["quantityPerTick"] = source.QuantityPerTick,
                    ["intervalTicks"] = source.IntervalTicks
                });
            }

            var cellDoc = new Dictionary<string, object>
            {
                ["id"] = cell.Id,
                ["x"] = cell.Position.X,
                ["y"] = cell.Position.Y,
                ["slots"] = slots,
                ["sources"] = sources
            };
            if (cell.Kind != CellKind.Standard)
            {
                cellDoc["kind"] = cell.Kind.ToString();
            }

            cells.Add(cellDoc);
        }

        var requiredResources = new List<string>(engine.Options.RequiredResources.Count);
        foreach (var resource in engine.Options.RequiredResources)
        {
            requiredResources.Add(loaded.Catalog.GetName(resource));
        }

        var fixture = new Dictionary<string, object>
        {
            ["resources"] = resources,
            ["grid"] = new Dictionary<string, object>
            {
                ["width"] = engine.World.Width,
                ["height"] = engine.World.Height,
                ["rocks"] = rocks
            },
            ["engine"] = new Dictionary<string, object>
            {
                ["glowTtlTicks"] = engine.Options.GlowTtlTicks,
                ["winRecentFlowWindowTicks"] = engine.Options.WinRecentFlowWindowTicks,
                ["swapRoundsPerTick"] = engine.Options.SwapRoundsPerTick,
                ["needDesiredQuantity"] = engine.Options.NeedDesiredQuantity,
                ["needOfferReserve"] = engine.Options.NeedOfferReserve,
                ["allowNeedOverflowPayments"] = engine.Options.AllowNeedOverflowPayments
            },
            ["cells"] = cells,
            ["win"] = new Dictionary<string, object>
            {
                ["requiredCells"] = engine.Options.RequiredCellIds.ToArray(),
                ["requiredResources"] = requiredResources,
                ["durationTicks"] = engine.Options.WinDurationTicks
            }
        };

        return JsonSerializer.Serialize(fixture);
    }

    private readonly record struct VisualSwapQuantities(
        int InitiatorPaidQuantity,
        int CounterpartyPaidQuantity,
        int InitiatorReceivedQuantity,
        int CounterpartyReceivedQuantity);
}
