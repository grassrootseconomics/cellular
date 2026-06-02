using System.Globalization;
using System.Text;
using CellularSim;

var run = ParseRun(args);
if (run.PuzzleSolutionSearchOptions is not null)
{
    if (run.PuzzleSolutionSearchOptions.ProgressStride > 0)
    {
        run.PuzzleSolutionSearchOptions.ProgressLogger = Console.WriteLine;
    }

    var solutionBatch = PuzzleSolutionSearcher.SearchRange(run.PuzzleSolutionSearchOptions);
    var failures = solutionBatch.Results.Count(result => !result.Won);
    Console.WriteLine($"Puzzle solution search complete: pass={solutionBatch.Results.Count - failures} fail={failures} summary={Path.Combine(run.PuzzleSolutionSearchOptions.OutputDirectory, "summary.csv")}");
    if (failures > 0)
    {
        Environment.ExitCode = 1;
    }

    return;
}

if (run.PlayablePuzzleBatchOptions is not null)
{
    SavePlayablePuzzleBatch(run.PlayablePuzzleBatchOptions);
    return;
}

if (run.PuzzleLevelOptions is not null
    && run.PuzzleLevelOptions.GenerationStrategy == PuzzleGenerationStrategy.ShapeFirstExact
    && (run.PuzzleLevelOptions.StartLevel > 0 || run.PuzzleLevelOptions.EndLevel > 0))
{
    if (run.PuzzleLevelOptions.ProgressStride > 0)
    {
        run.PuzzleLevelOptions.ProgressLogger = Console.WriteLine;
    }

    var outputDirectory = run.SaveDirectory ?? Path.Combine("sim", "generated", "playable-19-200-v2");
    var failures = SaveShapeFirstExactPuzzleBatch(run.PuzzleLevelOptions, outputDirectory);
    if (failures > 0)
    {
        Environment.ExitCode = 1;
    }

    return;
}

GeneratedScenario? generated = null;
GeneratedPuzzleLevel? puzzleLevel = null;
FixtureLoadResult loaded;
if (run.PuzzleLevelOptions is not null)
{
    if (run.PuzzleLevelOptions.ProgressStride > 0)
    {
        run.PuzzleLevelOptions.ProgressLogger = Console.WriteLine;
    }

    puzzleLevel = PuzzleLevelGenerator.Generate(run.PuzzleLevelOptions);
    loaded = puzzleLevel.StartingLoaded;
}
else if (run.GenerateOptions is not null)
{
    generated = RandomScenarioGenerator.Generate(run.GenerateOptions);
    loaded = generated.Loaded;
}
else
{
    loaded = FixtureLoader.LoadFromFile(run.FixturePath);
}

var engine = new CellularEngine(loaded.World, loaded.Options);

if (generated is not null && run.SaveDirectory is not null)
{
    SaveGeneratedScenario(generated, null, run.SaveDirectory);
}
else if (puzzleLevel is not null && run.SaveDirectory is not null)
{
    SavePuzzleLevel(puzzleLevel, run.SaveDirectory);
}

if (run.Debug)
{
    RunDebug(loaded, engine, run);
}
else if (puzzleLevel is not null)
{
    RunPuzzleLevelExample(puzzleLevel);
}
else if (generated is not null)
{
    RunGeneratedExample(generated, engine, run);
}
else
{
    RunExample(loaded, engine, run);
}

static RunOptions ParseRun(string[] args)
{
    var debug = false;
    var verbose = false;
    var fixturePath = "";
    var ticks = 3;
    var ticksSpecified = false;
    string? commands = null;
    string? saveDirectory = null;
    RandomScenarioOptions? generateOptions = null;
    PuzzleLevelOptions? puzzleLevelOptions = null;
    PlayablePuzzleBatchOptions? playablePuzzleBatchOptions = null;
    PuzzleSolutionSearchOptions? puzzleSolutionSearchOptions = null;

    for (var i = 0; i < args.Length; i++)
    {
        var arg = args[i];
        if (arg == "--solve-puzzle-levels")
        {
            puzzleSolutionSearchOptions ??= new PuzzleSolutionSearchOptions();
            continue;
        }

        if (arg == "--generate-playable-puzzle-levels")
        {
            playablePuzzleBatchOptions ??= new PlayablePuzzleBatchOptions();
            continue;
        }

        if (arg == "--generate-puzzle-level")
        {
            puzzleLevelOptions ??= new PuzzleLevelOptions();
            continue;
        }

        if (arg == "--generate")
        {
            generateOptions ??= new RandomScenarioOptions();
            continue;
        }

        if (arg == "--debug")
        {
            debug = true;
            continue;
        }

        if (arg == "--verbose" || arg == "-v")
        {
            verbose = true;
            continue;
        }

        if (arg == "--commands" && i + 1 < args.Length)
        {
            commands = args[++i];
            continue;
        }

        if (arg == "--ticks" && i + 1 < args.Length && int.TryParse(args[++i], out var parsedTicks))
        {
            ticks = parsedTicks;
            ticksSpecified = true;
            continue;
        }

        if (arg == "--save-dir" && i + 1 < args.Length)
        {
            saveDirectory = args[++i];
            continue;
        }

        if (TryParsePlayablePuzzleBatchOption(args, ref i, arg, ref playablePuzzleBatchOptions))
        {
            continue;
        }

        if (TryParsePuzzleSolutionSearchOption(args, ref i, arg, ref puzzleSolutionSearchOptions))
        {
            continue;
        }

        if (TryParseGeneratedOption(args, ref i, arg, ref generateOptions))
        {
            continue;
        }

        if (TryParsePuzzleLevelOption(args, ref i, arg, ref puzzleLevelOptions))
        {
            continue;
        }

        if (fixturePath.Length == 0)
        {
            fixturePath = arg;
        }
        else if (int.TryParse(arg, out var positionalTicks))
        {
            ticks = positionalTicks;
        }
    }

    if (puzzleSolutionSearchOptions is not null
        && (playablePuzzleBatchOptions is not null || generateOptions is not null || puzzleLevelOptions is not null))
    {
        throw new ArgumentException("Use --solve-puzzle-levels by itself.");
    }

    if (playablePuzzleBatchOptions is not null && (generateOptions is not null || puzzleLevelOptions is not null))
    {
        throw new ArgumentException("Use --generate-playable-puzzle-levels by itself.");
    }

    if (generateOptions is not null && puzzleLevelOptions is not null)
    {
        throw new ArgumentException("Use either --generate or --generate-puzzle-level, not both.");
    }

    if (puzzleSolutionSearchOptions is not null)
    {
        if (saveDirectory is not null)
        {
            puzzleSolutionSearchOptions.OutputDirectory = saveDirectory;
        }

        return new RunOptions("", ticks, debug, verbose, commands, null, null, null, puzzleSolutionSearchOptions, saveDirectory);
    }

    if (playablePuzzleBatchOptions is not null)
    {
        if (saveDirectory is not null)
        {
            playablePuzzleBatchOptions.GeneratedRoot = saveDirectory;
        }

        return new RunOptions("", ticks, debug, verbose, commands, null, null, playablePuzzleBatchOptions, null, saveDirectory);
    }

    if (generateOptions is not null)
    {
        if (!ticksSpecified)
        {
            ticks = 100;
        }

        return new RunOptions("", ticks, debug, verbose, commands, generateOptions, puzzleLevelOptions, null, null, saveDirectory);
    }

    if (puzzleLevelOptions is not null)
    {
        if (!ticksSpecified)
        {
            ticks = puzzleLevelOptions.TicksPerCandidate;
        }

        return new RunOptions("", ticks, debug, verbose, commands, null, puzzleLevelOptions, null, null, saveDirectory);
    }

    if (fixturePath.Length == 0)
    {
        fixturePath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../fixtures/routing.json"));
    }

    return new RunOptions(fixturePath, ticks, debug, verbose, commands, null, null, null, null, saveDirectory);
}

static bool TryParsePlayablePuzzleBatchOption(string[] args, ref int index, string arg, ref PlayablePuzzleBatchOptions? options)
{
    static int ParseInt(string value, string name)
    {
        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var result))
        {
            return result;
        }

        throw new ArgumentException($"Invalid integer for {name}: {value}");
    }

    if (arg == "--overwrite")
    {
        if (options is null)
        {
            return false;
        }

        options.SkipExisting = false;
        return true;
    }

    if (arg is not ("--from-level" or "--to-level" or "--level-seed-base" or "--source-rate" or "--ship-dir"))
    {
        return false;
    }

    if (options is null)
    {
        return false;
    }

    if (index + 1 >= args.Length)
    {
        throw new ArgumentException($"{arg} requires a value.");
    }

    var value = args[++index];
    switch (arg)
    {
        case "--from-level":
            options.StartLevel = ParseInt(value, arg);
            break;
        case "--to-level":
            options.EndLevel = ParseInt(value, arg);
            break;
        case "--level-seed-base":
            options.GenerationSeedBase = ParseInt(value, arg);
            break;
        case "--source-rate":
            options.SourceQuantityPerTick = ParseInt(value, arg);
            break;
        case "--ship-dir":
            options.ShipDirectory = value;
            break;
    }

    return true;
}

static bool TryParsePuzzleSolutionSearchOption(string[] args, ref int index, string arg, ref PuzzleSolutionSearchOptions? options)
{
    static int ParseInt(string value, string name)
    {
        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var result))
        {
            return result;
        }

        throw new ArgumentException($"Invalid integer for {name}: {value}");
    }

    if (arg == "--stop-on-failure")
    {
        if (options is null)
        {
            return false;
        }

        options.StopOnFailure = true;
        return true;
    }

    if (arg is not ("--from-level" or "--to-level" or "--levels-dir" or "--solution-ticks" or "--candidate-limit" or "--beam-size" or "--source-rate" or "--event-capacity" or "--progress-stride"))
    {
        return false;
    }

    if (options is null)
    {
        return false;
    }

    if (index + 1 >= args.Length)
    {
        throw new ArgumentException($"{arg} requires a value.");
    }

    var value = args[++index];
    switch (arg)
    {
        case "--from-level":
            options.StartLevel = ParseInt(value, arg);
            break;
        case "--to-level":
            options.EndLevel = ParseInt(value, arg);
            break;
        case "--levels-dir":
            options.LevelsDirectory = value;
            break;
        case "--solution-ticks":
            options.TicksPerCandidate = ParseInt(value, arg);
            break;
        case "--candidate-limit":
            options.CandidateLimit = ParseInt(value, arg);
            break;
        case "--beam-size":
            options.BeamSize = ParseInt(value, arg);
            break;
        case "--source-rate":
            options.SourceQuantityPerTick = ParseInt(value, arg);
            break;
        case "--event-capacity":
            options.EventCapacity = ParseInt(value, arg);
            break;
        case "--progress-stride":
            options.ProgressStride = ParseInt(value, arg);
            break;
    }

    return true;
}

static bool TryParseGeneratedOption(string[] args, ref int index, string arg, ref RandomScenarioOptions? options)
{
    static int ParseInt(string value, string name)
    {
        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var result))
        {
            return result;
        }

        throw new ArgumentException($"Invalid integer for {name}: {value}");
    }

    if (arg is not ("--seed" or "--size" or "--width" or "--height" or "--cells" or "--resources" or "--rocks" or "--min-needs" or "--max-needs" or "--source-rate" or "--source-interval" or "--event-capacity"))
    {
        return false;
    }

    if (options is null)
    {
        return false;
    }

    if (index + 1 >= args.Length)
    {
        throw new ArgumentException($"{arg} requires a value.");
    }

    var value = ParseInt(args[++index], arg);
    switch (arg)
    {
        case "--seed":
            options.Seed = value;
            break;
        case "--size":
            options.Width = value;
            options.Height = value;
            break;
        case "--width":
            options.Width = value;
            break;
        case "--height":
            options.Height = value;
            break;
        case "--cells":
            options.CellCount = value;
            break;
        case "--resources":
            options.ResourceCount = value;
            break;
        case "--rocks":
            options.RockCount = value;
            break;
        case "--min-needs":
            options.MinNeeds = value;
            break;
        case "--max-needs":
            options.MaxNeeds = value;
            break;
        case "--source-rate":
            options.SourceQuantityPerTick = value;
            break;
        case "--source-interval":
            options.SourceIntervalTicks = value;
            break;
        case "--event-capacity":
            options.EventCapacity = value;
            break;
    }

    return true;
}

static bool TryParsePuzzleLevelOption(string[] args, ref int index, string arg, ref PuzzleLevelOptions? options)
{
    static int ParseInt(string value, string name)
    {
        if (int.TryParse(value, NumberStyles.Integer, CultureInfo.InvariantCulture, out var result))
        {
            return result;
        }

        throw new ArgumentException($"Invalid integer for {name}: {value}");
    }

    if (arg == "--allow-near-win")
    {
        if (options is null)
        {
            return false;
        }

        options.AllowNearWin = true;
        return true;
    }

    if (arg == "--generation-strategy")
    {
        if (options is null)
        {
            return false;
        }

        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"{arg} requires a value.");
        }

        var strategy = args[++index];
        options.GenerationStrategy = strategy switch
        {
            "search" => PuzzleGenerationStrategy.Search,
            "shape-first-exact" => PuzzleGenerationStrategy.ShapeFirstExact,
            _ => throw new ArgumentException($"Invalid puzzle generation strategy: {strategy}")
        };
        return true;
    }

    if (arg == "--ship-dir")
    {
        if (options is null)
        {
            return false;
        }

        if (index + 1 >= args.Length)
        {
            throw new ArgumentException($"{arg} requires a value.");
        }

        options.ShipDirectory = args[++index];
        return true;
    }

    if (arg is not ("--level" or "--from-level" or "--to-level" or "--level-seed" or "--level-seed-base" or "--need-attempts" or "--layout-candidates" or "--solution-ticks" or "--source-rate" or "--source-interval" or "--event-capacity" or "--win-recent-flow-window-ticks" or "--win-duration-ticks" or "--required-alive-ticks-at-end" or "--shape-first-sustained-ticks" or "--max-swap-quantity-per-edge" or "--progress-stride"))
    {
        return false;
    }

    if (options is null)
    {
        return false;
    }

    if (index + 1 >= args.Length)
    {
        throw new ArgumentException($"{arg} requires a value.");
    }

    var value = ParseInt(args[++index], arg);
    switch (arg)
    {
        case "--level":
            options.LevelNumber = value;
            break;
        case "--from-level":
            options.StartLevel = value;
            break;
        case "--to-level":
            options.EndLevel = value;
            break;
        case "--level-seed":
            options.GenerationSeed = value;
            break;
        case "--level-seed-base":
            options.GenerationSeedBase = value;
            break;
        case "--need-attempts":
            options.NeedAttemptLimit = value;
            break;
        case "--layout-candidates":
            options.LayoutCandidateLimit = value;
            break;
        case "--solution-ticks":
            options.TicksPerCandidate = value;
            break;
        case "--source-rate":
            options.SourceQuantityPerTick = value;
            break;
        case "--source-interval":
            options.SourceIntervalTicks = value;
            break;
        case "--event-capacity":
            options.EventCapacity = value;
            break;
        case "--win-recent-flow-window-ticks":
            options.WinRecentFlowWindowTicks = value;
            break;
        case "--win-duration-ticks":
            options.WinDurationTicks = value;
            break;
        case "--required-alive-ticks-at-end":
            options.RequiredAliveTicksAtEnd = value;
            break;
        case "--shape-first-sustained-ticks":
            options.ShapeFirstSustainedTicks = value;
            break;
        case "--max-swap-quantity-per-edge":
            options.MaxSwapQuantityPerEdge = value;
            break;
        case "--progress-stride":
            options.ProgressStride = value;
            break;
    }

    return true;
}

static void RunExample(FixtureLoadResult loaded, CellularEngine engine, RunOptions run)
{
    Console.WriteLine("Cellular three-pool example");
    Console.WriteLine($"Fixture: {run.FixturePath}");
    Console.WriteLine();

    PrintSetup(loaded);
    PrintState("Initial state", loaded, engine);

    for (var i = 0; i < run.Ticks; i++)
    {
        engine.Tick();
        PrintTick(loaded, engine);
    }
}

static void RunGeneratedExample(GeneratedScenario generated, CellularEngine engine, RunOptions run)
{
    Console.WriteLine("Cellular generated scenario");
    PrintGeneratedHeader(generated.Options);
    Console.WriteLine();
    Console.Write(RenderMapText(generated.Loaded, compact: true));
    Console.WriteLine();

    var summary = SimulationSummaryRunner.Run(engine, run.Ticks);
    Console.Write(RenderSummaryText(summary));

    if (run.SaveDirectory is not null)
    {
        SaveGeneratedScenario(generated, summary, run.SaveDirectory);
        Console.WriteLine($"Saved generated scenario outputs to: {run.SaveDirectory}");
    }
}

static void RunPuzzleLevelExample(GeneratedPuzzleLevel level)
{
    Console.WriteLine("Cellular puzzle level");
    Console.WriteLine($"  level: {level.Definition.LevelNumber}");
    Console.WriteLine($"  seed: {level.Definition.GenerationSeed}");
    Console.WriteLine($"  mode: {level.Definition.Mode}");
    Console.WriteLine($"  difficulty: {level.Definition.Difficulty}");
    Console.WriteLine();
    Console.WriteLine("Starting layout");
    Console.WriteLine(level.Definition.StartingLayout.Ascii);
    Console.WriteLine();
    Console.WriteLine("Best known solution layout");
    Console.WriteLine(level.Definition.SolutionLayout.Ascii);
    Console.WriteLine();
    Console.Write(RenderPuzzleSummaryText(level));
}

static void RunDebug(FixtureLoadResult loaded, CellularEngine engine, RunOptions run)
{
    Console.WriteLine("Cellular debug mode");
    Console.WriteLine(run.PuzzleLevelOptions is not null
        ? "Fixture: generated puzzle level starting layout"
        : run.GenerateOptions is null ? $"Fixture: {run.FixturePath}" : "Fixture: generated scenario");
    Console.WriteLine($"Verbose: {run.Verbose}");
    Console.WriteLine("Type `help` for commands.");
    Console.WriteLine();

    if (run.Verbose)
    {
        PrintVerboseSetup(loaded);
        PrintState("Initial state", loaded, engine);
    }

    if (!string.IsNullOrWhiteSpace(run.Commands))
    {
        foreach (var command in run.Commands.Split(new char[] { ';', ',' }, StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
        {
            Console.WriteLine($"> {command}");
            if (!RunDebugCommand(command, loaded, engine, run.Verbose))
            {
                break;
            }
        }

        return;
    }

    while (true)
    {
        Console.Write("> ");
        var command = Console.ReadLine();
        if (command is null || !RunDebugCommand(command, loaded, engine, run.Verbose))
        {
            break;
        }
    }
}

static bool RunDebugCommand(string command, FixtureLoadResult loaded, CellularEngine engine, bool verbose)
{
    var trimmed = command.Trim();
    if (trimmed.Length == 0)
    {
        return true;
    }

    var parts = trimmed.Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
    var verb = parts[0].ToLowerInvariant();

    switch (verb)
    {
        case "help":
            PrintHelp();
            return true;
        case "setup":
            if (verbose)
            {
                PrintVerboseSetup(loaded);
            }
            else
            {
                PrintSetup(loaded);
            }
            return true;
        case "map":
            PrintAsciiMap(loaded);
            return true;
        case "touching":
        case "adjacent":
            PrintTouchingPairs(loaded);
            return true;
        case "state":
            PrintState($"State at tick {engine.CurrentTick}", loaded, engine);
            return true;
        case "score":
            PrintScore(engine);
            return true;
        case "circuit":
            PrintCircuitDiagnostics(loaded, engine);
            return true;
        case "cell":
            if (parts.Length < 2)
            {
                Console.WriteLine("Usage: cell <cell-id>");
                return true;
            }

            PrintCell(loaded, parts[1]);
            return true;
        case "events":
            PrintEvents(loaded, engine, parts.Length > 1 ? parts[1] : "current");
            return true;
        case "tick":
        case "step":
            var count = 1;
            if (parts.Length > 1 && (!int.TryParse(parts[1], out count) || count < 1))
            {
                Console.WriteLine("Usage: tick [positive-count]");
                return true;
            }

            for (var i = 0; i < count; i++)
            {
                engine.Tick();
                PrintTick(loaded, engine, verbose);
            }

            return true;
        case "trace":
            var traceTicks = 100;
            var stride = 10;
            if (parts.Length > 1 && (!int.TryParse(parts[1], out traceTicks) || traceTicks < 1))
            {
                Console.WriteLine("Usage: trace [positive-count] [positive-stride]");
                return true;
            }

            if (parts.Length > 2 && (!int.TryParse(parts[2], out stride) || stride < 1))
            {
                Console.WriteLine("Usage: trace [positive-count] [positive-stride]");
                return true;
            }

            TraceCircuit(loaded, engine, traceTicks, stride);
            return true;
        case "quit":
        case "exit":
            return false;
        default:
            Console.WriteLine($"Unknown command `{parts[0]}`. Type `help`.");
            return true;
    }
}

static void PrintHelp()
{
    Console.WriteLine("Commands:");
    Console.WriteLine("  setup           Show cells, produced resources, accepted needs, and reaction sets.");
    Console.WriteLine("  map             Show ASCII map.");
    Console.WriteLine("  touching        Show orthogonally touching cell pairs that can attempt swaps.");
    Console.WriteLine("  state           Show all current pool balances, glow state, strain, score, and circuit state.");
    Console.WriteLine("  cell <id>       Inspect one cell.");
    Console.WriteLine("  tick [n]        Advance one or more ticks and print outputs.");
    Console.WriteLine("  events          Show non-flow events for the current tick.");
    Console.WriteLine("  events all      Show all non-flow events in the bounded event buffer.");
    Console.WriteLine("  score           Show score and circuit state.");
    Console.WriteLine("  circuit         Show directed circuit diagnostics.");
    Console.WriteLine("  trace [n] [s]   Run n ticks silently and print circuit diagnostics every s ticks.");
    Console.WriteLine("  quit            Exit debug mode.");
    Console.WriteLine();
}

static void PrintVerboseSetup(FixtureLoadResult loaded)
{
    PrintSetup(loaded);
    PrintAsciiMap(loaded);
    PrintTouchingPairs(loaded);
}

static void PrintSetup(FixtureLoadResult loaded)
{
    Console.WriteLine("Human-readable setup");
    foreach (var cell in loaded.World.Cells)
    {
        var produced = NamesFor(cell, loaded, PoolSlotRole.SourceOutput);
        var needed = NamesFor(cell, loaded, PoolSlotRole.Need);
        var routed = NamesFor(cell, loaded, PoolSlotRole.AcceptOnly);
        var reactionSet = ReactionSetFor(cell, loaded);

        Console.WriteLine($"  {cell.Id}");
        Console.WriteLine($"    produces/offers: {produced}");
        Console.WriteLine($"    accepts/needs from neighbors: {needed}");
        Console.WriteLine($"    routing-only resources: {routed}");
        Console.WriteLine($"    glows after holding at least 1 of: {reactionSet}");
    }

    Console.WriteLine();
}

static void PrintState(string title, FixtureLoadResult loaded, CellularEngine engine)
{
    Console.WriteLine(title);
    foreach (var cell in loaded.World.Cells)
    {
        Console.WriteLine($"  {DescribeCellInventory(loaded, cell)}");
    }

    PrintScore(engine);
    Console.WriteLine();
}

static void PrintTick(FixtureLoadResult loaded, CellularEngine engine, bool verbose = false)
{
    Console.WriteLine($"Tick {engine.CurrentTick}");
    if (verbose)
    {
        PrintAsciiMap(loaded);
    }

    Console.WriteLine("  What happened:");
    var found = false;
    foreach (var simEvent in engine.Events.Where(simEvent => simEvent.Tick == engine.CurrentTick && simEvent is not FlowEvent))
    {
        found = true;
        Console.WriteLine($"    - {DescribeEvent(loaded, simEvent)}");
    }

    if (!found)
    {
        Console.WriteLine("    - no swaps, reactions, strain, overflow, or win changes");
    }

    Console.WriteLine("  Pool state after settlement:");
    foreach (var cell in loaded.World.Cells)
    {
        Console.WriteLine($"    - {DescribeCellInventory(loaded, cell)}");
    }

    PrintScore(engine);
    if (verbose)
    {
        Console.WriteLine("  Touching pairs:");
        PrintTouchingPairs(loaded, indent: "    ");
    }

    Console.WriteLine();
}

static void PrintAsciiMap(FixtureLoadResult loaded)
{
    Console.Write(RenderMapText(loaded, compact: true));
}

static string RenderMapText(FixtureLoadResult loaded, bool compact)
{
    var builder = new StringBuilder();
    var labels = BuildMapLabels(loaded);
    builder.AppendLine("ASCII map");
    builder.AppendLine("  Legend:");
    if (compact)
    {
        AppendProducedResourceLegend(builder, loaded);
    }
    else
    {
        foreach (var cell in loaded.World.Cells)
        {
            builder.AppendLine($"    {labels[cell.Id]} = {cell.Id}");
        }
    }

    builder.AppendLine("    # = rock");
    builder.AppendLine("    . = empty");
    builder.AppendLine();

    for (var y = 0; y < loaded.World.Height; y++)
    {
        builder.Append("  ");
        for (var x = 0; x < loaded.World.Width; x++)
        {
            var pos = new GridPosition(x, y);
            if (loaded.World.TryGetCellAt(pos, out var cell) && cell is not null)
            {
                builder.Append(compact ? ProducedResourceSymbol(loaded, cell) : labels[cell.Id]);
            }
            else if (loaded.World.HasRockAt(pos))
            {
                builder.Append('#');
            }
            else
            {
                builder.Append('.');
            }
        }

        builder.AppendLine();
    }

    builder.AppendLine();
    return builder.ToString();
}

static void AppendProducedResourceLegend(StringBuilder builder, FixtureLoadResult loaded)
{
    var seen = new HashSet<char>();
    foreach (var cell in loaded.World.Cells)
    {
        var symbol = ProducedResourceSymbol(loaded, cell);
        if (seen.Add(symbol))
        {
            var sourceName = SourceOutputName(loaded, cell);
            builder.AppendLine(sourceName.Length == 0
                ? $"    {symbol} = myco cell with no source"
                : $"    {symbol} = cell producing {sourceName}");
        }
    }
}

static char ProducedResourceSymbol(FixtureLoadResult loaded, CellState cell)
{
    var name = SourceOutputName(loaded, cell);
    if (name.Length == 0)
    {
        return '0';
    }

    var symbol = name[0];
    return symbol is '.' or '#' ? '?' : symbol;
}

static string SourceOutputName(FixtureLoadResult loaded, CellState cell)
{
    for (var i = 0; i < cell.Pool.Slots.Count; i++)
    {
        var slot = cell.Pool.Slots[i];
        if (slot.Role == PoolSlotRole.SourceOutput)
        {
            return loaded.Catalog.GetName(slot.Resource);
        }
    }

    return "";
}

static void PrintTouchingPairs(FixtureLoadResult loaded, string indent = "  ")
{
    Console.WriteLine($"{indent}Orthogonal touching pairs only:");
    if (loaded.World.AdjacentEdges.Count == 0)
    {
        Console.WriteLine($"{indent}  none");
        return;
    }

    foreach (var edge in loaded.World.AdjacentEdges)
    {
        var a = loaded.World.Cells[edge.A];
        var b = loaded.World.Cells[edge.B];
        Console.WriteLine($"{indent}  {a.Id} <-> {b.Id} ({DescribeCompatibility(loaded, a, b)})");
    }

    Console.WriteLine();
}

static void PrintCell(FixtureLoadResult loaded, string cellId)
{
    if (!loaded.World.TryGetCell(cellId, out var cell) || cell is null)
    {
        Console.WriteLine($"Unknown cell `{cellId}`.");
        return;
    }

    Console.WriteLine(cell.Id);
    Console.WriteLine($"  position: ({cell.Position.X},{cell.Position.Y})");
    Console.WriteLine($"  produces/offers: {NamesFor(cell, loaded, PoolSlotRole.SourceOutput)}");
    Console.WriteLine($"  accepts/needs: {NamesFor(cell, loaded, PoolSlotRole.Need)}");
    Console.WriteLine($"  routing-only: {NamesFor(cell, loaded, PoolSlotRole.AcceptOnly)}");
    Console.WriteLine($"  reaction set: {ReactionSetFor(cell, loaded)}");
    Console.WriteLine($"  balances: {DescribeSlots(loaded, cell)}");
    Console.WriteLine($"  glowing: {cell.IsGlowing} ({cell.GlowTicksRemaining} ticks remaining)");
    Console.WriteLine($"  strain: unmetNeed={cell.Strain.UnmetNeedTicks}, failedSwap={cell.Strain.FailedSwapCount}, sourceBlocked={cell.Strain.SourceBlockedTicks}, overCapacity={cell.Strain.OverCapacityPressureTicks}");
    Console.WriteLine();
}

static void PrintEvents(FixtureLoadResult loaded, CellularEngine engine, string scope)
{
    var all = scope.Equals("all", StringComparison.OrdinalIgnoreCase);
    var found = false;
    foreach (var simEvent in engine.Events)
    {
        if (simEvent is FlowEvent)
        {
            continue;
        }

        if (!all && simEvent.Tick != engine.CurrentTick)
        {
            continue;
        }

        found = true;
        Console.WriteLine($"  tick {simEvent.Tick}: {DescribeEvent(loaded, simEvent)}");
    }

    if (!found)
    {
        Console.WriteLine(all ? "  no non-flow events in buffer" : $"  no non-flow events at tick {engine.CurrentTick}");
    }

    Console.WriteLine();
}

static void PrintScore(CellularEngine engine)
{
    Console.WriteLine($"  score: total={engine.Score.TotalScore}, reactions={engine.Score.ReactionScore}, flowDiversity={engine.Score.FlowDiversityScore}, settlement={engine.Score.SettlementScore}, strainPenalty={engine.Score.StrainPenalty}");
    Console.WriteLine($"  circuit: alive={engine.Circuit.IsAliveThisTick}, sustainedTicks={engine.Circuit.SustainedTicks}, won={engine.Circuit.IsWon}");
}

static void TraceCircuit(FixtureLoadResult loaded, CellularEngine engine, int ticks, int stride)
{
    Console.WriteLine($"Circuit trace: ticks={ticks}, stride={stride}");
    var previousAlive = engine.Circuit.IsAliveThisTick;
    for (var i = 0; i < ticks; i++)
    {
        engine.Tick();
        var shouldPrint = engine.CurrentTick % stride == 0
            || i + 1 == ticks
            || engine.Circuit.IsAliveThisTick != previousAlive;
        if (shouldPrint)
        {
            PrintCircuitDiagnostics(loaded, engine, singleLine: true);
        }

        previousAlive = engine.Circuit.IsAliveThisTick;
    }

    PrintState($"State at tick {engine.CurrentTick}", loaded, engine);
}

static void PrintCircuitDiagnostics(
    FixtureLoadResult loaded,
    CellularEngine engine,
    bool singleLine = false)
{
    var diagnostics = CircuitDiagnostics.Build(engine);
    var strongGroups = FormatGroups(diagnostics.StrongGroups);
    var weakGroups = FormatGroups(diagnostics.WeakGroups);
    var missingResources = FormatResources(loaded, diagnostics.MissingRequiredResources);
    var nonGlowing = diagnostics.NonGlowingRequiredCells.Count == 0
        ? "none"
        : string.Join(",", diagnostics.NonGlowingRequiredCells);
    var blockers = FormatReactionBlockers(loaded, engine, diagnostics.NonGlowingRequiredCells);

    if (singleLine)
    {
        Console.WriteLine(
            $"  tick={engine.CurrentTick} alive={diagnostics.IsAlive} sustained={diagnostics.SustainedTicks} won={diagnostics.IsWon} "
            + $"strong={strongGroups} weak={weakGroups} missingResources={missingResources} nonGlowing={nonGlowing} blockers={blockers}");
        return;
    }

    Console.WriteLine("Directed circuit diagnostics");
    Console.WriteLine($"  tick: {engine.CurrentTick}");
    Console.WriteLine($"  alive: {diagnostics.IsAlive}");
    Console.WriteLine($"  sustained ticks: {diagnostics.SustainedTicks}");
    Console.WriteLine($"  won: {diagnostics.IsWon}");
    Console.WriteLine($"  recent-flow window starts at tick: {diagnostics.SinceTick}");
    Console.WriteLine($"  strong groups: {strongGroups}");
    Console.WriteLine($"  weak groups: {weakGroups}");
    Console.WriteLine($"  missing resources in recent flow: {missingResources}");
    Console.WriteLine($"  non-glowing required cells: {nonGlowing}");
    Console.WriteLine($"  current reaction blockers: {blockers}");
    Console.WriteLine("  directed edges:");
    if (diagnostics.DirectedEdges.Count == 0)
    {
        Console.WriteLine("    none");
    }
    else
    {
        foreach (var edge in diagnostics.DirectedEdges)
        {
            Console.WriteLine(
                $"    {edge.SourceCellId} -> {edge.TargetCellId}: "
                + $"{FormatResources(loaded, edge.Resources)} x{edge.Quantity}, latest tick {edge.LatestTick}");
        }
    }

    Console.WriteLine();
}

static string FormatGroups(IReadOnlyList<CircuitDiagnosticGroup> groups)
{
    if (groups.Count == 0)
    {
        return "none";
    }

    return string.Join(" | ", groups.Select(group => $"[{string.Join(",", group.CellIds)}]"));
}

static string FormatResources(FixtureLoadResult loaded, IReadOnlyList<ResourceId> resources)
{
    if (resources.Count == 0)
    {
        return "none";
    }

    return string.Join(",", resources.Select(loaded.Catalog.GetName));
}

static string FormatReactionBlockers(
    FixtureLoadResult loaded,
    CellularEngine engine,
    IReadOnlyList<string> cellIds)
{
    if (cellIds.Count == 0)
    {
        return "none";
    }

    var parts = new List<string>(cellIds.Count);
    foreach (var cellId in cellIds)
    {
        if (!engine.World.TryGetCell(cellId, out var cell) || cell is null)
        {
            parts.Add($"{cellId}:missing-cell");
            continue;
        }

        var missing = cell.Pool.Slots
            .Where(slot => slot.Role != PoolSlotRole.AcceptOnly && slot.Quantity <= 0)
            .Select(slot => loaded.Catalog.GetName(slot.Resource))
            .ToArray();
        parts.Add(missing.Length == 0 ? $"{cellId}:no-current-missing" : $"{cellId}:{string.Join("+", missing)}");
    }

    return string.Join(";", parts);
}

static void PrintGeneratedHeader(RandomScenarioOptions options)
{
    Console.WriteLine($"  seed: {options.Seed}");
    Console.WriteLine($"  map: {options.Width}x{options.Height}");
    Console.WriteLine($"  cells: {options.CellCount}");
    Console.WriteLine($"  rocks: {options.RockCount}");
    Console.WriteLine($"  resources: {options.ResourceCount}");
    Console.WriteLine(options.MinNeeds == options.MaxNeeds
        ? $"  needs per cell: {options.MinNeeds}"
        : $"  needs per cell: {options.MinNeeds}..{options.MaxNeeds}");
    Console.WriteLine($"  source rate: {options.SourceQuantityPerTick} every {options.SourceIntervalTicks} tick(s)");
}

static string RenderGeneratedSetupText(GeneratedScenario generated)
{
    var builder = new StringBuilder();
    builder.AppendLine("CELLULAR GENERATED SCENARIO");
    builder.AppendLine();
    builder.AppendLine("setup:");
    builder.AppendLine($"  seed: {generated.Options.Seed}");
    builder.AppendLine($"  map: {generated.Options.Width}x{generated.Options.Height}");
    builder.AppendLine($"  cells: {generated.Options.CellCount}");
    builder.AppendLine($"  rocks: {generated.Options.RockCount}");
    builder.AppendLine($"  resources: {generated.Options.ResourceCount}");
    builder.AppendLine(generated.Options.MinNeeds == generated.Options.MaxNeeds
        ? $"  needs per cell: {generated.Options.MinNeeds}"
        : $"  needs per cell: {generated.Options.MinNeeds}..{generated.Options.MaxNeeds}");
    builder.AppendLine($"  source rate: {generated.Options.SourceQuantityPerTick} every {generated.Options.SourceIntervalTicks} tick(s)");
    builder.AppendLine();
    builder.Append(RenderMapText(generated.Loaded, compact: true));
    builder.AppendLine("cells:");
    foreach (var cell in generated.Loaded.World.Cells)
    {
        builder.AppendLine($"  {cell.Id} @ ({cell.Position.X},{cell.Position.Y}): produces {NamesFor(cell, generated.Loaded, PoolSlotRole.SourceOutput)}; needs {NamesFor(cell, generated.Loaded, PoolSlotRole.Need)}");
    }

    return builder.ToString();
}

static string RenderSummaryText(SimulationSummary summary)
{
    var builder = new StringBuilder();
    builder.AppendLine("Simulation summary");
    builder.AppendLine($"  ticks: {summary.Ticks}");
    builder.AppendLine($"  cells: {summary.Cells}");
    builder.AppendLine($"  rocks: {summary.Rocks}");
    builder.AppendLine($"  touching pairs: {summary.AdjacentPairs}");
    builder.AppendLine($"  swaps: {summary.TotalSwaps} total, {summary.AverageSwapsPerTick:F2}/tick average");
    builder.AppendLine($"  reactions: {summary.TotalReactions} total, {summary.AverageReactionsPerTick:F2}/tick average");
    builder.AppendLine($"  last window: {summary.LastWindowTicks} ticks, {summary.LastWindowSwaps} swaps, {summary.LastWindowReactions} reactions");
    builder.AppendLine($"  active cells in last window: {summary.ActiveCellsInLastWindow}");
    builder.AppendLine($"  glowing cells at end: {summary.GlowingCells}");
    builder.AppendLine($"  cells with strain at end: {summary.CellsWithStrain}");
    builder.AppendLine($"  strain events: {summary.TotalStrainEvents}");
    builder.AppendLine($"  overflow events: {summary.TotalOverflows}");
    builder.AppendLine("  score breakdown:");
    builder.AppendLine($"    reactions: +{summary.ReactionScore}");
    builder.AppendLine($"    flow diversity: +{summary.FlowDiversityScore}");
    builder.AppendLine($"    settlement: +{summary.SettlementScore}");
    builder.AppendLine($"    strain penalty: -{summary.StrainPenalty}");
    builder.AppendLine($"    hoarding penalty: -{summary.HoardingPenalty}");
    builder.AppendLine($"    dead-loop penalty: -{summary.DeadLoopPenalty}");
    builder.AppendLine($"    total: {summary.FinalScore}");
    builder.AppendLine($"  stable signal: {summary.StableSignal}");
    builder.AppendLine();
    return builder.ToString();
}

static string RenderPuzzleSummaryText(GeneratedPuzzleLevel level)
{
    var summary = level.SolverSummary;
    var builder = new StringBuilder();
    builder.AppendLine("Puzzle solver summary");
    builder.AppendLine($"  playable only: {level.Options.PlayableOnly}");
    builder.AppendLine($"  won: {summary.Won}");
    builder.AppendLine($"  accepted near win: {summary.AcceptedNearWin}");
    builder.AppendLine($"  need attempt: {summary.NeedAttempt}");
    builder.AppendLine($"  candidate index: {summary.CandidateIndex}");
    builder.AppendLine($"  candidates evaluated in winning attempt: {summary.CandidateCount}");
    builder.AppendLine($"  ticks per candidate: {summary.TicksPerCandidate}");
    builder.AppendLine($"  win duration ticks: {summary.WinDurationTicks}");
    builder.AppendLine($"  required alive ticks at end: {summary.RequiredAliveTicksAtEnd}");
    builder.AppendLine($"  final sustained ticks: {summary.FinalSustainedTicks}");
    builder.AppendLine($"  stable at end: {summary.StableAtEnd}");
    builder.AppendLine($"  repair edits: {level.RepairEditCount}");
    builder.AppendLine($"  producer edits: {level.ProducerEditCount}");
    builder.AppendLine($"  glowing cells: {summary.GlowingCells}/{level.Definition.Cells.Count}");
    builder.AppendLine($"  swaps: {summary.TotalSwaps}");
    builder.AppendLine($"  reactions: {summary.TotalReactions}");
    builder.AppendLine($"  active cells in last window: {summary.ActiveCellsInLastWindow}");
    builder.AppendLine($"  touching pairs: {summary.AdjacentPairs}");
    builder.AppendLine($"  strain penalty: -{summary.StrainPenalty}");
    builder.AppendLine($"  final score: {summary.FinalScore}");
    builder.AppendLine();
    builder.AppendLine("Cells");
    foreach (var cell in level.Definition.Cells)
    {
        if (cell.Kind == CellKind.RedMyco)
        {
            builder.AppendLine($"  {cell.Id}: red myco; needs {string.Join(", ", cell.Needs)}");
        }
        else
        {
            builder.AppendLine($"  {cell.Id}: produces {cell.ProducedResource}; needs {string.Join(", ", cell.Needs)}");
        }
    }

    builder.AppendLine();
    return builder.ToString();
}

static void SaveGeneratedScenario(GeneratedScenario generated, SimulationSummary? summary, string directory)
{
    Directory.CreateDirectory(directory);
    File.WriteAllText(Path.Combine(directory, "scenario.json"), generated.FixtureJson);
    File.WriteAllText(Path.Combine(directory, "map.txt"), RenderGeneratedSetupText(generated));

    if (summary is not null)
    {
        File.WriteAllText(Path.Combine(directory, "results.txt"), RenderSummaryText(summary));
    }
}

static void SavePuzzleLevel(GeneratedPuzzleLevel level, string directory)
{
    Directory.CreateDirectory(directory);
    File.WriteAllText(Path.Combine(directory, "level.json"), level.LevelJson);
    File.WriteAllText(Path.Combine(directory, "starting-fixture.json"), level.StartingFixtureJson);
    File.WriteAllText(Path.Combine(directory, "starting-map.txt"), level.Definition.StartingLayout.Ascii + Environment.NewLine);
    if (!level.Options.PlayableOnly)
    {
        File.WriteAllText(Path.Combine(directory, "solution-fixture.json"), level.SolutionFixtureJson);
        File.WriteAllText(Path.Combine(directory, "solution-map.txt"), level.Definition.SolutionLayout.Ascii + Environment.NewLine);
    }

    File.WriteAllText(Path.Combine(directory, "results.txt"), RenderPuzzleSummaryText(level));
    if (level.Options.GenerationStrategy == PuzzleGenerationStrategy.ShapeFirstExact)
    {
        File.WriteAllText(Path.Combine(directory, "construction-proof.txt"), ShapeFirstExactPuzzleLevelGenerator.RenderConstructionProof(level));
    }
}

static int SaveShapeFirstExactPuzzleBatch(PuzzleLevelOptions batch, string generatedRoot)
{
    var startLevel = batch.StartLevel > 0 ? batch.StartLevel : batch.LevelNumber;
    var endLevel = batch.EndLevel > 0 ? batch.EndLevel : startLevel;
    if (startLevel <= 0 || endLevel < startLevel)
    {
        throw new ArgumentOutOfRangeException(nameof(batch), "Level range must be positive and ordered.");
    }

    Directory.CreateDirectory(generatedRoot);
    Directory.CreateDirectory(batch.ShipDirectory);
    var summaryPath = Path.Combine(generatedRoot, "summary.csv");
    var summary = new StringBuilder();
    summary.AppendLine("level,status,static_proof,sim_win,stable_at_end,sustained_ticks,total_swaps,total_reactions,flow,repair_edits,producer_edits,failure_category,generated_dir,shipped");

    var passed = 0;
    var failed = 0;
    for (var levelNumber = startLevel; levelNumber <= endLevel; levelNumber++)
    {
        var levelName = $"level-{levelNumber:000}";
        var generatedDirectory = Path.Combine(generatedRoot, levelName);
        try
        {
            var options = new PuzzleLevelOptions
            {
                StartLevel = batch.StartLevel,
                EndLevel = batch.EndLevel,
                LevelNumber = levelNumber,
                GenerationSeed = batch.GenerationSeedBase + levelNumber,
                GenerationSeedBase = batch.GenerationSeedBase,
                GenerationStrategy = PuzzleGenerationStrategy.ShapeFirstExact,
                NeedAttemptLimit = batch.NeedAttemptLimit,
                LayoutCandidateLimit = batch.LayoutCandidateLimit,
                TicksPerCandidate = batch.TicksPerCandidate,
                AllowNearWin = batch.AllowNearWin,
                SourceQuantityPerTick = batch.SourceQuantityPerTick,
                SourceIntervalTicks = batch.SourceIntervalTicks,
                EventCapacity = batch.EventCapacity,
                GlowTtlTicks = batch.GlowTtlTicks,
                WinRecentFlowWindowTicks = batch.WinRecentFlowWindowTicks,
                SwapRoundsPerTick = batch.SwapRoundsPerTick,
                NeedDesiredQuantity = batch.NeedDesiredQuantity,
                NeedOfferReserve = batch.NeedOfferReserve,
                AllowNeedOverflowPayments = batch.AllowNeedOverflowPayments,
                MaxSwapQuantityPerEdge = batch.MaxSwapQuantityPerEdge,
                WinDurationTicks = batch.WinDurationTicks,
                RequiredAliveTicksAtEnd = batch.RequiredAliveTicksAtEnd,
                ShapeFirstSustainedTicks = batch.ShapeFirstSustainedTicks,
                ProgressStride = batch.ProgressStride,
                ShipDirectory = batch.ShipDirectory,
                ProgressLogger = batch.ProgressLogger
            };
            var level = PuzzleLevelGenerator.Generate(options);
            SavePuzzleLevel(level, generatedDirectory);

            var proof = ShapeFirstExactPuzzleLevelGenerator.BuildConstructionProof(level);
            var shipped = options.ShapeFirstSustainedTicks > 0
                ? level.SolverSummary.Won
                    && level.SolverSummary.StableAtEnd
                    && level.SolverSummary.FinalSustainedTicks >= options.ShapeFirstSustainedTicks
                : level.SolverSummary.Won;
            if (shipped)
            {
                ShipPuzzleLevel(level, batch.ShipDirectory, levelName);
                passed++;
            }
            else
            {
                failed++;
            }

            var flow = level.SolverSummary.TicksPerCandidate == 0
                ? 0
                : (double)level.SolverSummary.TotalSwaps / level.SolverSummary.TicksPerCandidate;
            summary.AppendLine(string.Join(
                ',',
                levelNumber.ToString(CultureInfo.InvariantCulture),
                Csv(shipped ? "passed" : "failed"),
                Csv(proof.StaticProofPassed ? "yes" : "no"),
                Csv(level.SolverSummary.Won ? "yes" : "no"),
                Csv(level.SolverSummary.StableAtEnd ? "yes" : "no"),
                level.SolverSummary.FinalSustainedTicks.ToString(CultureInfo.InvariantCulture),
                level.SolverSummary.TotalSwaps.ToString(CultureInfo.InvariantCulture),
                level.SolverSummary.TotalReactions.ToString(CultureInfo.InvariantCulture),
                flow.ToString("F3", CultureInfo.InvariantCulture),
                level.RepairEditCount.ToString(CultureInfo.InvariantCulture),
                level.ProducerEditCount.ToString(CultureInfo.InvariantCulture),
                Csv(proof.FailureCategory),
                Csv(generatedDirectory),
                Csv(shipped ? "yes" : "no")));
            Console.WriteLine($"{levelName}: {(shipped ? "shipped" : "failed")} static={proof.StaticProofPassed} {RenderCompactPuzzleSummary(level.SolverSummary)}");
        }
        catch (Exception ex) when (ex is InvalidOperationException or ArgumentException or InvalidFixtureException)
        {
            failed++;
            Directory.CreateDirectory(generatedDirectory);
            File.WriteAllText(Path.Combine(generatedDirectory, "results.txt"), ex.ToString());
            summary.AppendLine(string.Join(
                ',',
                levelNumber.ToString(CultureInfo.InvariantCulture),
                Csv("failed"),
                Csv("no"),
                Csv("no"),
                Csv("no"),
                "0",
                "0",
                "0",
                "0.000",
                "0",
                "0",
                Csv(ex.GetType().Name),
                Csv(generatedDirectory),
                Csv("no")));
            Console.WriteLine($"{levelName}: failed {ex.Message}");
        }

        File.WriteAllText(summaryPath, summary.ToString());
    }

    Console.WriteLine($"Shape-first exact batch complete: pass={passed} fail={failed} summary={summaryPath}");
    return failed;
}

static void ShipPuzzleLevel(GeneratedPuzzleLevel level, string shipDirectory, string levelName)
{
    Directory.CreateDirectory(shipDirectory);
    File.WriteAllText(Path.Combine(shipDirectory, $"{levelName}.json"), level.StartingFixtureJson);
    File.WriteAllText(Path.Combine(shipDirectory, $"{levelName}.txt"), level.Definition.StartingLayout.Ascii + Environment.NewLine);
    File.WriteAllText(Path.Combine(shipDirectory, $"{levelName}-solution.txt"), level.Definition.SolutionLayout.Ascii + Environment.NewLine);
    File.WriteAllText(Path.Combine(shipDirectory, $"{levelName}-solution.json"), level.SolutionFixtureJson);
    File.WriteAllText(Path.Combine(shipDirectory, $"{levelName}-definition.json"), level.LevelJson);
}

static string RenderCompactPuzzleSummary(PuzzleSolverSummary summary) =>
    $"won={summary.Won} sustained={summary.FinalSustainedTicks} stableAtEnd={summary.StableAtEnd} swaps={summary.TotalSwaps} reactions={summary.TotalReactions}";

static string Csv(string value)
{
    if (!value.Contains(',') && !value.Contains('"') && !value.Contains('\n') && !value.Contains('\r'))
    {
        return value;
    }

    return "\"" + value.Replace("\"", "\"\"") + "\"";
}

static void SavePlayablePuzzleBatch(PlayablePuzzleBatchOptions batch)
{
    if (batch.StartLevel <= 0 || batch.EndLevel < batch.StartLevel)
    {
        throw new ArgumentOutOfRangeException(nameof(batch), "Level range must be positive and ordered.");
    }

    Directory.CreateDirectory(batch.GeneratedRoot);
    Directory.CreateDirectory(batch.ShipDirectory);

    var generated = 0;
    var skipped = 0;
    for (var levelNumber = batch.StartLevel; levelNumber <= batch.EndLevel; levelNumber++)
    {
        var levelName = $"level-{levelNumber:000}";
        var shippedFixturePath = Path.Combine(batch.ShipDirectory, $"{levelName}.json");
        if (batch.SkipExisting && File.Exists(shippedFixturePath))
        {
            skipped++;
            continue;
        }

        var levelOptions = new PuzzleLevelOptions
        {
            LevelNumber = levelNumber,
            GenerationSeed = batch.GenerationSeedBase + levelNumber,
            NeedAttemptLimit = 1,
            LayoutCandidateLimit = 1,
            TicksPerCandidate = 1,
            SourceQuantityPerTick = batch.SourceQuantityPerTick,
            PlayableOnly = true
        };
        var level = PuzzleLevelGenerator.Generate(levelOptions);
        var generatedDirectory = Path.Combine(batch.GeneratedRoot, levelName);
        SavePuzzleLevel(level, generatedDirectory);
        File.WriteAllText(shippedFixturePath, level.StartingFixtureJson);
        generated++;
        var normalCells = level.Definition.Cells.Count(cell => cell.Kind == CellKind.Standard);
        var redMycoCells = level.Definition.Cells.Count(cell => cell.Kind == CellKind.RedMyco);
        Console.WriteLine(
            $"{levelName}: generated playable start cells={level.Definition.Cells.Count} "
            + $"normal={normalCells} redMyco={redMycoCells} rocks={level.Definition.StartingLayout.Rocks.Count} "
            + $"grid={level.Definition.StartingLayout.Width}x{level.Definition.StartingLayout.Height} "
            + $"sourceRate={levelOptions.SourceQuantityPerTick}");
    }

    var missing = new List<int>();
    for (var levelNumber = batch.StartLevel; levelNumber <= batch.EndLevel; levelNumber++)
    {
        if (!File.Exists(Path.Combine(batch.ShipDirectory, $"level-{levelNumber:000}.json")))
        {
            missing.Add(levelNumber);
        }
    }

    Console.WriteLine($"Generated playable levels: {generated}; skipped existing: {skipped}.");
    if (missing.Count > 0)
    {
        throw new InvalidOperationException($"Missing shipped puzzle levels after generation: {string.Join(", ", missing)}");
    }
}

static string NamesFor(CellState cell, FixtureLoadResult loaded, PoolSlotRole role)
{
    var names = cell.Pool.Slots
        .Where(slot => slot.Role == role)
        .Select(slot => loaded.Catalog.GetName(slot.Resource))
        .ToArray();
    return names.Length == 0 ? "none" : string.Join(", ", names);
}

static string ReactionSetFor(CellState cell, FixtureLoadResult loaded)
{
    var names = cell.Pool.Slots
        .Where(slot => slot.Role != PoolSlotRole.AcceptOnly)
        .Select(slot => loaded.Catalog.GetName(slot.Resource))
        .ToArray();
    return names.Length == 0 ? "none" : string.Join(" + ", names);
}

static string DescribeCellInventory(FixtureLoadResult loaded, CellState cell) =>
    $"{cell.Id}: {DescribeSlots(loaded, cell)}; glowing={cell.IsGlowing}; strain={cell.Strain.Total}";

static string DescribeSlots(FixtureLoadResult loaded, CellState cell) =>
    string.Join(", ", cell.Pool.Slots.Select(slot =>
        $"{loaded.Catalog.GetName(slot.Resource)}({slot.Role})={slot.Quantity}/{slot.Capacity}"));

static string DescribeEvent(FixtureLoadResult loaded, SimEvent simEvent) =>
    simEvent switch
    {
        SwapEvent swap =>
            $"{swap.InitiatorCellId} initiated swap: "
            + $"{swap.InitiatorPaidQuantity} {loaded.Catalog.GetName(swap.InitiatorPaidResource)} "
            + $"for {swap.CounterpartyPaidQuantity} {loaded.Catalog.GetName(swap.CounterpartyPaidResource)} "
            + $"from {swap.CounterpartyCellId}. "
            + $"Checks passed: {swap.InitiatorCellId} had {loaded.Catalog.GetName(swap.InitiatorPaidResource)}; "
            + $"{swap.CounterpartyCellId} accepted {loaded.Catalog.GetName(swap.InitiatorPaidResource)} "
            + $"and held {loaded.Catalog.GetName(swap.InitiatorPaidResource)}={swap.CounterpartyReceivedBalanceAfterSwap}/{swap.CounterpartyReceivedCapacity} after swap; "
            + $"{swap.CounterpartyCellId} had {loaded.Catalog.GetName(swap.CounterpartyPaidResource)}; "
            + $"{swap.InitiatorCellId} accepted {loaded.Catalog.GetName(swap.CounterpartyPaidResource)} "
            + $"and held {loaded.Catalog.GetName(swap.CounterpartyPaidResource)}={swap.InitiatorReceivedBalanceAfterSwap}/{swap.InitiatorReceivedCapacity} after swap",
        FlowEvent flow =>
            $"{flow.SourceCellId} flow visual: {loaded.Catalog.GetName(flow.Resource)} x{flow.Quantity} to {flow.TargetCellId} ({flow.Kind})",
        ReactionEvent reaction =>
            $"{reaction.CellId} completed its resource set and consumed 1 of each active resource",
        StrainEvent strain =>
            $"{strain.CellId} strain: {strain.Reason}",
        OverflowEvent overflow =>
            $"{overflow.CellId} could not store produced {loaded.Catalog.GetName(overflow.Resource)} x{overflow.Quantity}",
        FailedSwapEvent failed =>
            $"{failed.SourceCellId} could not swap {loaded.Catalog.GetName(failed.Resource)} x{failed.Quantity} with {failed.TargetCellId}: {failed.Reason}",
        WinStateChangedEvent win =>
            $"win state changed to {win.IsWon}",
        _ => simEvent.ToString() ?? ""
    };

static Dictionary<string, char> BuildMapLabels(FixtureLoadResult loaded)
{
    const string symbols = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    var labels = new Dictionary<string, char>(StringComparer.Ordinal);
    for (var i = 0; i < loaded.World.Cells.Count; i++)
    {
        var symbol = i < symbols.Length ? symbols[i] : '?';
        labels[loaded.World.Cells[i].Id] = symbol;
    }

    return labels;
}

static string DescribeCompatibility(FixtureLoadResult loaded, CellState a, CellState b)
{
    var aToB = TradeableResources(loaded, a, b);
    var bToA = TradeableResources(loaded, b, a);
    return $"{a.Id} can offer [{aToB}], {b.Id} can offer [{bToA}]";
}

static string TradeableResources(FixtureLoadResult loaded, CellState source, CellState target)
{
    var names = new List<string>();
    foreach (var sourceSlot in source.Pool.Slots)
    {
        if (sourceSlot.Quantity <= 0)
        {
            continue;
        }

        var targetSlot = target.Pool.GetSlot(sourceSlot.Resource);
        if (targetSlot is null || targetSlot.Role == PoolSlotRole.SourceOutput)
        {
            continue;
        }

        names.Add(loaded.Catalog.GetName(sourceSlot.Resource));
    }

    return names.Count == 0 ? "none right now" : string.Join(", ", names);
}

internal sealed record RunOptions(
    string FixturePath,
    int Ticks,
    bool Debug,
    bool Verbose,
    string? Commands,
    RandomScenarioOptions? GenerateOptions,
    PuzzleLevelOptions? PuzzleLevelOptions,
    PlayablePuzzleBatchOptions? PlayablePuzzleBatchOptions,
    PuzzleSolutionSearchOptions? PuzzleSolutionSearchOptions,
    string? SaveDirectory);

internal sealed class PlayablePuzzleBatchOptions
{
    public int StartLevel { get; set; } = 1;
    public int EndLevel { get; set; } = 200;
    public int GenerationSeedBase { get; set; } = 1000;
    public int SourceQuantityPerTick { get; set; } = 32;
    public string GeneratedRoot { get; set; } = Path.Combine("sim", "generated");
    public string ShipDirectory { get; set; } = Path.Combine("levels", "puzzle");
    public bool SkipExisting { get; set; } = true;
}
