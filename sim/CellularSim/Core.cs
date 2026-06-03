namespace CellularSim;

/// <summary>
/// Dense integer resource identifier used inside simulation hot paths.
/// </summary>
public readonly record struct ResourceId(int Value)
{
    public bool IsValid => Value >= 0;
}

/// <summary>
/// Boundary lookup between human-readable resource names and dense IDs.
/// </summary>
public sealed class ResourceCatalog
{
    private readonly Dictionary<string, ResourceId> _idsByName = new(StringComparer.Ordinal);
    private readonly List<string> _names = new();

    public int Count => _names.Count;

    public ResourceId Register(string name)
    {
        if (string.IsNullOrWhiteSpace(name))
        {
            throw new ArgumentException("Resource name cannot be blank.", nameof(name));
        }

        if (_idsByName.TryGetValue(name, out var existing))
        {
            return existing;
        }

        var id = new ResourceId(_names.Count);
        _idsByName.Add(name, id);
        _names.Add(name);
        return id;
    }

    public ResourceId GetId(string name)
    {
        if (_idsByName.TryGetValue(name, out var id))
        {
            return id;
        }

        throw new KeyNotFoundException($"Unknown resource '{name}'.");
    }

    public bool TryGetId(string name, out ResourceId id) => _idsByName.TryGetValue(name, out id);

    public string GetName(ResourceId id)
    {
        if (!id.IsValid || id.Value >= _names.Count)
        {
            throw new ArgumentOutOfRangeException(nameof(id), "Unknown resource id.");
        }

        return _names[id.Value];
    }
}

public enum PoolSlotRole
{
    /// <summary>
    /// A resource this cell wants to receive from neighbors and consumes during reaction.
    /// </summary>
    Need,

    /// <summary>
    /// A resource this cell can route without making it part of its reaction requirement.
    /// </summary>
    AcceptOnly,

    /// <summary>
    /// A resource produced by this cell. It can be offered outward and can receive returned output from neighbors.
    /// </summary>
    SourceOutput,

    Catalyst
}

public enum CellKind
{
    Standard,
    WhiteMyco,
    RedMyco
}

public sealed class PoolSlot
{
    public PoolSlot(ResourceId resource, PoolSlotRole role, int quantity = 0, int capacity = SwapPoolState.DefaultSlotCapacity)
    {
        if (!resource.IsValid)
        {
            throw new ArgumentException("Resource id must be valid.", nameof(resource));
        }

        if (capacity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(capacity), "Capacity must be positive.");
        }

        if (quantity < 0 || quantity > capacity)
        {
            throw new ArgumentOutOfRangeException(nameof(quantity), "Quantity must be within slot capacity.");
        }

        Resource = resource;
        Role = role;
        Capacity = capacity;
        Quantity = quantity;
    }

    public ResourceId Resource { get; }
    public PoolSlotRole Role { get; }
    public int Capacity { get; }
    public int Quantity { get; private set; }

    public bool CanReceive(int amount = 1) => amount > 0 && Quantity + amount <= Capacity;

    public bool CanSend(int amount = 1) => amount > 0 && Quantity >= amount;

    public int Add(int amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be positive.");
        }

        var accepted = Math.Min(amount, Capacity - Quantity);
        Quantity += accepted;
        return accepted;
    }

    public void Remove(int amount)
    {
        if (!CanSend(amount))
        {
            throw new InvalidOperationException("Slot does not have enough quantity to remove.");
        }

        Quantity -= amount;
    }
}

/// <summary>
/// Bounded local pool for one cell. Milestone 1 supports up to four slots.
/// </summary>
public sealed class SwapPoolState
{
    public const int MaxSlots = 4;
    public const int DefaultSlotCapacity = 100;

    private readonly List<PoolSlot> _slots = new(MaxSlots);

    public IReadOnlyList<PoolSlot> Slots => _slots;

    public PoolSlot AddSlot(ResourceId resource, PoolSlotRole role, int quantity = 0, int capacity = DefaultSlotCapacity)
    {
        if (_slots.Count >= MaxSlots)
        {
            throw new InvalidOperationException($"Pools cannot have more than {MaxSlots} slots.");
        }

        if (GetSlot(resource) is not null)
        {
            throw new InvalidOperationException("Pools cannot contain duplicate resource slots.");
        }

        var slot = new PoolSlot(resource, role, quantity, capacity);
        _slots.Add(slot);
        return slot;
    }

    public void ClearSlots() => _slots.Clear();

    public PoolSlot? GetSlot(ResourceId resource)
    {
        for (var i = 0; i < _slots.Count; i++)
        {
            var slot = _slots[i];
            if (slot.Resource == resource)
            {
                return slot;
            }
        }

        return null;
    }

    public bool Accepts(ResourceId resource) => GetSlot(resource) is not null;

    public int GetQuantity(ResourceId resource) => GetSlot(resource)?.Quantity ?? 0;

    public bool CanReceive(ResourceId resource, int amount = 1, int reservedIncoming = 0)
    {
        var slot = GetSlot(resource);
        return slot is not null && amount > 0 && slot.Quantity + reservedIncoming + amount <= slot.Capacity;
    }

    public bool CanSend(ResourceId resource, int amount = 1, int reservedOutgoing = 0)
    {
        var slot = GetSlot(resource);
        return slot is not null && amount > 0 && slot.Quantity - reservedOutgoing >= amount;
    }

    public int AddResource(ResourceId resource, int amount)
    {
        var slot = GetSlot(resource) ?? throw new InvalidOperationException("Pool does not accept this resource.");
        return slot.Add(amount);
    }

    public void RemoveResource(ResourceId resource, int amount)
    {
        var slot = GetSlot(resource) ?? throw new InvalidOperationException("Pool does not contain this resource.");
        slot.Remove(amount);
    }

    public bool CanReact()
    {
        var hasNeed = false;
        var hasActiveSlot = false;

        for (var i = 0; i < _slots.Count; i++)
        {
            var slot = _slots[i];
            if (slot.Role == PoolSlotRole.Need)
            {
                hasNeed = true;
            }

            if (slot.Role == PoolSlotRole.AcceptOnly)
            {
                continue;
            }

            hasActiveSlot = true;
            if (slot.Quantity < 1)
            {
                return false;
            }
        }

        return hasNeed && hasActiveSlot;
    }

    public void React()
    {
        if (!CanReact())
        {
            throw new InvalidOperationException("Pool cannot react until every Need slot has at least one unit.");
        }

        for (var i = 0; i < _slots.Count; i++)
        {
            var slot = _slots[i];
            if (slot.Role != PoolSlotRole.AcceptOnly)
            {
                slot.Remove(1);
            }
        }
    }
}

public sealed class PrivateInventory
{
    private readonly Dictionary<ResourceId, int> _quantities = new();

    public int GetQuantity(ResourceId resource) => _quantities.TryGetValue(resource, out var quantity) ? quantity : 0;

    public void Add(ResourceId resource, int amount)
    {
        if (!resource.IsValid)
        {
            throw new ArgumentException("Resource id must be valid.", nameof(resource));
        }

        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be positive.");
        }

        _quantities[resource] = GetQuantity(resource) + amount;
    }

    public bool MoveToPool(SwapPoolState pool, ResourceId resource, int amount, PoolSlotRole newSlotRole = PoolSlotRole.AcceptOnly)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be positive.");
        }

        if (GetQuantity(resource) < amount)
        {
            return false;
        }

        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            slot = pool.AddSlot(resource, newSlotRole);
        }

        if (!slot.CanReceive(amount))
        {
            return false;
        }

        _quantities[resource] -= amount;
        pool.AddResource(resource, amount);
        return true;
    }

    public bool MoveFromPool(SwapPoolState pool, ResourceId resource, int amount)
    {
        if (amount <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(amount), "Amount must be positive.");
        }

        if (!pool.CanSend(resource, amount))
        {
            return false;
        }

        pool.RemoveResource(resource, amount);
        Add(resource, amount);
        return true;
    }
}

public readonly record struct GridPosition(int X, int Y);

public sealed class CellSource
{
    public CellSource(ResourceId resource, int quantityPerTick = 1, int intervalTicks = 1)
    {
        if (!resource.IsValid)
        {
            throw new ArgumentException("Resource id must be valid.", nameof(resource));
        }

        if (quantityPerTick <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(quantityPerTick), "Quantity per tick must be positive.");
        }

        if (intervalTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(intervalTicks), "Interval ticks must be positive.");
        }

        Resource = resource;
        QuantityPerTick = quantityPerTick;
        IntervalTicks = intervalTicks;
    }

    public ResourceId Resource { get; }
    public int QuantityPerTick { get; }
    public int IntervalTicks { get; }
}

public sealed class StrainState
{
    public int UnmetNeedTicks { get; internal set; }
    public int FailedSwapCount { get; internal set; }
    public int SourceBlockedTicks { get; internal set; }
    public int OverCapacityPressureTicks { get; internal set; }
    public int Total => UnmetNeedTicks + FailedSwapCount + SourceBlockedTicks + OverCapacityPressureTicks;
}

public sealed class CellState
{
    private readonly List<CellSource> _sources = new();

    public CellState(string id, GridPosition position, SwapPoolState? pool = null, CellKind kind = CellKind.Standard)
    {
        if (string.IsNullOrWhiteSpace(id))
        {
            throw new ArgumentException("Cell id cannot be blank.", nameof(id));
        }

        Id = id;
        Position = position;
        Pool = pool ?? new SwapPoolState();
        Kind = kind;
    }

    public int Index { get; internal set; } = -1;
    public string Id { get; }
    public CellKind Kind { get; }
    public GridPosition Position { get; internal set; }
    public SwapPoolState Pool { get; }
    public IReadOnlyList<CellSource> Sources => _sources;
    public StrainState Strain { get; } = new();
    public int GlowTicksRemaining { get; internal set; }
    public bool IsMyco => Kind is CellKind.WhiteMyco or CellKind.RedMyco;
    public bool IsRedMyco => Kind == CellKind.RedMyco;
    public bool IsGlowing => Kind == CellKind.WhiteMyco || GlowTicksRemaining > 0;

    public void AddSource(CellSource source) => _sources.Add(source);
}

public readonly record struct CellEdge(int A, int B);

public sealed class GridWorld
{
    private static readonly GridPosition[] NeighborOffsets =
    [
        new(1, 0),
        new(0, 1),
        new(-1, 0),
        new(0, -1)
    ];

    private readonly List<CellState> _cells = new();
    private readonly Dictionary<string, int> _cellIndexesById = new(StringComparer.Ordinal);
    private readonly Dictionary<GridPosition, int> _occupancy = new();
    private readonly HashSet<GridPosition> _rocks = new();
    private readonly List<CellEdge> _adjacentEdges = new();
    private bool _adjacentEdgesDirty = true;

    public GridWorld(int width, int height)
    {
        if (width <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(width), "Width must be positive.");
        }

        if (height <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(height), "Height must be positive.");
        }

        Width = width;
        Height = height;
    }

    public int Width { get; }
    public int Height { get; }
    public IReadOnlyList<CellState> Cells => _cells;
    public IReadOnlyCollection<GridPosition> Rocks => _rocks;
    public IReadOnlyList<CellEdge> AdjacentEdges => GetAdjacentEdges();
    public long TopologyVersion { get; private set; }

    public bool InBounds(GridPosition position) =>
        position.X >= 0 && position.X < Width && position.Y >= 0 && position.Y < Height;

    public void AddRock(GridPosition position)
    {
        EnsureInBounds(position);

        if (_occupancy.ContainsKey(position))
        {
            throw new InvalidOperationException("Cannot place a rock on a cell.");
        }

        if (_rocks.Add(position))
        {
            _adjacentEdgesDirty = true;
            TopologyVersion++;
        }
    }

    public CellState AddCell(CellState cell)
    {
        EnsureInBounds(cell.Position);

        if (_rocks.Contains(cell.Position))
        {
            throw new InvalidOperationException("Cannot place a cell on a rock.");
        }

        if (_occupancy.ContainsKey(cell.Position))
        {
            throw new InvalidOperationException("Cannot place two cells on the same tile.");
        }

        if (_cellIndexesById.ContainsKey(cell.Id))
        {
            throw new InvalidOperationException($"Duplicate cell id '{cell.Id}'.");
        }

        cell.Index = _cells.Count;
        _cells.Add(cell);
        _cellIndexesById.Add(cell.Id, cell.Index);
        _occupancy.Add(cell.Position, cell.Index);
        _adjacentEdgesDirty = true;
        TopologyVersion++;
        return cell;
    }

    public CellState GetCell(string id)
    {
        if (_cellIndexesById.TryGetValue(id, out var index))
        {
            return _cells[index];
        }

        throw new KeyNotFoundException($"Unknown cell '{id}'.");
    }

    public bool TryGetCell(string id, out CellState? cell)
    {
        if (_cellIndexesById.TryGetValue(id, out var index))
        {
            cell = _cells[index];
            return true;
        }

        cell = null;
        return false;
    }

    public bool TryGetCellAt(GridPosition position, out CellState? cell)
    {
        if (_occupancy.TryGetValue(position, out var index))
        {
            cell = _cells[index];
            return true;
        }

        cell = null;
        return false;
    }

    public bool HasRockAt(GridPosition position) => _rocks.Contains(position);

    public bool CanMoveCell(string id, GridPosition position)
    {
        if (!_cellIndexesById.TryGetValue(id, out var index))
        {
            return false;
        }

        if (!InBounds(position) || _rocks.Contains(position))
        {
            return false;
        }

        return !_occupancy.TryGetValue(position, out var occupantIndex) || occupantIndex == index;
    }

    public bool MoveCell(string id, GridPosition position)
    {
        if (!_cellIndexesById.TryGetValue(id, out var index))
        {
            return false;
        }

        if (!CanMoveCell(id, position))
        {
            return false;
        }

        var cell = _cells[index];
        if (cell.Position == position)
        {
            return true;
        }

        _occupancy.Remove(cell.Position);
        cell.Position = position;
        _occupancy[position] = index;
        _adjacentEdgesDirty = true;
        TopologyVersion++;
        return true;
    }

    internal IReadOnlyList<CellEdge> GetAdjacentEdges()
    {
        if (!_adjacentEdgesDirty)
        {
            return _adjacentEdges;
        }

        _adjacentEdges.Clear();

        for (var i = 0; i < _cells.Count; i++)
        {
            var cell = _cells[i];
            for (var offsetIndex = 0; offsetIndex < NeighborOffsets.Length; offsetIndex++)
            {
                var offset = NeighborOffsets[offsetIndex];
                var neighborPosition = new GridPosition(cell.Position.X + offset.X, cell.Position.Y + offset.Y);
                if (_occupancy.TryGetValue(neighborPosition, out var neighborIndex) && cell.Index < neighborIndex)
                {
                    var firstIndex = cell.Index;
                    var secondIndex = neighborIndex;
                    if (CompareCellsForStableEdgeOrder(_cells[firstIndex], _cells[secondIndex]) > 0)
                    {
                        (firstIndex, secondIndex) = (secondIndex, firstIndex);
                    }

                    _adjacentEdges.Add(new CellEdge(firstIndex, secondIndex));
                }
            }
        }

        _adjacentEdges.Sort((left, right) =>
        {
            var compareA = CompareCellsForStableEdgeOrder(_cells[left.A], _cells[right.A]);
            return compareA != 0 ? compareA : CompareCellsForStableEdgeOrder(_cells[left.B], _cells[right.B]);
        });
        _adjacentEdgesDirty = false;
        return _adjacentEdges;
    }

    private static int CompareCellsForStableEdgeOrder(CellState left, CellState right)
    {
        var compareY = left.Position.Y.CompareTo(right.Position.Y);
        if (compareY != 0)
        {
            return compareY;
        }

        var compareX = left.Position.X.CompareTo(right.Position.X);
        if (compareX != 0)
        {
            return compareX;
        }

        return string.CompareOrdinal(left.Id, right.Id);
    }

    private void EnsureInBounds(GridPosition position)
    {
        if (!InBounds(position))
        {
            throw new ArgumentOutOfRangeException(nameof(position), "Position is outside the grid.");
        }
    }
}
