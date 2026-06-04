using Godot;
using GdArray = Godot.Collections.Array;
using GdDictionary = Godot.Collections.Dictionary;

[GlobalClass]
public partial class CellularBoardRenderer : Control
{
    private const float SwapVisualTtlTicks = 10.0f;
    private const float ReactionVisualTtlTicks = 10.0f;
    private const float PipAngleSmooth = 0.22f;
    private const float PipOffsetSmooth = 0.24f;
    private const int MaxVisibleFlowLines = 192;
    private const ulong ZeroPipPulsePeriodMsec = 3_000;
    private const ulong ZeroPipPulseFadeMsec = 1_000;
    private const float ZeroPipPulseGlowScale = 1.20f;
    private const float ZeroPipPulseBrightnessScale = 1.20f;
    private const int MycoVisualPipCount = 4;
    private const ulong MycoFadeOutMsec = 1_000;
    private const ulong MycoAdaptTransitionMsec = 2_000;
    private const string MycoWaitingSignature = "<waiting>";
    private const float InventorySlotScale = 1.28f;
    private const float InventoryCellScale = 1.10f;
    private const float InventoryCellYOffset = 0.06f;
    private const float CellStressGlowStrength = 0.20f;
    private const float CellHealthyIdleGlowStrength = 0.36f;
    private const float CellHealthyActiveGlowStrength = 0.56f;
    private const float NeedPipMarkSizeScale = 1.10f;
    private const float NeedPipMarkWeightScale = 1.10f;
    private static readonly Color CellStressGlowColor = new(1.0f, 0.78f, 0.24f, 1.0f);
    private static readonly Color CellHealthyGlowColor = new(0.30f, 1.0f, 0.84f, 1.0f);
    private static readonly Color ZeroPipPulseColor = new(1.0f, 0.0f, 0.0f, 1.0f);

    private static readonly string[] ResourceLetters =
    [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L",
        "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
        "Y", "Z"
    ];

    private static readonly string[] ResourceSymbolMarks =
    [
        "+", "*", "#", "@", "$", "%", "&", "!",
        "?", "=", "~", "^", "<", ">", "/", "\\",
        ":", ";", "|", "_", "x", "o", "[", "]",
        "{", "}"
    ];

    private static readonly Color[] ResourceColors =
    [
        new(0.18f, 0.72f, 0.78f, 1.0f),
        new(0.93f, 0.42f, 0.25f, 1.0f),
        new(0.50f, 0.78f, 0.30f, 1.0f),
        new(0.78f, 0.46f, 0.92f, 1.0f),
        new(0.95f, 0.74f, 0.24f, 1.0f),
        new(0.36f, 0.52f, 0.95f, 1.0f),
        new(0.92f, 0.30f, 0.50f, 1.0f),
        new(0.24f, 0.80f, 0.56f, 1.0f)
    ];

    private const float RedMycoRingRadius = 0.54f;
    private static readonly Color RedMycoRingEdgeColor = new(0.86f, 0.02f, 0.04f, 0.16f);
    private static readonly Color RedMycoRingMidColor = new(0.92f, 0.04f, 0.06f, 0.44f);
    private static readonly Color RedMycoRingCoreColor = new(0.70f, 0.00f, 0.02f, 0.88f);

    private const string NeedStateMissing = "missing";
    private const string NeedStateAvailable = "available";
    private const string NeedStateActive = "active";
    private const string NeedStateSatisfied = "satisfied";
    private const string CellKindStandard = "Standard";
    private const string CellKindWhiteMyco = "WhiteMyco";
    private const string CellKindRedMyco = "RedMyco";

    private readonly List<string> _cells = [];
    private readonly List<string> _inventoryCells = [];
    private readonly Dictionary<string, Vector2I> _positions = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Vector2> _overrideCellCenters = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _overrideCellScales = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Vector2> _inventoryCenters = new(StringComparer.Ordinal);
    private readonly Dictionary<string, ulong> _inventoryFreshStarts = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _producedByCell = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _cellKinds = new(StringComparer.Ordinal);
    private readonly Dictionary<string, List<string>> _needs = new(StringComparer.Ordinal);
    private readonly HashSet<Vector2I> _rocks = [];
    private readonly HashSet<string> _clearingCells = new(StringComparer.Ordinal);
    private readonly Dictionary<string, CellVisualState> _cellStates = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _pipAngles = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _pipOffsets = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _pipPartners = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _displayFullness = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _mycoPipSignatures = new(StringComparer.Ordinal);
    private readonly Dictionary<string, ulong> _mycoPipTransitionStarts = new(StringComparer.Ordinal);
    private readonly Dictionary<string, List<string>> _mycoPreviousPipResources = new(StringComparer.Ordinal);
    private readonly Dictionary<string, List<string>> _mycoTargetPipResources = new(StringComparer.Ordinal);
    private readonly Dictionary<string, RecentFlowVisual> _recentFlowByNeed = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _recentSwapPartnerByNeed = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _possibleSwapPartnerByNeed = new(StringComparer.Ordinal);
    private readonly Dictionary<string, Dictionary<string, string>> _preferredNeedPartners = new(StringComparer.Ordinal);
    private readonly List<RecentFlowLineVisual> _visibleRecentFlows = [];
    private readonly List<float> _usedNeedAngles = [];

    private GdDictionary _snapshot = new();
    private Rect2 _boardRect;
    private Rect2 _boardViewportRect;
    private float _tileSize = 64.0f;
    private int _boardCols = 8;
    private int _boardRows = 8;
    private bool _boardVisible = true;
    private bool _usingCsharpSim;
    private bool _solved;
    private bool _circuitOverlayEnabled = true;
    private bool _fastDragMode;
    private string _dragCell = "";
    private Vector2 _dragPosition;
    private Vector2I _originalDragTile;
    private string _inventoryDragCell = "";
    private Vector2 _inventoryDragPosition;
    private string _hintA = "";
    private string _hintB = "";
    private float _clearEffectProgress = 1.0f;
    private float _clearEffectScale = 1.0f;
    private int _resourceMarkMode;
    private ulong _lastDrawMsec;
    private float _frameBlend = 1.0f;
    private bool _visualProfileEnabled;
    private int _visualProfilePrintEvery = 120;
    private int _visualProfileFrames;
    private ulong _visualProfileFrameUsec;
    private ulong _visualProfileMaxFrameUsec;
    private ulong _visualProfileBoardUsec;
    private ulong _visualProfileCircuitUsec;
    private ulong _visualProfileFlowsUsec;
    private ulong _visualProfileStickyUsec;
    private ulong _visualProfileHintUsec;
    private ulong _visualProfileCellsUsec;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        SetAnchorsPreset(LayoutPreset.FullRect);
    }

    public void set_render_state(GdDictionary state) => SetRenderState(state);

    public void SetRenderState(GdDictionary state)
    {
        ApplyViewState(
            GetRect2(state, "boardRect", _boardRect),
            GetRect2(state, "boardViewportRect", _boardRect),
            GetFloat(state, "tileSize", _tileSize));
        _boardCols = GetInt(state, "boardCols", _boardCols);
        _boardRows = GetInt(state, "boardRows", _boardRows);
        _boardVisible = GetBool(state, "boardVisible", true);
        _usingCsharpSim = GetBool(state, "usingCsharpSim", _usingCsharpSim);
        _solved = GetBool(state, "solved", _solved);
        _circuitOverlayEnabled = GetBool(state, "circuitOverlayEnabled", _circuitOverlayEnabled);
        _fastDragMode = GetBool(state, "fastDragMode", _fastDragMode);
        _dragCell = GetString(state, "dragCell", "");
        _dragPosition = GetVector2(state, "dragPosition", Vector2.Zero);
        _originalDragTile = GetVector2I(state, "originalDragTile", Vector2I.Zero);
        _inventoryDragCell = GetString(state, "inventoryDragCell", "");
        _inventoryDragPosition = GetVector2(state, "inventoryDragPosition", Vector2.Zero);
        _resourceMarkMode = GetInt(state, "resourceMarkMode", _resourceMarkMode);
        var profileWasEnabled = _visualProfileEnabled;
        _visualProfileEnabled = GetBool(state, "visualProfileEnabled", _visualProfileEnabled);
        _visualProfilePrintEvery = Math.Max(1, GetInt(state, "visualProfilePrintEvery", _visualProfilePrintEvery));
        if (_visualProfileEnabled && !profileWasEnabled)
        {
            ResetVisualProfile();
        }

        _hintA = "";
        _hintB = "";
        var hint = GetArray(state, "hintPair");
        if (hint.Count == 2)
        {
            _hintA = hint[0].AsString();
            _hintB = hint[1].AsString();
        }
        _clearEffectProgress = Mathf.Clamp(GetFloat(state, "clearEffectProgress", 1.0f), 0.0f, 1.0f);
        _clearEffectScale = Mathf.Clamp(GetFloat(state, "clearEffectScale", 1.0f), 1.0f, 1.85f);

        ReadCells(state);
        ReadInventoryCells(state);
        ReadPositions(state);
        ReadOverrideCellCenters(state);
        ReadOverrideCellScales(state);
        ReadInventoryCenters(state);
        ReadInventoryFreshStarts(state);
        ReadClearingCells(state);
        ReadRocks(state);
        ReadProduced(state);
        ReadCellKinds(state);
        ReadNeeds(state);
        ReadPreferredNeedPartners(state);
        _snapshot = GetDictionary(state, "snapshot");
        ReadCellStates();
        RebuildSnapshotIndexes();

        QueueRedraw();
    }

    public void set_view_state(Rect2 boardRect, Rect2 boardViewportRect, float tileSize) =>
        SetViewState(boardRect, boardViewportRect, tileSize);

    public void SetViewState(Rect2 boardRect, Rect2 boardViewportRect, float tileSize)
    {
        ApplyViewState(boardRect, boardViewportRect, tileSize);
        QueueRedraw();
    }

    private void ApplyViewState(Rect2 boardRect, Rect2 boardViewportRect, float tileSize)
    {
        _boardRect = boardRect;
        _boardViewportRect = boardViewportRect;
        if (_boardViewportRect.Size.X <= 1.0f || _boardViewportRect.Size.Y <= 1.0f)
        {
            _boardViewportRect = _boardRect;
        }
        _tileSize = tileSize;
    }

    public void set_drag_state(string dragCell, Vector2 dragPosition, Vector2I originalDragTile, bool fastDragMode) =>
        SetDragState(dragCell, dragPosition, originalDragTile, fastDragMode);

    public void SetDragState(string dragCell, Vector2 dragPosition, Vector2I originalDragTile, bool fastDragMode)
    {
        _dragCell = dragCell;
        _dragPosition = dragPosition;
        _originalDragTile = originalDragTile;
        _fastDragMode = fastDragMode;
        QueueRedraw();
    }

    public override void _Draw()
    {
        if (_visualProfileEnabled)
        {
            DrawProfiled();
            return;
        }

        UpdateFrameBlend();
        if (_boardVisible)
        {
            DrawBoard();
            DrawCircuitFlowGroups();
            DrawRecentFlows();
            DrawDragStickyConnections();
            DrawHint();
        }

        foreach (var cell in _cells)
        {
            if (cell == _dragCell)
            {
                continue;
            }

            DrawCell(cell, VisualCellCenter(cell), dragging: false, clipToViewport: _boardVisible, useSimState: true, visualScale: CellVisualScale(cell));
        }

        if (_boardVisible)
        {
            DrawInventoryCells();
        }

        if (!string.IsNullOrEmpty(_dragCell))
        {
            DrawCell(_dragCell, _dragPosition, dragging: true, visualScale: CellVisualScale(_dragCell));
        }

        if (_boardVisible)
        {
            DrawInventoryDragCell();
        }
    }

    private void DrawProfiled()
    {
        var frameStart = Time.GetTicksUsec();
        UpdateFrameBlend();
        var sectionStart = Time.GetTicksUsec();
        if (_boardVisible)
        {
            DrawBoard();
        }
        _visualProfileBoardUsec += Time.GetTicksUsec() - sectionStart;

        sectionStart = Time.GetTicksUsec();
        if (_boardVisible)
        {
            DrawCircuitFlowGroups();
        }
        _visualProfileCircuitUsec += Time.GetTicksUsec() - sectionStart;

        sectionStart = Time.GetTicksUsec();
        if (_boardVisible)
        {
            DrawRecentFlows();
        }
        _visualProfileFlowsUsec += Time.GetTicksUsec() - sectionStart;

        sectionStart = Time.GetTicksUsec();
        if (_boardVisible)
        {
            DrawDragStickyConnections();
        }
        _visualProfileStickyUsec += Time.GetTicksUsec() - sectionStart;

        sectionStart = Time.GetTicksUsec();
        if (_boardVisible)
        {
            DrawHint();
        }
        _visualProfileHintUsec += Time.GetTicksUsec() - sectionStart;

        sectionStart = Time.GetTicksUsec();
        foreach (var cell in _cells)
        {
            if (cell == _dragCell)
            {
                continue;
            }

            DrawCell(cell, VisualCellCenter(cell), dragging: false, clipToViewport: _boardVisible, useSimState: true, visualScale: CellVisualScale(cell));
        }

        if (_boardVisible)
        {
            DrawInventoryCells();
        }

        if (!string.IsNullOrEmpty(_dragCell))
        {
            DrawCell(_dragCell, _dragPosition, dragging: true, visualScale: CellVisualScale(_dragCell));
        }

        if (_boardVisible)
        {
            DrawInventoryDragCell();
        }
        _visualProfileCellsUsec += Time.GetTicksUsec() - sectionStart;

        var frameUsec = Time.GetTicksUsec() - frameStart;
        _visualProfileFrameUsec += frameUsec;
        _visualProfileMaxFrameUsec = Math.Max(_visualProfileMaxFrameUsec, frameUsec);
        _visualProfileFrames++;
        if (_visualProfileFrames >= _visualProfilePrintEvery)
        {
            PrintVisualProfile();
            ResetVisualProfile();
        }
    }

    private void PrintVisualProfile()
    {
        if (_visualProfileFrames <= 0)
        {
            return;
        }

        var frames = Math.Max(1, _visualProfileFrames);
        GD.Print(
            "[cellular-visual-profile] renderer=csharp ",
            "frames=", frames,
            " cells=", _cells.Count,
            " visible_flows=", _visibleRecentFlows.Count,
            " indexed_possible=", _possibleSwapPartnerByNeed.Count,
            " avg_ms=", UsecToMs(_visualProfileFrameUsec / (ulong)frames),
            " max_ms=", UsecToMs(_visualProfileMaxFrameUsec),
            " board_ms=", UsecToMs(_visualProfileBoardUsec / (ulong)frames),
            " circuit_ms=", UsecToMs(_visualProfileCircuitUsec / (ulong)frames),
            " flows_ms=", UsecToMs(_visualProfileFlowsUsec / (ulong)frames),
            " sticky_ms=", UsecToMs(_visualProfileStickyUsec / (ulong)frames),
            " hint_ms=", UsecToMs(_visualProfileHintUsec / (ulong)frames),
            " cells_ms=", UsecToMs(_visualProfileCellsUsec / (ulong)frames));
    }

    private void ResetVisualProfile()
    {
        _visualProfileFrames = 0;
        _visualProfileFrameUsec = 0;
        _visualProfileMaxFrameUsec = 0;
        _visualProfileBoardUsec = 0;
        _visualProfileCircuitUsec = 0;
        _visualProfileFlowsUsec = 0;
        _visualProfileStickyUsec = 0;
        _visualProfileHintUsec = 0;
        _visualProfileCellsUsec = 0;
    }

    private static string UsecToMs(ulong usec) => (usec / 1000.0).ToString("0.###");

    private void DrawBoard()
    {
        DrawRect(_boardViewportRect, new Color(0.015f, 0.030f, 0.035f, 0.88f), filled: true);
        var minX = VisibleMinX();
        var maxX = VisibleMaxX();
        var minY = VisibleMinY();
        var maxY = VisibleMaxY();
        for (var y = minY; y <= maxY; y++)
        {
            for (var x = minX; x <= maxX; x++)
            {
                if (_rocks.Contains(new Vector2I(x, y)))
                {
                    continue;
                }

                var rect = TileRect(new Vector2I(x, y)).Grow(-2.0f);
                if (!RectIntersectsViewport(rect, 2.0f))
                {
                    continue;
                }

                var shade = (x + y) % 2 == 0 ? 0.085f : 0.105f;
                DrawRect(rect, new Color(shade, shade + 0.035f, shade + 0.045f, 1.0f), filled: true);
                DrawRect(rect, new Color(0.24f, 0.42f, 0.42f, 0.18f), filled: false, width: 1.0f);
            }
        }

        if (string.IsNullOrEmpty(_dragCell))
        {
            return;
        }

        var tile = ScreenToTile(_dragPosition);
        if (IsTileInside(tile) && (IsTileEmpty(tile) || tile == _originalDragTile))
        {
            var highlight = TileRect(tile).Grow(-3.0f);
            if (!RectIntersectsViewport(highlight, 4.0f))
            {
                return;
            }

            DrawRect(highlight, new Color(0.45f, 1.0f, 0.78f, 0.20f), filled: true);
            DrawRect(highlight, new Color(0.55f, 1.0f, 0.82f, 0.70f), filled: false, width: 3.0f);
        }
    }

    private void DrawCircuitFlowGroups()
    {
        if (!_circuitOverlayEnabled || !_usingCsharpSim)
        {
            return;
        }

        var diagnostics = GetDictionary(_snapshot, "circuitDiagnostics");
        var edges = GetArray(diagnostics, "directedEdges");
        DrawCircuitBlockers(diagnostics);
        if (edges.Count == 0)
        {
            return;
        }

        var alive = GetBool(diagnostics, "alive", false);
        var windowTicks = Mathf.Max(1.0f, GetFloat(_snapshot, "tick", 0.0f) - GetFloat(diagnostics, "sinceTick", 0.0f));
        var strongGroupByCell = new Dictionary<string, int>(StringComparer.Ordinal);
        var cellsByGroup = new Dictionary<int, List<string>>();
        var groups = GetArray(diagnostics, "strongGroups");
        var groupIndex = 0;
        foreach (var groupVariant in groups)
        {
            var groupCells = StringsFromArray(groupVariant.AsGodotArray());
            if (groupCells.Count < 2)
            {
                continue;
            }

            cellsByGroup[groupIndex] = groupCells;
            foreach (var cell in groupCells)
            {
                strongGroupByCell[cell] = groupIndex;
            }

            groupIndex++;
        }

        var alphaByGroup = new Dictionary<int, float>();
        foreach (var edgeVariant in edges)
        {
            var edge = edgeVariant.AsGodotDictionary();
            var source = GetString(edge, "sourceCellId", "");
            var target = GetString(edge, "targetCellId", "");
            if (!strongGroupByCell.TryGetValue(source, out var sourceGroup)
                || !strongGroupByCell.TryGetValue(target, out var targetGroup)
                || sourceGroup != targetGroup)
            {
                continue;
            }

            var alpha = CircuitAgeAlpha(GetFloat(edge, "ageTicks", 0.0f), windowTicks);
            alphaByGroup[sourceGroup] = Mathf.Max(alphaByGroup.GetValueOrDefault(sourceGroup), alpha);
        }

        var circuitColor = new Color(0.30f, 1.00f, 0.84f, 1.0f);
        foreach (var (index, groupCells) in cellsByGroup)
        {
            var alpha = alphaByGroup.GetValueOrDefault(index);
            if (alpha <= 0.0f)
            {
                continue;
            }

            DrawCircuitComponentHalo(groupCells, circuitColor, FlowGroupContainsAllCells(groupCells) && alive, alpha);
        }

        foreach (var edgeVariant in edges)
        {
            var edge = edgeVariant.AsGodotDictionary();
            var source = GetString(edge, "sourceCellId", "");
            var target = GetString(edge, "targetCellId", "");
            if (string.IsNullOrEmpty(source) || string.IsNullOrEmpty(target))
            {
                continue;
            }

            var alpha = CircuitAgeAlpha(GetFloat(edge, "ageTicks", 0.0f), windowTicks);
            if (alpha <= 0.0f)
            {
                continue;
            }

            strongGroupByCell.TryGetValue(source, out var sourceGroup);
            strongGroupByCell.TryGetValue(target, out var targetGroup);
            var sameStrongGroup = strongGroupByCell.ContainsKey(source)
                && strongGroupByCell.ContainsKey(target)
                && sourceGroup == targetGroup;
            var color = sameStrongGroup ? circuitColor : new Color(1.0f, 0.70f, 0.20f, 1.0f);
            DrawDirectedCircuitLine(VisualCellCenter(source), VisualCellCenter(target), color, alpha, sameStrongGroup && alive, !sameStrongGroup);
        }
    }

    private void DrawCircuitComponentHalo(List<string> cells, Color color, bool complete, float strength)
    {
        strength = Mathf.Clamp(strength, 0.0f, 1.0f);
        if (strength <= 0.0f)
        {
            return;
        }

        var tiles = new HashSet<Vector2I>();
        foreach (var cell in cells)
        {
            tiles.Add(GetCellTile(cell));
        }

        var pulse = 0.5f + Mathf.Sin(Time.GetTicksMsec() / (complete ? 105.0f : 190.0f)) * 0.5f;
        var fillAlpha = (complete ? 0.28f + pulse * 0.10f : 0.13f + pulse * 0.04f) * strength;
        var boundaryAlpha = (complete ? 0.82f + pulse * 0.16f : 0.56f + pulse * 0.14f) * strength;
        var heatRadius = _tileSize * (complete ? 0.64f : 0.56f);
        var connectorWidth = _tileSize * (complete ? 0.96f : 0.88f);
        var boundaryWidth = complete ? 7.0f : 5.0f;
        var heat = color with { A = fillAlpha };

        foreach (var tile in tiles)
        {
            var center = TileCenter(tile);
            var right = new Vector2I(tile.X + 1, tile.Y);
            if (tiles.Contains(right))
            {
                var rightCenter = TileCenter(right);
                if (LineIntersectsViewport(center, rightCenter, connectorWidth))
                {
                    DrawLine(center, rightCenter, heat, connectorWidth, antialiased: true);
                }
            }

            var down = new Vector2I(tile.X, tile.Y + 1);
            if (tiles.Contains(down))
            {
                var downCenter = TileCenter(down);
                if (LineIntersectsViewport(center, downCenter, connectorWidth))
                {
                    DrawLine(center, downCenter, heat, connectorWidth, antialiased: true);
                }
            }
        }

        foreach (var tile in tiles)
        {
            var center = TileCenter(tile);
            if (PointIntersectsViewport(center, heatRadius))
            {
                DrawCircle(center, heatRadius, heat);
            }
        }

        foreach (var tile in tiles)
        {
            var origin = TileRect(tile).Position;
            var topLeft = origin;
            var topRight = origin + new Vector2(_tileSize, 0.0f);
            var bottomLeft = origin + new Vector2(0.0f, _tileSize);
            var bottomRight = origin + new Vector2(_tileSize, _tileSize);

            if (!tiles.Contains(new Vector2I(tile.X, tile.Y - 1)))
            {
                DrawComponentBoundarySegment(topLeft, topRight, color, boundaryAlpha, boundaryWidth);
            }

            if (!tiles.Contains(new Vector2I(tile.X + 1, tile.Y)))
            {
                DrawComponentBoundarySegment(topRight, bottomRight, color, boundaryAlpha, boundaryWidth);
            }

            if (!tiles.Contains(new Vector2I(tile.X, tile.Y + 1)))
            {
                DrawComponentBoundarySegment(bottomRight, bottomLeft, color, boundaryAlpha, boundaryWidth);
            }

            if (!tiles.Contains(new Vector2I(tile.X - 1, tile.Y)))
            {
                DrawComponentBoundarySegment(bottomLeft, topLeft, color, boundaryAlpha, boundaryWidth);
            }
        }
    }

    private void DrawComponentBoundarySegment(Vector2 start, Vector2 finish, Color color, float alpha, float width)
    {
        if (!LineIntersectsViewport(start, finish, width + 9.0f))
        {
            return;
        }

        DrawLine(start, finish, color with { A = alpha * 0.32f }, width + 9.0f, antialiased: true);
        DrawLine(start, finish, new Color(0.0f, 0.07f, 0.08f, alpha * 0.50f), width + 3.0f, antialiased: true);
        DrawLine(start, finish, color.Lightened(0.30f) with { A = alpha }, width, antialiased: true);
    }

    private void DrawCircuitBlockers(GdDictionary diagnostics)
    {
        var blocked = StringsFromArray(GetArray(diagnostics, "nonGlowingRequiredCells"));
        if (blocked.Count == 0)
        {
            return;
        }

        var pulse = 0.5f + Mathf.Sin(Time.GetTicksMsec() / 190.0f) * 0.5f;
        foreach (var cell in blocked)
        {
            var center = VisualCellCenter(cell);
            if (!PointIntersectsViewport(center, _tileSize * 0.62f))
            {
                continue;
            }

            DrawCircle(center, _tileSize * 0.56f, new Color(1.0f, 0.40f, 0.18f, 0.08f + pulse * 0.05f));
        DrawArc(center, _tileSize * 0.47f, -Mathf.Pi * 0.15f, Mathf.Tau * 0.82f, ArcSegments(_tileSize * 0.47f), new Color(1.0f, 0.72f, 0.28f, 0.22f + pulse * 0.12f), 2.5f, antialiased: true);
        }
    }

    private void DrawDirectedCircuitLine(Vector2 start, Vector2 finish, Color color, float alpha, bool intense, bool transient)
    {
        var delta = finish - start;
        if (delta.LengthSquared() <= 1.0f)
        {
            return;
        }

        var direction = delta.Normalized();
        var normal = direction.Orthogonal();
        var lineStart = start + direction * _tileSize * 0.30f;
        var lineFinish = finish - direction * _tileSize * 0.30f;
        if (!LineIntersectsViewport(lineStart, lineFinish, _tileSize * 0.50f))
        {
            return;
        }

        var pulse = 0.5f + Mathf.Sin(Time.GetTicksMsec() / (intense ? 90.0f : 150.0f) + start.X * 0.02f) * 0.5f;
        var broad = color with
        {
            A = transient ? 0.12f + alpha * 0.20f : intense ? 0.24f + alpha * 0.26f : 0.16f + alpha * 0.18f
        };
        DrawLine(lineStart, lineFinish, broad, _tileSize * (transient ? 0.28f : intense ? 0.46f : 0.34f), antialiased: true);

        var core = color.Lightened(0.25f) with
        {
            A = transient ? 0.34f + alpha * 0.28f : intense ? 0.50f + alpha * 0.44f : 0.32f + alpha * 0.32f
        };
        DrawLine(lineStart, lineFinish, core, Mathf.Max(3.0f, _tileSize * (transient ? 0.05f : intense ? 0.09f : 0.065f)), antialiased: true);

        var spark = new Color(1.0f, 1.0f, 1.0f, transient ? 0.24f + alpha * 0.24f : 0.28f + alpha * 0.38f);
        var offset = normal * Mathf.Sin(Time.GetTicksMsec() / 76.0f + finish.Y * 0.025f) * _tileSize * 0.035f;
        DrawLine(lineStart + offset, lineFinish - offset, spark, transient ? 1.8f : 2.2f, antialiased: true);

        var arrowAt = lineStart.Lerp(lineFinish, 0.66f + pulse * 0.12f);
        var arrowSize = _tileSize * (transient ? 0.15f : 0.18f);
        var arrowColor = core with { A = Mathf.Clamp(core.A + 0.12f, 0.0f, 1.0f) };
        DrawLine(arrowAt, arrowAt - direction * arrowSize + normal * arrowSize * 0.58f, arrowColor, 2.8f, antialiased: true);
        DrawLine(arrowAt, arrowAt - direction * arrowSize - normal * arrowSize * 0.58f, arrowColor, 2.8f, antialiased: true);
    }

    private void DrawRecentFlows()
    {
        if (!_usingCsharpSim)
        {
            return;
        }

        foreach (var flow in _visibleRecentFlows)
        {
            if (flow.Alpha <= 0.0f)
            {
                continue;
            }

            var sourcePoint = ResourceVisualPoint(flow.SourceCell, flow.Resource);
            var targetPoint = ResourceVisualPoint(flow.TargetCell, flow.Resource);
            if (!LineIntersectsViewport(sourcePoint, targetPoint, _tileSize * 0.20f))
            {
                continue;
            }

            var color = ResourceColor(flow.Resource);
            DrawElectricFlowLine(sourcePoint, targetPoint, color, flow.Alpha);
            var t = Mathf.Clamp(flow.AgeTicks / 2.4f, 0.0f, 1.0f);
            var particlePoint = sourcePoint.Lerp(targetPoint, t);
            if (PointIntersectsViewport(particlePoint, _tileSize * 0.08f))
            {
                DrawSwapParticle(particlePoint, flow.Resource, flow.Alpha);
            }
        }
    }

    private void DrawDragStickyConnections()
    {
        if (string.IsNullOrEmpty(_dragCell) || !_usingCsharpSim)
        {
            return;
        }

        DrawDragRecentFlowConnections();
        DrawDragPossibleSwapConnections();
    }

    private void DrawDragRecentFlowConnections()
    {
        var flows = GetArray(_snapshot, "flows");
        if (flows.Count == 0)
        {
            return;
        }

        var currentTick = GetFloat(_snapshot, "tick", 0.0f);
        foreach (var flowVariant in flows)
        {
            var flow = flowVariant.AsGodotDictionary();
            var source = GetString(flow, "sourceCellId", "");
            var target = GetString(flow, "targetCellId", "");
            var resource = GetString(flow, "resource", "");
            if ((source != _dragCell && target != _dragCell) || string.IsNullOrEmpty(resource))
            {
                continue;
            }

            var other = source == _dragCell ? target : source;
            if (string.IsNullOrEmpty(other))
            {
                continue;
            }

            var age = Mathf.Max(0.0f, currentTick - GetFloat(flow, "tick", currentTick));
            var alpha = Mathf.Clamp(1.0f - age / SwapVisualTtlTicks, 0.0f, 1.0f);
            if (alpha <= 0.0f)
            {
                continue;
            }

            var start = ResourceVisualPoint(_dragCell, resource);
            var finish = ResourceVisualPoint(other, resource);
            DrawDragElasticLine(start, finish, ResourceColor(resource), 0.30f + alpha * 0.44f, active: true);
        }
    }

    private void DrawDragPossibleSwapConnections()
    {
        var swaps = GetArray(_snapshot, "possibleSwaps");
        if (swaps.Count == 0)
        {
            return;
        }

        var drawnPairs = new HashSet<string>(StringComparer.Ordinal);
        foreach (var swapVariant in swaps)
        {
            var swap = swapVariant.AsGodotDictionary();
            var initiator = GetString(swap, "initiator", "");
            var counterparty = GetString(swap, "counterparty", "");
            if (initiator != _dragCell && counterparty != _dragCell)
            {
                continue;
            }

            var other = initiator == _dragCell ? counterparty : initiator;
            if (string.IsNullOrEmpty(other))
            {
                continue;
            }

            var pairKey = string.CompareOrdinal(_dragCell, other) < 0 ? $"{_dragCell}\0{other}" : $"{other}\0{_dragCell}";
            if (!drawnPairs.Add(pairKey))
            {
                continue;
            }

            var resource = initiator == _dragCell
                ? GetString(swap, "counterpartyPaidResource", "")
                : GetString(swap, "initiatorPaidResource", "");
            var color = string.IsNullOrEmpty(resource) ? new Color(0.35f, 1.0f, 0.86f, 1.0f) : ResourceColor(resource);
            var start = string.IsNullOrEmpty(resource) ? VisualCellCenter(_dragCell) : ResourceVisualPoint(_dragCell, resource);
            var finish = string.IsNullOrEmpty(resource) ? VisualCellCenter(other) : ResourceVisualPoint(other, resource);
            DrawDragElasticLine(start, finish, color, 0.48f, active: false);
        }
    }

    private void DrawDragElasticLine(Vector2 start, Vector2 finish, Color color, float alpha, bool active)
    {
        var delta = finish - start;
        if (delta.LengthSquared() <= 1.0f)
        {
            return;
        }

        var distance = delta.Length();
        var stretch = Mathf.Clamp((distance - _tileSize * 0.72f) / Mathf.Max(_tileSize * 4.0f, 1.0f), 0.0f, 1.0f);
        var direction = delta / distance;
        var normal = direction.Orthogonal();
        var phase = Time.GetTicksMsec() / (active ? 72.0f : 116.0f);
        var wave = Mathf.Sin(phase + start.X * 0.013f + finish.Y * 0.017f) * _tileSize * (0.018f + stretch * 0.030f);
        var offset = normal * wave;
        var lineStart = start + direction * _tileSize * 0.04f;
        var lineFinish = finish - direction * _tileSize * 0.04f;
        if (!LineIntersectsViewport(lineStart, lineFinish, _tileSize * 0.24f))
        {
            return;
        }

        var outer = color with { A = alpha * (active ? 0.28f : 0.20f) };
        DrawLine(lineStart, lineFinish, outer, _tileSize * (active ? 0.16f : 0.12f), antialiased: true);

        var body = color.Lightened(0.18f) with { A = alpha * (0.54f + stretch * 0.18f) };
        DrawLine(lineStart + offset, lineFinish - offset, body, Mathf.Max(3.0f, _tileSize * (active ? 0.055f : 0.040f)), antialiased: true);

        var highlight = new Color(1.0f, 1.0f, 1.0f, alpha * (active ? 0.34f : 0.22f));
        DrawLine(lineStart - offset * 0.65f, lineFinish + offset * 0.65f, highlight, active ? 1.8f : 1.3f, antialiased: true);
    }

    private void DrawSwapParticle(Vector2 position, string resource, float alpha)
    {
        if (!PointIntersectsViewport(position, _tileSize * 0.10f))
        {
            return;
        }

        var color = ResourceColor(resource) with { A = Mathf.Clamp(alpha, 0.0f, 1.0f) };
        var radius = Mathf.Max(3.0f, _tileSize * 0.055f);
        DrawCircle(position, radius, color);
        DrawArc(position, radius, 0.0f, Mathf.Tau, 24, new Color(1.0f, 1.0f, 1.0f, 0.34f * alpha), 1.6f, antialiased: true);
    }

    private void DrawElectricFlowLine(Vector2 start, Vector2 finish, Color color, float alpha)
    {
        var delta = finish - start;
        if (delta.LengthSquared() <= 1.0f)
        {
            return;
        }
        if (!LineIntersectsViewport(start, finish, _tileSize * 0.16f))
        {
            return;
        }

        var normal = delta.Orthogonal().Normalized();
        DrawLine(start, finish, color with { A = 0.24f + alpha * (CircuitAliveNow() ? 0.38f : 0.26f) }, 3.0f + alpha * 2.0f, antialiased: true);
        var phase = Time.GetTicksMsec() / 82.0f;
        for (var i = 0; i < 2; i++)
        {
            var wave = Mathf.Sin(phase + i * Mathf.Pi);
            var offset = normal * wave * _tileSize * 0.025f;
            DrawLine(start + offset, finish - offset, color.Lightened(0.22f) with { A = 0.14f + alpha * 0.20f }, 1.4f, antialiased: true);
        }
    }

    private void DrawHint()
    {
        if (string.IsNullOrEmpty(_hintA) || string.IsNullOrEmpty(_hintB))
        {
            return;
        }

        var a = VisualCellCenter(_hintA);
        var b = VisualCellCenter(_hintB);
        if (!LineIntersectsViewport(a, b, _tileSize * 0.60f))
        {
            return;
        }

        var hintColor = new Color(1.0f, 0.92f, 0.24f, 0.86f);
        DrawLine(a, b, new Color(1.0f, 0.92f, 0.24f, 0.34f), 9.0f, antialiased: true);
        DrawLine(a, b, hintColor, 3.0f, antialiased: true);
        DrawArc(a, _tileSize * 0.49f, 0.0f, Mathf.Tau, ArcSegments(_tileSize * 0.49f), hintColor, 5.0f, antialiased: true);
        DrawArc(b, _tileSize * 0.49f, 0.0f, Mathf.Tau, ArcSegments(_tileSize * 0.49f), hintColor, 5.0f, antialiased: true);
    }

    private void DrawInventoryCells()
    {
        foreach (var cell in _inventoryCells)
        {
            if (_inventoryCenters.TryGetValue(cell, out var center))
            {
                var freshStrength = InventoryFreshStrength(cell);
                var burst = Mathf.Sin((1.0f - freshStrength) * Mathf.Pi);
                var slotSize = _tileSize * InventorySlotScale;
                var cellCenter = InventoryVisualCenter(center);

                DrawInventorySlotBacking(center, slotSize);
                if (cell != _inventoryDragCell)
                {
                    if (freshStrength > 0.0f)
                    {
                        var cellHaloRadius = _tileSize * (0.50f + burst * 0.08f);
                        DrawCircle(cellCenter, cellHaloRadius, new Color(1.0f, 0.90f, 0.28f, 0.18f * freshStrength + 0.12f * burst));
                        DrawArc(cellCenter, cellHaloRadius * 1.04f, 0.0f, Mathf.Tau, 48, new Color(1.0f, 0.90f, 0.30f, 0.46f * freshStrength), Mathf.Max(3.0f, _tileSize * 0.052f), antialiased: true);
                    }

                    DrawCell(cell, cellCenter, dragging: false, clipToViewport: false, useSimState: false, visualScale: InventoryCellScale + freshStrength * 0.10f + burst * 0.07f);
                }

                DrawInventorySlotFrame(center, slotSize, 0.0f);
            }
        }
    }

    private void DrawInventoryDragCell()
    {
        if (!string.IsNullOrEmpty(_inventoryDragCell))
        {
            DrawCell(_inventoryDragCell, _inventoryDragPosition, dragging: true, clipToViewport: false, useSimState: false, visualScale: InventoryCellScale);
        }
    }

    private void DrawInventorySlotBacking(Vector2 center, float slotSize)
    {
        var slotRect = new Rect2(center - new Vector2(slotSize * 0.5f, slotSize * 0.5f), new Vector2(slotSize, slotSize));
        var shadowRect = new Rect2(slotRect.Position + new Vector2(0.0f, _tileSize * 0.055f), slotRect.Size).Grow(_tileSize * 0.018f);
        DrawRect(shadowRect, new Color(0.0f, 0.012f, 0.015f, 0.50f), filled: true);
        DrawRect(slotRect, new Color(0.085f, 0.120f, 0.130f, 0.98f), filled: true);
        DrawRect(slotRect.Grow(-_tileSize * 0.045f), new Color(0.115f, 0.158f, 0.165f, 0.55f), filled: true);
        DrawRect(slotRect.Grow(-_tileSize * 0.030f), new Color(0.24f, 0.42f, 0.42f, 0.20f), filled: false, width: Mathf.Max(1.4f, _tileSize * 0.018f));
    }

    private void DrawInventorySlotFrame(Vector2 center, float slotSize, float freshStrength)
    {
        var slotRect = new Rect2(center - new Vector2(slotSize * 0.5f, slotSize * 0.5f), new Vector2(slotSize, slotSize));
        var shadowRect = new Rect2(slotRect.Position + new Vector2(0.0f, _tileSize * 0.055f), slotRect.Size).Grow(_tileSize * 0.018f);
        DrawRect(shadowRect, new Color(0.0f, 0.012f, 0.015f, 0.36f), filled: false, width: Mathf.Max(3.0f, _tileSize * 0.040f));
        DrawRect(slotRect.Grow(-_tileSize * 0.030f), new Color(1.0f, 1.0f, 1.0f, 0.13f), filled: false, width: Mathf.Max(1.2f, _tileSize * 0.016f));
        DrawRect(slotRect, new Color(0.08f, 0.25f, 0.21f, 0.72f), filled: false, width: Mathf.Max(5.0f, _tileSize * 0.074f));
        DrawRect(slotRect.Grow(-_tileSize * 0.022f), new Color(0.54f, 1.0f, 0.84f, 0.82f), filled: false, width: Mathf.Max(3.2f, _tileSize * 0.046f));
    }

    private void DrawCell(string cell, Vector2 center, bool dragging, bool clipToViewport = true, bool useSimState = true, float visualScale = 1.0f)
    {
        var radius = _tileSize * (dragging ? 0.43f : 0.39f) * visualScale;
        var clearing = _clearingCells.Contains(cell);
        var clearAlpha = clearing ? ClearingAlpha() : 1.0f;
        var clearFlash = clearing ? ClearingFlash() : 0.0f;
        if (clearing)
        {
            radius *= 1.0f + (Mathf.Sin(_clearEffectProgress * Mathf.Pi) * 0.22f + clearFlash * 0.12f) * _clearEffectScale;
        }

        if (clipToViewport && !PointIntersectsViewport(center, radius * 1.95f))
        {
            return;
        }
        if (clearAlpha <= 0.02f)
        {
            return;
        }

        var kind = CellKindFor(cell);
        var isMyco = IsMycoKind(kind);
        var produced = CellProducedResource(cell);
        var color = isMyco ? new Color(0.94f, 0.97f, 0.94f, 1.0f) : ResourceColor(produced);
        var liveComplete = useSimState && CircuitAliveNow();
        var hasLiveState = useSimState && _usingCsharpSim && _cellStates.ContainsKey(cell);
        var bodyGlowColor = color;
        var glowAlpha = hasLiveState
            ? (CellIsGlowing(cell) ? 0.56f : 0.16f)
            : (useSimState && CellHasAllNeeds(cell) ? 0.46f : 0.18f);
        var hasNeedHealth = TryNeedHealth(cell, out var needHealth);
        if (hasNeedHealth)
        {
            var health = needHealth * needHealth * (3.0f - 2.0f * needHealth);
            bodyGlowColor = CellStressGlowColor.Lerp(CellHealthyGlowColor, health);
            var healthyGlowStrength = CellIsGlowing(cell) ? CellHealthyActiveGlowStrength : CellHealthyIdleGlowStrength;
            glowAlpha = Mathf.Lerp(CellStressGlowStrength, healthyGlowStrength, health);
        }
        if (liveComplete && (!hasNeedHealth || needHealth >= 0.95f))
        {
            bodyGlowColor = CellHealthyGlowColor;
            glowAlpha = 0.72f;
        }

        var reactionAlpha = hasLiveState ? RecentReactionAlpha(cell) : 0.0f;
        if (reactionAlpha > 0.0f)
        {
            var reactionHealth = hasNeedHealth ? needHealth : 1.0f;
            if (reactionHealth > 0.0f)
            {
                bodyGlowColor = bodyGlowColor.Lerp(CellHealthyGlowColor, reactionAlpha * reactionHealth);
                glowAlpha = Mathf.Max(glowAlpha, Mathf.Lerp(CellStressGlowStrength, 0.52f + reactionAlpha * 0.28f, reactionHealth));
                DrawCircle(center, radius * (1.22f + reactionAlpha * 0.10f), new Color(1.0f, 0.95f, 0.58f, reactionAlpha * 0.18f * reactionHealth * clearAlpha));
            }
        }

        DrawCircle(center, radius * (1.16f + (liveComplete && (!hasNeedHealth || needHealth >= 0.95f) ? 0.04f : 0.0f)), new Color(bodyGlowColor.R, bodyGlowColor.G, bodyGlowColor.B, glowAlpha * 0.28f * clearAlpha));
        DrawCircle(center, radius, new Color(color.R, color.G, color.B, 0.72f * clearAlpha));
        DrawArc(center, radius * 0.96f, 0.0f, Mathf.Tau, ArcSegments(radius), new Color(0.92f, 1.0f, 0.95f, 0.68f * clearAlpha), 3.0f, antialiased: true);
        if (clearing)
        {
            DrawCircle(center, radius * (1.05f + _clearEffectProgress * 0.28f * _clearEffectScale), new Color(1.0f, 0.95f, 0.34f, clearFlash * 0.48f + (1.0f - _clearEffectProgress) * 0.10f));
            DrawArc(center, radius * (1.12f + _clearEffectProgress * 0.34f * _clearEffectScale), 0.0f, Mathf.Tau, ArcSegments(radius), new Color(1.0f, 0.88f, 0.22f, clearAlpha * 0.46f), 4.5f * _clearEffectScale, antialiased: true);
        }

        if (kind == CellKindRedMyco)
        {
            DrawRedMycoRing(center, radius, clearAlpha);
        }

        var font = GetThemeDefaultFont();
        if (liveComplete)
        {
            var solvedPulse = 0.5f + Mathf.Sin(Time.GetTicksMsec() / 160.0f) * 0.5f;
            DrawArc(center, radius * (1.07f + solvedPulse * 0.03f), 0.0f, Mathf.Tau, ArcSegments(radius), new Color(0.62f, 1.0f, 0.88f, (0.28f + solvedPulse * 0.18f) * clearAlpha), 3.0f, antialiased: true);
        }

        if (!clearing && hasLiveState && !isMyco && !string.IsNullOrEmpty(produced))
        {
            DrawFullnessArc(center, radius * 1.07f, DisplayedFullness(cell, produced, SlotFullness(cell, produced)), color, 6.0f);
        }

        var currentNeeded = VisualNeedsForCell(cell, isMyco, useSimState);
        var mycoPipState = isMyco
            ? BuildMycoPipVisualState(cell, currentNeeded)
            : new MycoPipVisualState(currentNeeded, 1.0f);
        var needed = mycoPipState.Resources;
        var pipCount = isMyco ? MycoVisualPipCount : needed.Count;
        var mycoAdaptProgress = mycoPipState.Progress;
        var usedAngles = _usedNeedAngles;
        usedAngles.Clear();
        if (usedAngles.Capacity < pipCount)
        {
            usedAngles.Capacity = pipCount;
        }

        for (var i = 0; i < pipCount; i++)
        {
            var pipRadius = NeedPipRadius(radius);
            if (i >= needed.Count)
            {
                var blankAngle = -Mathf.Pi * 0.5f + i / Mathf.Max(1.0f, pipCount) * Mathf.Tau;
                var blankCenter = center + new Vector2(Mathf.Cos(blankAngle), Mathf.Sin(blankAngle)) * (radius * 1.18f);
                var blankColor = new Color(0.92f, 0.97f, 0.96f, clearAlpha);
                DrawCircle(blankCenter, pipRadius, blankColor);
                DrawArc(blankCenter, pipRadius, 0.0f, Mathf.Tau, ArcSegments(pipRadius), new Color(0.01f, 0.025f, 0.03f, 0.68f * clearAlpha), 2.2f, antialiased: true);
                DrawArc(blankCenter, pipRadius * 0.84f, 0.0f, Mathf.Tau, ArcSegments(pipRadius), new Color(1.0f, 1.0f, 1.0f, 0.52f * clearAlpha), 1.4f, antialiased: true);
                continue;
            }

            var need = needed[i];
            var fadingObsoleteMycoResource = isMyco && !ContainsResource(currentNeeded, need);
            var visual = fadingObsoleteMycoResource
                ? FadingMycoNeedVisual(i, pipCount, radius)
                : NeedVisualData(cell, need, i, pipCount, center, radius, pipRadius, usedAngles, applySmoothing: true, useSimState: useSimState);
            usedAngles.Add(visual.TargetAngle);
            var pipCenter = center + new Vector2(Mathf.Cos(visual.Angle), Mathf.Sin(visual.Angle)) * visual.Offset;
            var met = visual.State != NeedStateMissing || visual.Fullness > 0.0f;
            var pipColor = ResourceColor(need);

            if (visual.State == NeedStateMissing)
            {
                pipColor = pipColor.Darkened(0.48f) with { A = clearAlpha };
                DrawNeedTether(center, pipCenter, radius, pipRadius, new Color(0.75f, 0.88f, 0.90f, 0.28f * clearAlpha));
            }
            else if (visual.State == NeedStateAvailable)
            {
                pipColor = pipColor.Darkened(0.12f) with { A = clearAlpha };
                DrawNeedTether(center, pipCenter, radius, pipRadius, new Color(pipColor.R, pipColor.G, pipColor.B, 0.42f * clearAlpha));
            }
            else if (visual.State == NeedStateActive)
            {
                pipColor = pipColor with { A = clearAlpha };
                DrawCircle(pipCenter, pipRadius * (1.14f + visual.ActiveAlpha * 0.16f), new Color(pipColor.R, pipColor.G, pipColor.B, (0.20f + visual.ActiveAlpha * 0.26f) * clearAlpha));
            }
            else
            {
                pipColor = pipColor with { A = clearAlpha };
            }

            if (isMyco)
            {
                var waitingColor = new Color(0.92f, 0.97f, 0.96f, clearAlpha);
                pipColor = waitingColor.Lerp(pipColor, mycoAdaptProgress);
                pipColor.A = clearAlpha;
            }

            DrawCircle(pipCenter, pipRadius, pipColor);
            DrawArc(pipCenter, pipRadius, 0.0f, Mathf.Tau, ArcSegments(pipRadius), new Color(0.01f, 0.025f, 0.03f, 0.82f * clearAlpha), 2.2f, antialiased: true);
            DrawArc(pipCenter, pipRadius * 0.86f, 0.0f, Mathf.Tau, ArcSegments(pipRadius), new Color(1.0f, 1.0f, 1.0f, (met ? 0.44f : 0.28f) * clearAlpha), 1.4f, antialiased: true);
            var pipBarRadius = pipRadius * 1.12f;
            var pipBarWidth = Mathf.Max(2.0f, pipRadius * 0.20f);
            if (!clearing)
            {
                var fullness = isMyco ? visual.Fullness * mycoAdaptProgress : visual.Fullness;
                DrawFullnessArc(pipCenter, pipBarRadius, DisplayedFullness(cell, need, fullness), pipColor, pipBarWidth);
            }
            if (!clearing && hasLiveState && visual.Fullness <= 0.0f)
            {
                DrawZeroPipPulseArc(pipCenter, pipBarRadius, pipBarWidth);
            }
            var markAlpha = clearAlpha * (isMyco ? mycoAdaptProgress : 1.0f);
            DrawFastResourceMark(font, pipCenter, pipRadius, need, Mathf.RoundToInt(pipRadius * 1.02f * NeedPipMarkSizeScale), Colors.White with { A = markAlpha });
        }

        if (!isMyco)
        {
            DrawResourceMark(font, center, radius, produced, Mathf.RoundToInt(radius * 1.48f), Colors.White with { A = clearAlpha });
        }
    }

    private void DrawRedMycoRing(Vector2 center, float radius, float alpha = 1.0f)
    {
        var ringRadius = radius * RedMycoRingRadius;
        var segments = ArcSegments(ringRadius);
        DrawArc(center, ringRadius, 0.0f, Mathf.Tau, segments, RedMycoRingEdgeColor with { A = RedMycoRingEdgeColor.A * alpha }, Mathf.Max(2.0f, radius * 0.18f), antialiased: true);
        DrawArc(center, ringRadius, 0.0f, Mathf.Tau, segments, RedMycoRingMidColor with { A = RedMycoRingMidColor.A * alpha }, Mathf.Max(1.6f, radius * 0.12f), antialiased: true);
        DrawArc(center, ringRadius, 0.0f, Mathf.Tau, segments, RedMycoRingCoreColor with { A = RedMycoRingCoreColor.A * alpha }, Mathf.Max(1.2f, radius * 0.055f), antialiased: true);
    }

    private static NeedVisual FadingMycoNeedVisual(int index, int count, float cellRadius)
    {
        var angle = -Mathf.Pi * 0.5f + index / Mathf.Max(1.0f, count) * Mathf.Tau;
        return new NeedVisual(NeedStateSatisfied, "", 1.0f, 0.0f, angle, cellRadius * 1.18f, angle);
    }

    private List<string> VisualNeedsForCell(string cell, bool isMyco, bool useSimState)
    {
        if (isMyco && useSimState && _usingCsharpSim && _cellStates.TryGetValue(cell, out var state))
        {
            return state.NeedSlotResources;
        }

        return _needs.GetValueOrDefault(cell) ?? [];
    }

    private MycoPipVisualState BuildMycoPipVisualState(string cell, List<string> currentResources)
    {
        var now = Time.GetTicksMsec();
        var targetSignature = MycoPipSignature(currentResources);
        if (!_mycoPipSignatures.TryGetValue(cell, out var previousSignature))
        {
            _mycoPipSignatures[cell] = targetSignature;
            _mycoPipTransitionStarts[cell] = now;
            _mycoPreviousPipResources[cell] = [];
            _mycoTargetPipResources[cell] = new List<string>(currentResources);
            return currentResources.Count == 0
                ? new MycoPipVisualState([], 1.0f)
                : new MycoPipVisualState(currentResources, 0.0f);
        }

        if (previousSignature != targetSignature)
        {
            _mycoPipSignatures[cell] = targetSignature;
            _mycoPipTransitionStarts[cell] = now;
            _mycoPreviousPipResources[cell] = _mycoTargetPipResources.TryGetValue(cell, out var oldTarget)
                ? new List<string>(oldTarget)
                : ResourcesFromMycoPipSignature(previousSignature);
            _mycoTargetPipResources[cell] = new List<string>(currentResources);
        }

        if (!_mycoPipTransitionStarts.TryGetValue(cell, out var start))
        {
            return new MycoPipVisualState(currentResources, 1.0f);
        }

        var elapsed = now - start;
        var previousResources = _mycoPreviousPipResources.TryGetValue(cell, out var previous)
            ? previous
            : [];
        var targetResources = _mycoTargetPipResources.TryGetValue(cell, out var target)
            ? target
            : currentResources;

        if (previousResources.Count > 0 && elapsed < MycoFadeOutMsec)
        {
            var fadeOutProgress = 1.0f - Mathf.Clamp((float)elapsed / (float)MycoFadeOutMsec, 0.0f, 1.0f);
            return new MycoPipVisualState(previousResources, fadeOutProgress);
        }

        if (targetResources.Count == 0)
        {
            return new MycoPipVisualState([], 1.0f);
        }

        var fadeInElapsed = previousResources.Count > 0 ? elapsed - MycoFadeOutMsec : elapsed;
        var fadeInProgress = Mathf.Clamp((float)fadeInElapsed / (float)MycoAdaptTransitionMsec, 0.0f, 1.0f);
        return new MycoPipVisualState(targetResources, fadeInProgress);
    }

    private static string MycoPipSignature(List<string> resources) =>
        resources.Count == 0 ? MycoWaitingSignature : string.Join("|", resources);

    private static List<string> ResourcesFromMycoPipSignature(string signature) =>
        signature == MycoWaitingSignature
            ? []
            : signature.Split('|', StringSplitOptions.RemoveEmptyEntries).ToList();

    private static bool ContainsResource(List<string> resources, string resource)
    {
        for (var i = 0; i < resources.Count; i++)
        {
            if (resources[i] == resource)
            {
                return true;
            }
        }

        return false;
    }

    private void DrawSimpleNeedDots(string cell, Vector2 center, float cellRadius)
    {
        var isMyco = IsMycoCell(cell);
        var needed = VisualNeedsForCell(cell, isMyco, useSimState: true);
        if (needed.Count == 0)
        {
            return;
        }

        var pipRadius = NeedPipRadius(cellRadius) * 0.86f;
        var offset = cellRadius + pipRadius * 0.35f;
        for (var index = 0; index < needed.Count; index++)
        {
            var need = needed[index];
            var angle = -Mathf.Pi * 0.5f + index / Mathf.Max(1.0f, needed.Count) * Mathf.Tau;
            var pipCenter = center + new Vector2(Mathf.Cos(angle), Mathf.Sin(angle)) * offset;
            var pipColor = ResourceColor(need);
            pipColor.A = 1.0f;
            if (_usingCsharpSim && SlotFullness(cell, need) <= 0.0f)
            {
                pipColor = pipColor.Darkened(0.28f) with { A = 1.0f };
            }

            DrawCircle(pipCenter, pipRadius, pipColor);
            DrawArc(pipCenter, pipRadius, 0.0f, Mathf.Tau, 20, new Color(0.01f, 0.025f, 0.03f, 0.72f), 1.8f, antialiased: true);
        }
    }

    private void DrawNeedTether(Vector2 center, Vector2 pipCenter, float cellRadius, float pipRadius, Color color)
    {
        var delta = pipCenter - center;
        if (delta.LengthSquared() <= 1.0f)
        {
            return;
        }

        var direction = delta.Normalized();
        DrawLine(center + direction * (cellRadius * 0.78f), pipCenter - direction * (pipRadius * 0.72f), color, 2.0f, antialiased: true);
    }

    private void DrawResourceMark(Font font, Vector2 center, float radius, string resource, int fontSize, Color color)
    {
        var mark = ResourceMarkText(resource);
        if (string.IsNullOrEmpty(mark))
        {
            return;
        }

        DrawCenteredBoldResource(font, center, radius, mark, fontSize, color);
    }

    private void DrawFastResourceMark(Font font, Vector2 center, float radius, string resource, int fontSize, Color color)
    {
        var mark = ResourceMarkText(resource);
        if (string.IsNullOrEmpty(mark))
        {
            return;
        }

        var adjustedSize = fontSize;
        if (mark.Length > 1)
        {
            adjustedSize = Mathf.Max(8, Mathf.RoundToInt(fontSize / (mark.Length * 0.72f)));
        }

        var width = radius * 2.0f;
        var origin = new Vector2(center.X - radius, center.Y + adjustedSize * 0.35f);
        DrawString(font, origin + new Vector2(1.4f, 1.4f) * NeedPipMarkWeightScale, mark, HorizontalAlignment.Center, width, adjustedSize, new Color(0.01f, 0.025f, 0.03f, 0.78f * color.A));
        DrawString(font, origin, mark, HorizontalAlignment.Center, width, adjustedSize, color);
        DrawString(font, origin + new Vector2(0.7f * NeedPipMarkWeightScale, 0.0f), mark, HorizontalAlignment.Center, width, adjustedSize, color);
    }

    private string ResourceMarkText(string resource)
    {
        if (_resourceMarkMode == 2)
        {
            return "";
        }

        if (_resourceMarkMode == 1)
        {
            var index = ResourceIndex(resource);
            if (index >= 0 && index < ResourceSymbolMarks.Length)
            {
                return ResourceSymbolMarks[index];
            }
        }

        return resource;
    }

    private void DrawCenteredBoldResource(Font font, Vector2 center, float radius, string text, int fontSize, Color color)
    {
        if (string.IsNullOrEmpty(text))
        {
            return;
        }

        var adjustedSize = fontSize;
        if (text.Length > 1)
        {
            adjustedSize = Mathf.Max(8, Mathf.RoundToInt(fontSize / (text.Length * 0.72f)));
        }

        var width = radius * 2.0f;
        var origin = new Vector2(center.X - radius, center.Y + adjustedSize * 0.35f);
        var outline = new Color(0.01f, 0.025f, 0.03f, 0.86f * color.A);
        Span<Vector2> outlineOffsets =
        [
            new(-1.5f, 0.0f),
            new(1.5f, 0.0f),
            new(0.0f, -1.5f),
            new(0.0f, 1.5f)
        ];

        foreach (var offset in outlineOffsets)
        {
            DrawString(font, origin + offset, text, HorizontalAlignment.Center, width, adjustedSize, outline);
        }

        Span<Vector2> weightOffsets =
        [
            Vector2.Zero,
            new(0.75f, 0.0f),
            new(-0.75f, 0.0f)
        ];

        foreach (var offset in weightOffsets)
        {
            DrawString(font, origin + offset, text, HorizontalAlignment.Center, width, adjustedSize, color);
        }
    }

    private void DrawFullnessArc(Vector2 center, float radius, float fullness, Color color, float width)
    {
        var amount = Mathf.Clamp(fullness, 0.0f, 1.0f);
        var segments = FullnessArcSegments(radius);
        DrawArc(center, radius, -Mathf.Pi * 0.5f, Mathf.Pi * 1.5f, segments, new Color(0.0f, 0.0f, 0.0f, 0.34f), width, antialiased: true);
        if (amount <= 0.0f)
        {
            return;
        }

        DrawArc(center, radius, -Mathf.Pi * 0.5f, -Mathf.Pi * 0.5f + Mathf.Tau * amount, segments, color.Lightened(0.26f) with { A = 0.92f }, width, antialiased: true);
    }

    private void DrawZeroPipPulseArc(Vector2 center, float radius, float width)
    {
        var alpha = ZeroPipPulseAlpha();
        if (alpha <= 0.0f)
        {
            return;
        }

        var segments = FullnessArcSegments(radius * ZeroPipPulseGlowScale);
        DrawArc(center, radius * ZeroPipPulseGlowScale, -Mathf.Pi * 0.5f, Mathf.Pi * 1.5f, segments, ZeroPipPulseColor with { A = Mathf.Min(1.0f, 0.58f * ZeroPipPulseBrightnessScale * alpha) }, (width + 1.2f) * ZeroPipPulseGlowScale, antialiased: true);
        DrawArc(center, radius * 1.08f * ZeroPipPulseGlowScale, -Mathf.Pi * 0.5f, Mathf.Pi * 1.5f, segments, ZeroPipPulseColor with { A = Mathf.Min(1.0f, 0.22f * ZeroPipPulseBrightnessScale * alpha) }, Mathf.Max(1.4f, width * 0.55f) * ZeroPipPulseGlowScale, antialiased: true);
    }

    private static float ZeroPipPulseAlpha()
    {
        var phase = Time.GetTicksMsec() % ZeroPipPulsePeriodMsec;
        if (phase < ZeroPipPulseFadeMsec)
        {
            return phase / (float)ZeroPipPulseFadeMsec;
        }

        if (phase < ZeroPipPulseFadeMsec * 2)
        {
            return 1.0f - (phase - ZeroPipPulseFadeMsec) / (float)ZeroPipPulseFadeMsec;
        }

        return 0.0f;
    }

    private float ClearingAlpha()
    {
        var fadeProgress = Mathf.Clamp((_clearEffectProgress - 0.18f) / 0.82f, 0.0f, 1.0f);
        return Mathf.Clamp(1.0f - Mathf.Pow(fadeProgress, 1.35f), 0.0f, 1.0f);
    }

    private float ClearingFlash() =>
        Mathf.Clamp(1.0f - Mathf.Abs(_clearEffectProgress - 0.18f) / 0.18f, 0.0f, 1.0f);

    private void UpdateFrameBlend()
    {
        var now = Time.GetTicksMsec();
        if (_lastDrawMsec == 0)
        {
            _lastDrawMsec = now;
            _frameBlend = 1.0f;
            return;
        }

        var deltaSeconds = Mathf.Clamp((now - _lastDrawMsec) / 1000.0f, 0.0f, 0.10f);
        _lastDrawMsec = now;
        _frameBlend = 1.0f - Mathf.Exp(-deltaSeconds * 18.0f);
    }

    private float DisplayedFullness(string cell, string resource, float target)
    {
        var key = $"{cell}:{resource}";
        target = Mathf.Clamp(target, 0.0f, 1.0f);
        if (!_displayFullness.TryGetValue(key, out var current))
        {
            _displayFullness[key] = target;
            return target;
        }

        var next = Mathf.Lerp(current, target, _frameBlend);
        if (Mathf.Abs(next - target) < 0.0025f)
        {
            next = target;
        }

        _displayFullness[key] = next;
        return next;
    }

    private static int ArcSegments(float radius) => radius < 14.0f ? 16 : radius < 28.0f ? 24 : 36;

    private static int FullnessArcSegments(float radius) => radius < 14.0f ? 12 : radius < 28.0f ? 16 : 24;

    private NeedVisual NeedVisualData(
        string cell,
        string need,
        int index,
        int count,
        Vector2 center,
        float cellRadius,
        float pipRadius,
        List<float> usedAngles,
        bool applySmoothing,
        bool useSimState = true)
    {
        var state = NeedStateData(cell, need, useSimState);
        state = state with { Partner = StabilizeNeedPartner(cell, need, state.Partner, state.State) };
        var baseAngle = BaseNeedAngle(cell, need, index, count, center, state.Partner);
        var targetAngle = SeparateNeedAngle(baseAngle, usedAngles);
        var targetOffset = NeedPipOffsetForState(center, state.Partner, cellRadius, pipRadius, state.State);
        var key = $"{cell}:{need}";
        var angle = applySmoothing ? SmoothPipAngle(key, targetAngle) : targetAngle;
        var offset = applySmoothing ? SmoothPipOffset(key, targetOffset) : targetOffset;
        return state with { Angle = angle, Offset = offset, TargetAngle = targetAngle };
    }

    private NeedVisual NeedStateData(string cell, string need, bool useSimState)
    {
        var preferredPartner = PreferredNeedPartner(cell, need);
        if (!string.IsNullOrEmpty(preferredPartner))
        {
            return new NeedVisual(NeedStateAvailable, preferredPartner, 1.0f, 0.0f);
        }

        var useLiveSimState = useSimState && _usingCsharpSim;
        var fullness = useLiveSimState ? SlotFullness(cell, need) : 0.0f;
        var activePartner = useLiveSimState ? RecentFlowSourceForNeed(cell, need) : "";
        var activeAlpha = useLiveSimState ? RecentFlowAlphaForNeed(cell, need) : 0.0f;
        if (useLiveSimState && string.IsNullOrEmpty(activePartner))
        {
            activePartner = RecentSwapPartnerForNeed(cell, need);
        }

        if (useLiveSimState && !string.IsNullOrEmpty(activePartner))
        {
            return new NeedVisual(NeedStateActive, activePartner, Mathf.Max(fullness, 0.18f), Mathf.Max(activeAlpha, 0.45f));
        }

        var possiblePartner = useLiveSimState ? PossibleSwapPartnerForNeed(cell, need) : "";
        if (string.IsNullOrEmpty(possiblePartner) && useSimState && !useLiveSimState)
        {
            possiblePartner = AdjacentReciprocalPartnerForNeed(cell, need);
        }

        if (string.IsNullOrEmpty(possiblePartner) && useLiveSimState)
        {
            possiblePartner = AdjacentExchangePartnerForNeed(cell, need);
        }

        if (!string.IsNullOrEmpty(possiblePartner))
        {
            return new NeedVisual(NeedStateAvailable, possiblePartner, fullness, 0.0f);
        }

        if (fullness > 0.0f)
        {
            return new NeedVisual(NeedStateSatisfied, "", fullness, 0.0f);
        }

        return new NeedVisual(NeedStateMissing, "", 0.0f, 0.0f);
    }

    private string StabilizeNeedPartner(string cell, string need, string proposedPartner, string state)
    {
        var key = $"{cell}:{need}";
        if (!string.IsNullOrEmpty(proposedPartner) && IsPreferredNeedPartner(cell, need, proposedPartner))
        {
            _pipPartners[key] = proposedPartner;
            return proposedPartner;
        }

        if (_pipPartners.TryGetValue(key, out var currentPartner)
            && !string.IsNullOrEmpty(currentPartner)
            && currentPartner != proposedPartner
            && IsUsableNeedPartner(cell, need, currentPartner))
        {
            if (!string.IsNullOrEmpty(proposedPartner)
                || state == NeedStateSatisfied
                || state == NeedStateActive
                || state == NeedStateAvailable)
            {
                return currentPartner;
            }
        }

        if (!string.IsNullOrEmpty(proposedPartner) && IsAdjacent(cell, proposedPartner))
        {
            _pipPartners[key] = proposedPartner;
            return proposedPartner;
        }

        _pipPartners.Remove(key);
        return "";
    }

    private bool IsUsableNeedPartner(string cell, string need, string partner) =>
        IsPreferredNeedPartner(cell, need, partner)
        || IsAdjacent(cell, partner)
        && (CellProducedResource(partner) == need
            || CellCanOfferResourceTo(partner, need, cell)
            || RecentFlowSourceForNeed(cell, need) == partner
            || RecentSwapPartnerForNeed(cell, need) == partner);

    private bool IsAdjacent(string a, string b) =>
        !string.IsNullOrEmpty(a)
        && !string.IsNullOrEmpty(b)
        && _positions.ContainsKey(a)
        && _positions.ContainsKey(b)
        && GetCellTile(a).DistanceSquaredTo(GetCellTile(b)) == 1;

    private float BaseNeedAngle(string cell, string need, int index, int count, Vector2 center, string partner)
    {
        if (!string.IsNullOrEmpty(partner))
        {
            var delta = VisualCellCenter(partner) - center;
            if (delta.LengthSquared() > 1.0f)
            {
                return delta.Angle();
            }
        }

        if (!_usingCsharpSim)
        {
            var reciprocalPartner = AdjacentReciprocalPartnerForNeed(cell, need);
            if (!string.IsNullOrEmpty(reciprocalPartner))
            {
                var delta = VisualCellCenter(reciprocalPartner) - center;
                if (delta.LengthSquared() > 1.0f)
                {
                    return delta.Angle();
                }
            }
        }

        return -Mathf.Pi * 0.5f + index / Mathf.Max(1.0f, count) * Mathf.Tau;
    }

    private float SeparateNeedAngle(float baseAngle, List<float> usedAngles)
    {
        if (usedAngles.Count == 0)
        {
            return baseAngle;
        }

        const float minimumGap = 0.58f;
        Span<float> offsets = [0.0f, minimumGap, -minimumGap, minimumGap * 2.0f, -minimumGap * 2.0f];
        foreach (var offset in offsets)
        {
            var candidate = baseAngle + offset;
            var separated = true;
            foreach (var used in usedAngles)
            {
                if (Mathf.Abs(Mathf.Wrap(candidate - used, -Mathf.Pi, Mathf.Pi)) < minimumGap)
                {
                    separated = false;
                    break;
                }
            }

            if (separated)
            {
                return candidate;
            }
        }

        return baseAngle;
    }

    private float NeedPipOffsetForState(Vector2 center, string partner, float cellRadius, float pipRadius, string state)
    {
        if (string.IsNullOrEmpty(partner))
        {
            return state == NeedStateSatisfied ? cellRadius + pipRadius * 0.10f : cellRadius + pipRadius * 0.55f;
        }

        return NeedPipOffset(center, partner, cellRadius, pipRadius);
    }

    private float NeedPipOffset(Vector2 center, string partner, float cellRadius, float pipRadius)
    {
        if (string.IsNullOrEmpty(partner))
        {
            return cellRadius + pipRadius * 0.30f;
        }

        var centerDistance = (VisualCellCenter(partner) - center).Length();
        if (centerDistance <= 1.0f)
        {
            return cellRadius + pipRadius * 0.30f;
        }

        var rimOffset = cellRadius + pipRadius * 0.08f;
        var maximumOffset = Mathf.Max(rimOffset, centerDistance * 0.5f - pipRadius * 0.58f);
        return Mathf.Min(rimOffset, maximumOffset);
    }

    private float SmoothPipAngle(string key, float targetAngle)
    {
        if (!_pipAngles.TryGetValue(key, out var current))
        {
            _pipAngles[key] = targetAngle;
            return targetAngle;
        }

        var smoothed = current + Mathf.Wrap(targetAngle - current, -Mathf.Pi, Mathf.Pi) * PipAngleSmooth;
        _pipAngles[key] = smoothed;
        return smoothed;
    }

    private float SmoothPipOffset(string key, float targetOffset)
    {
        if (!_pipOffsets.TryGetValue(key, out var current))
        {
            _pipOffsets[key] = targetOffset;
            return targetOffset;
        }

        var smoothed = Mathf.Lerp(current, targetOffset, PipOffsetSmooth);
        _pipOffsets[key] = smoothed;
        return smoothed;
    }

    private Vector2 ResourceVisualPoint(string cell, string resource)
    {
        var center = VisualCellCenter(cell);
        var isMyco = IsMycoCell(cell);
        var needed = VisualNeedsForCell(cell, isMyco, useSimState: true);
        if (!ContainsResource(needed, resource))
        {
            return center;
        }

        return NeedPipCenterForResource(cell, resource, center, needed);
    }

    private Vector2 NeedPipCenterForResource(string cell, string resource, Vector2 center, List<string> needed)
    {
        var radius = _tileSize * (cell == _dragCell ? 0.43f : 0.39f);
        var pipRadius = NeedPipRadius(radius);
        var usedAngles = new List<float>(needed.Count);
        for (var i = 0; i < needed.Count; i++)
        {
            var need = needed[i];
            var visual = NeedVisualData(cell, need, i, needed.Count, center, radius, pipRadius, usedAngles, applySmoothing: false);
            usedAngles.Add(visual.TargetAngle);
            if (need != resource)
            {
                continue;
            }

            var key = $"{cell}:{need}";
            if (_pipAngles.TryGetValue(key, out var storedAngle) && _pipOffsets.TryGetValue(key, out var storedOffset))
            {
                return center + new Vector2(Mathf.Cos(storedAngle), Mathf.Sin(storedAngle)) * storedOffset;
            }

            return center + new Vector2(Mathf.Cos(visual.Angle), Mathf.Sin(visual.Angle)) * visual.Offset;
        }

        return center;
    }

    private float NeedPipRadius(float cellRadius) => Mathf.Max(5.5f, Mathf.Min(cellRadius * 0.38f, _tileSize * 0.15f));

    private string RecentFlowSourceForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return "";
        }

        return _recentFlowByNeed.TryGetValue(NeedLookupKey(cell, need), out var flow)
            ? flow.SourceCell
            : "";
    }

    private float RecentFlowAlphaForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return 0.0f;
        }

        return _recentFlowByNeed.TryGetValue(NeedLookupKey(cell, need), out var flow)
            ? flow.Alpha
            : 0.0f;
    }

    private string RecentSwapPartnerForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return "";
        }

        return _recentSwapPartnerByNeed.GetValueOrDefault(NeedLookupKey(cell, need), "");
    }

    private string PossibleSwapPartnerForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return "";
        }

        return _possibleSwapPartnerByNeed.GetValueOrDefault(NeedLookupKey(cell, need), "");
    }

    private string AdjacentReciprocalPartnerForNeed(string cell, string need)
    {
        foreach (var other in _cells)
        {
            if (other == cell || GetCellTile(cell).DistanceSquaredTo(GetCellTile(other)) != 1)
            {
                continue;
            }

            if (CellProducedResource(other) == need && CellNeedsResource(other, CellProducedResource(cell)))
            {
                return other;
            }
        }

        return "";
    }

    private string AdjacentExchangePartnerForNeed(string cell, string need)
    {
        foreach (var other in _cells)
        {
            if (other == cell || GetCellTile(cell).DistanceSquaredTo(GetCellTile(other)) != 1)
            {
                continue;
            }

            if (CellCanOfferResourceTo(other, need, cell) && CellHasPayableResourceFor(other, cell))
            {
                return other;
            }
        }

        return "";
    }

    private bool CellHasPayableResourceFor(string cell, string other)
    {
        var produced = CellProducedResource(cell);
        if (!string.IsNullOrEmpty(produced) && CellAcceptsResource(other, produced))
        {
            return true;
        }

        if (!_cellStates.TryGetValue(cell, out var state))
        {
            return false;
        }

        foreach (var (resource, slot) in state.Slots)
        {
            if (CellAcceptsResource(other, resource) && SlotOfferableQuantity(cell, resource) > 0)
            {
                return true;
            }
        }

        return false;
    }

    private bool CellCanOfferResourceTo(string cell, string resource, string other)
    {
        if (CellProducedResource(cell) == resource && CellAcceptsResource(other, resource))
        {
            return true;
        }

        return CellAcceptsResource(other, resource) && SlotOfferableQuantity(cell, resource) > 0;
    }

    private bool CellAcceptsResource(string cell, string resource)
    {
        if (CellProducedResource(cell) == resource || CellNeedsResource(cell, resource))
        {
            return true;
        }

        return _cellStates.TryGetValue(cell, out var state) && state.Slots.ContainsKey(resource);
    }

    private int SlotOfferableQuantity(string cell, string resource)
    {
        if (!_cellStates.TryGetValue(cell, out var state) || !state.Slots.TryGetValue(resource, out var slot))
        {
            return 0;
        }

        var quantity = slot.Quantity;
        if (IsMycoCell(cell))
        {
            return Math.Max(0, quantity);
        }

        if (slot.Role is "Need" or "SourceOutput")
        {
            quantity -= 1;
        }

        return Math.Max(0, quantity);
    }

    private bool CellHasAllNeeds(string cell)
    {
        var needed = _needs.GetValueOrDefault(cell) ?? [];
        foreach (var need in needed)
        {
            if (_usingCsharpSim)
            {
                if (SlotFullness(cell, need) <= 0.0f)
                {
                    return false;
                }
            }
            else if (string.IsNullOrEmpty(PreferredNeedPartner(cell, need)) && string.IsNullOrEmpty(AdjacentReciprocalPartnerForNeed(cell, need)))
            {
                return false;
            }
        }

        return needed.Count > 0;
    }

    private bool CellNeedsResource(string cell, string resource) =>
        _needs.TryGetValue(cell, out var needed) && needed.Contains(resource);

    private bool CellIsGlowing(string cell) =>
        _cellStates.TryGetValue(cell, out var state) && state.Glowing;

    private float SlotFullness(string cell, string resource) =>
        _cellStates.TryGetValue(cell, out var state) && state.Slots.TryGetValue(resource, out var slot)
            ? Mathf.Clamp(slot.Fullness, 0.0f, 1.0f)
            : 0.0f;

    private bool TryNeedHealth(string cell, out float health)
    {
        health = 1.0f;
        if (!_cellStates.TryGetValue(cell, out var state))
        {
            return false;
        }

        var foundNeed = false;
        foreach (var slot in state.Slots.Values)
        {
            if (slot.Role != "Need")
            {
                continue;
            }

            foundNeed = true;
            health = Mathf.Min(health, Mathf.Clamp(slot.Fullness, 0.0f, 1.0f));
        }

        return foundNeed;
    }

    private float RecentReactionAlpha(string cell)
    {
        if (!_usingCsharpSim)
        {
            return 0.0f;
        }

        var reactions = GetArray(_snapshot, "reactions");
        var currentTick = GetFloat(_snapshot, "tick", 0.0f);
        for (var i = reactions.Count - 1; i >= 0; i--)
        {
            var reaction = reactions[i].AsGodotDictionary();
            if (GetString(reaction, "cellId", "") != cell)
            {
                continue;
            }

            var age = Mathf.Max(0.0f, currentTick - GetFloat(reaction, "tick", currentTick));
            return Mathf.Clamp(1.0f - age / ReactionVisualTtlTicks, 0.0f, 1.0f);
        }

        return 0.0f;
    }

    private bool CircuitAliveNow() => _usingCsharpSim ? GetBool(_snapshot, "alive", false) : _solved;

    private Vector2 VisualCellCenter(string cell)
    {
        if (cell == _dragCell)
        {
            return _dragPosition;
        }

        if (cell == _inventoryDragCell)
        {
            return _inventoryDragPosition;
        }

        if (_overrideCellCenters.TryGetValue(cell, out var overrideCenter))
        {
            return overrideCenter;
        }

        return _inventoryCenters.TryGetValue(cell, out var center) ? InventoryVisualCenter(center) : TileCenter(GetCellTile(cell));
    }

    private Vector2 InventoryVisualCenter(Vector2 center) => center + new Vector2(0.0f, _tileSize * InventoryCellYOffset);

    private float CellVisualScale(string cell) => _overrideCellScales.GetValueOrDefault(cell, 1.0f);

    private string PreferredNeedPartner(string cell, string need)
    {
        if (!_preferredNeedPartners.TryGetValue(cell, out var needs))
        {
            return "";
        }

        var partner = needs.GetValueOrDefault(need, "");
        return !string.IsNullOrEmpty(partner) && _cells.Contains(partner) ? partner : "";
    }

    private bool IsPreferredNeedPartner(string cell, string need, string partner) =>
        !string.IsNullOrEmpty(partner) && PreferredNeedPartner(cell, need) == partner;

    private float InventoryFreshStrength(string cell)
    {
        if (!_inventoryFreshStarts.TryGetValue(cell, out var start))
        {
            return 0.0f;
        }

        var now = Time.GetTicksMsec();
        var elapsed = now > start ? (float)(now - start) / 1000.0f : 0.0f;
        return Mathf.Clamp(1.0f - elapsed / 1.55f, 0.0f, 1.0f);
    }

    private Vector2I GetCellTile(string cell) => _positions.GetValueOrDefault(cell);

    private Vector2 TileCenter(Vector2I tile) => _boardRect.Position + (new Vector2(tile.X, tile.Y) + new Vector2(0.5f, 0.5f)) * _tileSize;

    private Rect2 TileRect(Vector2I tile) => new(_boardRect.Position + new Vector2(tile.X, tile.Y) * _tileSize, new Vector2(_tileSize, _tileSize));

    private int VisibleMinX() => Mathf.Clamp(Mathf.FloorToInt((_boardViewportRect.Position.X - _boardRect.Position.X) / Mathf.Max(_tileSize, 1.0f)) - 1, 0, Math.Max(0, _boardCols - 1));

    private int VisibleMaxX() => Mathf.Clamp(Mathf.CeilToInt((_boardViewportRect.Position.X + _boardViewportRect.Size.X - _boardRect.Position.X) / Mathf.Max(_tileSize, 1.0f)) + 1, 0, Math.Max(0, _boardCols - 1));

    private int VisibleMinY() => Mathf.Clamp(Mathf.FloorToInt((_boardViewportRect.Position.Y - _boardRect.Position.Y) / Mathf.Max(_tileSize, 1.0f)) - 1, 0, Math.Max(0, _boardRows - 1));

    private int VisibleMaxY() => Mathf.Clamp(Mathf.CeilToInt((_boardViewportRect.Position.Y + _boardViewportRect.Size.Y - _boardRect.Position.Y) / Mathf.Max(_tileSize, 1.0f)) + 1, 0, Math.Max(0, _boardRows - 1));

    private bool RectIntersectsViewport(Rect2 rect, float grow = 0.0f) => _boardViewportRect.Grow(grow).Intersects(rect, true);

    private bool PointIntersectsViewport(Vector2 point, float radius) => _boardViewportRect.Grow(radius).HasPoint(point);

    private bool LineIntersectsViewport(Vector2 start, Vector2 finish, float grow)
    {
        var min = new Vector2(Mathf.Min(start.X, finish.X), Mathf.Min(start.Y, finish.Y));
        var max = new Vector2(Mathf.Max(start.X, finish.X), Mathf.Max(start.Y, finish.Y));
        return RectIntersectsViewport(new Rect2(min, max - min).Grow(grow), 0.0f);
    }

    private Vector2I ScreenToTile(Vector2 screenPosition)
    {
        var local = screenPosition - _boardRect.Position;
        return new Vector2I(Mathf.FloorToInt(local.X / _tileSize), Mathf.FloorToInt(local.Y / _tileSize));
    }

    private bool IsTileInside(Vector2I tile) => tile.X >= 0 && tile.Y >= 0 && tile.X < _boardCols && tile.Y < _boardRows;

    private bool IsTileEmpty(Vector2I tile)
    {
        if (_rocks.Contains(tile))
        {
            return false;
        }

        foreach (var cell in _cells)
        {
            if (cell == _dragCell)
            {
                continue;
            }

            if (GetCellTile(cell) == tile)
            {
                return false;
            }
        }

        return true;
    }

    private string CellProducedResource(string cell) =>
        IsMycoCell(cell) ? "" : _producedByCell.GetValueOrDefault(cell, cell);

    private string CellKindFor(string cell)
    {
        if (_cellKinds.TryGetValue(cell, out var kind))
        {
            return kind;
        }

        return _cellStates.TryGetValue(cell, out var state) ? state.Kind : CellKindStandard;
    }

    private bool IsMycoCell(string cell) => IsMycoKind(CellKindFor(cell));

    private static bool IsMycoKind(string kind) => kind is CellKindWhiteMyco or CellKindRedMyco;

    private Color ResourceColor(string resource)
    {
        var index = ResourceIndex(resource);
        if (index < 0)
        {
            return new Color(0.80f, 0.86f, 0.86f, 1.0f);
        }

        return ResourceColors[index % ResourceColors.Length];
    }

    private static int ResourceIndex(string resource)
    {
        if (resource.Length == 1)
        {
            var ch = resource[0];
            if (ch is >= 'A' and <= 'Z')
            {
                return ch - 'A';
            }
        }

        if (resource.Length > 1 && resource[0] == 'R' && int.TryParse(resource[1..], out var numbered))
        {
            return numbered;
        }

        return -1;
    }

    private bool FlowGroupContainsAllCells(List<string> cells)
    {
        if (cells.Count < _cells.Count)
        {
            return false;
        }

        var set = cells.ToHashSet(StringComparer.Ordinal);
        foreach (var cell in _cells)
        {
            if (!set.Contains(cell))
            {
                return false;
            }
        }

        return true;
    }

    private static float CircuitAgeAlpha(float age, float windowTicks)
    {
        var raw = Mathf.Clamp(1.0f - age / Mathf.Max(1.0f, windowTicks), 0.0f, 1.0f);
        return Mathf.Pow(raw, 1.65f);
    }

    private void ReadCells(GdDictionary state)
    {
        _cells.Clear();
        foreach (var cell in GetArray(state, "cells"))
        {
            _cells.Add(cell.AsString());
        }
    }

    private void ReadInventoryCells(GdDictionary state)
    {
        _inventoryCells.Clear();
        foreach (var cell in GetArray(state, "inventoryCells"))
        {
            _inventoryCells.Add(cell.AsString());
        }
    }

    private void ReadPositions(GdDictionary state)
    {
        _positions.Clear();
        var positions = GetDictionary(state, "positions");
        foreach (var keyVariant in positions.Keys)
        {
            var key = keyVariant.AsString();
            _positions[key] = positions[keyVariant].AsVector2I();
        }
    }

    private void ReadOverrideCellCenters(GdDictionary state)
    {
        _overrideCellCenters.Clear();
        var centers = GetDictionary(state, "overrideCellCenters");
        foreach (var keyVariant in centers.Keys)
        {
            _overrideCellCenters[keyVariant.AsString()] = centers[keyVariant].AsVector2();
        }
    }

    private void ReadOverrideCellScales(GdDictionary state)
    {
        _overrideCellScales.Clear();
        var scales = GetDictionary(state, "overrideCellScales");
        foreach (var keyVariant in scales.Keys)
        {
            _overrideCellScales[keyVariant.AsString()] = (float)scales[keyVariant].AsDouble();
        }
    }

    private void ReadInventoryCenters(GdDictionary state)
    {
        _inventoryCenters.Clear();
        var centers = GetDictionary(state, "inventoryCenters");
        foreach (var keyVariant in centers.Keys)
        {
            _inventoryCenters[keyVariant.AsString()] = centers[keyVariant].AsVector2();
        }
    }

    private void ReadInventoryFreshStarts(GdDictionary state)
    {
        _inventoryFreshStarts.Clear();
        var starts = GetDictionary(state, "inventoryFreshStarts");
        foreach (var keyVariant in starts.Keys)
        {
            var value = starts[keyVariant].AsInt64();
            if (value > 0)
            {
                _inventoryFreshStarts[keyVariant.AsString()] = (ulong)value;
            }
        }
    }

    private void ReadClearingCells(GdDictionary state)
    {
        _clearingCells.Clear();
        foreach (var cell in GetArray(state, "clearingCells"))
        {
            _clearingCells.Add(cell.AsString());
        }
    }

    private void ReadRocks(GdDictionary state)
    {
        _rocks.Clear();
        var rocks = GetDictionary(state, "rocks");
        foreach (var keyVariant in rocks.Keys)
        {
            if (TryParseTileKey(keyVariant.AsString(), out var tile))
            {
                _rocks.Add(tile);
            }
        }
    }

    private void ReadProduced(GdDictionary state)
    {
        _producedByCell.Clear();
        var produced = GetDictionary(state, "producedByCell");
        foreach (var keyVariant in produced.Keys)
        {
            _producedByCell[keyVariant.AsString()] = produced[keyVariant].AsString();
        }
    }

    private void ReadCellKinds(GdDictionary state)
    {
        _cellKinds.Clear();
        var kinds = GetDictionary(state, "cellKinds");
        foreach (var keyVariant in kinds.Keys)
        {
            _cellKinds[keyVariant.AsString()] = kinds[keyVariant].AsString();
        }
    }

    private void ReadNeeds(GdDictionary state)
    {
        _needs.Clear();
        var needs = GetDictionary(state, "needs");
        foreach (var keyVariant in needs.Keys)
        {
            var cell = keyVariant.AsString();
            var list = new List<string>();
            foreach (var need in needs[keyVariant].AsGodotArray())
            {
                list.Add(need.AsString());
            }

            _needs[cell] = list;
        }
    }

    private void ReadPreferredNeedPartners(GdDictionary state)
    {
        _preferredNeedPartners.Clear();
        var preferred = GetDictionary(state, "preferredNeedPartners");
        foreach (var cellVariant in preferred.Keys)
        {
            var cell = cellVariant.AsString();
            var partnerByNeed = new Dictionary<string, string>(StringComparer.Ordinal);
            var needs = preferred[cellVariant].AsGodotDictionary();
            foreach (var needVariant in needs.Keys)
            {
                var need = needVariant.AsString();
                var partner = needs[needVariant].AsString();
                if (!string.IsNullOrEmpty(need) && !string.IsNullOrEmpty(partner))
                {
                    partnerByNeed[need] = partner;
                }
            }

            if (partnerByNeed.Count > 0)
            {
                _preferredNeedPartners[cell] = partnerByNeed;
            }
        }
    }

    private void ReadCellStates()
    {
        _cellStates.Clear();
        var cells = GetArray(_snapshot, "cells");
        foreach (var cellVariant in cells)
        {
            var cell = cellVariant.AsGodotDictionary();
            var id = GetString(cell, "id", "");
            if (string.IsNullOrEmpty(id))
            {
                continue;
            }

            var kind = GetString(cell, "kind", CellKindStandard);
            _cellKinds.TryAdd(id, kind);
            var state = new CellVisualState
            {
                Kind = kind,
                Glowing = GetBool(cell, "glowing", false)
            };
            foreach (var slotVariant in GetArray(cell, "slots"))
            {
                var slot = slotVariant.AsGodotDictionary();
                var resource = GetString(slot, "resource", "");
                if (string.IsNullOrEmpty(resource))
                {
                    continue;
                }

                state.Slots[resource] = new SlotVisualState(
                    GetString(slot, "role", ""),
                    GetInt(slot, "quantity", 0),
                    GetFloat(slot, "fullness", 0.0f));
                if (state.Slots[resource].Role == "Need")
                {
                    state.NeedSlotResources.Add(resource);
                }
            }

            _cellStates[id] = state;
        }
    }

    private void RebuildSnapshotIndexes()
    {
        _recentFlowByNeed.Clear();
        _recentSwapPartnerByNeed.Clear();
        _possibleSwapPartnerByNeed.Clear();
        _visibleRecentFlows.Clear();
        if (!_usingCsharpSim)
        {
            return;
        }

        var currentTick = GetFloat(_snapshot, "tick", 0.0f);
        var flows = GetArray(_snapshot, "flows");
        var visibleFlowKeys = new HashSet<string>(StringComparer.Ordinal);
        for (var i = flows.Count - 1; i >= 0; i--)
        {
            var flow = flows[i].AsGodotDictionary();
            var target = GetString(flow, "targetCellId", "");
            var source = GetString(flow, "sourceCellId", "");
            var resource = GetString(flow, "resource", "");
            if (string.IsNullOrEmpty(target) || string.IsNullOrEmpty(source) || string.IsNullOrEmpty(resource))
            {
                continue;
            }

            var age = Mathf.Max(0.0f, currentTick - GetFloat(flow, "tick", currentTick));
            var alpha = Mathf.Clamp(1.0f - age / SwapVisualTtlTicks, 0.0f, 1.0f);

            var lineKey = NeedLookupKey(NeedLookupKey(source, target), resource);
            if (alpha > 0.0f && _visibleRecentFlows.Count < MaxVisibleFlowLines && visibleFlowKeys.Add(lineKey))
            {
                _visibleRecentFlows.Add(new RecentFlowLineVisual(source, target, resource, age, alpha));
            }

            var key = NeedLookupKey(target, resource);
            if (!_recentFlowByNeed.ContainsKey(key))
            {
                _recentFlowByNeed[key] = new RecentFlowVisual(source, alpha);
            }
        }

        var swaps = GetArray(_snapshot, "swaps");
        for (var i = swaps.Count - 1; i >= 0; i--)
        {
            var swap = swaps[i].AsGodotDictionary();
            IndexSwapPartner(_recentSwapPartnerByNeed, swap, overwrite: false);
        }

        var possibleSwaps = GetArray(_snapshot, "possibleSwaps");
        foreach (var swapVariant in possibleSwaps)
        {
            IndexSwapPartner(_possibleSwapPartnerByNeed, swapVariant.AsGodotDictionary(), overwrite: false);
        }
    }

    private static void IndexSwapPartner(Dictionary<string, string> index, GdDictionary swap, bool overwrite)
    {
        var initiator = GetString(swap, "initiator", "");
        var counterparty = GetString(swap, "counterparty", "");
        if (string.IsNullOrEmpty(initiator) || string.IsNullOrEmpty(counterparty))
        {
            return;
        }

        var initiatorReceived = GetString(swap, "counterpartyPaidResource", "");
        if (!string.IsNullOrEmpty(initiatorReceived))
        {
            var key = NeedLookupKey(initiator, initiatorReceived);
            if (overwrite || !index.ContainsKey(key))
            {
                index[key] = counterparty;
            }
        }

        var counterpartyReceived = GetString(swap, "initiatorPaidResource", "");
        if (!string.IsNullOrEmpty(counterpartyReceived))
        {
            var key = NeedLookupKey(counterparty, counterpartyReceived);
            if (overwrite || !index.ContainsKey(key))
            {
                index[key] = initiator;
            }
        }
    }

    private static string NeedLookupKey(string cell, string resource) => $"{cell}\0{resource}";

    private static List<string> StringsFromArray(GdArray array)
    {
        var result = new List<string>(array.Count);
        foreach (var item in array)
        {
            result.Add(item.AsString());
        }

        result.Sort(StringComparer.Ordinal);
        return result;
    }

    private static string GetString(GdDictionary dictionary, string key, string fallback) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsString() : fallback;

    private static int GetInt(GdDictionary dictionary, string key, int fallback) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsInt32() : fallback;

    private static float GetFloat(GdDictionary dictionary, string key, float fallback) =>
        dictionary.ContainsKey(key) ? (float)dictionary[key].AsDouble() : fallback;

    private static bool GetBool(GdDictionary dictionary, string key, bool fallback) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsBool() : fallback;

    private static Rect2 GetRect2(GdDictionary dictionary, string key, Rect2 fallback) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsRect2() : fallback;

    private static Vector2 GetVector2(GdDictionary dictionary, string key, Vector2 fallback) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsVector2() : fallback;

    private static Vector2I GetVector2I(GdDictionary dictionary, string key, Vector2I fallback) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsVector2I() : fallback;

    private static bool TryParseTileKey(string key, out Vector2I tile)
    {
        tile = Vector2I.Zero;
        var separator = key.IndexOf(':', StringComparison.Ordinal);
        if (separator <= 0 || separator + 1 >= key.Length)
        {
            return false;
        }

        if (!int.TryParse(key[..separator], out var x) || !int.TryParse(key[(separator + 1)..], out var y))
        {
            return false;
        }

        tile = new Vector2I(x, y);
        return true;
    }

    private static GdArray GetArray(GdDictionary dictionary, string key) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsGodotArray() : [];

    private static GdDictionary GetDictionary(GdDictionary dictionary, string key) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsGodotDictionary() : new GdDictionary();

    private sealed class CellVisualState
    {
        public string Kind { get; init; } = CellKindStandard;
        public bool Glowing { get; init; }

        public Dictionary<string, SlotVisualState> Slots { get; } = new(StringComparer.Ordinal);
        public List<string> NeedSlotResources { get; } = [];
    }

    private sealed record SlotVisualState(string Role, int Quantity, float Fullness);

    private sealed record RecentFlowVisual(string SourceCell, float Alpha);

    private sealed record RecentFlowLineVisual(string SourceCell, string TargetCell, string Resource, float AgeTicks, float Alpha);

    private sealed record MycoPipVisualState(List<string> Resources, float Progress);

    private sealed record NeedVisual(
        string State,
        string Partner,
        float Fullness,
        float ActiveAlpha,
        float Angle = 0.0f,
        float Offset = 0.0f,
        float TargetAngle = 0.0f);
}
