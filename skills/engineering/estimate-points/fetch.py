#!/usr/bin/env python3
"""Fetch Exponential tickets to score into a JSON file.

Status scope picks up only tickets with no points; --ticket picks the named
tickets whatever their points (a deliberate re-score).
Runs `exponential` with the inherited HOME, so prefix this script the same way
the repo prefixes its `exponential` calls.
"""
import argparse, json, subprocess, sys

ap = argparse.ArgumentParser()
ap.add_argument('--workspace', required=True, help='workspace slug or CUID')
ap.add_argument('--product', required=True, help='product slug or CUID')
ap.add_argument('--status', default='DONE,DEPLOYED')
ap.add_argument('--ticket', action='append', default=[], help='ticket number or CUID (repeatable)')
ap.add_argument('--out', required=True)
a = ap.parse_args()


def list_tickets(status=None):
    cmd = ['exponential', 'tickets', 'list', '--product', a.product, '--workspace', a.workspace, '--json']
    if status:
        cmd += ['--status', status]
    data = json.loads(subprocess.run(cmd, capture_output=True, text=True, check=True).stdout)
    return data['tickets'] if isinstance(data, dict) and 'tickets' in data else data


if a.ticket:
    wanted = set(a.ticket)
    picked = [t for t in list_tickets() if t['id'] in wanted or str(t['number']) in wanted
              or (t.get('shortId') and t['shortId'] in wanted)]
    found = {t['id'] for t in picked} | {str(t['number']) for t in picked} | {t.get('shortId') for t in picked}
    missing = wanted - found
    if missing:
        sys.exit(f'not found in this product: {", ".join(sorted(missing))}')
else:
    picked = [t for s in a.status.split(',') for t in list_tickets(s) if not t.get('points')]

todo = [{'id': t['id'], 'n': t['number'], 'type': t['type'], 'title': t['title'],
         'body': (t.get('body') or '')[:2500]} for t in picked]
json.dump(todo, open(a.out, 'w'), indent=1)
empty = sum(1 for t in todo if len(t['body'].strip()) < 40)
print(f'{len(todo)} tickets to score -> {a.out} ({empty} with empty/stub bodies)')
