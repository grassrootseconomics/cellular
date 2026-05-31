namespace CellularSim;

/// <summary>
/// V1 quote policy: one input unit produces one output unit and no fees are applied.
/// </summary>
public sealed class QuotePolicy
{
    public static QuotePolicy Unit { get; } = new();

    public int GetOutput(ResourceId inputResource, ResourceId outputResource, int inputQuantity)
    {
        if (!inputResource.IsValid)
        {
            throw new ArgumentException("Input resource id must be valid.", nameof(inputResource));
        }

        if (!outputResource.IsValid)
        {
            throw new ArgumentException("Output resource id must be valid.", nameof(outputResource));
        }

        if (inputQuantity <= 0)
        {
            throw new ArgumentOutOfRangeException(nameof(inputQuantity), "Input quantity must be positive.");
        }

        return inputQuantity;
    }
}

/// <summary>
/// V1 limit policy: each pool slot defaults to capacity 100.
/// </summary>
public sealed class LimitPolicy
{
    public static LimitPolicy Default { get; } = new();

    public int GetSlotCapacity(ResourceId resource, int requestedCapacity = SwapPoolState.DefaultSlotCapacity)
    {
        if (!resource.IsValid)
        {
            throw new ArgumentException("Resource id must be valid.", nameof(resource));
        }

        return requestedCapacity <= 0 ? SwapPoolState.DefaultSlotCapacity : requestedCapacity;
    }
}

public readonly record struct SwapRequest(
    int SourceCellIndex,
    int TargetCellIndex,
    ResourceId Resource,
    int Quantity);

public readonly record struct SwapResult(
    bool Success,
    ResourceId Resource,
    int Quantity,
    FailedSwapReason? FailureReason = null);
