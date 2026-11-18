# SPDX-License-Identifier: GPL-3.0-or-later
"""Command line use, without writing any Python:

    python -m ippo summary /path/to/data
    python -m ippo export /path/to/data /path/to/csv-folder
"""

import argparse

from .data import load


def main():
    """Runs the command given on the command line."""
    parser = argparse.ArgumentParser(prog="python -m ippo", description="Read an Ippo data folder.")
    commands = parser.add_subparsers(dest="command", required=True)
    summary = commands.add_parser("summary", help="show what the folder holds")
    summary.add_argument("folder", help="the data folder (the one holding events/)")
    export = commands.add_parser("export", help="write every table as a CSV file")
    export.add_argument("folder", help="the data folder (the one holding events/)")
    export.add_argument("out", help="the folder to write the CSV files into")
    arguments = parser.parse_args()

    data = load(arguments.folder)
    print(data.summary())
    if arguments.command == "export":
        for path in data.export_csv(arguments.out):
            print(f"wrote {path}")


if __name__ == "__main__":
    main()
