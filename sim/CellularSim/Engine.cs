namespace CellularSim;

public sealed class EngineOptions
{
    public int GlowTtlTicks { get; set; } = 5;
    public int EventCapacity { get; set; } = 4096;
    public int EdgeThroughputPerDirection { get; set; } = 1;
    public int WinDurationTicks { get; set; } = 30;
    public int WinRecentFlowWindowTicks { get; set; } = 30;
    public List<string> RequiredCellIds { get; } = new();
    public List<ResourceId> RequiredResources { get; } = new();
}

public sealed class ScoreState
{
    public int ReactionScore { get; internal set; }
    public int FlowDiversityScore { get; internal set; }
    public int SettlementScore { get; internal set; }
    public int ResilienceScore { get; internal set; }
    public int RepairScore { get; internal set; }
    public int AutonomyScore { get; internal set; }
    public int StrainPenalty { get; internal set; }
    public int HoardingPenalty { get; internal set; }
    public int DeadLoopPenalty { get; internal set; }

    public int TotalScore =>
        ReactionScore
        + FlowDiversityScore
        + SettlementScore
        + ResilienceScore
        + RepairScore
        + AutonomyScore
        - StrainPenalty
        - HoardingPenalty
        - DeadLoopPenalty;
}

public sealed class CircuitState
{
    public bool IsAliveThisTick { get; internal set; }
    public int SustainedTicks { get; internal set; }
    public bool IsWon { get; internal set; }
}

public sealed class CellularEngine
{
    private readonly EventBuffer _events;
    private readonly List<SwapProposal> _swapProposals = new(1024);
    private readonly List<int> _reactedCells = new(1024);
    private readonly HashSet<string> _reachSeen = new(StringComparer.Ordinal);
    private readonly Stack<string> _reachStack = new();
    private readonly Dictionary<string, List<string>> _winGraph = new(StringComparer.Ordinal);
    private readonly bool[] _flowResourceSeen;
    private int[,] _reservedOut = new int[0, 0];
    private int[,] _reservedIn = new int[0, 0];

    public CellularEngine(GridWorld world, EngineOptions? options = null)
    {
        World = world ?? throw new ArgumentNullException(nameof(world));
        Options = options ?? new EngineOptions();

        if (Options.GlowTtlTicks <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Glow TTL must be positive.");
        }

        if (Options.EdgeThroughputPerDirection <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Edge throughput must be positive.");
        }

        _events = new EventBuffer(Options.EventCapacity);
        _flowResourceSeen = new bool[ComputeResourceCapacity(World)];
        EnsureReservationCapacity();
    }

    public GridWorld World { get; }
    public EngineOptions Options { get; }
    public ScoreState Score { get; } = new();
    public CircuitState Circuit { get; } = new();
    public long CurrentTick { get; private set; }
    public IReadOnlyList<SimEvent> Events => _events.Snapshot();

    public void RunTicks(int count)
    {
        if (count < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(count), "Tick count cannot be negative.");
        }

        for (var i = 0; i < count; i++)
        {
            Tick();
        }
    }

    public void Tick()
    {
        CurrentTick++;

        RunSourceProduction();
        GenerateSwapProposals();
        ResolveSwapProposals();
        ResolveReactions();
        UpdateGlowAndStrain();
        UpdateScore();
        UpdateWinCheck();
    }

    private void RunSourceProduction()
    {
        foreach (var cell in World.Cells)
        {
            foreach (var source in cell.Sources)
            {
                if (CurrentTick % source.IntervalTicks != 0)
                {
                    continue;
                }

                var slot = cell.Pool.GetSlot(source.Resource);
                if (slot is null)
                {
                    cell.Strain.SourceBlockedTicks++;
                    _events.Add(new OverflowEvent(CurrentTick, cell.Id, source.Resource, source.QuantityPerTick));
                    _events.Add(new StrainEvent(CurrentTick, cell.Id, StrainReason.SourceBlocked));
                    continue;
                }

                var accepted = cell.Pool.AddResource(source.Resource, source.QuantityPerTick);
                if (accepted < source.QuantityPerTick)
                {
                    var blocked = source.QuantityPerTick - accepted;
                    cell.Strain.SourceBlockedTicks++;
                    cell.Strain.OverCapacityPressureTicks++;
                    _events.Add(new OverflowEvent(CurrentTick, cell.Id, source.Resource, blocked));
                    _events.Add(new StrainEvent(CurrentTick, cell.Id, StrainReason.OverCapacityPressure));
                }
            }
        }
    }

    private void GenerateSwapProposals()
    {
        _swapProposals.Clear();
        ClearReservations();

        foreach (var edge in World.GetAdjacentEdges())
        {
            if (TryBuildSwap(edge.A, edge.B, out var forwardProposal)
                || TryBuildSwap(edge.B, edge.A, out forwardProposal))
            {
                ReserveSwap(forwardProposal);
                _swapProposals.Add(forwardProposal);
            }
        }
    }

    private bool TryBuildSwap(
        int initiatorIndex,
        int counterpartyIndex,
        out SwapProposal proposal)
    {
        var initiator = World.Cells[initiatorIndex];
        var counterparty = World.Cells[counterpartyIndex];
        var initiatorSlots = initiator.Pool.Slots;
        var counterpartyPool = counterparty.Pool;

        for (var requestedIndex = 0; requestedIndex < initiatorSlots.Count; requestedIndex++)
        {
            var requestedSlot = initiatorSlots[requestedIndex];
            if (requestedSlot.Role != PoolSlotRole.Need)
            {
                continue;
            }

            var requestedResource = requestedSlot.Resource;
            if (!counterparty.Pool.CanSend(
                    requestedResource,
                    1,
                    GetReservedOut(counterpartyIndex, requestedResource)))
            {
                continue;
            }

            if (!initiator.Pool.CanReceive(
                    requestedResource,
                    1,
                    GetReservedIn(initiatorIndex, requestedResource)))
            {
                continue;
            }

            if (TrySelectOffer(initiator.Pool, counterpartyPool, initiatorIndex, counterpartyIndex, requestedResource, out var offeredResource))
            {
                proposal = new SwapProposal(initiatorIndex, counterpartyIndex, offeredResource, requestedResource, 1);
                return true;
            }
        }

        proposal = default;
        return false;
    }

    private bool TrySelectOffer(
        SwapPoolState initiatorPool,
        SwapPoolState counterpartyPool,
        int initiatorIndex,
        int counterpartyIndex,
        ResourceId requestedResource,
        out ResourceId offeredResource)
    {
        if (TrySelectOfferByRole(initiatorPool, counterpartyPool, initiatorIndex, counterpartyIndex, requestedResource, PoolSlotRole.SourceOutput, out offeredResource))
        {
            return true;
        }

        if (TrySelectOfferByRole(initiatorPool, counterpartyPool, initiatorIndex, counterpartyIndex, requestedResource, PoolSlotRole.Need, out offeredResource))
        {
            return true;
        }

        return TrySelectOfferByRole(initiatorPool, counterpartyPool, initiatorIndex, counterpartyIndex, requestedResource, PoolSlotRole.AcceptOnly, out offeredResource);
    }

    private bool TrySelectOfferByRole(
        SwapPoolState initiatorPool,
        SwapPoolState counterpartyPool,
        int initiatorIndex,
        int counterpartyIndex,
        ResourceId requestedResource,
        PoolSlotRole role,
        out ResourceId offeredResource)
    {
        var slots = initiatorPool.Slots;
        ResourceId best = default;
        var hasBest = false;
        for (var i = 0; i < slots.Count; i++)
        {
            var slot = slots[i];
            if (slot.Role != role || slot.Quantity <= 0 || slot.Resource == requestedResource)
            {
                continue;
            }

            var candidate = slot.Resource;
            if (!initiatorPool.CanSend(candidate, 1, GetReservedOut(initiatorIndex, candidate)))
            {
                continue;
            }

            var counterpartyReceiveSlot = counterpartyPool.GetSlot(candidate);
            if (counterpartyReceiveSlot is null || counterpartyReceiveSlot.Role == PoolSlotRole.SourceOutput)
            {
                continue;
            }

            if (!counterpartyPool.CanReceive(candidate, 1, GetReservedIn(counterpartyIndex, candidate)))
            {
                continue;
            }

            if (!hasBest || candidate.Value < best.Value)
            {
                best = candidate;
                hasBest = true;
            }
        }

        offeredResource = best;
        return hasBest;
    }

    private void ReserveSwap(SwapProposal proposal)
    {
        AddReservedOut(proposal.InitiatorIndex, proposal.InitiatorPaidResource, proposal.Quantity);
        AddReservedOut(proposal.CounterpartyIndex, proposal.CounterpartyPaidResource, proposal.Quantity);
        AddReservedIn(proposal.InitiatorIndex, proposal.CounterpartyPaidResource, proposal.Quantity);
        AddReservedIn(proposal.CounterpartyIndex, proposal.InitiatorPaidResource, proposal.Quantity);
    }

    private void ResolveSwapProposals()
    {
        for (var i = 0; i < _swapProposals.Count; i++)
        {
            var proposal = _swapProposals[i];
            var initiator = World.Cells[proposal.InitiatorIndex];
            var counterparty = World.Cells[proposal.CounterpartyIndex];

            var initiatorReceiveSlot = initiator.Pool.GetSlot(proposal.CounterpartyPaidResource)
                ?? throw new InvalidOperationException("Initiator receive slot disappeared before swap resolution.");
            var counterpartyReceiveSlot = counterparty.Pool.GetSlot(proposal.InitiatorPaidResource)
                ?? throw new InvalidOperationException("Counterparty receive slot disappeared before swap resolution.");

            initiator.Pool.RemoveResource(proposal.InitiatorPaidResource, proposal.Quantity);
            counterparty.Pool.RemoveResource(proposal.CounterpartyPaidResource, proposal.Quantity);
            initiator.Pool.AddResource(proposal.CounterpartyPaidResource, proposal.Quantity);
            counterparty.Pool.AddResource(proposal.InitiatorPaidResource, proposal.Quantity);

            _events.Add(new SwapEvent(
                CurrentTick,
                initiator.Id,
                counterparty.Id,
                proposal.InitiatorPaidResource,
                proposal.Quantity,
                proposal.CounterpartyPaidResource,
                proposal.Quantity,
                initiatorReceiveSlot.Quantity,
                initiatorReceiveSlot.Capacity,
                counterpartyReceiveSlot.Quantity,
                counterpartyReceiveSlot.Capacity));

            _events.Add(new FlowEvent(
                CurrentTick,
                initiator.Id,
                counterparty.Id,
                proposal.InitiatorPaidResource,
                proposal.Quantity,
                FlowKind.Reciprocal));
            _events.Add(new FlowEvent(
                CurrentTick,
                counterparty.Id,
                initiator.Id,
                proposal.CounterpartyPaidResource,
                proposal.Quantity,
                FlowKind.Reciprocal));
        }
    }

    private void ResolveReactions()
    {
        _reactedCells.Clear();

        foreach (var cell in World.Cells)
        {
            if (!cell.Pool.CanReact())
            {
                continue;
            }

            cell.Pool.React();
            cell.GlowTicksRemaining = Options.GlowTtlTicks;
            _reactedCells.Add(cell.Index);
            Score.ReactionScore += 10;
            _events.Add(new ReactionEvent(CurrentTick, cell.Id));
        }
    }

    private void UpdateGlowAndStrain()
    {
        foreach (var cell in World.Cells)
        {
            var reacted = DidReact(cell.Index);
            if (!reacted && cell.GlowTicksRemaining > 0)
            {
                cell.GlowTicksRemaining--;
            }

            if (reacted)
            {
                continue;
            }

            var slots = cell.Pool.Slots;
            for (var i = 0; i < slots.Count; i++)
            {
                var needSlot = slots[i];
                if (needSlot.Role != PoolSlotRole.Need)
                {
                    continue;
                }

                if (needSlot.Quantity > 0)
                {
                    continue;
                }

                cell.Strain.UnmetNeedTicks++;
                _events.Add(new StrainEvent(CurrentTick, cell.Id, StrainReason.UnmetNeed));
            }
        }
    }

    private void UpdateScore()
    {
        Array.Clear(_flowResourceSeen);
        var flowDiversity = 0;
        var settlement = 0;
        foreach (var simEvent in _events.Enumerate())
        {
            if (simEvent is FlowEvent flow)
            {
                var resourceIndex = flow.Resource.Value;
                if (resourceIndex >= 0 && resourceIndex < _flowResourceSeen.Length && !_flowResourceSeen[resourceIndex])
                {
                    _flowResourceSeen[resourceIndex] = true;
                    flowDiversity++;
                }
            }
            else if (simEvent is ReactionEvent)
            {
                settlement++;
            }
        }

        var strain = 0;
        foreach (var cell in World.Cells)
        {
            strain += cell.Strain.Total;
        }

        Score.FlowDiversityScore = flowDiversity * 2;
        Score.SettlementScore = settlement;
        Score.StrainPenalty = strain;
    }

    private void UpdateWinCheck()
    {
        var wasWon = Circuit.IsWon;
        var alive = ComputeLivingCircuit();

        Circuit.IsAliveThisTick = alive;
        Circuit.SustainedTicks = alive ? Circuit.SustainedTicks + 1 : 0;
        if (!Circuit.IsWon && alive && Circuit.SustainedTicks >= Options.WinDurationTicks)
        {
            Circuit.IsWon = true;
        }

        if (wasWon != Circuit.IsWon)
        {
            _events.Add(new WinStateChangedEvent(CurrentTick, Circuit.IsWon));
        }
    }

    private bool ComputeLivingCircuit()
    {
        if (Options.RequiredCellIds.Count == 0)
        {
            return false;
        }

        foreach (var cellId in Options.RequiredCellIds)
        {
            if (!World.TryGetCell(cellId, out var cell) || cell is null || !cell.IsGlowing)
            {
                return false;
            }
        }

        var sinceTick = CurrentTick - Options.WinRecentFlowWindowTicks;
        Array.Clear(_flowResourceSeen);
        _winGraph.Clear();

        foreach (var simEvent in _events.Enumerate())
        {
            if (simEvent is not FlowEvent flow || flow.Tick < sinceTick)
            {
                continue;
            }

            var resourceIndex = flow.Resource.Value;
            if (resourceIndex >= 0 && resourceIndex < _flowResourceSeen.Length)
            {
                _flowResourceSeen[resourceIndex] = true;
            }

            if (!_winGraph.TryGetValue(flow.SourceCellId, out var neighbors))
            {
                neighbors = new List<string>(4);
                _winGraph.Add(flow.SourceCellId, neighbors);
            }

            neighbors.Add(flow.TargetCellId);
        }

        for (var i = 0; i < Options.RequiredResources.Count; i++)
        {
            var resource = Options.RequiredResources[i];
            if (resource.Value < 0 || resource.Value >= _flowResourceSeen.Length || !_flowResourceSeen[resource.Value])
            {
                return false;
            }
        }

        if (Options.RequiredCellIds.Count <= 1)
        {
            return true;
        }

        foreach (var source in Options.RequiredCellIds)
        {
            foreach (var target in Options.RequiredCellIds)
            {
                if (source != target && !CanReach(_winGraph, source, target))
                {
                    return false;
                }
            }
        }

        return true;
    }

    private bool CanReach(Dictionary<string, List<string>> graph, string source, string target)
    {
        _reachSeen.Clear();
        _reachStack.Clear();
        _reachStack.Push(source);

        while (_reachStack.Count > 0)
        {
            var current = _reachStack.Pop();
            if (!_reachSeen.Add(current))
            {
                continue;
            }

            if (current == target)
            {
                return true;
            }

            if (!graph.TryGetValue(current, out var neighbors))
            {
                continue;
            }

            for (var i = 0; i < neighbors.Count; i++)
            {
                _reachStack.Push(neighbors[i]);
            }
        }

        return false;
    }

    private bool DidReact(int cellIndex)
    {
        for (var i = 0; i < _reactedCells.Count; i++)
        {
            if (_reactedCells[i] == cellIndex)
            {
                return true;
            }
        }

        return false;
    }

    private int GetReservedOut(int cellIndex, ResourceId resource) => _reservedOut[cellIndex, resource.Value];

    private int GetReservedIn(int cellIndex, ResourceId resource) => _reservedIn[cellIndex, resource.Value];

    private void AddReservedOut(int cellIndex, ResourceId resource, int quantity) => _reservedOut[cellIndex, resource.Value] += quantity;

    private void AddReservedIn(int cellIndex, ResourceId resource, int quantity) => _reservedIn[cellIndex, resource.Value] += quantity;

    private void ClearReservations()
    {
        Array.Clear(_reservedOut);
        Array.Clear(_reservedIn);
    }

    private void EnsureReservationCapacity()
    {
        var resourceCapacity = _flowResourceSeen.Length;
        _reservedOut = new int[World.Cells.Count, resourceCapacity];
        _reservedIn = new int[World.Cells.Count, resourceCapacity];
    }

    private static int ComputeResourceCapacity(GridWorld world)
    {
        var max = -1;
        foreach (var cell in world.Cells)
        {
            foreach (var slot in cell.Pool.Slots)
            {
                if (slot.Resource.Value > max)
                {
                    max = slot.Resource.Value;
                }
            }

            foreach (var source in cell.Sources)
            {
                if (source.Resource.Value > max)
                {
                    max = source.Resource.Value;
                }
            }
        }

        return Math.Max(1, max + 1);
    }

    private readonly record struct SwapProposal(
        int InitiatorIndex,
        int CounterpartyIndex,
        ResourceId InitiatorPaidResource,
        ResourceId CounterpartyPaidResource,
        int Quantity);
}
