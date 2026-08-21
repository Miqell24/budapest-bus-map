# Budapest Public Transport — interactive map

Interactive, poster-grade map of the public transport network of **Budapest**:
BKK buses, trolleybuses and trams, the metro M1–M4 and the MÁV-HÉV suburban
lines H5–H9 (all rail in the official line colors) — 376 lines / 8 400 km
drawn along the real street and track geometry, weighted mean matching error
0.37 m.

## Live

**https://miqell24.github.io/budapest-bus-map/** — GitHub Pages from `main:/docs`. Local build on port 8154 (`npm run serve`).

Everything comes from ONE feed — the BKK GTFS bundle
(https://bkk.hu/gtfs/budapest_gtfs.zip) — split by `route_type` at build time:

| mode | route_type | lines | graph |
|---|---|---|---|
| buses | 3 | 303 BKK lines incl. the agglomeration | OSM roadways |
| trolleybuses | 11 | 17 lines (70–83), drawn green on the bus network | OSM roadways |
| trams | 0 | 47 lines, incl. the Fogaskerekű (60) | `railway=tram` tracks (+ the rack railway) |
| metro | 1 | M1–M4, official colors from `routes.txt` | `railway=subway` tunnels |
| HÉV | 109 | H5–H9, official colors, up to 40 km (H6 to Ráckeve) | `railway=light_rail/rail` |

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

`npm run download` fetches the BKK feed, OSM roadways and rails (Overpass,
bbox 47.10–47.73 N / 18.62–19.45 E) and MapLibre GL. `npm run build`
map-matches every line (HMM/Viterbi on the OSM graphs) and writes GeoJSON to
`data/out/`. `npm run serve` hosts the map at http://localhost:8154.

Data: BKK (BKK Zrt., MÁV-HÉV) ·
base map © OpenFreeMap / OpenMapTiles / OpenStreetMap contributors.
