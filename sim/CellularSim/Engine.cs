namespace CellularSim;

public sealed class EngineOptions
{
    public int GlowTtlTicks { get; set; } = 5;
    public int EventCapacity { get; set; } = 4096;
    public int EdgeThroughputPerDirection { get; set; } = 1;
    public int MaxSwapQuantityPerEdge { get; set; } = 4;
    public int SwapRoundsPerTick { get; set; } = 1;
    public int NeedDesiredQuantity { get; set; } = 100;
    public int NeedOfferReserve { get; set; } = 1;
    public bool AllowNeedOverflowPayments { get; set; }
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
    private readonly List<PrioritizedSwapProposal> _candidateSwapProposals = new(1024);
    private readonly List<int> _reactedCells = new(1024);
    private readonly HashSet<string> _reachSeen = new(StringComparer.Ordinal);
    private readonly Stack<string> _reachStack = new();
    private readonly Dictionary<string, List<string>> _winGraph = new(StringComparer.Ordinal);
    private readonly bool[] _flowResourceSeen;
    private bool[] _edgeUsedThisTick = [];
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

        if (Options.MaxSwapQuantityPerEdge <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Max swap quantity per edge must be positive.");
        }

        if (Options.SwapRoundsPerTick <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Swap rounds per tick must be positive.");
        }

        if (Options.NeedDesiredQuantity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Need desired quantity must be positive.");
        }

        if (Options.NeedOfferReserve <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(options), "Need offer reserve must be positive.");
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
        ResolveSwapRounds();
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

    private void ResolveSwapRounds()
    {
        var edges = World.GetAdjacentEdges();
        if (edges.Count == 0)
        {
            return;
        }

        EnsureEdgeUseCapacity(edges.Count);
        Array.Clear(_edgeUsedThisTick, 0, edges.Count);
        for (var round = 0; round < Options.SwapRoundsPerTick; round++)
        {
            GenerateSwapProposals(edges, _edgeUsedThisTick);
            if (_swapProposals.Count == 0)
            {
                break;
            }

            ResolveSwapProposals();
        }
    }

    private void GenerateSwapProposals(IReadOnlyList<CellEdge> edges, bool[] edgeUsedThisTick)
    {
        _swapProposals.Clear();
        _candidateSwapProposals.Clear();
        ClearReservations();

        var edgeOrder = 0;
        foreach (var edge in edges)
        {
            if (edgeUsedThisTick[edgeOrder])
            {
                edgeOrder++;
                continue;
            }

            AddSwapCandidatesForDirection(edge.A, edge.B, edgeOrder);
            AddSwapCandidatesForDirection(edge.B, edge.A, edgeOrder);

            edgeOrder++;
        }

        _candidateSwapProposals.Sort(ComparePrioritizedSwapProposals);
        for (var i = 0; i < _candidateSwapProposals.Count; i++)
        {
            var candidate = _candidateSwapProposals[i];
            if (edgeUsedThisTick[candidate.EdgeOrder])
            {
                continue;
            }

            var proposal = candidate.Proposal;
            if (CanReserveSwap(proposal))
            {
                ReserveSwap(proposal);
                _swapProposals.Add(proposal);
                edgeUsedThisTick[candidate.EdgeOrder] = true;
            }
        }
    }

    private void AddSwapCandidatesForDirection(
        int initiatorIndex,
        int counterpartyIndex,
        int edgeOrder)
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

            AddSwapCandidatesForRequestedResource(
                    initiator.Pool,
                    counterpartyPool,
                    initiatorIndex,
                    counterpartyIndex,
                    requestedSlot,
                    edgeOrder);
        }
    }

    private bool CanReserveSwap(SwapProposal proposal)
    {
        var initiator = World.Cells[proposal.InitiatorIndex];
        var counterparty = World.Cells[proposal.CounterpartyIndex];
        var initiatorPaidSlot = initiator.Pool.GetSlot(proposal.InitiatorPaidResource);
        if (initiatorPaidSlot is null)
        {
            return false;
        }

        if (GetOfferableSwapQuantity(
                initiator.Pool,
                proposal.InitiatorPaidResource,
                GetReservedOut(proposal.InitiatorIndex, proposal.InitiatorPaidResource),
                Options.NeedOfferReserve) < proposal.Quantity)
        {
            return false;
        }

        if (GetOfferableSwapQuantity(
            counterparty.Pool,
            proposal.CounterpartyPaidResource,
            GetReservedOut(proposal.CounterpartyIndex, proposal.CounterpartyPaidResource),
            Options.NeedOfferReserve) < proposal.Quantity)
        {
            return false;
        }

        if (GetRequestedResourceReceivableSwapQuantity(
                initiator.Pool,
                proposal.CounterpartyPaidResource,
                GetReservedIn(proposal.InitiatorIndex, proposal.CounterpartyPaidResource)) < proposal.Quantity)
        {
            return false;
        }

        return GetReceivableSwapQuantity(
            counterparty.Pool,
            proposal.InitiatorPaidResource,
            GetReservedIn(proposal.CounterpartyIndex, proposal.InitiatorPaidResource)) >= proposal.Quantity;
    }

    private void AddSwapCandidatesForRequestedResource(
        SwapPoolState initiatorPool,
        SwapPoolState counterpartyPool,
        int initiatorIndex,
        int counterpartyIndex,
        PoolSlot requestedSlot,
        int edgeOrder)
    {
        var requestedResource = requestedSlot.Resource;
        var counterpartyRequestedOfferable = GetOfferableSwapQuantity(
            counterpartyPool,
            requestedResource,
            GetReservedOut(counterpartyIndex, requestedResource),
            Options.NeedOfferReserve);
        if (counterpartyRequestedOfferable <= 0)
        {
            return;
        }

        var initiatorRequestedReceivable = GetRequestedResourceReceivableSwapQuantity(
            initiatorPool,
            requestedResource,
            GetReservedIn(initiatorIndex, requestedResource));
        if (initiatorRequestedReceivable <= 0)
        {
            return;
        }

        var slots = initiatorPool.Slots;
        for (var i = 0; i < slots.Count; i++)
        {
            var slot = slots[i];
            if (slot.Quantity <= 0 || slot.Resource == requestedResource)
            {
                continue;
            }

            var candidate = slot.Resource;
            var initiatorCandidateOfferable = GetOfferableSwapQuantity(
                initiatorPool,
                candidate,
                GetReservedOut(initiatorIndex, candidate),
                Options.NeedOfferReserve);
            if (initiatorCandidateOfferable <= 0)
            {
                continue;
            }

            var counterpartyReceiveSlot = counterpartyPool.GetSlot(candidate);
            if (counterpartyReceiveSlot is null)
            {
                continue;
            }

            var counterpartyReservedIn = GetReservedIn(counterpartyIndex, candidate);
            var counterpartyCandidateReceivable = GetReceivableSwapQuantity(
                counterpartyPool,
                candidate,
                counterpartyReservedIn);
            if (counterpartyCandidateReceivable <= 0)
            {
                continue;
            }

            var quantity = Math.Min(
                Options.MaxSwapQuantityPerEdge,
                Math.Min(
                    Math.Min(initiatorCandidateOfferable, counterpartyRequestedOfferable),
                    Math.Min(initiatorRequestedReceivable, counterpartyCandidateReceivable)));
            if (quantity <= 0)
            {
                continue;
            }

            var candidatePriority = CreateOfferPriority(
                slot,
                counterpartyReceiveSlot,
                counterpartyReservedIn);
            var proposal = new SwapProposal(initiatorIndex, counterpartyIndex, candidate, requestedResource, quantity);
            var priority = new SwapPriority(
                requestedSlot.Quantity + GetReservedIn(initiatorIndex, requestedResource),
                candidatePriority);
            _candidateSwapProposals.Add(new PrioritizedSwapProposal(proposal, priority, edgeOrder));
        }
    }

    private int GetRequestedResourceReceivableSwapQuantity(
        SwapPoolState pool,
        ResourceId resource,
        int reservedIncoming)
    {
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        if (slot.Role == PoolSlotRole.Need)
        {
            var target = Math.Min(slot.Capacity, Options.NeedDesiredQuantity);
            return Math.Max(0, target - slot.Quantity - reservedIncoming);
        }

        return GetReceivableSwapQuantity(pool, resource, reservedIncoming);
    }

    private int GetReceivableSwapQuantity(
        SwapPoolState pool,
        ResourceId resource,
        int reservedIncoming)
    {
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        if (slot.Role == PoolSlotRole.SourceOutput
            || slot.Role == PoolSlotRole.Need && Options.AllowNeedOverflowPayments)
        {
            return int.MaxValue;
        }

        return Math.Max(0, slot.Capacity - slot.Quantity - reservedIncoming);
    }

    private static int GetOfferableSwapQuantity(
        SwapPoolState pool,
        ResourceId resource,
        int reservedOutgoing,
        int needOfferReserve = 1)
    {
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        var available = slot.Quantity - reservedOutgoing;
        if (slot.Role == PoolSlotRole.Need)
        {
            available -= needOfferReserve;
        }
        else if (slot.Role == PoolSlotRole.SourceOutput && HasNeedSlot(pool))
        {
            available--;
        }

        return Math.Max(0, available);
    }

    private static bool HasNeedSlot(SwapPoolState pool)
    {
        var slots = pool.Slots;
        for (var i = 0; i < slots.Count; i++)
        {
            if (slots[i].Role == PoolSlotRole.Need)
            {
                return true;
            }
        }

        return false;
    }

    private static OfferPriority CreateOfferPriority(
        PoolSlot offeredSlot,
        PoolSlot counterpartyReceiveSlot,
        int counterpartyReservedIn)
    {
        var counterpartyNeedBalance = counterpartyReceiveSlot.Quantity + counterpartyReservedIn;
        var counterpartyMissingNeedRank = counterpartyReceiveSlot.Role == PoolSlotRole.Need
            && counterpartyNeedBalance == 0
                ? 0
                : 1;
        var sourceReturnRank = counterpartyReceiveSlot.Role == PoolSlotRole.SourceOutput ? 0 : 1;
        var offeredRoleRank = offeredSlot.Role switch
        {
            PoolSlotRole.SourceOutput => 0,
            PoolSlotRole.Need => 1,
            PoolSlotRole.AcceptOnly => 2,
            _ => 3
        };

        return new OfferPriority(
            counterpartyMissingNeedRank,
            sourceReturnRank,
            counterpartyNeedBalance,
            offeredRoleRank);
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

    private int ComparePrioritizedSwapProposals(PrioritizedSwapProposal left, PrioritizedSwapProposal right)
    {
        var compareRequestedBalance = left.Priority.RequestedBalance.CompareTo(right.Priority.RequestedBalance);
        if (compareRequestedBalance != 0)
        {
            return compareRequestedBalance;
        }

        var compareOffer = CompareOfferPriorities(left.Priority.OfferPriority, right.Priority.OfferPriority);
        if (compareOffer != 0)
        {
            return compareOffer;
        }

        var compareQuantity = right.Proposal.Quantity.CompareTo(left.Proposal.Quantity);
        if (compareQuantity != 0)
        {
            return compareQuantity;
        }

        var compareEdge = left.EdgeOrder.CompareTo(right.EdgeOrder);
        if (compareEdge != 0)
        {
            return compareEdge;
        }

        var compareInitiator = CompareCellsForStableProposalOrder(
            World.Cells[left.Proposal.InitiatorIndex],
            World.Cells[right.Proposal.InitiatorIndex]);
        if (compareInitiator != 0)
        {
            return compareInitiator;
        }

        var compareCounterparty = CompareCellsForStableProposalOrder(
            World.Cells[left.Proposal.CounterpartyIndex],
            World.Cells[right.Proposal.CounterpartyIndex]);
        if (compareCounterparty != 0)
        {
            return compareCounterparty;
        }

        var compareInitiatorPaid = left.Proposal.InitiatorPaidResource.Value
            .CompareTo(right.Proposal.InitiatorPaidResource.Value);
        if (compareInitiatorPaid != 0)
        {
            return compareInitiatorPaid;
        }

        return left.Proposal.CounterpartyPaidResource.Value.CompareTo(right.Proposal.CounterpartyPaidResource.Value);
    }

    private static int CompareOfferPriorities(OfferPriority left, OfferPriority right)
    {
        var compareSourceReturn = left.SourceReturnRank.CompareTo(right.SourceReturnRank);
        if (compareSourceReturn != 0)
        {
            return compareSourceReturn;
        }

        var compareMissingNeed = left.CounterpartyMissingNeedRank.CompareTo(right.CounterpartyMissingNeedRank);
        if (compareMissingNeed != 0)
        {
            return compareMissingNeed;
        }

        var compareCounterpartyNeed = left.CounterpartyNeedBalance.CompareTo(right.CounterpartyNeedBalance);
        if (compareCounterpartyNeed != 0)
        {
            return compareCounterpartyNeed;
        }

        return left.OfferedRoleRank.CompareTo(right.OfferedRoleRank);
    }

    private static int CompareCellsForStableProposalOrder(CellState left, CellState right)
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

    private void EnsureEdgeUseCapacity(int edgeCount)
    {
        if (_edgeUsedThisTick.Length < edgeCount)
        {
            _edgeUsedThisTick = new bool[edgeCount];
        }
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

    private readonly record struct OfferPriority(
        int CounterpartyMissingNeedRank,
        int SourceReturnRank,
        int CounterpartyNeedBalance,
        int OfferedRoleRank);

    private readonly record struct SwapPriority(int RequestedBalance, OfferPriority OfferPriority);

    private readonly record struct PrioritizedSwapProposal(
        SwapProposal Proposal,
        SwapPriority Priority,
        int EdgeOrder);
}
