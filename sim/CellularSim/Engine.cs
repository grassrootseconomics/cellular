namespace CellularSim;

public sealed class EngineOptions
{
    public int GlowTtlTicks { get; set; } = 5;
    public int EventCapacity { get; set; } = 4096;
    public int EdgeThroughputPerDirection { get; set; } = 1;
    public int MaxSwapQuantityPerEdge { get; set; } = 8;
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
    private const int StandardMinimumGrossSwapQuantity = 1;
    private const int RedMycoOutwardFeeQuantity = 1;
    private const int RedMycoMinimumGrossSwapQuantity = RedMycoOutwardFeeQuantity + 1;
    private const int AdaptiveMycoStartingQuantity = 250;
    private const int AdaptiveMycoSlotCapacity = 500;

    private readonly EventBuffer _events;
    private readonly List<SwapProposal> _swapProposals = new(1024);
    private readonly List<PrioritizedSwapProposal> _candidateSwapProposals = new(1024);
    private readonly List<int> _reactedCells = new(1024);
    private readonly List<int> _glowRefreshedCells = new(128);
    private readonly HashSet<string> _reachSeen = new(StringComparer.Ordinal);
    private readonly Stack<string> _reachStack = new();
    private readonly Dictionary<string, List<string>> _winGraph = new(StringComparer.Ordinal);
    private readonly bool[] _flowResourceSeen;
    private bool[] _edgeUsedThisTick = [];
    private int[,] _reservedOut = new int[0, 0];
    private int[,] _reservedIn = new int[0, 0];
    private long _adaptiveMycoTopologyVersion = long.MinValue;
    private readonly Dictionary<string, string> _adaptiveMycoNeighborSignatures = new(StringComparer.Ordinal);

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
        RefreshAdaptiveMyco(force: true);
    }

    public GridWorld World { get; }
    public EngineOptions Options { get; }
    public ScoreState Score { get; } = new();
    public CircuitState Circuit { get; } = new();
    public long CurrentTick { get; private set; }
    public IReadOnlyList<SimEvent> Events => _events.Snapshot();

    public void ResetStateWithCurrentLayout()
    {
        CurrentTick = 0;
        _events.Clear();
        _swapProposals.Clear();
        _candidateSwapProposals.Clear();
        _reactedCells.Clear();
        _glowRefreshedCells.Clear();
        _reachSeen.Clear();
        _reachStack.Clear();
        _winGraph.Clear();
        Array.Clear(_flowResourceSeen);
        EnsureReservationCapacity();
        ClearReservations();

        Score.ReactionScore = 0;
        Score.FlowDiversityScore = 0;
        Score.SettlementScore = 0;
        Score.ResilienceScore = 0;
        Score.RepairScore = 0;
        Score.AutonomyScore = 0;
        Score.StrainPenalty = 0;
        Score.HoardingPenalty = 0;
        Score.DeadLoopPenalty = 0;

        Circuit.IsAliveThisTick = false;
        Circuit.SustainedTicks = 0;
        Circuit.IsWon = false;

        foreach (var cell in World.Cells)
        {
            cell.GlowTicksRemaining = 0;
            ResetStrain(cell.Strain);
            if (cell.IsMyco)
            {
                ResetAdaptiveMycoSlotQuantities(cell);
            }
            else
            {
                ResetPoolQuantities(cell.Pool);
            }
        }

        RefreshAdaptiveMyco();
    }

    public void RefreshAdaptiveMyco(bool force = false)
    {
        if (!force && _adaptiveMycoTopologyVersion == World.TopologyVersion)
        {
            return;
        }

        var mycoCells = new List<CellState>();
        foreach (var cell in World.Cells)
        {
            if (cell.IsMyco)
            {
                mycoCells.Add(cell);
            }
        }

        if (mycoCells.Count == 0)
        {
            _adaptiveMycoTopologyVersion = World.TopologyVersion;
            return;
        }

        var fullRefresh = force
            || _adaptiveMycoTopologyVersion == long.MinValue
            || _adaptiveMycoNeighborSignatures.Count == 0;
        var useInitialFixtureHints = fullRefresh && _adaptiveMycoTopologyVersion == long.MinValue && CurrentTick == 0;
        Dictionary<int, List<ResourceId>>? initialFixtureHints = null;
        var queue = new Queue<CellState>();
        var queuedCounts = new Dictionary<int, int>();

        if (fullRefresh)
        {
            _adaptiveMycoNeighborSignatures.Clear();
            foreach (var cell in mycoCells)
            {
                if (useInitialFixtureHints && cell.Pool.Slots.Count > 0)
                {
                    initialFixtureHints ??= new Dictionary<int, List<ResourceId>>();
                    var hintedResources = new List<ResourceId>(SwapPoolState.MaxSlots);
                    AddSlotResources(hintedResources, cell.Pool.Slots);
                    if (hintedResources.Count > 0)
                    {
                        initialFixtureHints[cell.Index] = hintedResources;
                    }
                }

                cell.Pool.ClearSlots();
                queue.Enqueue(cell);
                queuedCounts[cell.Index] = 1;
            }
        }
        else
        {
            foreach (var cell in mycoCells)
            {
                var signature = BuildMycoNeighborSignature(cell);
                if (!_adaptiveMycoNeighborSignatures.TryGetValue(cell.Id, out var previousSignature)
                    || !string.Equals(previousSignature, signature, StringComparison.Ordinal))
                {
                    cell.Pool.ClearSlots();
                    queue.Enqueue(cell);
                    queuedCounts[cell.Index] = 1;
                }
            }
        }

        while (queue.Count > 0)
        {
            var cell = queue.Dequeue();

            List<ResourceId>? hintedResources = null;
            initialFixtureHints?.TryGetValue(cell.Index, out hintedResources);
            var resources = SelectAdaptiveMycoResources(cell, hintedResources);
            var changed = ReplaceAdaptiveMycoSlots(cell, resources);
            _adaptiveMycoNeighborSignatures[cell.Id] = BuildMycoNeighborSignature(cell);

            if (changed)
            {
                EnqueueWaitingMycoNeighbors(cell, queue, queuedCounts);
            }
        }

        _adaptiveMycoTopologyVersion = World.TopologyVersion;
    }

    private void EnqueueWaitingMycoNeighbors(
        CellState myco,
        Queue<CellState> queue,
        Dictionary<int, int> queuedCounts)
    {
        var edges = World.GetAdjacentEdges();
        foreach (var edge in edges)
        {
            CellState? neighbor = null;
            if (edge.A == myco.Index)
            {
                neighbor = World.Cells[edge.B];
            }
            else if (edge.B == myco.Index)
            {
                neighbor = World.Cells[edge.A];
            }

            if (neighbor is null || !neighbor.IsMyco || neighbor.Pool.Slots.Count > 0)
            {
                continue;
            }

            queuedCounts.TryGetValue(neighbor.Index, out var queuedCount);
            if (queuedCount >= World.Cells.Count)
            {
                continue;
            }

            queue.Enqueue(neighbor);
            queuedCounts[neighbor.Index] = queuedCount + 1;
        }
    }

    private string BuildMycoNeighborSignature(CellState myco)
    {
        var names = new List<string>(4);
        var edges = World.GetAdjacentEdges();
        foreach (var edge in edges)
        {
            if (edge.A == myco.Index)
            {
                names.Add(World.Cells[edge.B].Id);
            }
            else if (edge.B == myco.Index)
            {
                names.Add(World.Cells[edge.A].Id);
            }
        }

        names.Sort(StringComparer.Ordinal);
        return string.Join("|", names);
    }

    private static void ResetStrain(StrainState strain)
    {
        strain.UnmetNeedTicks = 0;
        strain.FailedSwapCount = 0;
        strain.SourceBlockedTicks = 0;
        strain.OverCapacityPressureTicks = 0;
    }

    private static void ResetPoolQuantities(SwapPoolState pool)
    {
        foreach (var slot in pool.Slots)
        {
            if (slot.Quantity > 0)
            {
                slot.Remove(slot.Quantity);
            }
        }
    }

    private static void ResetAdaptiveMycoSlotQuantities(CellState myco)
    {
        if (myco.Pool.Slots.Count == 0)
        {
            return;
        }

        var resources = new List<ResourceId>(myco.Pool.Slots.Count);
        AddSlotResources(resources, myco.Pool.Slots);
        myco.Pool.ClearSlots();
        for (var i = 0; i < resources.Count && i < SwapPoolState.MaxSlots; i++)
        {
            myco.Pool.AddSlot(
                resources[i],
                PoolSlotRole.Need,
                AdaptiveMycoStartingQuantity,
                AdaptiveMycoSlotCapacity);
        }
    }

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
        RefreshAdaptiveMyco();
        CurrentTick++;
        _glowRefreshedCells.Clear();

        RunSourceProduction();
        ResolveSwapRounds();
        ResolveReactions();
        UpdateGlowAndStrain();
        UpdateScore();
        UpdateWinCheck();
    }

    private List<ResourceId> SelectAdaptiveMycoResources(
        CellState myco,
        IReadOnlyList<ResourceId>? hintedResources)
    {
        var usefulNeighbors = new List<CellState>(4);
        var edges = World.GetAdjacentEdges();
        foreach (var edge in edges)
        {
            CellState? neighbor = null;
            if (edge.A == myco.Index)
            {
                neighbor = World.Cells[edge.B];
            }
            else if (edge.B == myco.Index)
            {
                neighbor = World.Cells[edge.A];
            }

            if (neighbor is null)
            {
                continue;
            }

            if (!neighbor.IsMyco || neighbor.Pool.Slots.Count > 0)
            {
                usefulNeighbors.Add(neighbor);
            }
        }

        var resources = new List<ResourceId>(SwapPoolState.MaxSlots);
        if (usefulNeighbors.Count == 0)
        {
            return resources;
        }

        if (usefulNeighbors.Count == 1)
        {
            var neighbor = usefulNeighbors[0];
            if (neighbor.IsMyco)
            {
                AddSlotResources(resources, neighbor.Pool.Slots);
            }
            else
            {
                AddNormalOffers(resources, neighbor);
                AddRoleResources(resources, neighbor.Pool.Slots, PoolSlotRole.Need);
            }

            return resources;
        }

        return SelectAdaptiveMycoResourcesFromMultipleNeighbors(myco, usefulNeighbors, hintedResources);
    }

    private List<ResourceId> SelectAdaptiveMycoResourcesFromMultipleNeighbors(
        CellState myco,
        List<CellState> usefulNeighbors,
        IReadOnlyList<ResourceId>? hintedResources)
    {
        var scores = new Dictionary<ResourceId, int>();
        var localOffers = new List<ResourceId>(SwapPoolState.MaxSlots);
        AddConnectedComponentCandidateScores(myco, scores);

        for (var neighborIndex = 0; neighborIndex < usefulNeighbors.Count; neighborIndex++)
        {
            var neighbor = usefulNeighbors[neighborIndex];
            var slots = neighbor.Pool.Slots;
            for (var slotIndex = 0; slotIndex < slots.Count; slotIndex++)
            {
                var slot = slots[slotIndex];
                if (neighbor.IsMyco)
                {
                    AddCandidateScore(scores, slot.Resource, 170);
                    continue;
                }

                if (slot.Role == PoolSlotRole.SourceOutput)
                {
                    AddCandidateScore(scores, slot.Resource, 170);
                    AddUniqueResource(localOffers, slot.Resource);
                }
                else if (slot.Role == PoolSlotRole.Need)
                {
                    AddCandidateScore(scores, slot.Resource, 210);
                }
            }

            for (var sourceIndex = 0; sourceIndex < neighbor.Sources.Count; sourceIndex++)
            {
                AddCandidateScore(scores, neighbor.Sources[sourceIndex].Resource, 170);
                AddUniqueResource(localOffers, neighbor.Sources[sourceIndex].Resource);
            }
        }

        var candidates = new List<MycoResourceCandidate>(scores.Count);
        foreach (var pair in scores)
        {
            candidates.Add(new MycoResourceCandidate(
                pair.Key,
                pair.Value,
                StableAdaptiveMycoHash(myco.Id, "candidate", pair.Key, pair.Value, 0, World.TopologyVersion)));
        }

        AddHintedResourcesToCandidates(myco, candidates, scores, hintedResources);
        candidates.Sort(CompareMycoResourceCandidates);

        return SelectBestAdaptiveMycoResourceSet(myco, usefulNeighbors, candidates, localOffers, scores, hintedResources);
    }

    private List<ResourceId> SelectBestAdaptiveMycoResourceSet(
        CellState myco,
        List<CellState> usefulNeighbors,
        List<MycoResourceCandidate> candidates,
        List<ResourceId> localOffers,
        Dictionary<ResourceId, int> scores,
        IReadOnlyList<ResourceId>? hintedResources)
    {
        var bestResources = new List<ResourceId>(SwapPoolState.MaxSlots);
        var bestScore = int.MinValue;
        var bestHash = int.MaxValue;

        if (hintedResources is { Count: > 0 })
        {
            var normalizedHint = new List<ResourceId>(SwapPoolState.MaxSlots);
            for (var i = 0; i < hintedResources.Count && normalizedHint.Count < SwapPoolState.MaxSlots; i++)
            {
                AddUniqueResource(normalizedHint, hintedResources[i]);
            }

            ConsiderResourceSet(normalizedHint, isInitialFixtureHint: true);
        }

        var candidateLimit = Math.Min(12, candidates.Count);
        if (candidateLimit <= SwapPoolState.MaxSlots)
        {
            var resources = new List<ResourceId>(SwapPoolState.MaxSlots);
            for (var i = 0; i < candidateLimit; i++)
            {
                AddUniqueResource(resources, candidates[i].Resource);
            }

            ConsiderResourceSet(resources, isInitialFixtureHint: false);
        }
        else
        {
            for (var a = 0; a < candidateLimit - 3; a++)
            {
                for (var b = a + 1; b < candidateLimit - 2; b++)
                {
                    for (var c = b + 1; c < candidateLimit - 1; c++)
                    {
                        for (var d = c + 1; d < candidateLimit; d++)
                        {
                            var resources = new List<ResourceId>(SwapPoolState.MaxSlots)
                            {
                                candidates[a].Resource,
                                candidates[b].Resource,
                                candidates[c].Resource,
                                candidates[d].Resource
                            };
                            ConsiderResourceSet(resources, isInitialFixtureHint: false);
                        }
                    }
                }
            }
        }

        EnsureLocalPaymentResource(myco, bestResources, localOffers, scores, World.TopologyVersion);
        return bestResources;

        void ConsiderResourceSet(List<ResourceId> resources, bool isInitialFixtureHint)
        {
            if (resources.Count == 0)
            {
                return;
            }

            EnsureLocalPaymentResource(myco, resources, localOffers, scores, World.TopologyVersion);
            var score = ScoreAdaptiveMycoResourceSet(resources, usefulNeighbors, scores);
            if (isInitialFixtureHint)
            {
                // Old shipped fixtures often contain authored myco pips that make a verified
                // circuit work. They are not authoritative after movement, but on initial load
                // they are a useful candidate for the static solver.
                score += 100_000;
            }

            var hash = HashAdaptiveMycoResourceSet(myco.Id, resources, score, World.TopologyVersion);
            if (score > bestScore || score == bestScore && hash < bestHash)
            {
                bestScore = score;
                bestHash = hash;
                bestResources = new List<ResourceId>(resources);
            }
        }
    }

    private static void AddHintedResourcesToCandidates(
        CellState myco,
        List<MycoResourceCandidate> candidates,
        Dictionary<ResourceId, int> scores,
        IReadOnlyList<ResourceId>? hintedResources)
    {
        if (hintedResources is null)
        {
            return;
        }

        for (var i = 0; i < hintedResources.Count; i++)
        {
            var resource = hintedResources[i];
            if (!resource.IsValid)
            {
                continue;
            }

            var exists = false;
            for (var candidateIndex = 0; candidateIndex < candidates.Count; candidateIndex++)
            {
                if (candidates[candidateIndex].Resource == resource)
                {
                    exists = true;
                    break;
                }
            }

            if (exists)
            {
                continue;
            }

            var score = scores.TryGetValue(resource, out var existingScore) ? existingScore : 0;
            candidates.Add(new MycoResourceCandidate(
                resource,
                score,
                StableAdaptiveMycoHash(myco.Id, "hint", resource, score, i, 0)));
        }
    }

    private static int ScoreAdaptiveMycoResourceSet(
        IReadOnlyList<ResourceId> resources,
        List<CellState> usefulNeighbors,
        Dictionary<ResourceId, int> baseScores)
    {
        var score = 0;
        for (var i = 0; i < resources.Count; i++)
        {
            if (baseScores.TryGetValue(resources[i], out var baseScore))
            {
                score += baseScore;
            }
        }

        var reciprocalNeighbors = 0;
        for (var neighborIndex = 0; neighborIndex < usefulNeighbors.Count; neighborIndex++)
        {
            var neighbor = usefulNeighbors[neighborIndex];
            var receivesFromNeighbor = false;
            var paysNeighbor = false;
            var localOfferMatches = 0;
            var localNeedMatches = 0;
            for (var resourceIndex = 0; resourceIndex < resources.Count; resourceIndex++)
            {
                var resource = resources[resourceIndex];
                if (CellCanOfferResourceStatically(neighbor, resource))
                {
                    receivesFromNeighbor = true;
                    localOfferMatches++;
                }

                if (CellCanReceiveResourceStatically(neighbor, resource))
                {
                    paysNeighbor = true;
                }

                if (CellHasNeedResource(neighbor, resource))
                {
                    localNeedMatches++;
                }
            }

            score += localOfferMatches * 260;
            score += localNeedMatches * 320;
            if (receivesFromNeighbor && paysNeighbor)
            {
                score += 1400;
                reciprocalNeighbors++;
            }
            else if (receivesFromNeighbor || paysNeighbor)
            {
                score += 250;
            }
        }

        return score + reciprocalNeighbors * reciprocalNeighbors * 180;
    }

    private static bool CellCanOfferResourceStatically(CellState cell, ResourceId resource)
    {
        var slots = cell.Pool.Slots;
        for (var i = 0; i < slots.Count; i++)
        {
            var slot = slots[i];
            if (slot.Resource != resource)
            {
                continue;
            }

            if (cell.IsMyco || slot.Role == PoolSlotRole.SourceOutput || slot.Quantity > 1)
            {
                return true;
            }
        }

        for (var i = 0; i < cell.Sources.Count; i++)
        {
            if (cell.Sources[i].Resource == resource)
            {
                return true;
            }
        }

        return false;
    }

    private static bool CellCanReceiveResourceStatically(CellState cell, ResourceId resource) =>
        cell.Pool.GetSlot(resource) is not null;

    private static bool CellHasNeedResource(CellState cell, ResourceId resource)
    {
        var slots = cell.Pool.Slots;
        for (var i = 0; i < slots.Count; i++)
        {
            var slot = slots[i];
            if (slot.Resource == resource && slot.Role == PoolSlotRole.Need)
            {
                return true;
            }
        }

        return false;
    }

    private void AddConnectedComponentCandidateScores(CellState myco, Dictionary<ResourceId, int> scores)
    {
        const int maxDepth = 8;
        var edges = World.GetAdjacentEdges();
        var queue = new Queue<(int CellIndex, int Depth)>();
        var visited = new HashSet<int>();
        queue.Enqueue((myco.Index, 0));
        visited.Add(myco.Index);

        while (queue.Count > 0)
        {
            var (cellIndex, depth) = queue.Dequeue();
            if (depth > 0)
            {
                AddConnectedCellScores(World.Cells[cellIndex], depth, scores);
            }

            if (depth >= maxDepth)
            {
                continue;
            }

            foreach (var edge in edges)
            {
                var next = -1;
                if (edge.A == cellIndex)
                {
                    next = edge.B;
                }
                else if (edge.B == cellIndex)
                {
                    next = edge.A;
                }

                if (next >= 0 && visited.Add(next))
                {
                    queue.Enqueue((next, depth + 1));
                }
            }
        }
    }

    private static void AddConnectedCellScores(CellState cell, int depth, Dictionary<ResourceId, int> scores)
    {
        var distancePenalty = Math.Min(48, depth * 6);
        var slots = cell.Pool.Slots;
        for (var slotIndex = 0; slotIndex < slots.Count; slotIndex++)
        {
            var slot = slots[slotIndex];
            if (cell.IsMyco)
            {
                AddCandidateScore(scores, slot.Resource, Math.Max(12, 72 - distancePenalty));
            }
            else if (slot.Role == PoolSlotRole.SourceOutput)
            {
                AddCandidateScore(scores, slot.Resource, Math.Max(12, 88 - distancePenalty));
            }
            else if (slot.Role == PoolSlotRole.Need)
            {
                AddCandidateScore(scores, slot.Resource, Math.Max(8, 58 - distancePenalty));
            }
        }

        for (var sourceIndex = 0; sourceIndex < cell.Sources.Count; sourceIndex++)
        {
            AddCandidateScore(scores, cell.Sources[sourceIndex].Resource, Math.Max(12, 88 - distancePenalty));
        }
    }

    private static void AddCandidateScore(Dictionary<ResourceId, int> scores, ResourceId resource, int score)
    {
        if (!resource.IsValid || score <= 0)
        {
            return;
        }

        scores[resource] = scores.TryGetValue(resource, out var existing) ? existing + score : score;
    }

    private static void EnsureLocalPaymentResource(
        CellState myco,
        List<ResourceId> resources,
        List<ResourceId> localOffers,
        Dictionary<ResourceId, int> scores,
        long topologyVersion)
    {
        if (resources.Count == 0 || localOffers.Count == 0)
        {
            return;
        }

        for (var i = 0; i < resources.Count; i++)
        {
            for (var offerIndex = 0; offerIndex < localOffers.Count; offerIndex++)
            {
                if (resources[i] == localOffers[offerIndex])
                {
                    return;
                }
            }
        }

        var bestOffer = localOffers[0];
        var bestScore = scores.TryGetValue(bestOffer, out var firstScore) ? firstScore : 0;
        for (var i = 1; i < localOffers.Count; i++)
        {
            var offer = localOffers[i];
            var score = scores.TryGetValue(offer, out var candidateScore) ? candidateScore : 0;
            if (score > bestScore
                || score == bestScore
                && StableAdaptiveMycoHash(myco.Id, "local-offer", offer, score, i, topologyVersion) < StableAdaptiveMycoHash(myco.Id, "local-offer", bestOffer, bestScore, 0, topologyVersion))
            {
                bestOffer = offer;
                bestScore = score;
            }
        }

        resources[^1] = bestOffer;
    }

    private static bool ReplaceAdaptiveMycoSlots(CellState myco, List<ResourceId> resources)
    {
        var slots = myco.Pool.Slots;
        if (slots.Count == resources.Count)
        {
            var same = true;
            for (var i = 0; i < resources.Count; i++)
            {
                if (slots[i].Resource != resources[i]
                    || slots[i].Role != PoolSlotRole.Need
                    || slots[i].Quantity != AdaptiveMycoStartingQuantity
                    || slots[i].Capacity != AdaptiveMycoSlotCapacity)
                {
                    same = false;
                    break;
                }
            }

            if (same)
            {
                return false;
            }
        }

        myco.Pool.ClearSlots();
        for (var i = 0; i < resources.Count && i < SwapPoolState.MaxSlots; i++)
        {
            myco.Pool.AddSlot(
                resources[i],
                PoolSlotRole.Need,
                AdaptiveMycoStartingQuantity,
                AdaptiveMycoSlotCapacity);
        }

        return true;
    }

    private static void AddNormalOffers(List<ResourceId> resources, CellState cell)
    {
        AddRoleResources(resources, cell.Pool.Slots, PoolSlotRole.SourceOutput);
        for (var i = 0; i < cell.Sources.Count && resources.Count < SwapPoolState.MaxSlots; i++)
        {
            AddUniqueResource(resources, cell.Sources[i].Resource);
        }
    }

    private static void AddRoleResources(
        List<ResourceId> resources,
        IReadOnlyList<PoolSlot> slots,
        PoolSlotRole role)
    {
        for (var i = 0; i < slots.Count && resources.Count < SwapPoolState.MaxSlots; i++)
        {
            var slot = slots[i];
            if (slot.Role == role)
            {
                AddUniqueResource(resources, slot.Resource);
            }
        }
    }

    private static void AddSlotResources(List<ResourceId> resources, IReadOnlyList<PoolSlot> slots)
    {
        for (var i = 0; i < slots.Count && resources.Count < SwapPoolState.MaxSlots; i++)
        {
            AddUniqueResource(resources, slots[i].Resource);
        }
    }

    private static void AddUniqueResource(List<ResourceId> resources, ResourceId resource)
    {
        if (resources.Count >= SwapPoolState.MaxSlots)
        {
            return;
        }

        for (var i = 0; i < resources.Count; i++)
        {
            if (resources[i] == resource)
            {
                return;
            }
        }

        resources.Add(resource);
    }

    private static int CompareMycoResourceCandidates(MycoResourceCandidate left, MycoResourceCandidate right)
    {
        var leftBucket = left.Score / 25;
        var rightBucket = right.Score / 25;
        var compareScore = rightBucket.CompareTo(leftBucket);
        if (compareScore != 0)
        {
            return compareScore;
        }

        var compareHash = left.Hash.CompareTo(right.Hash);
        return compareHash != 0 ? compareHash : left.Resource.Value.CompareTo(right.Resource.Value);
    }

    private static int HashAdaptiveMycoResourceSet(
        string mycoId,
        IReadOnlyList<ResourceId> resources,
        int score,
        long topologyVersion)
    {
        unchecked
        {
            var hash = 2166136261u;
            AddStringToHash(ref hash, mycoId);
            hash = (hash ^ (uint)score) * 16777619u;
            hash = (hash ^ (uint)topologyVersion) * 16777619u;
            hash = (hash ^ (uint)(topologyVersion >> 32)) * 16777619u;
            for (var i = 0; i < resources.Count; i++)
            {
                hash = (hash ^ (uint)resources[i].Value) * 16777619u;
                hash = (hash ^ (uint)i) * 16777619u;
            }

            return (int)(hash & 0x7fffffff);
        }
    }

    private static int StableAdaptiveMycoHash(
        string mycoId,
        string neighborId,
        ResourceId resource,
        int neighborOrder,
        int slotOrder,
        long topologyVersion)
    {
        unchecked
        {
            var hash = 2166136261u;
            AddStringToHash(ref hash, mycoId);
            AddStringToHash(ref hash, neighborId);
            hash = (hash ^ (uint)resource.Value) * 16777619u;
            hash = (hash ^ (uint)neighborOrder) * 16777619u;
            hash = (hash ^ (uint)slotOrder) * 16777619u;
            hash = (hash ^ (uint)topologyVersion) * 16777619u;
            hash = (hash ^ (uint)(topologyVersion >> 32)) * 16777619u;
            return (int)(hash & 0x7fffffff);
        }
    }

    private static void AddStringToHash(ref uint hash, string value)
    {
        for (var i = 0; i < value.Length; i++)
        {
            hash = (hash ^ (uint)value[i]) * 16777619u;
        }
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

        for (var requestedIndex = 0; requestedIndex < initiatorSlots.Count; requestedIndex++)
        {
            var requestedSlot = initiatorSlots[requestedIndex];
            if (requestedSlot.Role != PoolSlotRole.Need)
            {
                continue;
            }

            AddSwapCandidatesForRequestedResource(
                    initiator,
                    counterparty,
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

        if (GetOfferableSwapQuantity(
                initiator,
                proposal.InitiatorPaidResource,
                GetReservedOut(proposal.InitiatorIndex, proposal.InitiatorPaidResource)) < proposal.InitiatorPaidQuantity)
        {
            return false;
        }

        if (GetOfferableSwapQuantity(
            counterparty,
            proposal.CounterpartyPaidResource,
            GetReservedOut(proposal.CounterpartyIndex, proposal.CounterpartyPaidResource)) < proposal.CounterpartyPaidQuantity)
        {
            return false;
        }

        if (GetRequestedResourceReceivableSwapQuantity(
                initiator,
                proposal.CounterpartyPaidResource,
                GetReservedIn(proposal.InitiatorIndex, proposal.CounterpartyPaidResource)) < proposal.InitiatorReceivedQuantity)
        {
            return false;
        }

        return GetReceivableSwapQuantity(
            counterparty,
            proposal.InitiatorPaidResource,
            GetReservedIn(proposal.CounterpartyIndex, proposal.InitiatorPaidResource)) >= proposal.CounterpartyReceivedQuantity;
    }

    private void AddSwapCandidatesForRequestedResource(
        CellState initiator,
        CellState counterparty,
        int initiatorIndex,
        int counterpartyIndex,
        PoolSlot requestedSlot,
        int edgeOrder)
    {
        var initiatorPool = initiator.Pool;
        var counterpartyPool = counterparty.Pool;
        var requestedResource = requestedSlot.Resource;
        var counterpartyRequestedOfferable = GetOfferableSwapQuantity(
            counterparty,
            requestedResource,
            GetReservedOut(counterpartyIndex, requestedResource));
        if (counterpartyRequestedOfferable <= 0)
        {
            return;
        }

        var initiatorRequestedReceivable = GetRequestedResourceReceivableSwapQuantity(
            initiator,
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
                initiator,
                candidate,
                GetReservedOut(initiatorIndex, candidate));
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
                counterparty,
                candidate,
                counterpartyReservedIn);
            if (counterpartyCandidateReceivable <= 0)
            {
                continue;
            }

            var proposal = CreateSwapProposal(
                initiator,
                counterparty,
                initiatorIndex,
                counterpartyIndex,
                candidate,
                requestedResource,
                initiatorCandidateOfferable,
                counterpartyRequestedOfferable,
                initiatorRequestedReceivable,
                counterpartyCandidateReceivable);
            if (proposal is null)
            {
                continue;
            }

            var candidatePriority = CreateOfferPriority(
                slot,
                counterpartyReceiveSlot,
                counterpartyReservedIn);
            var priority = new SwapPriority(
                requestedSlot.Quantity + GetReservedIn(initiatorIndex, requestedResource),
                candidatePriority);
            _candidateSwapProposals.Add(new PrioritizedSwapProposal(proposal.Value, priority, edgeOrder));
        }
    }

    private SwapProposal? CreateSwapProposal(
        CellState initiator,
        CellState counterparty,
        int initiatorIndex,
        int counterpartyIndex,
        ResourceId initiatorPaidResource,
        ResourceId counterpartyPaidResource,
        int initiatorPaidOfferable,
        int counterpartyPaidOfferable,
        int initiatorReceivable,
        int counterpartyReceivable)
    {
        var quantities = GetSwapQuantities(
            initiator,
            counterparty,
            Options.MaxSwapQuantityPerEdge,
            initiatorPaidOfferable,
            counterpartyPaidOfferable,
            initiatorReceivable,
            counterpartyReceivable);
        if (quantities is null)
        {
            return null;
        }

        return new SwapProposal(
            initiatorIndex,
            counterpartyIndex,
            initiatorPaidResource,
            counterpartyPaidResource,
            quantities.Value.InitiatorPaidQuantity,
            quantities.Value.CounterpartyPaidQuantity,
            quantities.Value.InitiatorReceivedQuantity,
            quantities.Value.CounterpartyReceivedQuantity);
    }

    private static SwapQuantities? GetSwapQuantities(
        CellState initiator,
        CellState counterparty,
        int maxSwapQuantityPerEdge,
        int initiatorPaidOfferable,
        int counterpartyPaidOfferable,
        int initiatorReceivable,
        int counterpartyReceivable)
    {
        var initiatorOutwardFee = GetRedMycoOutwardFee(initiator);
        var counterpartyOutwardFee = GetRedMycoOutwardFee(counterparty);
        // Red myco has a one-unit outward fee in the gross exchange envelope.
        // Gross-one red candidates stop here and never reserve an edge.
        var minimumGrossQuantity = GetMinimumGrossSwapQuantity(initiatorOutwardFee, counterpartyOutwardFee);
        var grossQuantity = Math.Min(
            maxSwapQuantityPerEdge,
            Math.Min(
                Math.Min(
                    initiatorPaidOfferable,
                    counterpartyPaidOfferable),
                Math.Min(
                    IncreaseLimit(initiatorReceivable, counterpartyOutwardFee),
                    IncreaseLimit(counterpartyReceivable, initiatorOutwardFee))));
        if (grossQuantity < minimumGrossQuantity)
        {
            return null;
        }

        return new SwapQuantities(
            grossQuantity,
            grossQuantity,
            grossQuantity - counterpartyOutwardFee,
            grossQuantity - initiatorOutwardFee);
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

    private int GetRequestedResourceReceivableSwapQuantity(
        CellState cell,
        ResourceId resource,
        int reservedIncoming)
    {
        var pool = cell.Pool;
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        if (cell.IsMyco)
        {
            return GetReceivableSwapQuantity(cell, resource, reservedIncoming);
        }

        if (slot.Role == PoolSlotRole.Need)
        {
            var target = Math.Min(slot.Capacity, Options.NeedDesiredQuantity);
            return Math.Max(0, target - slot.Quantity - reservedIncoming);
        }

        return GetReceivableSwapQuantity(cell, resource, reservedIncoming);
    }

    private int GetReceivableSwapQuantity(
        CellState cell,
        ResourceId resource,
        int reservedIncoming)
    {
        var pool = cell.Pool;
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        if (cell.IsMyco)
        {
            return Math.Max(0, slot.Capacity - slot.Quantity - reservedIncoming);
        }

        if (slot.Role == PoolSlotRole.SourceOutput
            || slot.Role == PoolSlotRole.Need && Options.AllowNeedOverflowPayments)
        {
            return int.MaxValue;
        }

        return Math.Max(0, slot.Capacity - slot.Quantity - reservedIncoming);
    }

    private int GetOfferableSwapQuantity(
        CellState cell,
        ResourceId resource,
        int reservedOutgoing)
    {
        var pool = cell.Pool;
        var slot = pool.GetSlot(resource);
        if (slot is null)
        {
            return 0;
        }

        var available = slot.Quantity - reservedOutgoing;
        if (cell.IsMyco)
        {
            return Math.Max(0, available);
        }

        if (slot.Role == PoolSlotRole.Need)
        {
            available -= Options.NeedOfferReserve;
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
        AddReservedOut(proposal.InitiatorIndex, proposal.InitiatorPaidResource, proposal.InitiatorPaidQuantity);
        AddReservedOut(proposal.CounterpartyIndex, proposal.CounterpartyPaidResource, proposal.CounterpartyPaidQuantity);
        AddReservedIn(proposal.InitiatorIndex, proposal.CounterpartyPaidResource, proposal.InitiatorReceivedQuantity);
        AddReservedIn(proposal.CounterpartyIndex, proposal.InitiatorPaidResource, proposal.CounterpartyReceivedQuantity);
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

            initiator.Pool.RemoveResource(proposal.InitiatorPaidResource, proposal.InitiatorPaidQuantity);
            counterparty.Pool.RemoveResource(proposal.CounterpartyPaidResource, proposal.CounterpartyPaidQuantity);
            initiator.Pool.AddResource(proposal.CounterpartyPaidResource, proposal.InitiatorReceivedQuantity);
            counterparty.Pool.AddResource(proposal.InitiatorPaidResource, proposal.CounterpartyReceivedQuantity);

            if (initiator.IsRedMyco || counterparty.IsRedMyco)
            {
                if (initiator.IsRedMyco)
                {
                    initiator.GlowTicksRemaining = Options.GlowTtlTicks;
                    _glowRefreshedCells.Add(initiator.Index);
                }

                if (counterparty.IsRedMyco)
                {
                    counterparty.GlowTicksRemaining = Options.GlowTtlTicks;
                    _glowRefreshedCells.Add(counterparty.Index);
                }
            }

            _events.Add(new SwapEvent(
                CurrentTick,
                initiator.Id,
                counterparty.Id,
                proposal.InitiatorPaidResource,
                proposal.InitiatorPaidQuantity,
                proposal.CounterpartyPaidResource,
                proposal.CounterpartyPaidQuantity,
                proposal.InitiatorReceivedQuantity,
                proposal.CounterpartyReceivedQuantity,
                initiatorReceiveSlot.Quantity,
                initiatorReceiveSlot.Capacity,
                counterpartyReceiveSlot.Quantity,
                counterpartyReceiveSlot.Capacity));

            _events.Add(new FlowEvent(
                CurrentTick,
                initiator.Id,
                counterparty.Id,
                proposal.InitiatorPaidResource,
                proposal.CounterpartyReceivedQuantity,
                FlowKind.Reciprocal));
            _events.Add(new FlowEvent(
                CurrentTick,
                counterparty.Id,
                initiator.Id,
                proposal.CounterpartyPaidResource,
                proposal.InitiatorReceivedQuantity,
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

        var compareQuantity = right.Proposal.PriorityQuantity.CompareTo(left.Proposal.PriorityQuantity);
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
            if (cell.IsMyco)
            {
                continue;
            }

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
            var glowRefreshed = WasGlowRefreshed(cell.Index);
            if (!reacted && !glowRefreshed && cell.GlowTicksRemaining > 0)
            {
                cell.GlowTicksRemaining--;
            }

            if (reacted || cell.IsMyco)
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

    private bool WasGlowRefreshed(int cellIndex)
    {
        for (var i = 0; i < _glowRefreshedCells.Count; i++)
        {
            if (_glowRefreshedCells[i] == cellIndex)
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
        int InitiatorPaidQuantity,
        int CounterpartyPaidQuantity,
        int InitiatorReceivedQuantity,
        int CounterpartyReceivedQuantity)
    {
        public int PriorityQuantity => Math.Max(InitiatorPaidQuantity, CounterpartyPaidQuantity);
    }

    private readonly record struct SwapQuantities(
        int InitiatorPaidQuantity,
        int CounterpartyPaidQuantity,
        int InitiatorReceivedQuantity,
        int CounterpartyReceivedQuantity);

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

    private readonly record struct MycoResourceCandidate(
        ResourceId Resource,
        int Score,
        int Hash);
}
