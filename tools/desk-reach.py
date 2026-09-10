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
    #  gub/lib/tool-bundle/ is HERMETIC. It is never compiled in the desk's
    #  namespace: mcp.hoon takes it as a directory import and seeds it into
    #  its tools.tools child as that instance's own /code/lib, and a code
    #  namespace never falls back to a parent (+find-code-ns: "Lower
    #  namespaces must include marks/libs they need"). So a tool's
    #  `/lib/tools.hoon` means tool-bundle/tools.hoon, not gub/lib/tools.hoon.
    #  Resolving it against gub/lib was silent and total: the walker pruned
    #  the bundle's own copies of its deps, every lattice tool then failed to
    #  compile, +scan-own skips a tool that will not compile without a word,
    #  and the mcp app listed zero tools.
    bundle = 'gub/lib/tool-bundle/'
    for a, b in ball_re.findall(src):
        pm = a or b
        if pm.startswith('/'):
            if p.startswith(bundle) and pm.startswith('/lib/'):
                q = bundle + pm[len('/lib/'):]
            else:
                q = ('gub' + pm) if in_gub else pm.lstrip('/')
        else:
            q = norm(os.path.dirname(p) + '/' + pm)
        #  A DIRECTORY import (/& on a trailing slash) pulls in everything
        #  under it - the shell's docs-agent takes /lib/docs-tools/ that way.
        if q.endswith('/'):
            for f in files:
                if f.startswith(q): out.add(f)
            continue
        #  Try the path AS WRITTEN before assuming .hoon. Appending it
        #  unconditionally is what made this walker call shell/home.html,
        #  marked.min.js and hoon-grammar.json unreachable: it looked for
        #  home.html.hoon. The trim then deleted all three, the shell would
        #  not compile, and its HTTP binding went with it.
        if not ex(q) and not q.endswith('.hoon'): q += '.hoon'
        if ex(q): out.add(q)
        elif in_gub and ex(q[4:]): out.add(q[4:])
    for dirp, name in marc_re.findall(src):
        q = mar_path(dirp, name)
        if q: out.add(q)
    return out

def is_root(p):
    if p.startswith('app/') or p == 'lib/root.hoon' or p.startswith('ted/') or p.startswith('gen/'): return True
    if p.startswith('gub/nex/lattice/') or p.startswith('gub/nex/mcp/') or p == 'gub/nex/mcp.hoon': return True
    #  The shell and the desk nexus are what this distribution now runs ON,
    #  not apps it happens to carry: the shell manages permissions and owns
    #  cross-ship discovery, and the desk nexus mirrors a published code
    #  directory. The 2026-09-05 trim deleted both, because at the time
    #  nothing reached them.
    #
    #  What is NOT a root, deliberately, on the assumption that every other
    #  app arrives by adding a peer and installing it:
    #    gub/nex/tiles.hoon         the shell welds read-local-tiles with
    #                               read-app-tiles, and an absent store peeks
    #                               to a non-%ball view and returns ~. App
    #                               tiles come from each app's own tile.json,
    #                               so the launcher grid works without it.
    #    gub/nex/notifications.hoon +register-notify is poke-soft and says so:
    #                               "a failed registration is logged, not
    #                               fatal - re-run on every rise".
    #    gub/nex/peers.hoon         the usergroup/ship-management UI, not the
    #                               peering mechanism (that is the shell's
    #                               peers.json poke and /peers mirrors).
    #  gub/nex/tools.hoon is a root because nothing IMPORTS it: mcp's
    #  tools.tools CHILD INSTANCE needs the nexus to exist, and reachability
    #  by import cannot see that. Same shape as the /apps rows in root.hoon.
    if p.startswith('gub/nex/shell/') or p.startswith('gub/nex/desk/') or p in ('gub/nex/shell.hoon', 'gub/nex/desk.hoon', 'gub/nex/tools.hoon'): return True
    #  explorer is a DEFAULT app, not an app-tier extra: it is the only way
    #  to look at the namespace on a ship that has just booted, so it has a
    #  root.hoon row and therefore a root here. It costs feather.hoon and
    #  ~83 KB of its own assets; the codemirror and lib/ui bundles it uses
    #  were already carried.
    if p.startswith('gub/nex/explorer/') or p == 'gub/nex/explorer.hoon': return True
    #  the git forge, and the git_repo nexus its instances run. data.hoon is
    #  reached by no import - forge houses it as a CHILD INSTANCE - so it is
    #  a root for the same reason gub/nex/tools.hoon is.
    if p.startswith('gub/nex/git/'): return True
    #  create_desk: the tool that installs a code dir as a stock desk. Nothing
    #  imports a tool; the bundle is a directory import, and the trim scopes
    #  that directory to what we name here.
    if p == 'gub/lib/tool-bundle/tools/create-desk.hoon': return True
    if p.startswith('gub/mar/') or p.startswith('mar/') or p.startswith('sur/'): return True
    #  Only LATTICE's tools are roots. Upstream's tool-bundle carries 92
    #  more - bitcoin, s3, calendar, the assistants - and a lattice ship
    #  has no use for them; treating the whole directory as roots would
    #  drag their libs back in and undo the trim. mcp.hoon imports the
    #  bundle as a DIRECTORY, so a smaller directory is simply a smaller
    #  tool list, which is what a lattice-only distribution wants.
    if p.startswith('gub/lib/tool-bundle/tools/lattice-') and not no_tools:
        base = p.split('/')[-1]
        return not any(base.startswith(d) for d in drop)
    #  The three META-tools. tools/list over the MCP protocol does not
    #  advertise the registry: mcp-rpc +handle-request skims it down to
    #  list_tools, call_tool and echo, and a client reaches everything else
    #  through call_tool. Trim those three away and an MCP client sees a
    #  server with no tools at all, however full the registry is - which is
    #  exactly what happened. Each imports only /lib/tools.hoon.
    if p in ('gub/lib/tool-bundle/tools/echo.hoon',
             'gub/lib/tool-bundle/tools/list-tools.hoon',
             'gub/lib/tool-bundle/tools/call-tool.hoon'): return True
    #  tool-bundle's own copy of the tool interface: hermetic, so the bundle
    #  needs it even though the desk has gub/lib/tools.hoon.
    if p == 'gub/lib/tool-bundle/tools.hoon': return True
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
