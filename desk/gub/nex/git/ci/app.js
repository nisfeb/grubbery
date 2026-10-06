// forge ci: runs, watched repos and runners, from /api/state every 3 s.
// Everything from the ship is set as text, never as HTML: repo names, log
// lines and workflow errors come from people who can push to GitHub.
const api = '/grubbery/forge/ci/api/'
const $ = (id) => document.getElementById(id)
let state = null
let open = null // {run, job, from, text}

function h(tag, attrs = {}, ...kids) {
  const el = document.createElement(tag)
  for (const [k, v] of Object.entries(attrs)) {
    if (k.startsWith('on')) el.addEventListener(k.slice(2), v)
    else if (v !== null && v !== undefined && v !== false) el.setAttribute(k, v)
  }
  for (const kid of kids.flat()) el.append(kid instanceof Node ? kid : String(kid ?? ''))
  return el
}

async function post(path, body) {
  const res = await fetch(api + path, {
    method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(body),
  })
  const text = await res.text()
  let jon = {}
  try { jon = JSON.parse(text) } catch { jon = { error: text } }
  if (!res.ok) throw new Error(jon.error || `${res.status}`)
  return jon
}

function ago(ms) {
  if (!ms) return ''
  const s = Math.max(0, Math.round((state.now - ms) / 1000))
  if (s < 60) return `${s}s ago`
  if (s < 3600) return `${Math.round(s / 60)}m ago`
  if (s < 86400) return `${Math.round(s / 3600)}h ago`
  return new Date(ms).toLocaleString()
}

function took(job) {
  if (!job.started) return ''
  const s = Math.round(((job.ended || state.now) - job.started) / 1000)
  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m ${s % 60}s`
}

const csv = (s) => s.split(',').map((x) => x.trim()).filter(Boolean)
const online = (r) => r.status && r.status.seen && state.now - r.status.seen < 3 * 60 * 1000

// a queued runner job no online runner can take is shown as waiting
function shown(job) {
  if (job.state !== 'queued') return job.state
  const can = state.runners.some((r) => online(r) && r.enabled !== false &&
    (job.runs_on || []).every((l) => (r.status.labels || []).includes(l)) &&
    (!(r.repos || []).length || r.repos.includes(job.repo)))
  return can ? 'queued' : 'waiting'
}

function act(label, fn) {
  return h('button', { onclick: async (e) => {
    e.target.disabled = true
    try { await fn() } catch (err) { $('status').textContent = err.message }
    e.target.disabled = false
    refresh()
  } }, label)
}

function renderRuns() {
  const runs = state.runs
  $('runs-count').textContent = runs.length || ''
  const t = $('runs')
  t.replaceChildren()
  if (!runs.length) { t.append(h('tr', {}, h('td', { class: 'empty' }, 'no runs yet'))); return }
  t.append(h('tr', {}, ['when', 'repo', 'workflow', 'branch', 'commit', 'jobs', ''].map((c) => h('th', {}, c))))
  for (const r of runs) {
    const jobs = r.job_states || []
    const live = jobs.some((j) => j.state === 'queued' || j.state === 'running')
    t.append(h('tr', {},
      h('td', { class: 'muted', title: new Date(r.made).toLocaleString() }, ago(r.made)),
      h('td', {}, r.repo),
      h('td', {}, r.workflow, r.trigger === 'manual' ? h('span', { class: 'muted' }, ' (manual)') : ''),
      h('td', {}, r.branch),
      h('td', { class: 'mono' }, (r.sha || '').slice(0, 7)),
      h('td', {}, jobs.map((j) => h('span', {
        class: `badge ${shown(j)}`,
        title: j.error || `${shown(j)} ${took(j)}`,
        onclick: () => openLog(r.run, j.job),
      }, `${j.job} ${shown(j)}`))),
      h('td', {}, live ? act('cancel', () => post('cancel', { run: r.run }))
                       : act('rerun', () => post('rerun', { run: r.run }))),
    ))
  }
}

function renderWatched() {
  const ws = state.watched
  $('watched-count').textContent = ws.length || ''
  const t = $('watched')
  t.replaceChildren()
  if (!ws.length) { t.append(h('tr', {}, h('td', { class: 'empty' }, 'no watched repos'))); return }
  t.append(h('tr', {}, ['repo', 'branches', 'poll', 'last seen tips', ''].map((c) => h('th', {}, c))))
  for (const w of ws) {
    const seen = w.seen || {}
    t.append(h('tr', {},
      h('td', {}, w.repo),
      h('td', {}, (w.branches || []).map((b) =>
        h('span', {}, b, ' ', act('run now', () => post('run', { name: w.name, branch: b })), ' '))),
      h('td', { class: 'muted' }, `${w.minutes}m`),
      h('td', { class: 'mono' }, Object.keys(seen).length
        ? Object.entries(seen).map(([b, s]) => `${b} ${String(s).slice(0, 7)}`).join(', ')
        : h('span', { class: 'muted' }, 'not checked yet')),
      h('td', {}, act('remove', () => post('watched/delete', { name: w.name }))),
    ))
  }
}

function renderRunners() {
  const rs = state.runners
  $('runners-count').textContent = rs.length || ''
  const t = $('runners')
  t.replaceChildren()
  if (!rs.length) { t.append(h('tr', {}, h('td', { class: 'empty' }, 'no runners yet'))); return }
  t.append(h('tr', {}, ['name', 'labels', 'platform', 'state', 'last seen', 'job', 'repos', ''].map((c) => h('th', {}, c))))
  for (const r of rs) {
    const s = r.status || {}
    t.append(h('tr', {},
      h('td', {}, r.name, h('div', { class: 'muted mono' }, r.id)),
      h('td', {}, (s.labels || []).join(', ')),
      h('td', { class: 'muted' }, s.os ? `${s.os}/${s.arch} ${s.version || ''}` : 'never connected'),
      h('td', { class: online(r) ? 'online' : 'offline' },
        r.enabled === false ? 'disabled' : online(r) ? 'online' : 'offline'),
      h('td', { class: 'muted' }, ago(s.seen)),
      h('td', { class: 'mono' }, s.job || ''),
      h('td', { class: 'muted' }, (r.repos || []).join(', ') || 'any'),
      h('td', {},
        act(r.enabled === false ? 'enable' : 'disable',
          () => post('runners/set', { id: r.id, enabled: r.enabled === false })),
        ' ',
        act('revoke', () => confirmed(`revoke ${r.name}? its key stops working`) &&
          post('runners/delete', { id: r.id }))),
    ))
  }
}

// a second click within 4 s confirms; no browser dialogs
let armed = null
function confirmed(msg) {
  if (armed === msg) { armed = null; return true }
  armed = msg
  $('status').textContent = `${msg} (click again to confirm)`
  setTimeout(() => { if (armed === msg) armed = null }, 4000)
  return false
}

async function openLog(run, job) {
  open = { run, job, from: 0, text: '' }
  await pollLog()
}

async function pollLog() {
  const box = $('log')
  if (!open) { box.replaceChildren(); return }
  const { run, job } = open
  try {
    const res = await fetch(`${api}log?run=${encodeURIComponent(run)}&job=${encodeURIComponent(job)}&from=${open.from}`)
    const j = await res.json()
    if (!open || open.run !== run || open.job !== job) return
    open.text += j.text || ''
    open.from = j.next
  } catch {}
  const st = findJob(run, job)
  box.replaceChildren(
    h('h2', {}, `log: ${job}`, h('span', { class: 'count' }, st ? `${shown(st)} ${took(st)}` : ''),
      h('button', { onclick: () => { open = null; pollLog() } }, 'close')),
    st && st.error ? h('div', { class: 'err' }, st.error) : '',
    h('pre', {}, open.text || '(no output yet)'),
  )
  const pre = box.querySelector('pre')
  pre.scrollTop = pre.scrollHeight
}

function findJob(run, job) {
  const r = state && state.runs.find((x) => x.run === run)
  return r && (r.job_states || []).find((x) => x.job === job)
}

async function refresh() {
  try {
    const res = await fetch(api + 'state')
    if (!res.ok) throw new Error(`state: ${res.status}`)
    state = await res.json()
    renderRuns(); renderWatched(); renderRunners()
    if (open) {
      const st = findJob(open.run, open.job)
      if (st && (st.state === 'queued' || st.state === 'running' || open.from === 0)) await pollLog()
    }
  } catch (err) { $('status').textContent = err.message }
}

$('watch-form').addEventListener('submit', async (e) => {
  e.preventDefault()
  const f = new FormData(e.target)
  try {
    await post('watched/add', { repo: f.get('repo').trim(), branches: csv(f.get('branches') || ''),
                                minutes: Number(f.get('minutes')) || 5 })
    e.target.reset(); $('status').textContent = ''
  } catch (err) { $('status').textContent = err.message }
  refresh()
})

$('runner-form').addEventListener('submit', async (e) => {
  e.preventDefault()
  const f = new FormData(e.target)
  try {
    const k = await post('runners/add', { name: f.get('name').trim(), repos: csv(f.get('repos') || '') })
    const cfg = JSON.stringify({ ship: location.origin, key: k.key, labels: ['linux', 'x86_64'],
                                 workdir: '/var/lib/forge-runner/work' }, null, 2)
    $('new-key').replaceChildren(h('div', { class: 'key' },
      h('strong', {}, 'This key is shown once. '), 'Put it in forge-runner.json on the build machine and set its labels:',
      h('pre', { class: 'mono' }, cfg),
      h('button', { onclick: () => $('new-key').replaceChildren() }, 'I saved it')))
    e.target.reset(); $('status').textContent = ''
  } catch (err) { $('status').textContent = err.message }
  refresh()
})

refresh()
setInterval(refresh, 3000)
