using System.Globalization;
using System.Text;
using CellularSim;

var run = ParseRun(args);
GeneratedScenario? generated = null;
GeneratedPuzzleLevel? puzzleLevel = null;
FixtureLoadResult loaded;
if (run.PuzzleLevelOptions is not null)
{
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

    for (var i = 0; i < args.Length; i++)
    {
        var arg = args[i];
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

    if (generateOptions is not null && puzzleLevelOptions is not null)
    {
        throw new ArgumentException("Use either --generate or --generate-puzzle-level, not both.");
    }

    if (generateOptions is not null)
    {
        if (!ticksSpecified)
        {
            ticks = 100;
        }

        return new RunOptions("", ticks, debug, verbose, commands, generateOptions, puzzleLevelOptions, saveDirectory);
    }

    if (puzzleLevelOptions is not null)
    {
        if (!ticksSpecified)
        {
            ticks = puzzleLevelOptions.TicksPerCandidate;
        }

        return new RunOptions("", ticks, debug, verbose, commands, null, puzzleLevelOptions, saveDirectory);
    }

    if (fixturePath.Length == 0)
    {
        fixturePath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, "../../../../fixtures/routing.json"));
    }

    return new RunOptions(fixturePath, ticks, debug, verbose, commands, null, null, saveDirectory);
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

    if (arg is not ("--level" or "--level-seed" or "--need-attempts" or "--layout-candidates" or "--solution-ticks" or "--source-rate" or "--source-interval" or "--event-capacity" or "--win-duration-ticks" or "--required-alive-ticks-at-end"))
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
        case "--level-seed":
            options.GenerationSeed = value;
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
        case "--win-duration-ticks":
            options.WinDurationTicks = value;
            break;
        case "--required-alive-ticks-at-end":
            options.RequiredAliveTicksAtEnd = value;
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
        builder.AppendLine($"  {cell.Id}: produces {cell.ProducedResource}; needs {string.Join(", ", cell.Needs)}");
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
    File.WriteAllText(Path.Combine(directory, "solution-fixture.json"), level.SolutionFixtureJson);
    File.WriteAllText(Path.Combine(directory, "starting-map.txt"), level.Definition.StartingLayout.Ascii + Environment.NewLine);
    File.WriteAllText(Path.Combine(directory, "solution-map.txt"), level.Definition.SolutionLayout.Ascii + Environment.NewLine);
    File.WriteAllText(Path.Combine(directory, "results.txt"), RenderPuzzleSummaryText(level));
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
    string? SaveDirectory);
