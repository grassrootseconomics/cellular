using System.Text.Json;
using CellularSim;

namespace CellularSim.Tests;

public sealed class PuzzleSolutionSearchTests
{
    [Fact]
    public void PuzzleSolutionSearcher_ReciprocalMainNeedOutranksOneWayAndDuplicateProvider()
    {
        var reciprocal = PuzzleSolutionSearcher.ScoreCellMatchForTests(
            "A",
            ["B"],
            CellKind.Standard,
            "B",
            ["A"],
            CellKind.Standard);

        var oneWay = PuzzleSolutionSearcher.ScoreCellMatchForTests(
            "A",
            ["B"],
            CellKind.Standard,
            "B",
            ["C"],
            CellKind.Standard);

        var duplicateProvider = PuzzleSolutionSearcher.ScoreCellMatchForTests(
            "B",
            ["C", "E", "F"],
            CellKind.Standard,
            "B",
            ["A", "E", "F"],
            CellKind.Standard);

        Assert.True(reciprocal > oneWay);
        Assert.True(oneWay > duplicateProvider);
    }

    [Fact]
    public void PuzzleSolutionSearcher_MycoEdgesAreLowerPriorityUnlessTheyEnableExchange()
    {
        var reciprocalStandard = PuzzleSolutionSearcher.ScoreCellMatchForTests(
            "A",
            ["B"],
            CellKind.Standard,
            "B",
            ["A"],
            CellKind.Standard);

        var usefulMyco = PuzzleSolutionSearcher.ScoreCellMatchForTests(
            "",
            ["B"],
            CellKind.WhiteMyco,
            "B",
            ["A"],
            CellKind.Standard);

        var emptyMyco = PuzzleSolutionSearcher.ScoreCellMatchForTests(
            "",
            ["C"],
            CellKind.WhiteMyco,
            "B",
            ["A"],
            CellKind.Standard);

        Assert.True(usefulMyco > emptyMyco);
        Assert.True(reciprocalStandard > usefulMyco);
    }

    [Fact]
    public void PuzzleSolutionSearcher_GeneratedCandidatesStayOnOpenTiles()
    {
        var candidates = PuzzleSolutionSearcher.GenerateCandidateLayoutsForTests("""
        {
          "resources": ["A", "B", "C"],
          "grid": { "width": 3, "height": 3, "rocks": [{ "x": 1, "y": 1 }] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "B", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-b",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                { "resource": "C", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-c",
              "x": 2,
              "y": 0,
              "slots": [
                { "resource": "C", "role": "SourceOutput", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """, candidateLimit: 32, beamSize: 16);

        Assert.NotEmpty(candidates);
        foreach (var candidate in candidates)
        {
            Assert.Equal(3, candidate.Placements.Count);
            Assert.Equal(candidate.Placements.Count, candidate.Placements.Values.Distinct().Count());
            foreach (var position in candidate.Placements.Values)
            {
                Assert.InRange(position.X, 0, 2);
                Assert.InRange(position.Y, 0, 2);
                Assert.NotEqual(new GridPosition(1, 1), position);
            }
        }
    }

    [Fact]
    public void PuzzleSolutionSearcher_CandidateLayoutsRemainConnectedWhenSpaceAllows()
    {
        var candidates = PuzzleSolutionSearcher.GenerateCandidateLayoutsForTests("""
        {
          "resources": ["A", "B", "C"],
          "grid": { "width": 3, "height": 3, "rocks": [] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "B", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-b",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                { "resource": "C", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-c",
              "x": 2,
              "y": 0,
              "slots": [
                { "resource": "C", "role": "SourceOutput", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """, candidateLimit: 32, beamSize: 16);

        Assert.NotEmpty(candidates);
        foreach (var candidate in candidates)
        {
            Assert.True(IsConnected(candidate.Placements.Values));
        }
    }

    [Fact]
    public void PuzzleSolutionSearcher_StaleAsciiSeedWithMissingLiveCellsIsIgnored()
    {
        var count = PuzzleSolutionSearcher.CountAsciiSeedCandidatesForTests("""
        {
          "resources": ["A", "B"],
          "grid": { "width": 3, "height": 2, "rocks": [] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "B", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "red-myco-001",
              "kind": "RedMyco",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "Need", "quantity": 250, "capacity": 500 }
              ]
            }
          ]
        }
        """, "AK");

        Assert.Equal(0, count);
    }

    [Fact]
    public void PuzzleSolutionSearcher_RendersRedMycoAsStar()
    {
        var map = PuzzleSolutionSearcher.RenderCandidateMapForTests("""
        {
          "resources": ["A"],
          "grid": { "width": 2, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 }
              ]
            },
            {
              "id": "red-myco-001",
              "kind": "RedMyco",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "Need", "quantity": 250, "capacity": 500 }
              ]
            }
          ]
        }
        """, new Dictionary<string, GridPosition>
        {
            ["cell-a"] = new(0, 0),
            ["red-myco-001"] = new(1, 0)
        });

        Assert.Equal("A*\n", map);
    }

    [Fact]
    public void PuzzleSolutionSearcher_AnnotatedMapDisambiguatesDuplicateProducersWithLegend()
    {
        var map = PuzzleSolutionSearcher.RenderAnnotatedCandidateMapForTests("""
        {
          "resources": ["A", "B", "C"],
          "grid": { "width": 3, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell-a-001",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "B", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-a-002",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "C", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "red-myco-001",
              "kind": "RedMyco",
              "x": 2,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "Need", "quantity": 250, "capacity": 500 }
              ]
            }
          ]
        }
        """, new Dictionary<string, GridPosition>
        {
            ["cell-a-001"] = new(0, 0),
            ["cell-a-002"] = new(1, 0),
            ["red-myco-001"] = new(2, 0)
        });

        Assert.Contains("A1 A2 *1", map, StringComparison.Ordinal);
        Assert.Contains("A1: cell-a-001; produces A; needs B", map, StringComparison.Ordinal);
        Assert.Contains("A2: cell-a-002; produces A; needs C", map, StringComparison.Ordinal);
        Assert.Contains("*1: red-myco-001; red-myco; needs A", map, StringComparison.Ordinal);
    }

    [Fact]
    public void PuzzleSolutionSearcher_NonGlowingHistogramNamesBlockingCells()
    {
        var histogram = PuzzleSolutionSearcher.BuildNonGlowingHistogramForTests([
            new PuzzleSolutionCandidateReport(0, false, -1, 0, 0, 0, 0, 0, 0, 0, 2, 0, "cell-a|cell-b", "", 0, 0, 0, ""),
            new PuzzleSolutionCandidateReport(1, false, -1, 0, 0, 0, 0, 0, 0, 0, 1, 0, "cell-a", "", 0, 0, 0, "")
        ]);

        Assert.Contains("cell-a=2", histogram, StringComparison.Ordinal);
        Assert.Contains("cell-b=1", histogram, StringComparison.Ordinal);
    }

    [Fact]
    public void PuzzleSolutionSearcher_ShapeFirstNeedsSuggestionDoesNotSuggestSelfNeed()
    {
        var suggestion = PuzzleSolutionSearcher.BuildShapeFirstNeedsSuggestionForTests("""
        {
          "resources": ["A", "B", "C"],
          "grid": { "width": 3, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "C", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-b",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-a-duplicate",
              "x": 2,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "B", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """, new Dictionary<string, GridPosition>
        {
            ["cell-a"] = new(1, 0),
            ["cell-b"] = new(0, 0),
            ["cell-a-duplicate"] = new(2, 0)
        });

        Assert.Contains("cell-a: C -> B", suggestion, StringComparison.Ordinal);
        Assert.DoesNotContain("cell-a: C -> A", suggestion, StringComparison.Ordinal);
    }

    [Fact]
    public void PuzzleSolutionSearcher_ShapeFirstNeedsSuggestionUsesStressedAdjacentResource()
    {
        var suggestion = PuzzleSolutionSearcher.BuildShapeFirstNeedsSuggestionForTests("""
        {
          "resources": ["A", "B", "D", "E", "F"],
          "grid": { "width": 2, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell-d",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "D", "role": "SourceOutput", "quantity": 0 },
                { "resource": "F", "role": "Need", "quantity": 0 },
                { "resource": "E", "role": "Need", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-b",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                { "resource": "D", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """, new Dictionary<string, GridPosition>
        {
            ["cell-d"] = new(0, 0),
            ["cell-b"] = new(1, 0)
        }, new Dictionary<string, string[]>
        {
            ["cell-d"] = ["A"]
        }, ["cell-d"]);

        Assert.Contains("cell-d: F|E|A -> F|E|B", suggestion, StringComparison.Ordinal);
        Assert.Contains("empty A;", suggestion, StringComparison.Ordinal);
        Assert.Contains("edit A->B and keep 3 needs", suggestion, StringComparison.Ordinal);
    }

    [Fact]
    public void PuzzleSolutionSearcher_StressNeedsRepairTriesCombinedLocalAvailableResourceEdits()
    {
        var variants = PuzzleSolutionSearcher.GenerateStressNeedRepairFixtureJsonsForTests("""
        {
          "resources": ["A", "B", "C", "E", "F", "G", "H", "K", "L"],
          "grid": { "width": 3, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell-l",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "L", "role": "SourceOutput", "quantity": 0 },
                { "resource": "F", "role": "Need", "quantity": 0 },
                { "resource": "K", "role": "Need", "quantity": 0 },
                { "resource": "C", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-b",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                { "resource": "L", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-e",
              "x": 2,
              "y": 0,
              "slots": [
                { "resource": "E", "role": "SourceOutput", "quantity": 0 },
                { "resource": "H", "role": "Need", "quantity": 0 },
                { "resource": "G", "role": "Need", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """, new Dictionary<string, GridPosition>
        {
            ["cell-l"] = new(0, 0),
            ["cell-b"] = new(1, 0),
            ["cell-e"] = new(2, 0)
        }, new Dictionary<string, string[]>
        {
            ["cell-l"] = ["C"],
            ["cell-e"] = ["A"]
        }, ["cell-l", "cell-e"], candidateLimit: 16);

        Assert.Contains(variants, json =>
            NeedsFor(json, "cell-l").SequenceEqual(new[] { "F", "K", "B" })
            && NeedsFor(json, "cell-e").SequenceEqual(new[] { "H", "G", "B" }));
    }

    [Fact]
    public void PuzzleSolutionSearcher_StressNeedsRepairUsesResourcesCarriedByAdjacentNeeds()
    {
        var variants = PuzzleSolutionSearcher.GenerateStressNeedRepairFixtureJsonsForTests("""
        {
          "resources": ["A", "D", "E", "G", "I", "M"],
          "grid": { "width": 2, "height": 1, "rocks": [] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "M", "role": "Need", "quantity": 0 },
                { "resource": "G", "role": "Need", "quantity": 0 },
                { "resource": "I", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-i",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "I", "role": "SourceOutput", "quantity": 0 },
                { "resource": "D", "role": "Need", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 },
                { "resource": "E", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """, new Dictionary<string, GridPosition>
        {
            ["cell-a"] = new(0, 0),
            ["cell-i"] = new(1, 0)
        }, new Dictionary<string, string[]>
        {
            ["cell-a"] = ["M"]
        }, ["cell-a"], candidateLimit: 16);

        Assert.Contains(variants, json =>
            NeedsFor(json, "cell-a").SequenceEqual(new[] { "D", "G", "I" }));
    }

    [Fact]
    public void PuzzleSolutionSearcher_RepairLayoutsMoveBlockerTowardNeededProvider()
    {
        var fixture = """
        {
          "resources": ["A", "B", "C"],
          "grid": { "width": 3, "height": 2, "rocks": [] },
          "cells": [
            {
              "id": "cell-a",
              "x": 0,
              "y": 0,
              "slots": [
                { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                { "resource": "B", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-b",
              "x": 2,
              "y": 0,
              "slots": [
                { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            },
            {
              "id": "cell-c",
              "x": 1,
              "y": 0,
              "slots": [
                { "resource": "C", "role": "SourceOutput", "quantity": 0 },
                { "resource": "A", "role": "Need", "quantity": 0 }
              ]
            }
          ]
        }
        """;

        var repairs = PuzzleSolutionSearcher.GenerateRepairLayoutsForTests(
            fixture,
            new Dictionary<string, GridPosition>
            {
                ["cell-a"] = new(0, 0),
                ["cell-b"] = new(2, 0),
                ["cell-c"] = new(1, 0)
            },
            ["cell-a"]);

        Assert.Contains(repairs, layout =>
            Math.Abs(layout.Placements["cell-a"].X - layout.Placements["cell-b"].X)
            + Math.Abs(layout.Placements["cell-a"].Y - layout.Placements["cell-b"].Y) == 1);
    }

    [Fact]
    public void PuzzleSolutionSearcher_BlockingRocksReportFailure()
    {
        var result = PuzzleSolutionSearcher.SearchFixture(
            99,
            "level-099",
            "blocking-rocks.json",
            """
            {
              "resources": ["A", "B"],
              "grid": { "width": 3, "height": 1, "rocks": [{ "x": 1, "y": 0 }] },
              "cells": [
                {
                  "id": "cell-a",
                  "x": 0,
                  "y": 0,
                  "slots": [
                    { "resource": "A", "role": "SourceOutput", "quantity": 0 },
                    { "resource": "B", "role": "Need", "quantity": 0 }
                  ],
                  "sources": [{ "resource": "A", "quantityPerTick": 12, "intervalTicks": 1 }]
                },
                {
                  "id": "cell-b",
                  "x": 2,
                  "y": 0,
                  "slots": [
                    { "resource": "B", "role": "SourceOutput", "quantity": 0 },
                    { "resource": "A", "role": "Need", "quantity": 0 }
                  ],
                  "sources": [{ "resource": "B", "quantityPerTick": 12, "intervalTicks": 1 }]
                }
              ],
              "win": {
                "requiredCells": ["cell-a", "cell-b"],
                "requiredResources": ["A", "B"],
                "durationTicks": 1
              }
            }
            """,
            new PuzzleSolutionSearchOptions
            {
                StartLevel = 99,
                EndLevel = 99,
                TicksPerCandidate = 40,
                CandidateLimit = 8,
                BeamSize = 4,
                ProgressStride = 0
            });

        Assert.False(result.Won);
        Assert.Equal("spatial blockage", result.FailureCategory);
        Assert.True(result.CandidatesEvaluated > 0);
    }

    [Fact]
    public void PuzzleSolutionSearcher_LevelOneFixtureSolvesAndWritesArtifacts()
    {
        var repoRoot = FindRepoRoot();
        var sourceFixture = Path.Combine(repoRoot, "levels", "puzzle", "level-001.json");
        Assert.True(File.Exists(sourceFixture), $"Missing fixture: {sourceFixture}");

        var root = Directory.CreateTempSubdirectory("cellular-solver-test-");
        try
        {
            var levelsDir = Path.Combine(root.FullName, "levels");
            var outputDir = Path.Combine(root.FullName, "solutions");
            Directory.CreateDirectory(levelsDir);
            File.Copy(sourceFixture, Path.Combine(levelsDir, "level-001.json"));

            var batch = PuzzleSolutionSearcher.SearchRange(new PuzzleSolutionSearchOptions
            {
                StartLevel = 1,
                EndLevel = 1,
                LevelsDirectory = levelsDir,
                OutputDirectory = outputDir,
                TicksPerCandidate = 240,
                CandidateLimit = 512,
                BeamSize = 128,
                ProgressStride = 0
            });

            var result = Assert.Single(batch.Results);
            Assert.True(result.Won, result.Diagnostics);
            Assert.True(result.FirstWinTick >= 0);
            Assert.True(File.Exists(Path.Combine(outputDir, "level-001", "solution-fixture.json")));
            Assert.True(File.Exists(Path.Combine(outputDir, "level-001", "solution-map.txt")));
            Assert.True(File.Exists(Path.Combine(outputDir, "level-001", "results.txt")));
            Assert.True(File.Exists(Path.Combine(outputDir, "level-001", "candidates.csv")));
            Assert.True(File.Exists(Path.Combine(outputDir, "summary.csv")));
        }
        finally
        {
            root.Delete(recursive: true);
        }
    }

    private static bool IsConnected(IEnumerable<GridPosition> positions)
    {
        var set = positions.ToHashSet();
        var start = set.First();
        var seen = new HashSet<GridPosition> { start };
        var queue = new Queue<GridPosition>();
        queue.Enqueue(start);
        while (queue.Count > 0)
        {
            var current = queue.Dequeue();
            foreach (var neighbor in new[]
            {
                new GridPosition(current.X + 1, current.Y),
                new GridPosition(current.X - 1, current.Y),
                new GridPosition(current.X, current.Y + 1),
                new GridPosition(current.X, current.Y - 1)
            })
            {
                if (set.Contains(neighbor) && seen.Add(neighbor))
                {
                    queue.Enqueue(neighbor);
                }
            }
        }

        return seen.Count == set.Count;
    }

    private static string[] NeedsFor(string fixtureJson, string cellId)
    {
        using var document = JsonDocument.Parse(fixtureJson);
        return document.RootElement.GetProperty("cells")
            .EnumerateArray()
            .Single(cell => cell.GetProperty("id").GetString() == cellId)
            .GetProperty("slots")
            .EnumerateArray()
            .Where(slot => slot.TryGetProperty("role", out var role) && role.GetString() == "Need")
            .Select(slot => slot.GetProperty("resource").GetString() ?? "")
            .ToArray();
    }

    private static string FindRepoRoot()
    {
        var directory = new DirectoryInfo(AppContext.BaseDirectory);
        while (directory is not null)
        {
            if (File.Exists(Path.Combine(directory.FullName, "Cellular.csproj")))
            {
                return directory.FullName;
            }

            directory = directory.Parent;
        }

        throw new InvalidOperationException("Could not find repository root.");
    }
}
