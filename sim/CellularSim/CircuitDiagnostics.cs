namespace CellularSim;

public sealed record CircuitDiagnosticEdge(
    string SourceCellId,
    string TargetCellId,
    long LatestTick,
    int Quantity,
    IReadOnlyList<ResourceId> Resources);

public sealed record CircuitDiagnosticGroup(IReadOnlyList<string> CellIds);

public sealed record CircuitDiagnosticsSnapshot(
    bool IsAlive,
    bool IsWon,
    int SustainedTicks,
    long SinceTick,
    IReadOnlyList<CircuitDiagnosticEdge> DirectedEdges,
    IReadOnlyList<CircuitDiagnosticGroup> StrongGroups,
    IReadOnlyList<CircuitDiagnosticGroup> WeakGroups,
    IReadOnlyList<string> NonGlowingRequiredCells,
    IReadOnlyList<ResourceId> MissingRequiredResources);

public static class CircuitDiagnostics
{
    public static CircuitDiagnosticsSnapshot Build(CellularEngine engine)
    {
        ArgumentNullException.ThrowIfNull(engine);

        return Build(
            engine.World,
            engine.Options,
            engine.Events,
            engine.CurrentTick,
            engine.Circuit.IsAliveThisTick,
            engine.Circuit.IsWon,
            engine.Circuit.SustainedTicks);
    }

    public static CircuitDiagnosticsSnapshot Build(
        GridWorld world,
        EngineOptions options,
        IEnumerable<SimEvent> events,
        long currentTick,
        bool isAlive,
        bool isWon,
        int sustainedTicks)
    {
        ArgumentNullException.ThrowIfNull(world);
        ArgumentNullException.ThrowIfNull(options);
        ArgumentNullException.ThrowIfNull(events);

        var sinceTick = currentTick - options.WinRecentFlowWindowTicks;
        var requiredCells = options.RequiredCellIds.Count > 0
            ? options.RequiredCellIds.Distinct(StringComparer.Ordinal).ToArray()
            : world.Cells.Select(cell => cell.Id).Distinct(StringComparer.Ordinal).ToArray();
        Array.Sort(requiredCells, StringComparer.Ordinal);

        var requiredCellSet = new HashSet<string>(requiredCells, StringComparer.Ordinal);
        var adjacency = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        var weakParent = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var cellId in requiredCells)
        {
            adjacency[cellId] = new List<string>(4);
            weakParent[cellId] = cellId;
        }

        var edgeAccumulators = new Dictionary<(string Source, string Target), EdgeAccumulator>();
        var seenResources = new HashSet<ResourceId>();
        foreach (var simEvent in events)
        {
            if (simEvent is not FlowEvent flow || flow.Tick < sinceTick)
            {
                continue;
            }

            seenResources.Add(flow.Resource);
            var key = (flow.SourceCellId, flow.TargetCellId);
            if (!edgeAccumulators.TryGetValue(key, out var accumulator))
            {
                accumulator = new EdgeAccumulator(flow.SourceCellId, flow.TargetCellId);
                edgeAccumulators.Add(key, accumulator);
            }

            accumulator.Quantity += flow.Quantity;
            accumulator.LatestTick = Math.Max(accumulator.LatestTick, flow.Tick);
            accumulator.Resources.Add(flow.Resource);

            if (requiredCellSet.Contains(flow.SourceCellId) && requiredCellSet.Contains(flow.TargetCellId))
            {
                adjacency[flow.SourceCellId].Add(flow.TargetCellId);
                Union(weakParent, flow.SourceCellId, flow.TargetCellId);
            }
        }

        var directedEdges = edgeAccumulators.Values
            .Select(accumulator => accumulator.ToEdge())
            .OrderBy(edge => edge.SourceCellId, StringComparer.Ordinal)
            .ThenBy(edge => edge.TargetCellId, StringComparer.Ordinal)
            .ToArray();
        var strongGroups = BuildStrongGroups(requiredCells, adjacency);
        var weakGroups = BuildWeakGroups(requiredCells, weakParent);
        var nonGlowing = BuildNonGlowingRequiredCells(world, requiredCells);
        var missingResources = options.RequiredResources
            .Where(resource => !seenResources.Contains(resource))
            .OrderBy(resource => resource.Value)
            .ToArray();

        return new CircuitDiagnosticsSnapshot(
            isAlive,
            isWon,
            sustainedTicks,
            sinceTick,
            directedEdges,
            strongGroups,
            weakGroups,
            nonGlowing,
            missingResources);
    }

    private static IReadOnlyList<string> BuildNonGlowingRequiredCells(GridWorld world, IReadOnlyList<string> requiredCells)
    {
        var nonGlowing = new List<string>();
        foreach (var cellId in requiredCells)
        {
            if (!world.TryGetCell(cellId, out var cell) || cell is null || !cell.IsGlowing)
            {
                nonGlowing.Add(cellId);
            }
        }

        return nonGlowing;
    }

    private static IReadOnlyList<CircuitDiagnosticGroup> BuildStrongGroups(
        IReadOnlyList<string> nodes,
        Dictionary<string, List<string>> adjacency)
    {
        var index = 0;
        var stack = new Stack<string>();
        var onStack = new HashSet<string>(StringComparer.Ordinal);
        var indexes = new Dictionary<string, int>(StringComparer.Ordinal);
        var lowLinks = new Dictionary<string, int>(StringComparer.Ordinal);
        var groups = new List<CircuitDiagnosticGroup>();

        foreach (var node in nodes)
        {
            if (!indexes.ContainsKey(node))
            {
                Visit(node);
            }
        }

        return SortGroups(groups);

        void Visit(string node)
        {
            indexes[node] = index;
            lowLinks[node] = index;
            index++;
            stack.Push(node);
            onStack.Add(node);

            foreach (var target in adjacency[node])
            {
                if (!indexes.ContainsKey(target))
                {
                    Visit(target);
                    lowLinks[node] = Math.Min(lowLinks[node], lowLinks[target]);
                }
                else if (onStack.Contains(target))
                {
                    lowLinks[node] = Math.Min(lowLinks[node], indexes[target]);
                }
            }

            if (lowLinks[node] != indexes[node])
            {
                return;
            }

            var members = new List<string>();
            string member;
            do
            {
                member = stack.Pop();
                onStack.Remove(member);
                members.Add(member);
            }
            while (member != node);

            members.Sort(StringComparer.Ordinal);
            groups.Add(new CircuitDiagnosticGroup(members));
        }
    }

    private static IReadOnlyList<CircuitDiagnosticGroup> BuildWeakGroups(
        IReadOnlyList<string> nodes,
        Dictionary<string, string> parent)
    {
        var groupsByRoot = new Dictionary<string, List<string>>(StringComparer.Ordinal);
        foreach (var node in nodes)
        {
            var root = Find(parent, node);
            if (!groupsByRoot.TryGetValue(root, out var group))
            {
                group = new List<string>();
                groupsByRoot.Add(root, group);
            }

            group.Add(node);
        }

        var groups = new List<CircuitDiagnosticGroup>(groupsByRoot.Count);
        foreach (var group in groupsByRoot.Values)
        {
            group.Sort(StringComparer.Ordinal);
            groups.Add(new CircuitDiagnosticGroup(group));
        }

        return SortGroups(groups);
    }

    private static IReadOnlyList<CircuitDiagnosticGroup> SortGroups(List<CircuitDiagnosticGroup> groups) =>
        groups
            .OrderByDescending(group => group.CellIds.Count)
            .ThenBy(group => group.CellIds.Count > 0 ? group.CellIds[0] : "", StringComparer.Ordinal)
            .ToArray();

    private static string Find(Dictionary<string, string> parent, string node)
    {
        if (!parent.TryGetValue(node, out var current))
        {
            parent[node] = node;
            return node;
        }

        if (current == node)
        {
            return node;
        }

        var root = Find(parent, current);
        parent[node] = root;
        return root;
    }

    private static void Union(Dictionary<string, string> parent, string a, string b)
    {
        var rootA = Find(parent, a);
        var rootB = Find(parent, b);
        if (rootA == rootB)
        {
            return;
        }

        if (string.CompareOrdinal(rootA, rootB) < 0)
        {
            parent[rootB] = rootA;
        }
        else
        {
            parent[rootA] = rootB;
        }
    }

    private sealed class EdgeAccumulator
    {
        public EdgeAccumulator(string sourceCellId, string targetCellId)
        {
            SourceCellId = sourceCellId;
            TargetCellId = targetCellId;
        }

        public string SourceCellId { get; }
        public string TargetCellId { get; }
        public long LatestTick { get; set; }
        public int Quantity { get; set; }
        public HashSet<ResourceId> Resources { get; } = new();

        public CircuitDiagnosticEdge ToEdge() =>
            new(
                SourceCellId,
                TargetCellId,
                LatestTick,
                Quantity,
                Resources.OrderBy(resource => resource.Value).ToArray());
    }
}
