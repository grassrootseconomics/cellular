namespace CellularSim;

public sealed record SimulationSummary(
    int Ticks,
    int Cells,
    int Rocks,
    int AdjacentPairs,
    int TotalSwaps,
    int TotalReactions,
    int TotalStrainEvents,
    int TotalOverflows,
    int FirstWindowTicks,
    int FirstWindowSwaps,
    int FirstWindowReactions,
    int LastWindowTicks,
    int LastWindowSwaps,
    int LastWindowReactions,
    int ActiveCellsInLastWindow,
    int GlowingCells,
    int CellsWithStrain,
    int ReactionScore,
    int FlowDiversityScore,
    int SettlementScore,
    int StrainPenalty,
    int HoardingPenalty,
    int DeadLoopPenalty,
    int FinalScore,
    bool StableSignal)
{
    public double AverageSwapsPerTick => Ticks == 0 ? 0 : (double)TotalSwaps / Ticks;
    public double AverageReactionsPerTick => Ticks == 0 ? 0 : (double)TotalReactions / Ticks;
    public double LastWindowAverageSwapsPerTick => LastWindowTicks == 0 ? 0 : (double)LastWindowSwaps / LastWindowTicks;
    public double LastWindowAverageReactionsPerTick => LastWindowTicks == 0 ? 0 : (double)LastWindowReactions / LastWindowTicks;
}

public static class SimulationSummaryRunner
{
    public static SimulationSummary Run(CellularEngine engine, int ticks)
    {
        if (ticks < 0)
        {
            throw new ArgumentOutOfRangeException(nameof(ticks), "Tick count cannot be negative.");
        }

        var windowTicks = ticks == 0 ? 0 : Math.Max(1, ticks / 5);
        var firstWindowEnd = windowTicks;
        var lastWindowStart = ticks == 0 ? 1 : ticks - windowTicks + 1;
        var activeCellsInLastWindow = new HashSet<string>(StringComparer.Ordinal);

        var totalSwaps = 0;
        var totalReactions = 0;
        var totalStrain = 0;
        var totalOverflows = 0;
        var firstWindowSwaps = 0;
        var firstWindowReactions = 0;
        var lastWindowSwaps = 0;
        var lastWindowReactions = 0;

        for (var i = 0; i < ticks; i++)
        {
            engine.Tick();
            var tick = engine.CurrentTick;

            foreach (var simEvent in engine.Events)
            {
                if (simEvent.Tick != tick)
                {
                    continue;
                }

                switch (simEvent)
                {
                    case SwapEvent swap:
                        totalSwaps++;
                        if (tick <= firstWindowEnd)
                        {
                            firstWindowSwaps++;
                        }

                        if (tick >= lastWindowStart)
                        {
                            lastWindowSwaps++;
                            activeCellsInLastWindow.Add(swap.InitiatorCellId);
                            activeCellsInLastWindow.Add(swap.CounterpartyCellId);
                        }

                        break;
                    case ReactionEvent reaction:
                        totalReactions++;
                        if (tick <= firstWindowEnd)
                        {
                            firstWindowReactions++;
                        }

                        if (tick >= lastWindowStart)
                        {
                            lastWindowReactions++;
                            activeCellsInLastWindow.Add(reaction.CellId);
                        }

                        break;
                    case StrainEvent:
                        totalStrain++;
                        break;
                    case OverflowEvent:
                        totalOverflows++;
                        break;
                }
            }
        }

        var glowingCells = 0;
        var cellsWithStrain = 0;
        foreach (var cell in engine.World.Cells)
        {
            if (cell.IsGlowing)
            {
                glowingCells++;
            }

            if (cell.Strain.Total > 0)
            {
                cellsWithStrain++;
            }
        }

        var minimumActiveCells = Math.Max(3, engine.World.Cells.Count / 5);
        var maximumStrainedCells = engine.World.Cells.Count / 2;
        var stableSignal = ticks > 0
            && lastWindowSwaps > 0
            && lastWindowReactions > 0
            && lastWindowReactions >= Math.Max(1, firstWindowReactions / 4)
            && activeCellsInLastWindow.Count >= minimumActiveCells
            && cellsWithStrain <= maximumStrainedCells;

        return new SimulationSummary(
            ticks,
            engine.World.Cells.Count,
            engine.World.Rocks.Count,
            engine.World.AdjacentEdges.Count,
            totalSwaps,
            totalReactions,
            totalStrain,
            totalOverflows,
            firstWindowEnd,
            firstWindowSwaps,
            firstWindowReactions,
            windowTicks,
            lastWindowSwaps,
            lastWindowReactions,
            activeCellsInLastWindow.Count,
            glowingCells,
            cellsWithStrain,
            engine.Score.ReactionScore,
            engine.Score.FlowDiversityScore,
            engine.Score.SettlementScore,
            engine.Score.StrainPenalty,
            engine.Score.HoardingPenalty,
            engine.Score.DeadLoopPenalty,
            engine.Score.TotalScore,
            stableSignal);
    }
}
