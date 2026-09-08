#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Cuts the OSM extracts out of the Geofabrik hungary .pbf — same JSON shape as
Overpass ('elements': ways with tags, node ids and geometry), so build.mjs
cannot tell the difference.

Budapest used to fetch its roads from Overpass over a 0.6 x 0.8 deg box. With
the Volanbusz regional lines 300-899 on the map the frame is 200 x 165 km
(Salgotarjan in the north, Szekszard in the south, Szolnok in the east) and no
public Overpass mirror will serve that — the same wall Berlin, London and
Sao Paulo hit, see the family note on pbf tiles.

The rail cut stays small on purpose: trams, the metro and the HEV never leave
the agglomeration, so their graph is the old Overpass box.
"""
import json, os, re, sys
import osmium

ROOT = os.path.join(os.path.dirname(__file__), '..')
PBF = os.path.join(ROOT, 'data', 'hungary-latest.osm.pbf')

# must match pipeline/download.sh: the stop extent of BKK + Volanbusz 300-899
# (46.35-48.13 N, 18.03-20.22 E) plus a margin for the roads the shapes use
S, N, W, E = 46.25, 48.22, 17.90, 20.35
GRID = 7
RAIL_BOX = (47.10, 18.62, 47.73, 19.45)   # S, W, N, E — trams, metro, HEV

HW = re.compile(r'^(motorway|trunk|primary|secondary|tertiary|unclassified|residential|living_street|service|busway|construction|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link)$')
RAIL = re.compile(r'^(subway|tram|light_rail|rail)$')

road_tiles = {}
for i in range(1, GRID * GRID + 1):
    f = os.path.join(ROOT, f'data/osm/tiles/t{i}.json')
    if os.path.exists(f):
        continue
    row, col = (i - 1) // GRID, (i - 1) % GRID
    road_tiles[i] = (S + (N - S) * row / GRID, S + (N - S) * (row + 1) / GRID,
                     W + (E - W) * col / GRID, W + (E - W) * (col + 1) / GRID)
rail_file = os.path.join(ROOT, 'data/osm/budapest-rail.json')
need_rail = not os.path.exists(rail_file)
print('brakujące kafle dróg:', len(road_tiles), '| szyny:', need_rail, flush=True)
if not road_tiles and not need_rail:
    sys.exit(0)
os.makedirs(os.path.join(ROOT, 'data/osm/tiles'), exist_ok=True)

out = {i: [] for i in road_tiles}
out_rail = []


class H(osmium.SimpleHandler):
    def way(self, w):
        tags = w.tags
        hw = tags.get('highway')
        rw = tags.get('railway')
        is_road = bool(road_tiles) and hw is not None and HW.match(hw)
        is_rail = need_rail and rw is not None and RAIL.match(rw)
        if not is_road and not is_rail:
            return
        geom, ids = [], []
        la0, la1, lo0, lo1 = 90.0, -90.0, 180.0, -180.0
        for n in w.nodes:
            try:
                lo, la = n.lon, n.lat
            except osmium.InvalidLocationError:
                continue
            # node ids ride along: buildGraph() builds topology from el.nodes
            # and SILENTLY skips ways without them (the London t13 hole)
            ids.append(n.ref)
            geom.append({'lat': la, 'lon': lo})
            if la < la0: la0 = la
            if la > la1: la1 = la
            if lo < lo0: lo0 = lo
            if lo > lo1: lo1 = lo
        if len(geom) < 2:
            return
        el = None

        def make():
            nonlocal el
            if el is None:
                el = {'type': 'way', 'id': w.id, 'nodes': ids,
                      'tags': {t.k: t.v for t in tags}, 'geometry': geom}
            return el

        if is_road:
            for i, (s, n_, w_, e) in road_tiles.items():
                if la1 >= s and la0 <= n_ and lo1 >= w_ and lo0 <= e:
                    out[i].append(make())
        if is_rail:
            s, w_, n_, e = RAIL_BOX
            if la1 >= s and la0 <= n_ and lo1 >= w_ and lo0 <= e:
                out_rail.append(make())


if not os.path.exists(PBF):
    sys.exit(f'brak {PBF} — pobierz go (pipeline/download.sh)')
print('czytam', os.path.basename(PBF), flush=True)
H().apply_file(PBF, locations=True, idx='flex_mem')

GEN = 'pbf-tiles.py (Geofabrik hungary)'
for i, els in out.items():
    f = os.path.join(ROOT, f'data/osm/tiles/t{i}.json')
    json.dump({'version': 0.6, 'generator': GEN, 'elements': els}, open(f, 'w'))
    print(f't{i}: {len(els)} dróg', flush=True)
if need_rail:
    json.dump({'version': 0.6, 'generator': GEN, 'elements': out_rail}, open(rail_file, 'w'))
    print(f'szyny: {len(out_rail)} odcinków', flush=True)
print('gotowe', flush=True)
