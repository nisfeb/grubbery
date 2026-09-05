#!/usr/bin/env python3
"""Reachability over a grubbery desk.
Follows: ford runes /- /+ /= /* (agent, marks, libs under lib/ sur/ mar/),
the ball's own `/<  face  /lib/x.hoon` (absolute = under gub/, or relative),
and [/dir %name] marc references. Roots: agents, root, the instantiated
nexuses (lattice, mcp, port), EVERY mark (a ship from any lineage may hold
grubs of them), sur, ted, gen, and (pass 1) every MCP tool.
Usage: desk-reach.py <desk> [--no-tools] [--drop-tools=prefix,prefix]"""
import os, re, sys
desk = sys.argv[1].rstrip('/')
no_tools = '--no-tools' in sys.argv
drop = []
for a in sys.argv[2:]:
    if a.startswith('--drop-tools='): drop = a.split('=', 1)[1].split(',')
files = {}
for dp, dn, fn in os.walk(desk):
    for f in fn:
        if f.endswith('.hoon'):
            p = os.path.relpath(os.path.join(dp, f), desk)
            files[p] = open(os.path.join(dp, f), encoding='utf-8', errors='replace').read()
ex = files.__contains__

def fits(name):
    # every way of reading '-' as '/', '-' preferred first, left to right
    out = [name]
    i = name.find('-')
    while i >= 0:
        out += [n[:i] + '/' + n[i+1:] for n in list(out) if n[i] == '-']
        i = name.find('-', i + 1)
    return out
def lib_path(name):
    for n in fits(name):
        for c in (f'lib/{n}.hoon', f'gub/lib/{n}.hoon'):
            if ex(c): return c
def sur_path(name):
    for n in fits(name):
        for c in (f'sur/{n}.hoon', f'gub/sur/{n}.hoon'):
            if ex(c): return c
def mar_path(dirp, name):
    d = '/'.join(s for s in dirp.split('/') if s)
    cands = [f'gub/mar/{d}/{name}.hoon', f'mar/{d}/{name}.hoon'] if d else [f'gub/mar/{name}.hoon', f'mar/{name}.hoon']
    for c in cands:
        if ex(c): return c

ford_re = re.compile(r'^\s*/([-+*=])\s+(.*)$', re.M)
ball_re = re.compile(r'^\s*/[<&]\s+\S+\s+(\S+)|^\s*/\*\s+\S+\s+%\S+\s+(\S+)', re.M)
name_re = re.compile(r'[a-z][a-z0-9-]*')
marc_re = re.compile(r'\[\s*/((?:[a-z0-9-]+/?)*)\s+%([a-z][a-z0-9-]*)\s*\]')
path_re = re.compile(r'/(?:lib|sur|mar|tests|ted|gen|app)/[a-z0-9/-]+')

def norm(p):
    parts = []
    for s in p.split('/'):
        if s in ('', '.'): continue
        if s == '..': parts and parts.pop()
        else: parts.append(s)
    return '/'.join(parts)

def deps(p):
    src = files[p]
    out = set()
    # a /+ or /- list may continue over following lines (each ends with ',')
    lines = src.split('\n'); joined = []
    i = 0
    while i < len(lines):
        m = re.match(r'^\s*/([-+*=])\s+(.*)$', lines[i])
        if m and m.group(1) in '-+':
            rest = m.group(2).split('::')[0]
            while rest.rstrip().endswith(',') and i + 1 < len(lines):
                i += 1; rest += ' ' + lines[i].split('::')[0]
            joined.append((m.group(1), rest))
        elif m: joined.append((m.group(1), m.group(2)))
        i += 1
    for rune, rest in joined:
        rest = rest.split('::')[0]
        if rune in '-+':
            for tok in re.split(r'[,\s]+', rest):
                tok = tok.strip()
                if not tok: continue
                if '=' in tok: tok = tok.split('=')[-1]
                tok = tok.lstrip('*')
                if not name_re.fullmatch(tok): continue
                q = (sur_path if rune == '-' else lib_path)(tok)
                if q: out.add(q)
        else:
            for pm in path_re.findall(rest):
                q = pm.lstrip('/') + '.hoon'
                if ex(q): out.add(q)
    in_gub = p.startswith('gub/')
    for a, b in ball_re.findall(src):
        pm = a or b
        if pm.startswith('/'):
            q = ('gub' + pm) if in_gub else pm.lstrip('/')
        else:
            q = norm(os.path.dirname(p) + '/' + pm)
        if not q.endswith('.hoon'): q += '.hoon'
        if ex(q): out.add(q)
        elif in_gub and ex(q[4:]): out.add(q[4:])
    for dirp, name in marc_re.findall(src):
        q = mar_path(dirp, name)
        if q: out.add(q)
    return out

def is_root(p):
    if p.startswith('app/') or p == 'lib/root.hoon' or p.startswith('ted/') or p.startswith('gen/'): return True
    if p.startswith('gub/nex/lattice/') or p.startswith('gub/nex/mcp/') or p in ('gub/nex/mcp.hoon', 'gub/nex/port.hoon'): return True
    if p.startswith('gub/mar/') or p.startswith('mar/') or p.startswith('sur/'): return True
    if p.startswith('gub/lib/mcp/') and not no_tools:
        base = p.split('/')[-1]
        return not any(base.startswith(d) for d in drop)
    return False
roots = {p for p in files if is_root(p)}
seen = set(roots); stack = list(roots)
while stack:
    p = stack.pop()
    for d in deps(p):
        if d not in seen: seen.add(d); stack.append(d)
unreach = sorted(p for p in files if p not in seen)
tot = sum(len(files[p]) for p in unreach)
print(f'files: {len(files)}  reachable: {len(seen)}  unreachable: {len(unreach)} ({tot//1024} KB)')
by = {}
for p in unreach:
    d = '/'.join(p.split('/')[:2]) if p.startswith('gub/') else p.split('/')[0]
    by.setdefault(d, []).append(p)
for d in sorted(by):
    t = sum(len(files[p]) for p in by[d])
    print(f'\n== {d}: {len(by[d])} files, {t//1024} KB ==')
    for p in by[d]: print('  ' + p)
if '--tools' in sys.argv:
    print('\n== MCP tools and their library imports ==')
    for p in sorted(files):
        if p.startswith('gub/lib/mcp/'):
            ds = sorted(d for d in deps(p) if not d.startswith('gub/lib/mcp/'))
            print(f'  {p.split("/")[-1][:-5]:28} {" ".join(d.replace("gub/lib/","") for d in ds)}')
