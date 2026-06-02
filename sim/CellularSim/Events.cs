namespace CellularSim;

public enum FlowKind
{
    OneWay,
    Reciprocal
}

public enum FailedSwapReason
{
    SourceInsufficient,
    TargetFull
}

public enum StrainReason
{
    UnmetNeed,
    FailedSwap,
    SourceBlocked,
    OverCapacityPressure
}

public abstract record SimEvent(long Tick);

public sealed record FlowEvent(
    long Tick,
    string SourceCellId,
    string TargetCellId,
    ResourceId Resource,
    int Quantity,
    FlowKind Kind) : SimEvent(Tick);

public sealed record SwapEvent(
    long Tick,
    string InitiatorCellId,
    string CounterpartyCellId,
    ResourceId InitiatorPaidResource,
    int InitiatorPaidQuantity,
    ResourceId CounterpartyPaidResource,
    int CounterpartyPaidQuantity,
    int InitiatorReceivedQuantity,
    int CounterpartyReceivedQuantity,
    int InitiatorReceivedBalanceAfterSwap,
    int InitiatorReceivedCapacity,
    int CounterpartyReceivedBalanceAfterSwap,
    int CounterpartyReceivedCapacity) : SimEvent(Tick);

public sealed record FailedSwapEvent(
    long Tick,
    string SourceCellId,
    string TargetCellId,
    ResourceId Resource,
    int Quantity,
    FailedSwapReason Reason) : SimEvent(Tick);

public sealed record ReactionEvent(long Tick, string CellId) : SimEvent(Tick);

public sealed record StrainEvent(long Tick, string CellId, StrainReason Reason) : SimEvent(Tick);

public sealed record OverflowEvent(long Tick, string CellId, ResourceId Resource, int Quantity) : SimEvent(Tick);

public sealed record WinStateChangedEvent(long Tick, bool IsWon) : SimEvent(Tick);

internal sealed class EventBuffer
{
    private readonly int _capacity;
    private readonly Queue<SimEvent> _events = new();

    public EventBuffer(int capacity)
    {
        if (capacity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(capacity), "Event capacity must be positive.");
        }

        _capacity = capacity;
    }

    public void Add(SimEvent simEvent)
    {
        _events.Enqueue(simEvent);
        while (_events.Count > _capacity)
        {
            _events.Dequeue();
        }
    }

    public IReadOnlyList<SimEvent> Snapshot() => _events.ToArray();

    public IEnumerable<SimEvent> Enumerate() => _events;

    public IEnumerable<TEvent> OfType<TEvent>()
        where TEvent : SimEvent => _events.OfType<TEvent>();
}
