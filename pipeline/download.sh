#!/usr/bin/env bash
# Downloads input data: BKK GTFS feed, OSM networks (Overpass), MapLibre GL.
# Everything is cached — re-running only fetches what is missing.
#
# ONE feed covers Budapest and its agglomeration (bkk.hu/gtfs/):
# BKK buses (3) and trolleybuses (11), trams (0), metro M1–M4 (1) and the
# MÁV-HÉV suburban lines H5–H9 (109) — shapes and official line colors
# included. Modes are separated by route_type at build time.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p data/gtfs data/osm web/vendor

# A downloaded extract is only accepted if it PARSES and carries a plausible
# number of elements. `grep -q '"elements"'` — the guard this family used
# everywhere — passes on a truncated response too: Brașov's roads arrived as a
# 65 kB fragment that still contained the string, was taken for complete, and
# silently skipped the city (16.08.2026).
# The minimum differs by extract: a road network runs to tens of thousands of
# ways, a city rail network to a few hundred, so the caller passes its own floor
# rather than sharing one.
# A rejected file is deleted rather than left behind — the `[ ! -f … ]` gates
# below only ask whether the file exists, so a fragment on disk would be taken
# for a finished download on the next run.
ok_json () { # $1=file  $2=minimum element count
  python3 - "$1" "$2" <<'PYEOF' 2>/dev/null
import json, sys
try:
    sys.exit(0 if len(json.load(open(sys.argv[1])).get("elements", [])) >= int(sys.argv[2]) else 1)
except Exception:
    sys.exit(1)
PYEOF
}

# 1) GTFS — the regional bundle (stable URL, refreshed in place by TPBI)
if [ ! -f data/gtfs/routes.txt ]; then
  echo "== BKK GTFS (Budapest) =="
  curl -fL --retry 3 --max-time 600 -o data/budapest_gtfs.zip \
    "https://bkk.hu/gtfs/budapest_gtfs.zip"
  unzip -o data/budapest_gtfs.zip -d data/gtfs
fi

# 2) OSM — roadways over the whole region (GTFS stops extent 47.18–47.66 N,
#    18.72–19.38 E plus margin: agglomeration communes on every side, incl.
#    the Ráckeve HÉV corridor in the south)
if [ ! -f data/osm/budapest.json ]; then
  echo "== Overpass (roads) =="
  Q='[out:json][timeout:900];way(47.10,18.62,47.73,19.45)["highway"~"^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 900 -o data/osm/budapest.json --data-urlencode "data=$Q" "$EP" \
       && ok_json "data/osm/budapest.json" 2000; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/budapest.json; echo "Overpass: all mirrors failed" >&2; exit 1; }
fi

# 2b) OSM — rails for the tram/metro/HÉV modes: tram tracks, metro tunnels
#     (railway=subway; M1 shallow, M2–M4 deep) and light_rail/rail for the
#     HÉV lines. Same bbox as the roads.
if [ ! -f data/osm/budapest-rail.json ]; then
  echo "== Overpass (rails) =="
  QT='[out:json][timeout:300];way(47.10,18.62,47.73,19.45)["railway"~"^(subway|tram|light_rail|rail)$"];out geom;'
  ok=0
  for EP in "https://overpass-api.de/api/interpreter" \
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter" \
            "https://overpass.kumi.systems/api/interpreter"; do
    echo "-- $EP"
    if curl -fsS --max-time 300 -o data/osm/budapest-rail.json --data-urlencode "data=$QT" "$EP" \
       && ok_json "data/osm/budapest-rail.json" 40; then
      ok=1; break
    fi
  done
  [ "$ok" = 1 ] || { rm -f data/osm/budapest-rail.json; echo "Overpass (rails): all mirrors failed" >&2; exit 1; }
fi

# 3) MapLibre GL (vendored, no CDN at runtime)
if [ ! -f web/vendor/maplibre-gl.js ]; then
  echo "== MapLibre GL =="
  curl -fL --retry 3 -o web/vendor/maplibre-gl.js  https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.js
  curl -fL --retry 3 -o web/vendor/maplibre-gl.css https://unpkg.com/maplibre-gl@5.6.1/dist/maplibre-gl.css
fi

echo "OK — data ready:"
du -sh data/bucharest-region.zip data/osm/budapest.json data/osm/budapest-rail.json 2>/dev/null || true
