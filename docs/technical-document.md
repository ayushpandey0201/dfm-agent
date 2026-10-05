# Technical Document — Methodology Report

DfM Analyzer for Injection Molding — Team Stack.
Covers: system architecture, algorithms (with flowcharts), validation results,
and performance. Reflects the v2 engine (Phase 2, July 2026).

---

## 1. System Architecture

Client–server, deliberately simple:

- **Backend — Python / FastAPI** (`api.py`): one endpoint `POST /analyze`
  (multipart STEP upload, optional `direction=x,y,z` form field for manual
  override). All geometry runs on OpenCASCADE via the `OCP` bindings
  (`cadquery` for tessellation export).
- **Frontend — React + Vite** (`frontend/`): three.js via
  `@react-three/fiber`. Renders color-coded faces (core / cavity / undercut /
  low-draft warning), the parting line, an exploded core–cavity view, and the
  mold-direction override panel.
- **CLI harness** (`scripts/analyze_cli.py`): headless regression runner used
  to validate every algorithm change against reference parts.

```mermaid
flowchart LR
    A[STEP file] --> B[step_parser\nfaces + surface samples]
    B --> C[UndercutRaycaster\nbuilt once per part]
    C --> D[mold_direction\naxis sweep + sign pick]
    D --> D2[silhouette\nsplit straddling faces\nfor perpendicular pulls]
    D2 --> E[draft_angle\nworst-case per face]
    E --> F[face_classifier\ncore / cavity / undercut]
    F --> G[parting_line\nsingle closed primary loop]
    F --> G2[undercut_regions\nside cores and lifters]
    G --> H[JSON response\nmetrics + tessellated geometry]
    G2 --> H
    H --> I[React 3D viewer]
```

---

## 2. STEP Parsing & Surface Sampling (`core/step_parser.py`)

Every face gets a **grid of surface samples**, not just its UV midpoint:

1. Explore all `TopAbs_FACE` entities; compute area, centroid, surface type.
2. Sample a UV grid (3×3 for planes, 5×5 for curved surfaces, capped at 15
   points). Each UV point is kept only if it classifies `TopAbs_IN` (actually
   on the trimmed face, not in a hole).
3. Store the exact surface normal at every sample
   (`GeomLProp_SLProps`, flipped for reversed faces).
4. For cylinders/cones, store the rotational axis — these become
   geometry-driven mold-direction candidates.

**Why**: a cylinder's midpoint normal misrepresents the surface (its normals
span up to 360°). Phase 1's single-normal approach was the root cause of the
undercut false positives. Multi-sampling makes every downstream verdict an
area-weighted vote over the real surface.

---

## 3. Undercut Detection (`core/undercut_detector.py`)

**Definition used (from Bosch):** *an undercut is any feature that cannot be
released from the mold* for the chosen opening direction.

A face is trapped only if **neither mold half can pull away from it**:

```mermaid
flowchart TD
    S[sample point p, normal n\npull direction d] --> Q{n · d}
    Q -- "> ε (faces cavity)" --> R1[cast ray from p along +d]
    Q -- "< -ε (faces core)" --> R2[cast ray from p along -d]
    Q -- "≈ 0 (vertical wall)" --> R3[cast rays along +d AND -d]
    R1 --> B1{blocked?}
    R2 --> B2{blocked?}
    R3 --> B3{both blocked?}
    B1 -- yes --> T[sample TRAPPED]
    B2 -- yes --> T
    B3 -- yes --> T
    B1 -- no --> F[sample free]
    B2 -- no --> F
    B3 -- no --> F
```

- Rays via `IntCurvesFace_ShapeIntersector` over a compound of all faces,
  built **once** per part and reused for every direction tested.
- Ray origin offset 0.01 mm along the surface normal; hits closer than
  0.1 mm ignored (self-intersection noise); ray length = 1.5× the part's
  bounding-box diagonal.
- **Transition filter**: only hits where the ray *enters* material
  (`IntCurveSurface_In`) count as blockers. Tangential grazes along adjacent
  walls/fillets (`Out`/`Tangent`) are not physical obstructions — this
  filter is what brings Part 1 to the judges' reference answer of **zero
  undercuts**.
- **Face verdict**: a face is an undercut when ≥ 50 % of its samples are
  trapped (`trapped_fraction`), with per-face early exit once the majority
  is decided either way.
- The trapped test is symmetric in ±d — undercuts depend on the mold *axis*,
  which halves the direction search.

---

## 4. Optimal Mold Direction (`core/mold_direction.py`)

```mermaid
flowchart TD
    A[candidate axes:\n3 cartesian + 6 diagonals\n+ cylinder/cone axes by area] --> B[for each axis:\nevaluate undercuts\n5 samples/face]
    B --> C{running undercut area\n> best so far?}
    C -- yes --> D[abort axis early\nmark candidate as pruned]
    C -- no --> E[record count + area\nsnapshot per-face verdicts]
    D --> F{more axes?}
    E --> F
    F -- yes --> B
    F -- no --> G[rank by undercut AREA,\ncount as tie-break]
    G --> H[pick pull SIGN:\ninternal features open toward core]
    H --> I[full-resolution re-check of\nfaces that showed trapping]
    I --> J[best direction + ranked candidate list]
```

Key decisions:
- **Ranking metric — area first** (per Bosch guidance): a face split into
  several patches must not outrank one large trapped face.
- **Branch-and-bound pruning**: faces are evaluated biggest-first; an axis is
  abandoned the moment its accumulated undercut area exceeds the incumbent
  best. Losing axes cost ~0 s. Pruned candidates are reported as lower
  bounds (`≥ N` in the UI, `undercuts>N` in the CLI) — never as exact values.
- **Sign selection**: undercut counts are sign-symmetric, but which half is
  *core* vs *cavity* is not. Convention (validated on the judges' cap
  example): **the core forms the internal surfaces**, entering from the side
  the part's internal features open toward; the pull direction (toward the
  cavity) is the opposite. Internal features are detected by ray probes: a
  sample whose own normal points at more part material across a void belongs
  to an internal feature, and the axis direction it escapes toward marks the
  core side. Faces covering 90 % of the surface area vote (area-weighted).
- **Winner refinement**: verdicts of the incumbent best axis are snapshotted
  during the sweep; at the end, only faces that showed any trapping are
  re-evaluated at full sample resolution.

## 5. Silhouette Splitting (`core/silhouette.py`)

A face whose normal changes sign across the pull direction is physically
formed by BOTH mold halves. `face_classifier` can only assign a whole face to
one half, so an unsplit straddling face pins the core/cavity boundary to that
face's own edges instead of letting it run through the middle where it
belongs. This never mattered for a pull roughly along a part's own axis —
Part 1 has 0% straddling area under its pull — but a pull PERPENDICULAR to a
part's dominant axis can straddle most of the surface (66% on the reviewer's
nozzle example, reconstructed from the Phase 1 call).

```mermaid
flowchart TD
    A[winning pull direction] --> B{any face's normal\nchanges sign vs pull?}
    B -- "< 2% of area" --> Z[skip: not worth\nre-parsing the shape]
    B -- ">= 2% of area" --> C{a revolved axis\nperpendicular to pull?}
    C -- no --> Z
    C -- yes --> D[cut the SHELL along the plane\ncontaining that axis, normal = pull]
    D --> E[re-sample faces from\nthe split shape]
    E --> F[continue: draft angle,\nclassification, parting line]
```

Two details decide whether the cut is safe:
- **Cuts the SHELL, never the solid.** Splitting a solid divides it into two
  bodies and injects cross-section faces that are not real part surfaces,
  which corrupts both the undercut count and the parting line.
- **Anchored on the straddling face's own axis**, not the part centroid, so
  an axis offset from the centroid does not misplace the cut.

For any surface of revolution about axis `a` with pull `d` perpendicular to
`a`, the locus `n·d = 0` sits at θ = ±90° — the plane containing `a` with
normal `d`. One planar cut therefore produces every silhouette on the part at
once, and that plane is exactly the clamshell parting plane a mold designer
would draw. Guarded three ways: skipped below 2% straddling area, skipped
when no revolved axis is perpendicular to the pull, and falls back to the
unsplit shape on any failure — so it is always safe to attempt and a no-op on
every previously-validated part.

## 6. Manual Override

`POST /analyze` with `direction=x,y,z` skips the search and evaluates exactly
that vector: undercuts, classification, parting line, and score are recomputed
so the user immediately sees the consequence of their choice (e.g. previously
free faces flagged as undercuts). The UI exposes ranked candidate buttons, a
custom vector input, and a reset to the auto-detected optimum.

---

## 7. Face Classification (`core/face_classifier.py`)

Every face gets `mold_half` (which half **forms** it) and `classification`
(render label: core / cavity / undercut):

1. **Normal voting**: area-weighted vote over surface samples —
   `n·d > 0` → cavity, `n·d < 0` → core.
2. **Vertical walls** (all samples perpendicular): assigned by
   **reachability** — rays from the wall toward each half; if the path
   toward the cavity is blocked (e.g. a bore under a closed top), only the
   core can form it, and vice versa.
3. **Through-holes / internal channels** (reachable from both halves but
   facing part material across a void): assigned to the **core** (core-pin
   convention, matching the judges' cap example).
4. **External walls reachable from BOTH halves** are genuinely ambiguous —
   physics does not decide them, and either assignment yields a
   manufacturable mold. They are deferred, grouped into connected
   **regions**, and each region is assigned by the **shared edge length** it
   has with already-decided faces (`_resolve_ambiguous_regions`). Taking the
   side with the greater shared length yields the shorter core↔cavity
   interface — the mold-design principle of keeping the split on the
   shortest closed boundary. Edge length is the weight because it is exactly
   the parting line produced; face area never appears in the boundary.
   Undercut faces are excluded from voting (a side action releases them, so
   they must not steer the main parting line). A region with no decided
   neighbour, or an exact tie, falls back to the cavity.

Draft (`core/draft_angle.py`) is orthogonal: worst-case draft angle per face
= min over samples of `asin(|n·d|)`; faces under 1° are flagged as warnings
(not undercuts — Bosch parts intentionally carry no design draft).

---

## 8. Parting Line (`core/parting_line.py`)

**Definition used (from Bosch):** *the parting curve is where core surfaces
and cavity surfaces meet*, and the main parting line must be **one closed
continuous loop** (a discontinuous loop cannot form a mold face).

```mermaid
flowchart TD
    A[all edges where a CORE face\nmeets a CAVITY face] --> B[group edges into\nconnected components]
    B --> C[chain each component:\norder edges end-to-end,\ntessellate curves adaptively]
    C --> D{closed loop?\nevery edge used once,\nends meet}
    D -- no --> E[score × 0.25\nopen chains can never win]
    D -- yes --> F[score on 6 metrics]
    F --> G[projected enclosed area 40%\nordered shoelace, non-convex safe]
    F --> H[outer-boundary confidence 20%]
    F --> I[moldability 15% · simplicity 10%\nseparation 10% · length 5%]
    G --> J[rank loops,\nselect PRIMARY]
    H --> J
    I --> J
    E --> J
    J --> K[single closed primary loop\n+ ranked alternates for debug]
```

Implementation notes:
- Long curved edges (arcs, splines) are tessellated **along the curve**
  (adaptive density — a circular rim made of 2 semicircular edges gets ~64
  points), then chained by endpoint matching into an ordered polygon. The
  shoelace area of that ordered polygon is valid for non-convex rims —
  this is what makes the true outer rim win on the Phase 2 part.
- Ambiguity flag: if the top two loops score within 5 %, the result is
  marked ambiguous and both are exposed to the UI.

---

## 9. Side Cores & Lifters (`core/undercut_regions.py`)

A trapped face's B-rep neighbours are almost never the same as its physical
feature — one circumferential groove can arrive as dozens of fillet slivers.
Reporting a raw face count therefore misrepresents the tooling problem, so
trapped faces are clustered into connected **regions** first and each region
is treated as one feature.

```mermaid
flowchart TD
    A[faces flagged is_undercut] --> B[build face adjacency\nfrom the shape]
    B --> C[connected-component\ncluster into regions]
    C --> D{internal bore/pocket,\nor external recess?}
    D -- internal --> E[lifter or\ncollapsible core]
    D -- external --> F[side-action slider]
    E --> G[retraction axis,\nangular wrap, area]
    F --> G
    G --> H[flag when several regions\nshare one axis\nvs need separate slides]
```

Each region reports its mechanism, retraction axis, angular wrap, and share
of total surface area. Regions sharing one axis (two opposed clips, for
example) are flagged distinctly from regions that would each need their own
slide, since the former is a cheaper tool. Validated against a real
GrabCAD side-core mould (see §11): the engine recommends a side-action
slider for PLASTIC BUSH's trapped feature, and the mould that was actually
built uses a Slide Core.

## 10. Manufacturability Score (`core/models.py`)

`100 − area-weighted undercut penalty − count penalty − low-draft penalties`,
clamped to [0, 100]. Both area and count matter: one large undercut is
usually easier to fix than twenty scattered ones.

---

## 11. Validation & Performance

Reference results (WSL2, single core, includes STEP parse):

| Part | Faces | Best pull | Undercuts | Core/Cavity | Primary PL | Time |
|---|---|---|---|---|---|---|
| Part 1 (Phase 1 cap) | 311 | Z+ | **0** (= judges' answer) | 269 / 42 | **planar** closed rim, 8 edges @ z=15 | ~6 s |
| Part 3 (Phase 2) | 414 | Z− | 88 (side-action clips) | 322 / 4 | planar closed circle ø36 @ z=4 | ~25 s |
| GrabCAD cup holder | 56 | Z− | 8 (snap-clip clusters) | 42 / 6 | closed loop, 24 edges, z 69.8–84.2 | ~3 s |
| Synthetic cup (ø60×80, 3 mm wall) | 5 | Z− | 0 | inner=core, outer=cavity | planar rim | <0.1 s |
| Synthetic cap + lateral hole | 7 | Z− | exactly the 2 hole walls | correct | closed rim | <0.1 s |

**External validation against a built mould.** `sidecore/` (GrabCAD) ships the
Cavity Plate and Core Plate alongside the parts they produce. The plates meet
at **z = 0**, and the engine independently puts PLASTIC BUSH's parting line at
**z = 0.00** and Coupler's at z = 1.00 (inside the plate overlap; the Core
Plate tops at +0.51). PLASTIC BUSH is also flagged with 2 undercut regions,
and the real mould uses a Slide Core. PLASTIC SLEEVE is the weakest result at
z = 2.03, about 2 mm high. These files are large third-party downloads and are
not tracked in the repo.

Synthetic parts are generated with known ground truth (cadquery) and asserted
in a **33-test** suite that gates every algorithm change: 24 in
`tests/test_synthetic.py` (construction-known answers) plus 9 in
`tests/test_parting_line_topology.py`, which assert the primary loop is a
single closed **planar** loop. The planarity assertion exists because its
absence let Part 1's parting line regress from a flat rim to a meandering
loop across three commits without any test failing.
