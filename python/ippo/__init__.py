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

try:
    import pandas  # noqa: F401
except ImportError:
    raise ImportError(
        "The ippo package needs pandas. Install it in a separate environment "
        "rather than the system Python, for example: "
        "conda create -n ippo python=3.12 pandas"
    ) from None

from .data import IppoData, load  # noqa: E402
from .reading import FORMAT_VERSION, Problem  # noqa: E402

__all__ = ["FORMAT_VERSION", "IppoData", "Problem", "load"]
__version__ = "0.1.0"
