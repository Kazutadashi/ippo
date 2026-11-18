This folder holds data from Ippo, a health and habit tracker.

events/
  One file per device (each install of the app), named after a random
  device id. Each line is one event in JSON: something that happened,
  such as "a habit was marked done" or "a food was eaten". Lines are
  only ever added; mistakes are fixed by adding a new event.
  Read every file here (except hidden ones starting with "."), and
  remove repeated events by their "id".

backups/
  Monthly copies of each device's event file. They repeat what is in
  events/, so leave them out of an analysis.

To analyse the data, copy this folder to your computer. Ippo's source
code includes a small Python package that turns the events into tidy
tables (habits, food, exercise sets, sleep, and one row per day), and
the full description of the format in docs/data-format.md.
