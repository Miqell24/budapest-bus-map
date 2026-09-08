#!/usr/bin/env bash
# Downloads input data: the BKK and Volánbusz GTFS feeds, the OSM network
# (Geofabrik + pyosmium) and MapLibre GL. Everything is cached — re-running
# only fetches what is missing.
#
# TWO feeds:
#   BKK (bkk.hu/gtfs/) — the city: buses (3) and trolleybuses (11), trams (0),
#   metro M1–M4 (1) and the MÁV-HÉV suburban lines H5–H9 (109), shapes and
#   official line colours included; modes split by route_type at build time.
#   Volánbusz — the national regional feed, of which this map draws the
#   300–899 block: the Budapest region's own numbering, 439 lines. The
#   operator publishes its GTFS on request (volanbusz.hu/hu/menetrendek/gtfs
#   → gtfs-igenybejelento), so the open copy used here is the daily mirror at
#   gtfs.menetbrand.com, the same file the MobilityDatabase entry points to.

set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm/tiles web/vendor

# 1) GTFS — the regional bundle (stable URL, refreshed in place by TPBI)
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== BKK GTFS (Budapest) =="
  curl -fL --retry 3 --max-time 600 -o data/budapest_gtfs.zip \
    "https://bkk.hu/gtfs/budapest_gtfs.zip"
  unzip -o data/budapest_gtfs.zip -d data/gtfs
fi

# 1b) GTFS — Volánbusz (national; the build keeps the 300–899 regional block)
if [ ! -f data/gtfs-volan/routes.txt ]; then
  echo "== Volánbusz GTFS (regional) =="
  mkdir -p data/gtfs-volan
  curl -fL --retry 3 --max-time 1800 -A "Mozilla/5.0" -o data/volanbusz_gtfs.zip \n    "https://gtfs.menetbrand.com/download/volanbusz/"
  unzip -o data/volanbusz_gtfs.zip -d data/gtfs-volan
fi

# 2) OSM — from the Geofabrik hungary extract, not Overpass.
#    With the regional lines the frame is 200 × 165 km (46.25–48.22 N,
#    17.90–20.35 E): half of Hungary, far past what a public Overpass mirror
#    will serve — the wall Berlin, London and São Paulo hit before.
#    pipeline/pbf-tiles.py cuts 7 × 7 road tiles AND the small rail box
#    (trams, metro, HÉV never leave the agglomeration) out of the .pbf and
#    writes exactly the JSON shape Overpass would have returned — ways with
#    tags, NODE IDS and geometry (buildGraph silently drops ways without
#    el.nodes).
if [ ! -f data/osm/tiles/t49.json ] || [ ! -f data/osm/budapest-rail.json ]; then
  python3 -c "import osmium" 2>/dev/null || { echo "brak pakietu osmium — zainstaluj: pip3 install --user osmium" >&2; exit 1; }
  if [ ! -f data/hungary-latest.osm.pbf ]; then
    echo "== Geofabrik hungary-latest.osm.pbf =="
    curl -fL --retry 5 --retry-delay 5 -C - --max-time 3600 -o data/hungary-latest.osm.pbf \n      "https://download.geofabrik.de/europe/hungary-latest.osm.pbf"
  fi
  echo "== cutting OSM tiles out of the extract =="
  python3 pipeline/pbf-tiles.py
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/gtfs data/gtfs-volan data/osm 2>/dev/null || true
