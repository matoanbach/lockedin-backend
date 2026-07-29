"""Export the FastAPI OpenAPI document for review or Postman import."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from lockedin_backend.app.main import app


DEFAULT_OUTPUT = Path(__file__).resolve().parents[1] / "docs" / "openapi.json"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help=f"Output path (default: {DEFAULT_OUTPUT})",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(
        json.dumps(app.openapi(), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"Exported OpenAPI schema to {output}")


if __name__ == "__main__":
    main()
