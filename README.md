# Budapest Public Transport — interactive map

Interactive, poster-grade map of the public transport network of **Budapest and
its region**: BKK buses, trolleybuses and trams, the metro M1–M4 and the
MÁV-HÉV suburban lines H5–H9 (all rail in the official line colors), plus the
whole Volánbusz regional block **300–899** — 806 lines / 34 700 km
drawn along the real street and track geometry, weighted mean matching error
0.37 m.

## Live

**https://miqell24.github.io/budapest-bus-map/** — GitHub Pages from `main:/docs`. Local build on port 8154 (`npm run serve`).

Two feeds. The BKK bundle (https://bkk.hu/gtfs/budapest_gtfs.zip) is the city,
split by `route_type` at build time; the national Volánbusz feed contributes
its 300–899 lines, the numbering block of the Budapest region:

| mode | route_type | lines | graph |
|---|---|---|---|
| buses | 3 | 298 BKK city lines | OSM roadways |
| trolleybuses | 11 | 16 lines (70–83 + night), drawn green on the bus network | OSM roadways |
| trams | 0 | 44 lines, incl. the Fogaskerekű (60) | `railway=tram` tracks (+ the rack railway) |
| metro | 1 | M1–M4, official colors from `routes.txt` | `railway=subway` tunnels |
| HÉV | 109 | H5–H9, official colors, up to 40 km (H6 to Ráckeve) | `railway=light_rail/rail` |
| regional buses | 200 (+3) | 439 Volánbusz lines 300–899, grouped in the panel by hundreds block | OSM roadways |

The regional lines are buses and are drawn in the bus colour: on these maps
the ink says the MODE, never the operator. What tells the two networks apart is
the panel, which groups its chips the way the Berlin map groups the Verbund —
BKK and MÁV-HÉV under their own headings, and Volánbusz under the hundreds
block that IS the region: 300s north-east to Vác, 400s east to Gödöllő, 500s
south-east to Cegléd, 600s south to Ráckeve, 700s west to Érd, 800s north-west
to Szentendre and Esztergom. Nothing about that grouping is invented — the
block is the number the feed ships, and the towns in each heading are counted
off that block's own stop names at build time (the bearings confirm it: each
block's stops sit within a few degrees of one direction).

Not every 300–899 line sees Budapest: the block is the region's, so 555
(Cegléd–Szekszárd, 130 km), 533 (Szolnok–Abony) and 361 (Vác–Salgótarján) are
on the map too, and they are what makes the frame 200 × 165 km.

Volánbusz publishes its GTFS on request (volanbusz.hu/hu/menetrendek/gtfs →
`gtfs-igenybejelento`), so the open copy used here is the daily mirror at
gtfs.menetbrand.com — the same file the MobilityDatabase entry (mdb-1836)
points to.

Build quirks worth knowing: replacement services (route_id `VP*`/`TP*`/`MP*` —
villamos-/troli-/metrópótló buses that duplicate rail numbers, active during
the current track works) are skipped, so no phantom bus "M2" appears; the
Fogaskerekű is BKK tram route 60 but OSM tags it `railway=light_rail` + `rack`,
so the tram graph admits that one oddball; depot-happy shapes are trimmed to
the passenger stretch between the first and last stop; 22 lines carry one
constant `direction_id` on all trips, so where direction_id cannot tell the
directions apart the headsign becomes the bucket key; and the representative
variant of every line+direction is the LONGEST pattern still worked by ≥15%
of the busiest pattern's trips — the busiest shape is usually a peak short-turn
(71 line-directions moved, +269 km drawn). One 757 m stretch of the night tram
N42-50 in Kispest runs where OSM has no tracks and is drawn from the GTFS
shape as-is.

## Pipeline

`npm run download` fetches both feeds, the OSM network and MapLibre GL. The
roads no longer come from Overpass: a 200 × 165 km box (46.25–48.22 N /
17.90–20.35 E) is far past what the public mirrors will serve, so
`pipeline/pbf-tiles.py` cuts 7 × 7 road tiles — and the small rail box the
trams, metro and HÉV need — out of the Geofabrik `hungary` extract. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8154.

Data: BKK (BKK Zrt., MÁV-HÉV) · Volánbusz (regional lines 300–899) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
