using CellularSim;

namespace CellularSim.Tests;

internal static class TestSupport
{
    public static FixtureLoadResult LoadFixture(string fileName)
    {
        var path = Path.Combine(AppContext.BaseDirectory, "fixtures", fileName);
        return FixtureLoader.LoadFromFile(path);
    }

    public static string FormatEvent(SimEvent simEvent) =>
        simEvent switch
        {
            FlowEvent flow => $"{flow.Tick}:flow:{flow.SourceCellId}:{flow.TargetCellId}:{flow.Resource.Value}:{flow.Quantity}:{flow.Kind}",
            SwapEvent swap => $"{swap.Tick}:swap:{swap.InitiatorCellId}:{swap.InitiatorPaidResource.Value}:{swap.CounterpartyCellId}:{swap.CounterpartyPaidResource.Value}",
            ReactionEvent reaction => $"{reaction.Tick}:reaction:{reaction.CellId}",
            StrainEvent strain => $"{strain.Tick}:strain:{strain.CellId}:{strain.Reason}",
            OverflowEvent overflow => $"{overflow.Tick}:overflow:{overflow.CellId}:{overflow.Resource.Value}:{overflow.Quantity}",
            FailedSwapEvent failed => $"{failed.Tick}:failed:{failed.SourceCellId}:{failed.TargetCellId}:{failed.Resource.Value}:{failed.Reason}",
            WinStateChangedEvent win => $"{win.Tick}:win:{win.IsWon}",
            _ => simEvent.ToString() ?? ""
        };
}
