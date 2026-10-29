#!/usr/bin/env python3
"""Validate estimate files against the fetched list, then write the points.

usage: apply.py todo.json est0.json [est1.json ...] [--dry-run]
Runs `exponential` with the inherited HOME, like fetch.py.
"""
import collections, json, subprocess, sys

args = [x for x in sys.argv[1:] if x != '--dry-run']
dry = '--dry-run' in sys.argv
if len(args) < 2:
    sys.exit(__doc__)

todo = {t['id'] for t in json.load(open(args[0]))}
est = {}
for f in args[1:]:
    est.update(json.load(open(f)))

missing, extra = todo - set(est), set(est) - todo
bad = {k: v for k, v in est.items() if v not in (1, 2, 3, 5, 8, 13)}
if missing or extra or bad:
    sys.exit(f'refusing: {len(missing)} missing, {len(extra)} unknown ids, {len(bad)} off-scale values')

dist = collections.Counter(est.values())
print('distribution:', {p: f'{dist[p]} ({dist[p] * 100 // len(est)}%)' for p in sorted(dist)})
if dry:
    sys.exit(0)

fail = 0
for tid, p in est.items():
    r = subprocess.run(['exponential', 'tickets', 'update', '--id', tid, '--points', str(p)],
                       capture_output=True, text=True)
    if r.returncode:
        fail += 1
        print('FAIL', tid, r.stderr[:200])
print(f'wrote {len(est) - fail}, failed {fail}')
sys.exit(1 if fail else 0)
