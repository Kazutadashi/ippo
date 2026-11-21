# SPDX-License-Identifier: GPL-3.0-or-later
"""Writes every table to a folder that explains itself.

The folder holds, for each table:

- ``<table>.csv``: plain text, for spreadsheets, R, or any program;
- ``<table>.parquet``: the same table in Apache Parquet, a compact file
  format for tables that keeps each column's type (pandas, R arrow,
  Polars, DuckDB, Spark read it). Written only when the optional
  ``pyarrow`` package is installed (``pip install ippo[parquet]``).

and, describing them:

- ``datapackage.json``: a Frictionless Data Package (v2,
  https://datapackage.org), the open standard that describes tabular
  data: each table's columns with their type and meaning, plus, as
  extra properties, the unit (UCUM) and standard codes of each column;
- ``codebook.csv``: the same descriptions as one plain table;
- ``README.txt``: what the folder is, in a few lines.
"""

import json
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from . import codebook

#: Where the Data Package standard's descriptor schema lives.
_DATA_PACKAGE_SCHEMA = "https://datapackage.org/profiles/2.0/datapackage.json"


def parquet_available():
    """True if Parquet files can be written: ``pyarrow`` is installed,
    and built with Parquet (some builds are not)."""
    try:
        import pyarrow.parquet  # noqa: F401
    except ImportError:
        return False
    return True


def export(tables, out_folder, parquet=None):
    """Writes ``tables`` (a dict of table name to DataFrame) into
    ``out_folder``, created if needed, and returns the paths written.

    ``parquet``: True to write Parquet files (needs ``pyarrow``), False
    not to, None (the default) to write them when ``pyarrow`` is there.
    """
    out_folder = Path(out_folder)
    out_folder.mkdir(parents=True, exist_ok=True)
    if parquet is None:
        parquet = parquet_available()
    elif parquet and not parquet_available():
        raise ImportError("Writing Parquet needs pyarrow with Parquet support: pip install ippo[parquet]")

    written = []
    resources = []
    codebook_rows = []
    for name, frame in tables.items():
        frame = _with_date_column(frame)
        columns = [_describe(name, column) for column in frame.columns]
        path = out_folder / f"{name}.csv"
        _for_csv(frame).to_csv(path, index=False)
        written.append(path)
        if parquet:
            parquet_path = out_folder / f"{name}.parquet"
            frame.to_parquet(parquet_path, index=False)
            written.append(parquet_path)
        resources.append(_resource(name, columns))
        codebook_rows.extend(_codebook_row(name, column) for column in columns)

    package_path = out_folder / "datapackage.json"
    package_path.write_text(
        json.dumps(_package(resources), indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    written.append(package_path)

    codebook_path = out_folder / "codebook.csv"
    pd.DataFrame(codebook_rows).to_csv(codebook_path, index=False)
    written.append(codebook_path)

    readme_path = out_folder / "README.txt"
    readme_path.write_text(_README.format(parquet=_PARQUET_NOTE if parquet else ""), encoding="utf-8")
    written.append(readme_path)
    return written


def _with_date_column(frame):
    """Tables indexed by date get it as a plain first column, so every
    file has the same shape: one row per record, every value in a
    column."""
    if frame.index.name == "date":
        return frame.reset_index()
    return frame.reset_index(drop=True)


def _describe(table, column):
    described = codebook.describe(table, column)
    if described is None:
        # Never silently: a test makes sure this does not happen for the
        # package's own tables.
        return codebook.Column(column, "any", "Not described in the codebook.")
    return described


def _resource(name, columns):
    """One table's entry in ``datapackage.json``."""
    fields = []
    for column in columns:
        entry = {"name": column.name, "type": column.type, "description": column.description}
        if column.type == "datetime" and column.name.endswith("_local"):
            entry["description"] += " No time zone: the clock time where the user was."
        if column.unit:
            entry["unit"] = column.unit
        if column.codes:
            entry["codes"] = column.codes
        fields.append(entry)
    return {
        "name": name.replace("_", "-"),
        "path": f"{name}.csv",
        "format": "csv",
        "mediatype": "text/csv",
        "encoding": "utf-8",
        "schema": {"fields": fields, "missingValues": [""]},
    }


def _package(resources):
    """The whole ``datapackage.json``."""
    return {
        "$schema": _DATA_PACKAGE_SCHEMA,
        "name": "ippo-export",
        "title": "Ippo data export",
        "description": (
            "Personal tracking data from the Ippo app, as tidy tables. Each field gives its type "
            "and meaning; 'unit' is a UCUM code (https://ucum.org) and 'codes' gives identifiers "
            "from INFOODS, USDA FoodData Central and LOINC where one fits. An empty cell means "
            "not recorded, never zero. The format of the raw files is described in "
            "docs/data-format.md of the Ippo source code."
        ),
        "created": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "licenses": [{"name": "other-closed", "title": "The data's owner decides how it may be shared."}],
        "resources": resources,
    }


def _codebook_row(table, column):
    return {
        "table": table,
        "column": column.name,
        "type": column.type,
        "unit_ucum": column.unit,
        "description": column.description,
        "infoods": column.codes.get("infoods", ""),
        "usda_fdc_id": column.codes.get("usda_fdc_id", ""),
        "usda_fdc_number": column.codes.get("usda_fdc_number", ""),
        "loinc": column.codes.get("loinc", ""),
    }


def _for_csv(frame):
    """Writes dates and moments as plain, unambiguous text."""
    frame = frame.copy()
    for column in frame.columns:
        values = frame[column]
        if isinstance(values.dtype, pd.DatetimeTZDtype):
            frame[column] = values.dt.strftime("%Y-%m-%dT%H:%M:%S.%f").str[:-3] + "+00:00"
        elif pd.api.types.is_datetime64_dtype(values):
            if column == "date":
                frame[column] = values.dt.strftime("%Y-%m-%d")
            else:
                frame[column] = values.dt.strftime("%Y-%m-%dT%H:%M:%S.%f").str[:-3]
    return frame


_PARQUET_NOTE = """
Each table is also a .parquet file (Apache Parquet): the same rows, with
each column's type kept, for pandas, R (arrow), Polars, DuckDB or Spark.
"""

_README = """This folder is an export of data from the Ippo app.

Each table is a .csv file: one row per record, one value per cell.
{parquet}
What every column means, its type, its unit (as a UCUM code) and any
standard code (INFOODS and USDA FoodData Central for nutrients, LOINC for
body weight and steps) is in:

  codebook.csv       one row per column of every table
  datapackage.json   the same, as a Frictionless Data Package
                     (https://datapackage.org), which tools such as
                     frictionless (Python, R) read directly

Rules that hold everywhere:

- An empty cell means "not recorded". It is never a hidden zero.
- "date" is the day as lived; a day lasts until 05:00 the next morning.
- Columns ending in _utc are exact moments in UTC; columns ending in
  _local are the clock time where the person was, without a time zone.
- Ids are UUIDv7 and stay the same when things are renamed, so tables
  join on them (habit_id, food_id, exercise_id).
- events.csv holds every raw event; the other tables are worked out
  from it. The raw format is described in docs/data-format.md of the
  Ippo source code.
"""
