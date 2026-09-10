#!/usr/bin/env python3
"""Every import in every remaining .hoon under gub/ must resolve to a file
that is still here. The bar is 0.

This exists because desk-reach.py was wrong and said so confidently. It
appended .hoon to every import, so it never saw shell/home.html or
marked.min.js, called them unreachable, and the trim deleted the files the
shell needs - after which shell.hoon did not compile and its HTTP binding
went with it, while the walker still reported a clean run.

So a trim is gated on TWO passes computed differently: desk-reach.py says
what nothing reaches, this says what is reached but missing. Neither alone
is evidence.

Usage: imports-resolve.py <desk>
"""
import os, re, sys
desk = sys.argv[1].rstrip('/')
files = set()
for dp, dn, fn in os.walk(desk):
    for f in fn:
        files.add(os.path.relpath(os.path.join(dp, f), desk))
def norm(p):
    o = []
    for s in p.split('/'):
        if s in ('', '.'): continue
        if s == '..': o and o.pop()
        else: o.append(s)
    return '/'.join(o)
ball = re.compile(r'^\s*/[<&]\s+\S+\s+(\S+)|^\s*/\*\s+\S+\s+%\S+\s+(\S+)', re.M)
bad = []
hoon = sorted(f for f in files if f.endswith('.hoon'))
for p in hoon:
    src = open(os.path.join(desk, p), encoding='utf-8', errors='replace').read()
    in_gub = p.startswith('gub/')
    #  the tool bundle is a hermetic sub-namespace: mcp seeds it into its
    #  tools.tools child as that instance's own /code/lib, so /lib/x.hoon
    #  there means tool-bundle/x.hoon, not gub/lib/x.hoon.
    bundle = 'gub/lib/tool-bundle/'
    for a, b in ball.findall(src):
        pm = a or b
        if pm.startswith('/'):
            if p.startswith(bundle) and pm.startswith('/lib/'):
                q = bundle + pm[len('/lib/'):]
            else:
                q = ('gub' + pm) if in_gub else pm.lstrip('/')
        else:
            q = norm(os.path.dirname(p) + '/' + pm)
        q = norm(q)
        if pm.endswith('/'):
            if not any(f.startswith(q + '/') for f in files): bad.append((p, pm, 'dir'))
            continue
        if q in files or q + '.hoon' in files: continue
        if in_gub and (q[4:] in files or q[4:] + '.hoon' in files): continue
        bad.append((p, pm, 'file'))
print(f'{len(hoon)} hoon files, {len(files)} files total, {len(bad)} unresolved imports')
for p, q, k in bad: print(f'   {k:4} {q:44} <- {p}')
sys.exit(1 if bad else 0)
