#!/usr/bin/env python3
import re
import sys
from pathlib import Path


def patch_file(path: Path) -> None:
    if not path.exists():
        return
    data = path.read_text()
    if "EXPECTED_HASH" not in data:
        return
    if "#ifndef NDEBUG" in data:
        return

    def repl(match: re.Match) -> str:
        indent = match.group(1)
        stmt = match.group(2)
        return f"\n{indent}#ifndef NDEBUG\n{indent}{stmt}\n{indent}#endif"

    updated = re.sub(
        r"\n(\s*)(assert\(0 == memcmp\([^;]+\);)",
        repl,
        data,
    )
    path.write_text(updated)


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("src")
    targets = [
        root / "rosidl" / "rosidl_runtime_c" / "src" / "type_description" / "field__description.c",
        root / "rosidl" / "rosidl_runtime_c" / "src" / "type_description" / "individual_type_description__description.c",
        root / "rosidl" / "rosidl_runtime_c" / "src" / "type_description" / "type_description__description.c",
    ]
    for path in targets:
        patch_file(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
