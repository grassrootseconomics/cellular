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

    private const string NeedStateMissing = "missing";
    private const string NeedStateAvailable = "available";
    private const string NeedStateActive = "active";
    private const string NeedStateSatisfied = "satisfied";

    private readonly List<string> _cells = [];
    private readonly Dictionary<string, Vector2I> _positions = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _producedByCell = new(StringComparer.Ordinal);
    private readonly Dictionary<string, List<string>> _needs = new(StringComparer.Ordinal);
    private readonly Dictionary<string, CellVisualState> _cellStates = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _pipAngles = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _pipOffsets = new(StringComparer.Ordinal);
    private readonly Dictionary<string, string> _pipPartners = new(StringComparer.Ordinal);
    private readonly Dictionary<string, float> _displayFullness = new(StringComparer.Ordinal);

    private GdDictionary _snapshot = new();
    private Rect2 _boardRect;
    private float _tileSize = 64.0f;
    private int _boardCols = 8;
    private int _boardRows = 8;
    private bool _usingCsharpSim;
    private bool _solved;
    private bool _circuitOverlayEnabled = true;
    private bool _fastDragMode;
    private string _dragCell = "";
    private Vector2 _dragPosition;
    private Vector2I _originalDragTile;
    private string _hintA = "";
    private string _hintB = "";
    private int _resourceMarkMode;
    private ulong _lastDrawMsec;
    private float _frameBlend = 1.0f;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        SetAnchorsPreset(LayoutPreset.FullRect);
    }

    public void set_render_state(GdDictionary state) => SetRenderState(state);

    public void SetRenderState(GdDictionary state)
    {
        _boardRect = GetRect2(state, "boardRect", _boardRect);
        _tileSize = GetFloat(state, "tileSize", _tileSize);
        _boardCols = GetInt(state, "boardCols", _boardCols);
        _boardRows = GetInt(state, "boardRows", _boardRows);
        _usingCsharpSim = GetBool(state, "usingCsharpSim", _usingCsharpSim);
        _solved = GetBool(state, "solved", _solved);
        _circuitOverlayEnabled = GetBool(state, "circuitOverlayEnabled", _circuitOverlayEnabled);
        _fastDragMode = GetBool(state, "fastDragMode", _fastDragMode);
        _dragCell = GetString(state, "dragCell", "");
        _dragPosition = GetVector2(state, "dragPosition", Vector2.Zero);
        _originalDragTile = GetVector2I(state, "originalDragTile", Vector2I.Zero);
        _resourceMarkMode = GetInt(state, "resourceMarkMode", _resourceMarkMode);

        _hintA = "";
        _hintB = "";
        var hint = GetArray(state, "hintPair");
        if (hint.Count == 2)
        {
            _hintA = hint[0].AsString();
            _hintB = hint[1].AsString();
        }

        ReadCells(state);
        ReadPositions(state);
        ReadProduced(state);
        ReadNeeds(state);
        _snapshot = GetDictionary(state, "snapshot");
        ReadCellStates();

        QueueRedraw();
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
        UpdateFrameBlend();
        DrawBoard();
        if (!_fastDragMode)
        {
            DrawCircuitFlowGroups();
            DrawRecentFlows();
        }

        DrawHint();

        foreach (var cell in _cells)
        {
            if (cell == _dragCell)
            {
                continue;
            }

            DrawCell(cell, TileCenter(GetCellTile(cell)), dragging: false);
        }

        if (!string.IsNullOrEmpty(_dragCell))
        {
            DrawCell(_dragCell, _dragPosition, dragging: true);
        }
    }

    private void DrawBoard()
    {
        DrawRect(_boardRect.Grow(10.0f), new Color(0.015f, 0.030f, 0.035f, 0.88f), filled: true);
        for (var y = 0; y < _boardRows; y++)
        {
            for (var x = 0; x < _boardCols; x++)
            {
                var rect = new Rect2(_boardRect.Position + new Vector2(x, y) * _tileSize, new Vector2(_tileSize, _tileSize)).Grow(-2.0f);
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
            var highlight = new Rect2(_boardRect.Position + new Vector2(tile.X, tile.Y) * _tileSize, new Vector2(_tileSize, _tileSize)).Grow(-3.0f);
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
                DrawLine(center, TileCenter(right), heat, connectorWidth, antialiased: true);
            }

            var down = new Vector2I(tile.X, tile.Y + 1);
            if (tiles.Contains(down))
            {
                DrawLine(center, TileCenter(down), heat, connectorWidth, antialiased: true);
            }
        }

        foreach (var tile in tiles)
        {
            DrawCircle(TileCenter(tile), heatRadius, heat);
        }

        foreach (var tile in tiles)
        {
            var origin = _boardRect.Position + new Vector2(tile.X, tile.Y) * _tileSize;
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

        var flows = GetArray(_snapshot, "flows");
        var currentTick = GetFloat(_snapshot, "tick", 0.0f);
        foreach (var flowVariant in flows)
        {
            var flow = flowVariant.AsGodotDictionary();
            var source = GetString(flow, "sourceCellId", "");
            var target = GetString(flow, "targetCellId", "");
            var resource = GetString(flow, "resource", "");
            if (string.IsNullOrEmpty(source) || string.IsNullOrEmpty(target) || string.IsNullOrEmpty(resource))
            {
                continue;
            }

            var age = Mathf.Max(0.0f, currentTick - GetFloat(flow, "tick", currentTick));
            var alpha = Mathf.Clamp(1.0f - age / SwapVisualTtlTicks, 0.0f, 1.0f);
            if (alpha <= 0.0f)
            {
                continue;
            }

            var sourcePoint = ResourceVisualPoint(source, resource);
            var targetPoint = ResourceVisualPoint(target, resource);
            var color = ResourceColor(resource);
            DrawElectricFlowLine(sourcePoint, targetPoint, color, alpha);
            var t = Mathf.Clamp(age / 2.4f, 0.0f, 1.0f);
            DrawSwapParticle(sourcePoint.Lerp(targetPoint, t), resource, alpha);
        }
    }

    private void DrawSwapParticle(Vector2 position, string resource, float alpha)
    {
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
        var hintColor = new Color(1.0f, 0.92f, 0.24f, 0.86f);
        DrawLine(a, b, new Color(1.0f, 0.92f, 0.24f, 0.34f), 9.0f, antialiased: true);
        DrawLine(a, b, hintColor, 3.0f, antialiased: true);
        DrawArc(a, _tileSize * 0.49f, 0.0f, Mathf.Tau, ArcSegments(_tileSize * 0.49f), hintColor, 5.0f, antialiased: true);
        DrawArc(b, _tileSize * 0.49f, 0.0f, Mathf.Tau, ArcSegments(_tileSize * 0.49f), hintColor, 5.0f, antialiased: true);
    }

    private void DrawCell(string cell, Vector2 center, bool dragging)
    {
        var radius = _tileSize * (dragging ? 0.43f : 0.39f);
        var produced = CellProducedResource(cell);
        var color = ResourceColor(produced);
        var detailed = !_fastDragMode || dragging;
        var liveComplete = CircuitAliveNow();
        var glowAlpha = _usingCsharpSim ? (CellIsGlowing(cell) ? 0.56f : 0.16f) : (CellHasAllNeeds(cell) ? 0.46f : 0.18f);
        if (liveComplete)
        {
            glowAlpha = 0.72f;
        }

        var reactionAlpha = RecentReactionAlpha(cell);
        if (reactionAlpha > 0.0f)
        {
            glowAlpha = Mathf.Max(glowAlpha, 0.52f + reactionAlpha * 0.28f);
            DrawCircle(center, radius * (1.22f + reactionAlpha * 0.10f), new Color(1.0f, 0.95f, 0.58f, reactionAlpha * 0.18f));
        }

        DrawCircle(center, radius * (1.16f + (liveComplete ? 0.04f : 0.0f)), new Color(color.R, color.G, color.B, glowAlpha * 0.28f));
        DrawCircle(center, radius, new Color(color.R, color.G, color.B, 0.72f));
        DrawArc(center, radius * 0.96f, 0.0f, Mathf.Tau, ArcSegments(radius), new Color(0.92f, 1.0f, 0.95f, 0.68f), 3.0f, antialiased: true);

        var font = GetThemeDefaultFont();
        if (!detailed)
        {
            DrawSimpleNeedDots(cell, center, radius);
            DrawFastResourceMark(font, center, radius, produced, Mathf.RoundToInt(radius * 1.36f), Colors.White);
            return;
        }

        if (liveComplete)
        {
            var solvedPulse = 0.5f + Mathf.Sin(Time.GetTicksMsec() / 160.0f) * 0.5f;
            DrawArc(center, radius * (1.07f + solvedPulse * 0.03f), 0.0f, Mathf.Tau, ArcSegments(radius), new Color(0.62f, 1.0f, 0.88f, 0.28f + solvedPulse * 0.18f), 3.0f, antialiased: true);
        }

        if (_usingCsharpSim)
        {
            DrawFullnessArc(center, radius * 1.07f, DisplayedFullness(cell, produced, SlotFullness(cell, produced)), color, 6.0f);
        }

        var needed = _needs.GetValueOrDefault(cell) ?? [];
        var usedAngles = new List<float>(needed.Count);
        for (var i = 0; i < needed.Count; i++)
        {
            var need = needed[i];
            var pipRadius = NeedPipRadius(radius);
            var visual = NeedVisualData(cell, need, i, needed.Count, center, radius, pipRadius, usedAngles, applySmoothing: true);
            usedAngles.Add(visual.TargetAngle);
            var pipCenter = center + new Vector2(Mathf.Cos(visual.Angle), Mathf.Sin(visual.Angle)) * visual.Offset;
            var met = visual.State != NeedStateMissing || visual.Fullness > 0.0f;
            var pipColor = ResourceColor(need);

            if (visual.State == NeedStateMissing)
            {
                pipColor = pipColor.Darkened(0.48f) with { A = 1.0f };
                DrawNeedTether(center, pipCenter, radius, pipRadius, new Color(0.75f, 0.88f, 0.90f, 0.28f));
            }
            else if (visual.State == NeedStateAvailable)
            {
                pipColor = pipColor.Darkened(0.12f) with { A = 1.0f };
                DrawNeedTether(center, pipCenter, radius, pipRadius, new Color(pipColor.R, pipColor.G, pipColor.B, 0.42f));
            }
            else if (visual.State == NeedStateActive)
            {
                DrawCircle(pipCenter, pipRadius * (1.14f + visual.ActiveAlpha * 0.16f), new Color(pipColor.R, pipColor.G, pipColor.B, 0.20f + visual.ActiveAlpha * 0.26f));
            }

            DrawCircle(pipCenter, pipRadius, pipColor);
            DrawArc(pipCenter, pipRadius, 0.0f, Mathf.Tau, ArcSegments(pipRadius), new Color(0.01f, 0.025f, 0.03f, 0.82f), 2.2f, antialiased: true);
            DrawArc(pipCenter, pipRadius * 0.86f, 0.0f, Mathf.Tau, ArcSegments(pipRadius), new Color(1.0f, 1.0f, 1.0f, met ? 0.44f : 0.28f), 1.4f, antialiased: true);
            DrawFullnessArc(pipCenter, pipRadius * 1.12f, DisplayedFullness(cell, need, visual.Fullness), pipColor, Mathf.Max(2.0f, pipRadius * 0.20f));
            DrawResourceMark(font, pipCenter, pipRadius, need, Mathf.RoundToInt(pipRadius * 1.02f), Colors.White);
        }

        DrawResourceMark(font, center, radius, produced, Mathf.RoundToInt(radius * 1.48f), Colors.White);
    }

    private void DrawSimpleNeedDots(string cell, Vector2 center, float cellRadius)
    {
        var needed = _needs.GetValueOrDefault(cell) ?? [];
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
        DrawString(font, origin + new Vector2(1.4f, 1.4f), mark, HorizontalAlignment.Center, width, adjustedSize, new Color(0.01f, 0.025f, 0.03f, 0.78f));
        DrawString(font, origin, mark, HorizontalAlignment.Center, width, adjustedSize, color);
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
        var outline = new Color(0.01f, 0.025f, 0.03f, 0.86f);
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
        bool applySmoothing)
    {
        var state = NeedStateData(cell, need);
        state = state with { Partner = StabilizeNeedPartner(cell, need, state.Partner, state.State) };
        var baseAngle = BaseNeedAngle(cell, need, index, count, center, state.Partner);
        var targetAngle = SeparateNeedAngle(baseAngle, usedAngles);
        var targetOffset = NeedPipOffsetForState(center, state.Partner, cellRadius, pipRadius, state.State);
        var key = $"{cell}:{need}";
        var angle = applySmoothing ? SmoothPipAngle(key, targetAngle) : targetAngle;
        var offset = applySmoothing ? SmoothPipOffset(key, targetOffset) : targetOffset;
        return state with { Angle = angle, Offset = offset, TargetAngle = targetAngle };
    }

    private NeedVisual NeedStateData(string cell, string need)
    {
        var fullness = _usingCsharpSim ? SlotFullness(cell, need) : 0.0f;
        var activePartner = RecentFlowSourceForNeed(cell, need);
        var activeAlpha = RecentFlowAlphaForNeed(cell, need);
        if (string.IsNullOrEmpty(activePartner))
        {
            activePartner = RecentSwapPartnerForNeed(cell, need);
        }

        if (!string.IsNullOrEmpty(activePartner))
        {
            return new NeedVisual(NeedStateActive, activePartner, Mathf.Max(fullness, 0.18f), Mathf.Max(activeAlpha, 0.45f));
        }

        var possiblePartner = PossibleSwapPartnerForNeed(cell, need);
        if (string.IsNullOrEmpty(possiblePartner) && !_usingCsharpSim)
        {
            possiblePartner = AdjacentReciprocalPartnerForNeed(cell, need);
        }

        if (string.IsNullOrEmpty(possiblePartner) && _usingCsharpSim)
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
        IsAdjacent(cell, partner)
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
        if (!CellNeedsResource(cell, resource))
        {
            return center;
        }

        return NeedPipCenterForResource(cell, resource, center);
    }

    private Vector2 NeedPipCenterForResource(string cell, string resource, Vector2 center)
    {
        var needed = _needs.GetValueOrDefault(cell) ?? [];
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

        var flows = GetArray(_snapshot, "flows");
        for (var i = flows.Count - 1; i >= 0; i--)
        {
            var flow = flows[i].AsGodotDictionary();
            if (GetString(flow, "targetCellId", "") == cell && GetString(flow, "resource", "") == need)
            {
                return GetString(flow, "sourceCellId", "");
            }
        }

        return "";
    }

    private float RecentFlowAlphaForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return 0.0f;
        }

        var flows = GetArray(_snapshot, "flows");
        var currentTick = GetFloat(_snapshot, "tick", 0.0f);
        for (var i = flows.Count - 1; i >= 0; i--)
        {
            var flow = flows[i].AsGodotDictionary();
            if (GetString(flow, "targetCellId", "") != cell || GetString(flow, "resource", "") != need)
            {
                continue;
            }

            var age = Mathf.Max(0.0f, currentTick - GetFloat(flow, "tick", currentTick));
            return Mathf.Clamp(1.0f - age / SwapVisualTtlTicks, 0.0f, 1.0f);
        }

        return 0.0f;
    }

    private string RecentSwapPartnerForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return "";
        }

        var swaps = GetArray(_snapshot, "swaps");
        for (var i = swaps.Count - 1; i >= 0; i--)
        {
            var swap = swaps[i].AsGodotDictionary();
            var initiator = GetString(swap, "initiator", "");
            var counterparty = GetString(swap, "counterparty", "");
            var initiatorReceived = GetString(swap, "counterpartyPaidResource", "");
            var counterpartyReceived = GetString(swap, "initiatorPaidResource", "");
            if (cell == initiator && need == initiatorReceived)
            {
                return counterparty;
            }

            if (cell == counterparty && need == counterpartyReceived)
            {
                return initiator;
            }
        }

        return "";
    }

    private string PossibleSwapPartnerForNeed(string cell, string need)
    {
        if (!_usingCsharpSim)
        {
            return "";
        }

        var swaps = GetArray(_snapshot, "possibleSwaps");
        foreach (var swapVariant in swaps)
        {
            var swap = swapVariant.AsGodotDictionary();
            var initiator = GetString(swap, "initiator", "");
            var counterparty = GetString(swap, "counterparty", "");
            var initiatorReceived = GetString(swap, "counterpartyPaidResource", "");
            var counterpartyReceived = GetString(swap, "initiatorPaidResource", "");
            if (cell == initiator && need == initiatorReceived)
            {
                return counterparty;
            }

            if (cell == counterparty && need == counterpartyReceived)
            {
                return initiator;
            }
        }

        return "";
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
        if (CellAcceptsResource(other, produced))
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
            else if (string.IsNullOrEmpty(AdjacentReciprocalPartnerForNeed(cell, need)))
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

    private Vector2 VisualCellCenter(string cell) => cell == _dragCell ? _dragPosition : TileCenter(GetCellTile(cell));

    private Vector2I GetCellTile(string cell) => _positions.GetValueOrDefault(cell);

    private Vector2 TileCenter(Vector2I tile) => _boardRect.Position + (new Vector2(tile.X, tile.Y) + new Vector2(0.5f, 0.5f)) * _tileSize;

    private Vector2I ScreenToTile(Vector2 screenPosition)
    {
        var local = screenPosition - _boardRect.Position;
        return new Vector2I(Mathf.FloorToInt(local.X / _tileSize), Mathf.FloorToInt(local.Y / _tileSize));
    }

    private bool IsTileInside(Vector2I tile) => tile.X >= 0 && tile.Y >= 0 && tile.X < _boardCols && tile.Y < _boardRows;

    private bool IsTileEmpty(Vector2I tile)
    {
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

    private string CellProducedResource(string cell) => _producedByCell.GetValueOrDefault(cell, cell);

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

    private void ReadProduced(GdDictionary state)
    {
        _producedByCell.Clear();
        var produced = GetDictionary(state, "producedByCell");
        foreach (var keyVariant in produced.Keys)
        {
            _producedByCell[keyVariant.AsString()] = produced[keyVariant].AsString();
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

            var state = new CellVisualState
            {
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
            }

            _cellStates[id] = state;
        }
    }

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

    private static GdArray GetArray(GdDictionary dictionary, string key) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsGodotArray() : [];

    private static GdDictionary GetDictionary(GdDictionary dictionary, string key) =>
        dictionary.ContainsKey(key) ? dictionary[key].AsGodotDictionary() : new GdDictionary();

    private sealed class CellVisualState
    {
        public bool Glowing { get; init; }

        public Dictionary<string, SlotVisualState> Slots { get; } = new(StringComparer.Ordinal);
    }

    private sealed record SlotVisualState(string Role, int Quantity, float Fullness);

    private sealed record NeedVisual(
        string State,
        string Partner,
        float Fullness,
        float ActiveAlpha,
        float Angle = 0.0f,
        float Offset = 0.0f,
        float TargetAngle = 0.0f);
}
