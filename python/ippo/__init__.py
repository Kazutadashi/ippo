# SPDX-License-Identifier: GPL-3.0-or-later
"""Load Ippo data into pandas tables.

Example::

    import ippo

    data = ippo.load("/path/to/data")
    print(data.summary())
    daily = data.daily()            # one row per day, every module
    daily["sleep_before_h"].rolling(28).mean().plot()

Each table has the changes and deletions made in the app already
applied. The format itself is described in ``docs/data-format.md``.
"""

from .data import IppoData, load
from .reading import FORMAT_VERSION, Problem

__all__ = ["FORMAT_VERSION", "IppoData", "Problem", "load"]
__version__ = "0.1.0"
