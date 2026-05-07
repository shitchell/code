from __future__ import annotations
import argparse
from pathlib import Path
from dashboard.app import DashboardApp
from dashboard.config import load_config_file


def main() -> None:
    parser = argparse.ArgumentParser(description="Exec Dashboard")
    parser.add_argument(
        "--config",
        type=Path,
        default=Path("dashboard.yaml"),
        help="Path to dashboard YAML config (default: dashboard.yaml)",
    )
    args = parser.parse_args()
    config = load_config_file(args.config)
    DashboardApp(config).run()


if __name__ == "__main__":
    main()
