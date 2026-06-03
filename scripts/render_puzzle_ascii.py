#!/usr/bin/env python3
from __future__ import annotations

import json
import argparse
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LEVEL_DIR = ROOT / "levels" / "puzzle"
LABEL_SUFFIXES = "123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ0abcdefghijklmnopqrstuvwxyz!$%&()+,-;=@[]^_{}~"


def load_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def cell_marker(cell: dict) -> str:
    kind = cell.get("kind", "")
    if kind == "RedMyco":
        return "*"
    if kind == "WhiteMyco":
        return "0"

    produced = produced_resource(cell)
    return produced[:1] if produced else "0"


def produced_resource(cell: dict) -> str:
    for slot in cell.get("slots", []):
        if slot.get("role") == "SourceOutput":
            return str(slot.get("resource", ""))
    return ""


def need_resources(cell: dict) -> list[str]:
    return [
        str(slot.get("resource", ""))
        for slot in cell.get("slots", [])
        if slot.get("role") == "Need"
    ]


def build_labels(cells: list[dict]) -> dict[str, str]:
    groups: dict[str, list[dict]] = defaultdict(list)
    for cell in cells:
        groups[cell_marker(cell)].append(cell)

    labels: dict[str, str] = {}
    for marker in sorted(groups.keys(), key=lambda value: "ZZZ*" if value == "*" else value):
        for index, cell in enumerate(sorted(groups[marker], key=lambda value: str(value.get("id", ""))), 1):
            suffix = LABEL_SUFFIXES[index - 1] if index <= len(LABEL_SUFFIXES) else "?"
            labels[str(cell["id"])] = f"{marker}{suffix}"
    return labels


def render_fixture(document: dict) -> str:
    grid = document["grid"]
    width = int(grid["width"])
    height = int(grid["height"])
    rocks = {
        (int(rock["x"]), int(rock["y"]))
        for rock in grid.get("rocks", [])
    }
    cells = list(document.get("cells", []))
    labels = build_labels(cells)
    by_position = {
        (int(cell["x"]), int(cell["y"])): str(cell["id"])
        for cell in cells
    }

    lines: list[str] = []
    for y in range(height):
        tokens: list[str] = []
        for x in range(width):
            cell_id = by_position.get((x, y))
            if cell_id is not None:
                tokens.append(labels[cell_id])
            elif (x, y) in rocks:
                tokens.append("##")
            else:
                tokens.append("..")
        lines.append(" ".join(tokens))

    lines.append("")
    lines.append("Legend:")
    by_id = {str(cell["id"]): cell for cell in cells}
    for cell_id, label in sorted(labels.items(), key=lambda pair: pair[1]):
        cell = by_id[cell_id]
        kind = cell.get("kind", "")
        if kind == "RedMyco":
            type_text = "red-myco"
        elif kind == "WhiteMyco":
            type_text = "white-myco"
        else:
            type_text = f"produces {produced_resource(cell)}"
        needs = need_resources(cell)
        lines.append(f"{label}: {cell_id}; {type_text}; needs {','.join(needs) if needs else 'none'}")

    return "\n".join(lines) + "\n"


def parse_map_tokens(text: str) -> list[list[str]]:
    rows: list[list[str]] = []
    for raw_line in text.replace("\r", "").split("\n"):
        line = raw_line.strip()
        if not line or line.lower() == "map:":
            continue
        if line.lower().startswith("legend:"):
            break

        if " " in line:
            rows.append(line.split())
        else:
            rows.append(list(line))
    return rows


def render_existing_map(document: dict, text: str) -> str:
    labels = build_labels(list(document.get("cells", [])))
    labels_by_marker: dict[str, list[str]] = defaultdict(list)
    for cell_id, label in sorted(labels.items(), key=lambda pair: pair[1]):
        labels_by_marker[label[:1]].append(label)

    label_index: dict[str, int] = defaultdict(int)
    rendered_rows: list[str] = []
    for row in parse_map_tokens(text):
        rendered_tokens: list[str] = []
        for token in row:
            if token and all(character == "." for character in token):
                rendered_tokens.append("..")
                continue
            if token and all(character == "#" for character in token):
                rendered_tokens.append("##")
                continue

            marker = normalize_existing_marker(token[:1], labels_by_marker)
            options = labels_by_marker.get(marker, [])
            index = label_index[marker]
            if index < len(options):
                rendered_tokens.append(options[index])
                label_index[marker] = index + 1
            else:
                rendered_tokens.append(f"{marker}?")

        rendered_rows.append(" ".join(rendered_tokens))

    rendered_rows.append("")
    rendered_rows.append("Legend:")
    by_id = {str(cell["id"]): cell for cell in document.get("cells", [])}
    for cell_id, label in sorted(labels.items(), key=lambda pair: pair[1]):
        cell = by_id[cell_id]
        kind = cell.get("kind", "")
        if kind == "RedMyco":
            type_text = "red-myco"
        elif kind == "WhiteMyco":
            type_text = "white-myco"
        else:
            type_text = f"produces {produced_resource(cell)}"
        needs = need_resources(cell)
        rendered_rows.append(f"{label}: {cell_id}; {type_text}; needs {','.join(needs) if needs else 'none'}")

    return "\n".join(rendered_rows) + "\n"


def normalize_existing_marker(marker: str, labels_by_marker: dict[str, list[str]]) -> str:
    if marker == "0" and not labels_by_marker.get("0") and labels_by_marker.get("*"):
        return "*"
    return marker


def can_render_existing_map(document: dict, text: str) -> bool:
    labels = build_labels(list(document.get("cells", [])))
    labels_by_marker: dict[str, list[str]] = defaultdict(list)
    for label in labels.values():
        labels_by_marker[label[:1]].append(label)

    counts: dict[str, int] = defaultdict(int)
    for row in parse_map_tokens(text):
        for token in row:
            if token and (all(character == "." for character in token) or all(character == "#" for character in token)):
                continue
            marker = normalize_existing_marker(token[:1], labels_by_marker)
            if marker not in labels_by_marker:
                return False
            counts[marker] += 1

    return all(count <= len(labels_by_marker[marker]) for marker, count in counts.items())


def same_board(a: dict, b: dict) -> bool:
    grid_a = a.get("grid", {})
    grid_b = b.get("grid", {})
    rocks_a = sorted((int(rock["x"]), int(rock["y"])) for rock in grid_a.get("rocks", []))
    rocks_b = sorted((int(rock["x"]), int(rock["y"])) for rock in grid_b.get("rocks", []))
    return (
        int(grid_a.get("width", -1)) == int(grid_b.get("width", -2))
        and int(grid_a.get("height", -1)) == int(grid_b.get("height", -2))
        and rocks_a == rocks_b
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Render puzzle fixture JSON files as two-character ASCII maps with legends.")
    parser.add_argument("--from-level", type=int, default=1)
    parser.add_argument("--to-level", type=int, default=999)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    from_level = max(1, int(args.from_level))
    to_level = max(from_level, int(args.to_level))
    skipped: list[str] = []
    converted_from_text: list[str] = []
    wrote = 0

    for fixture_path in sorted(LEVEL_DIR.glob("level-[0-9][0-9][0-9].json")):
        level = fixture_path.stem.removeprefix("level-")
        level_number = int(level)
        if level_number < from_level or level_number > to_level:
            continue
        document = load_json(fixture_path)
        (LEVEL_DIR / f"level-{level}.txt").write_text(render_fixture(document), encoding="utf-8")
        wrote += 1

        solution_path = LEVEL_DIR / f"level-{level}-solution.json"
        if not solution_path.exists():
            continue

        solution = load_json(solution_path)
        if not same_board(document, solution):
            solution_text_path = LEVEL_DIR / f"level-{level}-solution.txt"
            source_text_path = solution_text_path
            if not source_text_path.exists():
                source_text_path = ROOT / "sim" / "solutions" / "puzzle" / f"level-{level}" / "solution-map.txt"

            if source_text_path.exists():
                source_text = source_text_path.read_text(encoding="utf-8")
                if can_render_existing_map(document, source_text):
                    solution_text_path.write_text(
                        render_existing_map(document, source_text),
                        encoding="utf-8")
                    converted_from_text.append(f"level-{level}-solution.txt")
                else:
                    solution_text_path.write_text(render_fixture(solution), encoding="utf-8")
                    skipped.append(f"level-{level}-solution.txt rendered from stale solution fixture")
                wrote += 1
            else:
                solution_text_path.write_text(render_fixture(solution), encoding="utf-8")
                skipped.append(f"level-{level}-solution.txt rendered from stale solution fixture")
                wrote += 1
            continue

        (LEVEL_DIR / f"level-{level}-solution.txt").write_text(render_fixture(solution), encoding="utf-8")
        wrote += 1

    print(f"wrote {wrote} ASCII maps")
    if converted_from_text:
        print("converted stale solution maps from existing text:")
        for name in converted_from_text:
            print(f"  {name}")
    if skipped:
        print("skipped stale solution maps:")
        for name in skipped:
            print(f"  {name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
