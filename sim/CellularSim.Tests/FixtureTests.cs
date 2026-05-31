using CellularSim;

namespace CellularSim.Tests;

public sealed class FixtureTests
{
    [Fact]
    public void FixtureLoader_LoadsDirectReciprocity()
    {
        var loaded = TestSupport.LoadFixture("direct-reciprocity.json");

        Assert.Equal(2, loaded.Catalog.Count);
        Assert.Equal(2, loaded.World.Cells.Count);
        Assert.Contains("cell-a", loaded.Options.RequiredCellIds);
    }

    [Fact]
    public void FixtureLoader_RejectsDuplicateCellIds()
    {
        const string json = """
        {
          "resources": ["A"],
          "grid": { "width": 2, "height": 1, "rocks": [] },
          "cells": [
            { "id": "same", "x": 0, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] },
            { "id": "same", "x": 1, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }

    [Fact]
    public void FixtureLoader_RejectsCellOnRock()
    {
        const string json = """
        {
          "resources": ["A"],
          "grid": { "width": 1, "height": 1, "rocks": [{ "x": 0, "y": 0 }] },
          "cells": [
            { "id": "cell", "x": 0, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }

    [Fact]
    public void FixtureLoader_RejectsInvalidResourceNames()
    {
        const string json = """
        {
          "resources": ["A"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            { "id": "cell", "x": 0, "y": 0, "slots": [{ "resource": "B", "role": "AcceptOnly", "quantity": 0 }] }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }

    [Fact]
    public void FixtureLoader_RejectsMoreThanFourSlots()
    {
        const string json = """
        {
          "resources": ["A", "B", "C", "D", "E"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "AcceptOnly", "quantity": 0 },
                { "resource": "B", "role": "AcceptOnly", "quantity": 0 },
                { "resource": "C", "role": "AcceptOnly", "quantity": 0 },
                { "resource": "D", "role": "AcceptOnly", "quantity": 0 },
                { "resource": "E", "role": "AcceptOnly", "quantity": 0 }
              ]
            }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }

    [Fact]
    public void FixtureLoader_RejectsStartingQuantityAboveCap()
    {
        const string json = """
        {
          "resources": ["A"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            { "id": "cell", "x": 0, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 101 }] }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }

    [Fact]
    public void FixtureLoader_RejectsSourceWithoutSlot()
    {
        const string json = """
        {
          "resources": ["A", "B"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell",
              "x": 0,
              "y": 0,
              "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }],
              "sources": [{ "resource": "B", "quantityPerTick": 1, "intervalTicks": 1 }]
            }
          ]
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }

    [Fact]
    public void FixtureLoader_RejectsMissingRequiredEntities()
    {
        const string json = """
        {
          "resources": ["A"],
          "grid": { "width": 1, "height": 1, "rocks": [] },
          "cells": [
            { "id": "cell", "x": 0, "y": 0, "slots": [{ "resource": "A", "role": "AcceptOnly", "quantity": 0 }] }
          ],
          "win": {
            "requiredCells": ["missing"],
            "requiredResources": ["A"]
          }
        }
        """;

        Assert.Throws<InvalidFixtureException>(() => FixtureLoader.LoadFromJson(json));
    }
}
