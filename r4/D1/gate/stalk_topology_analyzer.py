#!/usr/bin/env python3
"""
stalk_topology_analyzer.py -- event-time readout for lamellar -> stalk / non-lamellar transitions in
Martini 3 stacked-bilayer simulations (works for any pressure coupling / box shape that stays orthorhombic).

WHAT IT MEASURES (per frame)
  1. Tail continuum connectivity:  all lipid tail beads (default regex ^[CD][0-9][AB]$ , e.g. C1A D2A C3A C4A C1B D2B C3B C4B
     of DOPE/DOPC) are linked if closer than --cutoff (default 0.75 nm) under periodic boundary conditions.
       ncl  = number of connected components.  Intact stack of two bilayers separated by water: ncl = 2.
              A stalk / pore / fusion bridge between bilayers: ncl -> 1.
       wind = rank of the set of winding vectors of the largest component (0-3): the dimensionality of percolation.
              Each isolated bilayer percolates in 2 directions (wind = 2).  When BOTH water gaps of a periodic
              2-bilayer stack are bridged, the tail continuum percolates along the stack normal too (wind = 3).
              Fully 3D-connected hydrophobic continuum = lamellar bilayers merged / H_II-like / cubic-like.
  2. Layering contrast along x, y, z of PO4 (position of the phosphate bead): Cx, Cy, Cz = std/mean of the 1D histogram
     (0.25 nm bins).  Cz ~ 1.9 for an intact stack (stack normal = z); falls when layering is lost.
  3. Polar-domain connectivity (headgroup/glycerol beads NH3 NC3 PO4 GL0 GL1 GL2 CNO plus water beads, cutoff --polar-cutoff,
     default 0.8 nm): npol, wpol.  Intact 2-bilayer stack: npol = 2, wpol = 2 (two polar slabs).  Water/headgroup TUBES (H_II)
     would give wpol = 1.  wpol = 2 with npol > 2 = polar slabs with holes/fragments (intermediate states).
  4. Box lengths and angles.
EVENT TIMES (written to the summary JSON): first time ncl==1 sustained for >= --persist ns ('t_merge'), first time wind==3
  sustained >= --persist ns ('t_wind3'); None if never (right-censored at the last frame -> use with survival statistics).

LIMITS (read before use)
  * ncl==1 means "tail continuum connected" (stalk, pore, hemifusion, fusion, H_II ...): it is NOT a phase assignment.
    Phase assignment (H_II lattice, d_NN, order) still needs the lattice/order readouts.
  * Written for orthorhombic boxes (angles ~90 deg).  Triclinic boxes need the minimum-image logic extended.
  * Validated only on 3 w/l DOPE 2-bilayer stacks (256 lipids, 0.5 ns/frame; 01_实验复盘 section 5; n = 1-2, exploratory):
    the initial structure gives ncl=2, wind=2, npol=2, wpol=2; a 380 K run gives ncl 2->1 between 0.4 and 0.5 ns, wind 3 at 1.0 ns and, from ~47 ns, polar
    domains with winding rank 1 (water-tube-like, tails still wind=3); at 320 K one of two c-rescale runs develops a persistent interbilayer
    bridge (ncl=1, wind=2) at 63.0 ns, both water gaps bridged (wind=3) from 108 ns, with the polar domains still sheets (wpol=2).  Single-frame contacts
    (ncl=1 for one 0.5 ns frame) occur in several runs of both barostat arms and are not counted as events (--persist 5).
    No validation on other lipids, hydrations or on real H_II lattices; wpol=1 is a topological signature only (no lattice / d_NN is measured).
  * Cutoff 0.75 nm is a choice, not a calibrated threshold.  On the runs above the persistent-bridge call is stable for 0.65-0.95 nm; 0.55 nm is too tight
    for the starting structure (the tail network splits into >=3 components).  Re-check with --cutoff (kit: scripts/sens_all.py) before trusting events on other systems.

USAGE
  python stalk_topology_analyzer.py TOPOLOGY.gro TRAJ.xtc --out series.csv --summary summary.json [--every 1]
"""
import argparse, json, re, sys
import numpy as np
import MDAnalysis as mda
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components

def tail_topology(pos_nm, box_nm, cutoff=0.75):
    """return (n_components, size_of_largest, winding_rank_of_largest)"""
    L = np.asarray(box_nm[:3], float)
    p = np.mod(pos_nm, L)
    pairs = cKDTree(p, boxsize=L).query_pairs(cutoff, output_type='ndarray')
    n = len(p)
    if len(pairs) == 0:
        return n, 1, 0
    i, j = pairs[:, 0], pairs[:, 1]
    ncl, lab = connected_components(coo_matrix((np.ones(len(i)), (i, j)), shape=(n, n)), directed=False)
    sizes = np.bincount(lab)
    big = int(np.argmax(sizes))
    members = set(np.where(lab == big)[0].tolist())
    sel = np.array([a in members for a in i])
    ei, ej = i[sel], j[sel]
    adj = {}
    for a, b in zip(ei.tolist(), ej.tolist()):
        adj.setdefault(a, []).append(b)
        adj.setdefault(b, []).append(a)
    start = next(iter(members))
    off = {start: np.zeros(3)}
    stack = [start]
    while stack:
        a = stack.pop()
        for b in adj.get(a, []):
            if b not in off:
                dx = p[b] - p[a]
                dx -= L * np.round(dx / L)
                off[b] = off[a] + dx
                stack.append(b)
    wind = []
    for a, b in zip(ei.tolist(), ej.tolist()):
        dx = p[b] - p[a]
        dx -= L * np.round(dx / L)
        w = np.round((off[a] + dx - off[b]) / L)
        if np.any(w != 0):
            wind.append(w)
    rank = int(np.linalg.matrix_rank(np.array(wind))) if wind else 0
    return int(ncl), int(sizes[big]), rank

def first_sustained(times, flags, persist_ns):
    """first time t such that flags stay True for >= persist_ns (or until the end if the run ends earlier -> not counted)"""
    n = len(times)
    for k in range(n):
        if not flags[k]:
            continue
        m = k
        while m + 1 < n and flags[m + 1]:
            m += 1
        if times[m] - times[k] >= persist_ns:
            return float(times[k])
    return None

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('topology'); ap.add_argument('trajectory')
    ap.add_argument('--out', default='series.csv'); ap.add_argument('--summary', default='summary.json')
    ap.add_argument('--cutoff', type=float, default=0.75); ap.add_argument('--every', type=int, default=1)
    ap.add_argument('--tail-regex', default=r'^[CD][0-9][AB]$'); ap.add_argument('--po4', default='PO4')
    ap.add_argument('--persist', type=float, default=5.0, help='ns an event must persist to be counted')
    ap.add_argument('--polar-cutoff', type=float, default=0.8)
    ap.add_argument('--polar-select', default='name NH3 NC3 PO4 GL0 GL1 GL2 CNO or resname W')
    a = ap.parse_args()
    u = mda.Universe(a.topology, a.trajectory)
    rx = re.compile(a.tail_regex)
    tails = u.atoms[[i for i, nm in enumerate(u.atoms.names) if rx.match(nm)]]
    po4 = u.select_atoms('name ' + a.po4)
    polar = u.select_atoms(a.polar_select)
    rows = []
    for ts in u.trajectory[::a.every]:
        box = ts.dimensions[:3] / 10.0
        ncl, big, wr = tail_topology(tails.positions / 10.0, box, a.cutoff)
        pp = po4.positions / 10.0
        C = []
        for ax in range(3):
            h, _ = np.histogram(np.mod(pp[:, ax], box[ax]), bins=int(round(box[ax] / 0.25)), range=(0, box[ax]))
            C.append(float(h.std() / max(h.mean(), 1e-9)))
        npol, _, wpol = tail_topology(polar.positions / 10.0, box, a.polar_cutoff)
        rows.append((float(ts.time) / 1000.0, *box, *ts.dimensions[3:], ncl, big, wr, *C, npol, wpol))
    cols = ['t_ns', 'Lx', 'Ly', 'Lz', 'alpha', 'beta', 'gamma', 'ncl', 'n_largest', 'wind', 'Cx', 'Cy', 'Cz', 'npol', 'wpol']
    with open(a.out, 'w') as f:
        f.write(','.join(cols) + '\n')
        for r in rows:
            f.write(','.join('%.4f' % x if isinstance(x, float) else str(x) for x in r) + '\n')
    t = np.array([r[0] for r in rows]); ncl = np.array([r[7] for r in rows]); wd = np.array([r[9] for r in rows])
    summ = dict(n_frames=len(rows), t_first=float(t[0]), t_last=float(t[-1]), cutoff_nm=a.cutoff, persist_ns=a.persist,
                t_merge=first_sustained(t, ncl == 1, a.persist), t_wind3=first_sustained(t, wd == 3, a.persist),
                ncl_last=int(ncl[-1]), wind_last=int(wd[-1]), npol_last=int(rows[-1][13]), wpol_last=int(rows[-1][14]),
                censored_at_ns=float(t[-1]))
    json.dump(summ, open(a.summary, 'w'), indent=1)
    print(json.dumps(summ))

if __name__ == '__main__':
    main()
