from __future__ import annotations

import argparse
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a local .env file from .env.example."
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite .env even if it already exists.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    project_dir = Path(__file__).resolve().parents[1]
    source = project_dir / ".env.example"
    destination = project_dir / ".env"

    if not source.exists():
        raise SystemExit(f"Missing environment template: {source}")

    if destination.exists() and not args.force:
        print(f"Skipped: {destination} already exists")
        return

    destination.write_text(source.read_text(encoding="utf-8"), encoding="utf-8")
    print(f"Created {destination}")


if __name__ == "__main__":
    main()
