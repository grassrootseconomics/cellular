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
        return _engine?.World.MoveCell(cellId, new GridPosition(x, y)) ?? false;
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
            var fixtureJson = BuildCleanFixtureJson(_loaded, _engine);
            return LoadFixtureJson(fixtureJson);
        }
        catch (Exception ex)
        {
            _lastError = ex.Message;
            return false;
        }
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
        snapshot["cells"] = BuildCellsSnapshot(_loaded, _engine);
        snapshot["swaps"] = BuildRecentSwapsSnapshot(_loaded, _engine);
        snapshot["flows"] = BuildRecentFlowsSnapshot(_loaded, _engine);
        snapshot["reactions"] = BuildRecentReactionsSnapshot(_engine);
        snapshot["possibleSwaps"] = BuildPossibleSwapsSnapshot(_loaded, _engine);
        snapshot["circuitDiagnostics"] = BuildCircuitDiagnosticsSnapshot(_loaded, _engine);
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
                ["glowing"] = cell.IsGlowing,
                ["glowTicks"] = cell.GlowTicksRemaining,
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

    private static GdArray BuildRecentSwapsSnapshot(FixtureLoadResult loaded, CellularEngine engine)
    {
        var swaps = new GdArray();
        var minTick = engine.CurrentTick - RecentEventWindowTicks;
        foreach (var simEvent in engine.Events)
        {
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
                ["initiatorReceivedBalance"] = swap.InitiatorReceivedBalanceAfterSwap,
                ["initiatorReceivedCapacity"] = swap.InitiatorReceivedCapacity,
                ["counterpartyReceivedBalance"] = swap.CounterpartyReceivedBalanceAfterSwap,
                ["counterpartyReceivedCapacity"] = swap.CounterpartyReceivedCapacity
            });
        }

        return swaps;
    }

    private static GdArray BuildRecentReactionsSnapshot(CellularEngine engine)
    {
        var reactions = new GdArray();
        var minTick = engine.CurrentTick - RecentEventWindowTicks;
        foreach (var simEvent in engine.Events)
        {
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

    private static GdArray BuildRecentFlowsSnapshot(FixtureLoadResult loaded, CellularEngine engine)
    {
        var flows = new GdArray();
        var minTick = engine.CurrentTick - RecentEventWindowTicks;
        foreach (var simEvent in engine.Events)
        {
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

    private static GdDictionary BuildCircuitDiagnosticsSnapshot(FixtureLoadResult loaded, CellularEngine engine)
    {
        var diagnostics = CircuitDiagnostics.Build(engine);
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
            var requestedOfferable = GetVisualOfferableQuantity(counterparty.Pool, requestedResource);
            var requestedReceivable = GetVisualReceivableQuantity(initiator.Pool, requestedResource);
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
                var offeredQuantity = GetVisualOfferableQuantity(initiator.Pool, offeredResource);
                var counterpartyReceivable = GetVisualReceivableQuantity(counterparty.Pool, offeredResource);
                var quantity = Math.Min(
                    engine.Options.MaxSwapQuantityPerEdge,
                    Math.Min(Math.Min(requestedOfferable, requestedReceivable), Math.Min(offeredQuantity, counterpartyReceivable)));
                if (quantity <= 0)
                {
                    continue;
                }

                possibleSwaps.Add(new GdDictionary
                {
                    ["initiator"] = initiator.Id,
                    ["counterparty"] = counterparty.Id,
                    ["initiatorPaidResource"] = loaded.Catalog.GetName(offeredResource),
                    ["counterpartyPaidResource"] = loaded.Catalog.GetName(requestedResource),
                    ["quantity"] = quantity
                });

                if (possibleSwaps.Count >= PossibleSwapSnapshotLimit)
                {
                    return;
                }
            }
        }
    }

    private static int GetVisualReceivableQuantity(SwapPoolState pool, ResourceId resource)
    {
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        return slot.Role == PoolSlotRole.SourceOutput
            ? int.MaxValue
            : Math.Max(0, slot.Capacity - slot.Quantity);
    }

    private static int GetVisualOfferableQuantity(SwapPoolState pool, ResourceId resource)
    {
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        var available = slot.Quantity;
        if (slot.Role == PoolSlotRole.Need || slot.Role == PoolSlotRole.SourceOutput && HasNeedSlot(pool))
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

    private static string ProducedResourceName(FixtureLoadResult loaded, CellState cell)
    {
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

            cells.Add(new Dictionary<string, object>
            {
                ["id"] = cell.Id,
                ["x"] = cell.Position.X,
                ["y"] = cell.Position.Y,
                ["slots"] = slots,
                ["sources"] = sources
            });
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
}
