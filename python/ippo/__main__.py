# SPDX-License-Identifier: GPL-3.0-or-later
"""Command line use, without writing any Python:

    python -m ippo summary /path/to/data
    python -m ippo export /path/to/data /path/to/export-folder
"""

import argparse

from .data import load


def main():
    """Runs the command given on the command line."""
    parser = argparse.ArgumentParser(prog="python -m ippo", description="Read an Ippo data folder.")
    commands = parser.add_subparsers(dest="command", required=True)
    summary = commands.add_parser("summary", help="show what the folder holds")
    summary.add_argument("folder", help="the data folder (the one holding events/)")
    export = commands.add_parser(
        "export",
        help="write every table as CSV (and Parquet, if pyarrow is installed), "
        "with datapackage.json and codebook.csv describing every column",
    )
    export.add_argument("folder", help="the data folder (the one holding events/)")
    export.add_argument("out", help="the folder to write the files into")
    export.add_argument("--no-parquet", action="store_true", help="write CSV only")
    arguments = parser.parse_args()

    data = load(arguments.folder)
    print(data.summary())
    if arguments.command == "export":
        parquet = False if arguments.no_parquet else None
        for path in data.export(arguments.out, parquet=parquet):
            print(f"wrote {path}")


if __name__ == "__main__":
    main()
