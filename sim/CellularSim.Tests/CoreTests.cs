using CellularSim;

namespace CellularSim.Tests;

public sealed class CoreTests
{
    [Fact]
    public void ResourceCatalog_UsesDenseStableIds()
    {
        var catalog = new ResourceCatalog();

        var a = catalog.Register("A");
        var b = catalog.Register("B");
        var aAgain = catalog.Register("A");

        Assert.Equal(0, a.Value);
        Assert.Equal(1, b.Value);
        Assert.Equal(a, aAgain);
        Assert.Equal("B", catalog.GetName(b));
    }

    [Fact]
    public void Pool_EnforcesSlotCap()
    {
        var resource = new ResourceId(0);
        var pool = new SwapPoolState();
        pool.AddSlot(resource, PoolSlotRole.AcceptOnly, quantity: 99);

        Assert.Equal(1, pool.AddResource(resource, 5));
        Assert.Equal(100, pool.GetQuantity(resource));
        Assert.False(pool.CanReceive(resource));
    }

    [Fact]
    public void Pool_EnforcesFourSlotLimit()
    {
        var pool = new SwapPoolState();
        pool.AddSlot(new ResourceId(0), PoolSlotRole.AcceptOnly);
        pool.AddSlot(new ResourceId(1), PoolSlotRole.AcceptOnly);
        pool.AddSlot(new ResourceId(2), PoolSlotRole.AcceptOnly);
        pool.AddSlot(new ResourceId(3), PoolSlotRole.AcceptOnly);

        Assert.Throws<InvalidOperationException>(() =>
            pool.AddSlot(new ResourceId(4), PoolSlotRole.AcceptOnly));
    }

    [Fact]
    public void PrivateInventory_CanMoveIntoAndOutOfPool()
    {
        var resource = new ResourceId(0);
        var inventory = new PrivateInventory();
        var pool = new SwapPoolState();
        inventory.Add(resource, 3);

        Assert.True(inventory.MoveToPool(pool, resource, 2));
        Assert.Equal(1, inventory.GetQuantity(resource));
        Assert.Equal(2, pool.GetQuantity(resource));

        Assert.True(inventory.MoveFromPool(pool, resource, 1));
        Assert.Equal(2, inventory.GetQuantity(resource));
        Assert.Equal(1, pool.GetQuantity(resource));
    }

    [Fact]
    public void Reaction_ConsumesFullActiveResourceSet()
    {
        var sourceOutput = new ResourceId(0);
        var need = new ResourceId(1);
        var acceptOnly = new ResourceId(2);
        var pool = new SwapPoolState();
        pool.AddSlot(sourceOutput, PoolSlotRole.SourceOutput, quantity: 1);
        pool.AddSlot(need, PoolSlotRole.Need, quantity: 1);
        pool.AddSlot(acceptOnly, PoolSlotRole.AcceptOnly, quantity: 5);

        Assert.True(pool.CanReact());
        pool.React();

        Assert.Equal(0, pool.GetQuantity(sourceOutput));
        Assert.Equal(0, pool.GetQuantity(need));
        Assert.Equal(5, pool.GetQuantity(acceptOnly));
    }

    [Fact]
    public void AcceptOnlySlot_DoesNotTriggerReaction()
    {
        var pool = new SwapPoolState();
        pool.AddSlot(new ResourceId(0), PoolSlotRole.AcceptOnly, quantity: 10);

        Assert.False(pool.CanReact());
    }
}
