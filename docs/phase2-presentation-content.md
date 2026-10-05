# Phase 2 Presentation — Content Sheet

**DfM Auto-Analyzer · Bosch review · Team Stack (BMS College of Engineering)**

11 slides, ~15 minutes, + 4 backup slides. Copy the text as written; "Say" lines
are spoken, not printed. Every number was re-measured on the current code —
except the two marked **[not re-run]**.

| # | Slide | Time |
|---|---|---|
| 1 | Title | 10s |
| 2 | The problem, and what the tool answers | 1m |
| 3 | **Phase 1 → Phase 2: what your feedback changed** ★ | 3m |
| 4 | How it works | 1.5m |
| 5 | Undercuts and the pull direction | 2m |
| 6 | Core, cavity, and the parting line | 2m |
| 7 | **The nozzle you drew** ★ | 2.5m |
| 8 | Results | 1.5m |
| 9 | How we know it's right | 1.5m |
| 10 | Limits and roadmap | 1m |
| 11 | Live demo + close | 3m |

Slides **3** and **7** earn the room. If you lose time, cut 5 and 6 to one line
each — not those two.

---

## 1 — Title

**DfM Auto-Analyzer**
Automated injection-molding manufacturability analysis for STEP parts
Phase 2 · August 2026 · BMS College of Engineering

Vivek Boora · Ayush Pandey · Nitin · Afeera

**Visual:** one render of Part 3 from the viewer — core blue, cavity gold, cyan
parting line. No text over it.

**Say:** "Same tool you saw in June, rebuilt around your review-call feedback.
Most of my time goes on what changed and why."

---

## 2 — The problem, and what the tool answers

**Headline:** DfM review is the queue, not the work
**Sub-head:** One STEP file in. Five decisions out — in seconds.

A tooling expert inspects drafts, undercuts and the split line by hand: 3–4
hours, and only once geometry is frozen. The checks are geometric and
repeatable. They do not need a human every time.

| # | Output | Answers |
|---|---|---|
| 1 | **Pull direction** | Which way the mold opens — ranked, runners-up shown |
| 2 | **Core / cavity split** | Which half forms each face |
| 3 | **Parting line** | One closed loop where the halves meet |
| 4 | **Undercuts as features** | What is trapped, and the mechanism that frees it |
| 5 | **Draft warnings + score** | Ejection risk, and one number for triage |

**Big number:** `3–4 hours → under a minute`

**Visual:** the viewer with the metrics sidebar, five callouts.

**Say:** "We are not replacing the tool designer — we are removing the wait
before they get involved. And the important word is *deterministic*: same file,
same answer, every time. No model, no training data."

---

## 3 — Phase 1 → Phase 2 ★

**Headline:** What your feedback changed
**Sub-head:** Every item from the Phase 1 review, and what we did about it.

| Your feedback | What we changed | Where it landed |
|---|---|---|
| **"Part 1 has zero undercuts — you reported four."** | Faces are sampled on a UV grid (up to 15 points), not at one midpoint; and only rays that *enter* material count as blockers, so grazing a neighbouring fillet is no longer a trapped face. | Part 1 now reports **0 undercuts** — your reference answer. |
| **"The parting line must be one closed loop — a broken loop is solid steel."** | Boundary edges chained end-to-end, curved edges tessellated along the curve, closure verified, open chains scored ×0.25 so they can never win. | Part 1: **closed, planar, 8 edges** at z = 15. Part 3: **closed circle ø36** at z = 4. |
| **"Rank pull directions by AREA, not count."** | Area first, count breaks ties. Branch-and-bound aborts losing axes early; a pruned axis reports **≥ N**, never an exact figure. | Same winner as the exhaustive search, ~3× faster. |
| **"Even the internal surface is formed by the core."** | Vertical walls assigned by reachability rays; through-holes to the core by the core-pin convention; pull sign chosen so the core enters from the side internal features open toward. | Matches your cap example, and every synthetic part with a known answer. |
| **"A nozzle with an O-ring groove pulls perpendicular to its axis."** | New step: faces whose normal flips across the pull are split along the plane containing the part's revolved axis — the clamshell plane. | All three of your stated answers now reproduce as tests. **Slide 7.** |
| **"An undercut is a tooling decision, not a failure."** | Trapped faces cluster into connected features; each reports mechanism, retraction axis, angular wrap and area. | Part 3's 88 trapped faces read as **2 opposed side actions on one axis**. |
| *(our own gap)* Nothing caught regressions. | 33-test suite over parts built to a known answer, plus a headless CLI harness. | Slide 9. |

**Also new in the UI:** manual direction override with the ranked candidates,
exploded core/cavity view, Side Cores & Lifters panel.

**Footnote (small, keep it):** Part 1's score moved 87.2 → 88.0 and its
low-draft warnings 74 → 78. The extra four are real — draft is now the *worst*
value across a face's samples, not the midpoint value, so zero-draft bands on
curved faces stop hiding.

**Visual:** two columns, June vs August, Part 1 in each — red undercut faces on
the left, none on the right. That image is the slide.

**Say:** "Four of these came straight off your call. The false undercuts had one
root cause: we read one normal per face. A cylinder's normals sweep 360°, so one
sample was never going to be enough."

---

## 4 — How it works

**Headline:** Three tiers, eight stages, one open-source stack
**Sub-head:** Nothing here carries a per-seat licence.

| Layer | Technology |
|---|---|
| Client | React · Vite · three.js |
| API | FastAPI — `POST /analyze` (optional `direction=x,y,z`) |
| Geometry engine | OpenCASCADE via OCP · cadquery |
| Regression harness | CLI + pytest, re-run on every change |

**The pipeline:** parse & sample → build the raycaster → search the pull axis →
pick the sign → **split silhouettes** → classify → **extract the parting line** →
group undercuts & score.

**Visual:** the phase 1 three-tier diagram (it was the best slide in the old
deck) with the pipeline underneath. Highlight the three stages that are new
since phase 1: sampling, silhouette split, parting-line chaining.

**Say:** "Phase 1 had five stages. The three new ones are exactly the three
things you told us were wrong. And the kernel is OpenCASCADE — the same one
under several commercial CAD systems, so there is no licence cost to put this
on every engineer's desk."

---

## 5 — Undercuts and the pull direction

**Headline:** Ask the surface, not one point on it
**Sub-head:** The rule, and how the search uses it.

**The undercut rule:**
> A face is trapped only if **neither** half can pull away from it. Faces the
> cavity → must escape along +pull. Faces the core → along −pull. Vertical wall
> → trapped only if **both** are blocked.

Up to 15 UV samples per face; a face is an undercut when **≥ 50 %** of its
samples are trapped. Only ray hits that *enter* material block the pull.

**The direction search:**
- Undercuts are symmetric in ±d, so we search **axes** — half the rays. 9 fixed axes (3 cartesian + 6 diagonals) plus up to 3 taken from the part's own cylinders and cones.
- Ranked by **trapped area**; count only breaks ties.
- **Override**: any candidate, or a typed `x,y,z`, recomputes the whole analysis — so a tool designer sees what their own choice traps.

| Part | Winner | Trapped area | Runner-up |
|---|---|---|---|
| Part 1 | **Z+** | 0 mm² · 0 faces | 1157.8 mm² · 170 faces |
| Part 3 | **Z−** | 1366.8 mm² · 88 faces | 2082.5 mm² · 147 faces |

**Visual:** one face with a single arrow (June) vs a 5×5 grid of arrows
(August), and the ranked candidate list from the UI beside it.

**Say:** "Both parts win by a wide margin — the answer is not sitting on a knife
edge between two axes. And the tool proposes the direction; it does not decide
it."

---

## 6 — Core, cavity, and the parting line

**Headline:** Physics decides what it can. The rest goes to the shortest boundary.

| Case | Rule |
|---|---|
| Clear normal | Area-weighted vote: `n·d > 0` → cavity, `n·d < 0` → core |
| Vertical wall | **Reachability** — path to the cavity blocked (a bore under a closed top) → core |
| Through-hole | **Core**, by the core-pin convention — your cap example |
| Wall reachable from both halves | Undecided by physics. Grouped into regions, given to the side it shares the most **edge length** with |

Edge length, not area, because the shared edge *is* the parting line produced —
so the greater shared length gives the shorter core↔cavity interface.

**The parting line:** collect every core↔cavity edge → chain end-to-end,
tessellating curves *along the curve* → verify closure → rank on six metrics
(projected area 40 %, outer-boundary confidence 20 %, moldability 15 %,
simplicity 10 %, separation 10 %, length 5 %) → open chains ×0.25 → return
**one** loop. If the top two land within 5 %, it is flagged ambiguous and both
are shown.

| Part | Primary loop | Closed | Planar | Ambiguous |
|---|---|---|---|---|
| Part 1 | 8 edges, 69.5 mm, z = 15.00 | ✓ | ✓ | no |
| Part 3 | circle ø36, 113.1 mm, z = 4.00 | ✓ | ✓ | no |

**Visual:** Part 1 exploded — core blue, cavity gold, cyan rim between them,
with a side-on inset showing the rim is flat.

**Say:** "Sampling only edge endpoints collapsed a circular rim into a zero-area
polygon, which let a tiny feature loop win. Ordering points along the curve is
what makes the true outer rim come first."

---

## 7 — The nozzle you drew ★

**Headline:** The example from the review call — end to end
**Sub-head:** We rebuilt the part from your sketch and wrote your three answers down as tests.

A turned nozzle with a bore and a 360° external O-ring groove. A groove that
wraps the full circumference is trapped by **any** draw along the part's axis, at
any parting-line height.

| Your answer | Test | Status |
|---|---|---|
| The pull runs **perpendicular** to the part axis | `test_nozzle_pull_is_perpendicular_to_the_part_axis` | passes |
| The bore is formed by a **side core along the axis** | `test_nozzle_bore_is_released_by_an_axial_side_core` | passes |
| The parting plane **contains** the axis (clamshell) | `test_nozzle_parting_line_contains_the_part_axis` | passes |

**What we had to build — silhouette splitting.** A face whose normal flips
across the pull is formed by **both** halves, but the classifier can only give a
whole face to one — which pinned the boundary to that face's own edges. It never
showed while parts pulled along their own axis (Part 1: 0 % straddling area). On
this nozzle **66 %** of the surface straddles (measured: 66.3 %).

Fix: cut the **shell** — never the solid, which would inject fake cross-section
faces — along the plane containing the revolved axis, with the pull as its
normal. For a surface of revolution that single plane carries every silhouette,
and it is exactly the clamshell plane. Guarded three ways: skipped below 2 %
straddling area, skipped when no revolved axis is perpendicular to the pull, and
falls back to the unsplit shape on failure — a no-op on every part already
validated.

**Result:** the parting line was landing as a circle **across** the axis. It now
runs **along** it.

**Visual:** the nozzle with the split plane through it, before/after parting
line side by side. Your best slide — give it the most space.

**Say:** "This was not in our test set, it was on your whiteboard. We wrote your
three answers down as assertions and the third one failed until we built the
silhouette split. That is the sequence we want you to see."

---

## 8 — Results

**Headline:** Both reference parts, measured
**Sub-head:** Full output of the current engine — nothing rounded in our favour.

| | **Part 1** (Phase 1 cap) | **Part 3** (Phase 2) |
|---|---|---|
| Faces | 311 | 414 |
| Pull direction | **Z+** | **Z−** |
| Undercuts | **0** (= your reference answer) | 88 faces = **2 side actions on 1 axis** |
| Core / cavity | 269 / 42 | 322 / 4 |
| Low-draft warnings | 78 | 81 |
| Parting line | closed planar rim, 8 edges, z = 15.00 | closed planar circle ø36, z = 4.00 |
| Score | **88.0** | **81.8** |
| Time (UI path) | **3.1 s** | **21.5 s** |

**Part 3's undercuts, as tooling:** 2 external regions, 44 faces and 683.4 mm²
each, 172° wrap, z 12.35–21.65, both **side-action sliders** on opposed
directions ±(0.643, −0.766, 0) — one slide mechanism, not two. One
circumferential feature arrives from the B-rep as dozens of slivers, so a raw
face count misrepresents the tooling problem.

Timings: WSL2 laptop, single core, including STEP parse. Exact ranking of every
axis takes 11.0 s / 44.9 s; the UI prunes first and fills in the exact ranking
from a second request — same winner either way.

**Say:** "Part 3 scores lower and it should — those side actions are real
tooling cost. The score is a triage signal for sorting a folder of parts, not a
pass/fail gate. And '2 regions on 1 axis' is something a quoting engineer can
price. '88 undercut faces' is not."

---

## 9 — How we know it's right

**Headline:** Three independent checks
**Sub-head:** Your answer, a known answer, and a mold that was actually built.

**1 · Your reference answers.** Part 1 returns 0 undercuts and a flat closed rim.
The nozzle reproduces all three of your stated answers.

**2 · Parts whose answer is known by construction.** 33 tests, **32 passing** in
~3 minutes. Synthetic parts are generated with cadquery, so the answer follows
from how they were built — a cup's bore *must* belong to the core, a radial hole
*must* be the only undercut under an axial pull. 24 construction-known answers +
9 parting-line topology assertions.

> The planarity assertion exists for a reason: without it, Part 1's parting line
> drifted from a flat rim to a meandering loop across three commits and no test
> noticed.

**3 · A mold that exists.** **[not re-run — see note]** A public GrabCAD
side-core mold ships its Cavity and Core Plates next to the parts they produce.
The plates meet at **z = 0**; the engine independently puts PLASTIC BUSH's
parting line at **z = 0.00** and flags 2 undercut regions — the real mold uses a
slide core. Coupler lands at z = 1.00, inside the plate overlap. PLASTIC SLEEVE
is the weakest at z = 2.03, ~2 mm out.

**Visual:** three columns, a tick each; for column 3, the mold plate beside the
part with the z = 0 line drawn across both.

**Say:** "The third one matters most — it is the only check where the answer
came from a mold somebody actually cut steel for."

**Before you present:** that third check is the 33rd test, and it *skips itself*
on a clean clone because the CAD files are third-party. Drop
`PLASTIC BUSH.stp` into `assets/sidecore/` and re-run, so you can say "we ran it
this morning" instead of quoting a record.

---

## 10 — Limits and roadmap

**Headline:** Where the honest edges are

| Limit | Where it bites |
|---|---|
| Silhouette splitting handles **surfaces of revolution** | A freeform part needing a non-planar split still gets a planar loop |
| **One** primary parting line per analysis | A stepped parting surface is approximated by the closed loop |
| No wall thickness, sink, flow, gate or cooling | A moldability check, not a mold-flow simulation |
| Draft is **flagged, not fixed** | We do not modify geometry — no auto-drafting |

**Next, in order:** freeform silhouette splitting → wall-thickness and sink risk
→ stepped parting surfaces → multi-cavity layout and a native CAD plugin.

**Say:** "We would rather you hear these from us than find them. The first two
decide whether this generalises past turned and prismatic parts."

---

## 11 — Live demo + close

**Demo — Part 3, 2 minutes, run in this order:**
1. Upload `Part3.stp` — "414 faces, ranking every candidate axis while it renders."
2. Metrics land → **Z−**, score **81.8**, *2 regions on 1 side-action axis*.
3. Rotate once → the **cyan loop**: "closed, planar, at z = 4."
4. Toggle **Core** / **Cavity** to explode the halves → "269 faces on the core — that includes the internal surfaces."
5. **Side Cores & Lifters** panel → read one region: 172° wrap, slider, retraction axis.
6. **Override the direction** to a runner-up, let it recompute → "this is what that choice costs." Reset.

*Backup: have a screen recording of this exact sequence and the CLI output open
in tabs before you start.*

**Close — three lines:**
- Every item from the Phase 1 review is closed, and each is held closed by a test.
- The part you drew on the call now returns all three of your own answers.
- Undercuts read as tooling decisions — mechanism, axis, area — not as a face count.

**The ask:** "Give us a part where you already know the answer and we do not.
That is the fastest way to find where this breaks."

**Run it yourself:**
```
git clone https://github.com/Vivek1537/dfm-agent.git && cd dfm-agent && ./app.sh
```
Windows: double-click `app.bat`. Then open http://localhost:5173.
Deliverables: working tool · 4 documents · 33-test suite · CLI harness · two
reference parts.

---

# Backup slides

## B1 — What the colours mean

Blue = **core** (moving half, includes internal surfaces) · amber = **cavity**
(fixed half, outer shell) · red = **undercut** (neither half releases it) ·
orange = **warning** (draft below 1° — ejection risk, not a defect; your parts
carry no design draft on purpose) · cyan = **parting line**.

## B2 — The score

`100 − undercut area (≤30) − undercut count (≤20) − low-draft area (≤15) −
low-draft count (≤5)`, clamped to 0–100. Both area and count are in there
deliberately: one large undercut is usually easier to fix than twenty scattered
ones, and an area-only formula scored obviously-worse directions identically.

## B3 — Performance

Intersector built **once** per part and reused for every axis · axes only, not
directions (±d symmetry) · branch-and-bound, biggest faces first · only
trapped-suspect faces re-checked at full resolution. Measured: Part 1 11.0 s →
3.1 s, Part 3 44.9 s → 21.5 s, same winner and same score.

## B4 — Ambiguous walls

An external wall reachable from both halves is undecided by physics. A fixed
default ("always cavity") routed Part 1's boundary around every snap-tab window
instead of closing at the rim. Deciding per region, by shared **edge length**,
restores the flat 8-edge rim and leaves every previously validated part
unchanged. Half *naming* stays fixed by the internal-surfaces-are-core rule, so
this can never invert core and cavity.

---

# Numbers reference sheet

Re-measured today. Quote from here, not from memory.

**Part 1** — 311 faces · Z+ · 0 undercuts · 269 core / 42 cavity · 78 warnings ·
score 88.0 · parting line: 1 candidate loop, closed, planar, 8 edges, 69.5 mm
perimeter, 348.3 mm² projected, z = 15.000 · not ambiguous · 11.0 s exact /
3.1 s pruned.

**Part 3** — 414 faces · Z− · 88 undercut faces in 2 regions · 322 core / 4
cavity · 81 warnings · score 81.8 · parting line: 6 candidate loops, primary
closed and planar, 2 semicircular edges, 113.1 mm perimeter, 1016.2 mm²
projected, ø36, z = 4.000 · not ambiguous · 44.9 s exact / 21.5 s pruned.

**Part 3 regions** — both external, 44 faces / 683.4 mm² each, 172° wrap,
z 12.35 → 21.65, side-action sliders on ±(0.643, −0.766, 0).

**Search space** — 9 fixed axes + up to 3 from the part's own cylinders/cones,
de-duplicated. Part 1 evaluated 9 candidates, Part 3 evaluated 10.

**Tests** — 33 collected, **32 passed, 1 skipped in 175 s** (run today). The skip
is `test_bush_undercuts_match_the_reference_slide_core`; it needs
`assets/sidecore/PLASTIC BUSH.stp`, a third-party file the repo does not carry.

**Phase 1 deck said** 87.2 / 4 undercuts / 74 warnings on Part 1. **Now** 88.0 /
0 / 78. If anyone has the old deck open, the warning count is what they will
ask about — draft is now worst-case across the sample grid, not the midpoint.

**[not re-run]** the GrabCAD mold comparison (z = 0.00 / 1.00 / 2.03) — on the
project record, not a fresh reading, because the third-party CAD files are not
in the repo. Restore them and re-run before stating it as a measurement. The
nozzle's straddling figure **has** now been re-measured: **66.3 %**.

---

# Q&A prep

**"Is this AI?"** No, deliberately. Computational geometry on the OpenCASCADE
kernel — same file, same answer, every time, and every verdict traces to a ray
test you can check by hand.

**"How do you know the parting line is the one a tool designer would pick?"** It
matches your reference answer on Part 1; it is asserted closed and planar by
tests; and on a mold whose plates were actually cut, the engine put the line at
z = 0.00 against a real plate interface at z = 0.

**"What if our tool designer disagrees with the direction?"** They override it —
ranked candidate or typed vector — and the whole analysis recomputes, so they
see immediately what their choice traps.

**"Why does Part 3 score 81.8 if the side actions are legitimate?"** Because they
cost money. It is a triage signal for sorting parts by tooling complexity, not a
verdict on one part.

**"How does it scale to 5,000 faces?"** Runtime scales with faces × candidate
axes; our worst measured case is 414 faces in 22 s. The intersector is built once
and pruning kills losing axes early, so growth is closer to linear in faces than
in candidates. We have not profiled a 5,000-face part and will not claim a number
for one.

**"Wall thickness / mold flow?"** Out of scope, first on the roadmap after
freeform splitting.

**"Licensing / deployment?"** Fully open-source stack, runs locally — no part
geometry leaves the machine. That usually matters more than the licence.

**"What breaks it?"** A freeform part needing a non-planar split, and a stepped
parting surface. Both on slide 10.

---

# Images

All of them are in `docs/deck-images/`, with a slide-by-slide index in that
folder's README. They are real engine output and real screenshots of the running
app — no mock-ups. The 3D renders are transparent-background PNGs at 2400×1800,
so they sit on either slide background, and `scripts/render_deck_images.py`
regenerates them.

The two that carry the meeting:

- **Slide 3's June/August pair** — the four faces the Phase 1 engine flagged, in
  red, against the same part with the same camera and no red. The June frame was
  produced by running commit `63a5b2d`, the actual Phase 1 code, which reports
  87.2 / 4 undercuts / 74 warnings — the Phase 1 deck's own numbers.
- **Slide 7's nozzle pair** — the parting line as a circle *across* the axis with
  silhouette splitting disabled, and running *along* the axis with it on.

# Design notes

- **One idea per slide.** Slides 5 and 6 each carry two merged topics — if either feels crowded when built, push the parting-line table to backup.
- **Build two custom graphics and no more:** Part 1 with red faces vs without (slide 3), and the nozzle's parting line across the axis vs along it (slide 7).
- **Keep the phase 1 architecture diagram.** It was the best slide in the old deck.
- **Dropped from phase 1:** the four near-identical "Four Views. One Upload." slides — one idea over four slides. Slide 2 and the live demo replace them.
- **Speaker notes carry the depth.** Everything under "Say" is spoken, not printed.
