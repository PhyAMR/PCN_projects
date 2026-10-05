# Combined report — working guideline

One PDF, two independent projects, ten pages of body text.

| | Project | Score | Chapters | Body pages |
|---|---|---|---|---|
| Part I | 45 — Network reconstruction from EvoSim trajectories | 1.2 | 1–4 | 6 |
| Part II | 24 — Entanglement percolation (Cuquet & Calsamiglia, PRL 103, 240503) | 0.6 | 5–8 | 4 |

The split follows the scores. The front page, the reference list and the appendices do not count against the ten pages; the course rule allows up to five supplementary pages per task, which is a large budget you should use rather than fight the limit in the body.

## Where things live

```
reports/
├── GUIDELINES.md          this file
├── check_pages.sh         page-budget check after each render
├── main.pdf               rendered output (overwritten by quarto render)
└── report/
    ├── _quarto.yml        output-dir: ..
    ├── main.qmd           includes all eight chapters, budget in a comment
    ├── bibliography.bib   shared, split into three commented blocks
    ├── base/              packages.tex, style.tex, quarto-header.tex
    ├── images/            logo, cover art
    ├── briefs/            project_45.md, project_24.md, the PRL paper
    ├── figures/p45/       figures for Part I
    ├── figures/p24/       figures for Part II
    └── sections/
        ├── front_page.tex
        ├── p45_task1..4.qmd
        ├── p24_task1..4.qmd
        ├── references.qmd
        └── appendix.qmd
```

Render with `cd reports/report && quarto render`, then `bash reports/check_pages.sh`.

Your R code stays where it already is: `data_pprojects/project_45/code/` and a new `theoretical_projects/topic_08_quantum_networks/project_24/code/`. Figures are written by those scripts into `reports/report/figures/p45/` and `figures/p24/` as PDF, and the `.qmd` files only reference them. Do not put live R chunks in the report — a render that has to re-run a 1200-epoch analysis is a render you will stop doing.

Every chapter is a `# Heading`, which in `documentclass: report` is a `\chapter` and therefore starts on a fresh page. Eight chapters, ten pages: chapters 2 and 3 get two pages each and the rest get one. There is no slack for a half-empty page anywhere, so write each chapter to fill its allocation.

---

# Part I — Project 45

The brief lists seven analysis objectives and six deliverables. The chapter split maps onto them one-to-one, so nothing can be silently dropped:

| Chapter | Objectives | Deliverables |
|---|---|---|
| 1 | 1 | cleaned trajectory data |
| 2 | 2, 3 | two network types, node/edge files, snapshot visualisations |
| 3 | 4, 5 | — |
| 4 | 6, 7 + extensions | — |
| — | — | scripts (live in `code/`, referenced from ch. 1 and the appendix) |

## Step 1 — the data (done)

All runs from `code/run_simulations.sh` have been executed and live in `data/raw/` (208 MB). The ex-post theoretical analysis (`evosim.analysis.theory`) has been applied to every run, so `diversity_timeseries.csv`, `qess_like_states.csv` and `raf_persistence.csv` are present.

| run | epochs | pop. at end | max pop. | note |
|---|---|---|---|---|
| `smoke_modern` | 3 | 3 | 3 | plumbing check, seed 4242 |
| `rich_punctuated` | 120 | 46 | 149 | main run, seed 4242 |
| `rich_punctuated_10x` | **205** | **0** | 149 | configured for 1200; **went extinct at epoch 205** and the engine stopped |
| `ablation_rich/runs/legacy_baseline` | 120 | 120 | 120 | seed 42, no reaction-network products |
| `ablation_rich/runs/metabolic_generated_raf` | 120 | 48 | 133 | seed 42, 1 RAF set |
| `ablation_rich/runs/metabolic_open_chemistry` | 120 | 113 | 120 | seed 42, 0 RAF sets |
| `ablation_rich/runs/hybrid_transition` | 120 | 48 | 120 | seed 42, 1 RAF set |

Two consequences worth planning around. First, the extinction in `rich_punctuated_10x` is a real collapse, not a truncated run — it is the best available material for chapter 3's "does structure change before collapse" question, so treat that run, not `rich_punctuated`, as the transition case study. Second, `legacy_baseline` has no `catalysis_events.csv` or `autocatalytic_sets.csv` because its reaction-network module is switched off, so any chemistry-derived network is undefined for the baseline. Say this in chapter 4 rather than leaving a blank cell.

The ablation directory also carries experiment-level products: `run_table.csv`, `run_summary.csv`, `scenario_summary.csv`, `theoretical_analysis_summary.csv` and `theoretical_scenario_summary.csv`. `scenario_summary.csv` is close to the table chapter 4 needs.

To re-run anything, note that `run_simulations.sh` expects a working `.venv`; the runs above were produced by invoking `evosim.simulation.runner` and `evosim.experiments.ablation` directly with `PYTHONPATH=src` and only `networkx` + `pandas` installed.

## Step 2 — clean

Write `code/01_clean.R`. It reads `data/raw/<run>/` and writes tidy tables to `data/clean/<run>/`. The files you actually need are a small subset of what EvoSim emits:

- population: `simulation_log.csv`, `simulation_organisms.csv`
- lineage and types: `lineages.csv`, `type_abundance.csv`, `organism_types.csv`
- chemistry: `dynamic_metabolic_fluxes.csv` (the temporal one — `epoch, organism_id, reaction_id, flux, energy_delta, biomass_delta, limiting_substrate, catalysts_available`), plus the static `reaction_network.json`, `active_reactions.csv`, `autocatalytic_sets.csv` and `compartment_raf_membership.csv`
- theory: `diversity_timeseries.csv`, `raf_persistence.csv`, `qess_like_states.csv`, `dynamic_energy_biomass_budget.csv`
- provenance: `run_manifest.json`, `mechanism_manifest.json`, `config_snapshot.json`

The cleaning rules are what chapter 1 is graded on, so decide them explicitly and write them down as you code: which column is the epoch key in each file, how organism and type IDs are canonicalised across files, what happens to epochs with zero population, whether a truncated final epoch is dropped, and how duplicate catalysis events are collapsed. Tools: `readr`, `dplyr`, `tidyr`, `jsonlite`.

## Step 3 — reconstruct the two networks

Write `code/02_networks.R`. Both networks come from the same runs, which is the point of the project.

**Lineage network $L_t$.** Nodes are organisms, edges are parent → offspring from `lineages.csv`. Directed, unweighted. Two decisions to make and state: whether a snapshot is the set of births in the interval $(t-1, t]$ or the cumulative forest truncated at $t$, and what happens to founders with no parent. The incremental definition is easier to interpret and gives a meaningful turnover series, so prefer it unless you have a reason not to.

**Metabolic co-activity network $M_t$.** Nodes are organisms alive at epoch $t$; the edge between $i$ and $j$ is weighted by the similarity of their metabolic activity vectors. Undirected, weighted.

The original plan was a catalyst → reaction network, but the data does not support it: the chemistry in these runs is a fixed set of four reactions (`R1`–`R4`) over six molecules, and `catalysis_events.csv` is a four-row static map with no epoch column. There is no temporal catalysis network to reconstruct. The temporal metabolic signal lives instead in `dynamic_metabolic_fluxes.csv`, which has 59,790 rows of `(epoch, organism_id, reaction_id, flux)` — organisms differ in *which* reactions carry flux and *how much*, and that is what changes over the run.

So: for each organism $i$ alive at epoch $t$, build the flux vector $\mathbf{f}_i^{(t)} \in \mathbb{R}^4$ over the four reactions, and set $w_{ij}^{(t)} = \cos(\mathbf{f}_i^{(t)}, \mathbf{f}_j^{(t)})$, keeping edges above a threshold you state and justify. Report the sensitivity to that threshold in the appendix — it is the obvious question a grader will ask. Carry RAF membership from `compartment_raf_membership.csv` (11,862 rows of `epoch, organism_id, set_id, membership_basis`) as a node attribute, which is what lets chapter 3 discuss metabolic reorganisation.

Two things to say plainly in chapter 2 rather than bury: the four-dimensional flux space is small, so $M_t$ is a coarse instrument; and $M_t$ is undefined for the `legacy_baseline` scenario, which produces no flux products at all.

Export every snapshot in exactly the format the brief specifies, into `data/networks/<run>/<network>/`:

```
nodes_epoch<t>.csv   nodeID nodeLabel type epoch <attributes>
edges_epoch<t>.csv   nodeID_from nodeID_to weight epoch
```

Do not invent a different column order. The brief names these columns, and matching them costs nothing.

Choose maybe 10–20 export epochs for the 120-epoch run — enough to see the transitions, few enough to inspect by hand.

## Step 4 — temporal statistics

Write `code/03_stats.R` on top of `igraph`. For each network and each epoch compute the node and edge counts, the number of weakly connected components, the degree distribution (summarise it by mean degree plus either a fitted exponent or the entropy — do not put twenty degree histograms in a two-page chapter), the average clustering coefficient of the undirected projection, the modularity of a Louvain partition, and turnover between consecutive snapshots.

Define turnover as the Jaccard distance between consecutive node sets,

$$\tau_t = 1 - \frac{|V_t \cap V_{t+1}|}{|V_t \cup V_{t+1}|},$$

and be aware when you write chapter 4 that for the incremental lineage network this is close to definitional — the honest framing is that $\tau_t$ measures demographic churn, which is useful but not a structural discovery.

Output: `figures/p45/temporal_stats.pdf`, six panels, both networks overlaid in each.

## Step 5 — couple to population dynamics

Write `code/04_coupling.R`. Assemble the population series (population size, energy and biomass, diversity, an extinction-risk proxy you define, RAF persistence), z-score everything so it can share an axis, and produce `figures/p45/overlay.pdf` with two stacked panels sharing the epoch axis.

Then the quantitative part: Spearman cross-correlation between each network descriptor and each population observable over lags in roughly $[-20, +20]$ epochs, with a null from circular shifts or a block bootstrap. Report the best lag and its sign in one table. Say "leads" and "lags", never "causes".

For the transition analysis, define a window around each detected event (collapse, diversification, RAF reorganisation) and report two or three concrete numbers for what changes in the pre-window. A clean negative result — "no descriptor moves before the collapse in either network" — is worth more marks than a hedged positive one.

## Step 6 — scenarios

Write `code/05_scenarios.R` over `ablation_rich`. Evaluate the same fixed descriptor set for legacy baseline, metabolic with generated RAF, metabolic with open chemistry, and the hybrid transition, at a common epoch or averaged over the last quarter of each run. One table. If you have one seed per scenario, say so and call the comparison qualitative.

Chapter 4 then answers objective 7 directly: which representation is most informative, defended on discrimination across scenarios and sensitivity to transitions. Commit to an answer.

## Extensions

Only if the body budget survives. Each attempted extension is one sentence in chapter 4 and one appendix subsection. The two with the best effort-to-reward ratio here are the multiplex overlap between $L_t$ and $M_t$ (you already have both, so it is a join and a Jaccard) and structural RAF versus dynamic flux networks (you already load both files).

---

# Part II — Project 24

The whole project is a reproduction of a four-page PRL. The source is in `report/briefs/PhysRevLett.103.240503.pdf`. Four chapters at one page each: theory, generating functions, ER and scale-free, small-world and discussion.

## Step 1 — read and extract

The physics you need reduces to a short list. A network edge is two copies of $|\psi\rangle = \sqrt{\lambda_0}|00\rangle + \sqrt{\lambda_1}|11\rangle$; the single-copy singlet conversion probability is $p = \min[1, 2(1-\lambda_0)]$; two copies give $p_2 = 2p - p^2$ without distillation and $p_2 = \min(1, 2p - p^2/2)$ with it. Classical entanglement percolation is bond percolation at occupation $p_2$. The $q$-swap turns a $q$-star into a $q$-cycle whose edges have SCP $p$, and detaches the central node. A strategy is the binary vector $\{\gamma_q\}$.

Chapter 5 is exactly this, plus a redrawn version of the paper's Fig. 1.

## Step 2 — implement the generating-function machinery

Write `code/01_gf.R`. Everything in chapter 6 and 7 comes out of one solver:

1. `G0(x)`, `G1(x)` for the degree distribution family (Poisson for ER, power law with exponential cutoff for scale-free, $x^q$ for the Bethe check).
2. `H1_tilde(u; p, gamma)` implementing the paper's Eq. (3), which is the classical fixed point plus one $\tilde H_{1,q}$ term per active $q$-swap, each built from $C_q(x)$ in Eq. (2).
3. Solve $u = \tilde H_1(1)$ by fixed-point iteration or `uniroot`.
4. Find $\tilde p_c$ by bisection on $p$: the smallest $p$ admitting a root $u < 1$.
5. Get $\tilde S$ from Eq. (4), and the corrected $\hat S = \tilde S\, S_\infty / \tilde S_\infty$ that removes the detached nodes — Fig. 2(b) needs it.
6. Optimal strategy by exhaustive search over binary $\{\gamma_q\}$ up to $q_{\max} \approx 8$.

Define the gain once, $\Delta = (\tilde p_c - p_c)/p_c$, and use the same definition in every figure.

Before trusting any of it, run the Bethe lattice check: $G_0 = x^q$ must give $(q-1)^{-1} = p_2$ classically and the paper's post-swap expression after. It is four lines of code and it catches most sign errors.

## Step 3 — Monte Carlo

Write `code/02_simulate.R` on `igraph`. For each realisation: build the graph, apply the $q$-swap set (select degree-$q$ nodes subject to the no-neighbouring-swap constraint, rewire star to cycle, drop the centre), occupy the surviving original edges with probability $p_2$ and the new cycle edges with probability $p$, then measure the largest component. $N = 10^5$ is enough; the paper uses $10^6$. Average over enough realisations that error bars are smaller than the markers, and say how many.

Targets, in order of importance: ER at $z = 2.5$ without distillation before and after the $\{2,3\}$-swap (this is Fig. 2(b) and it is the single most convincing panel), then the gain-versus-$z$ curves, the scale-free sweep over the cutoff $\kappa$ at $\gamma = 1$, and the WWW sample with degree cutoff $k = 15$.

The headline numbers to reproduce: gain up to about 20% with distillation and 24% without in ER, about 25% for scale-free, against 3% and 16% for the honeycomb-to-triangular transformation on lattices. If your numbers differ by more than a point, report the difference and your best explanation rather than quietly adjusting.

## Step 4 — small-world

Degrees are correlated, so the theory does not apply and this chapter is simulation only. $N$ vertices on a ring plus $\phi N$ random shortcuts, 2-swap with distillation, $p_c$ versus $\phi$ and the GCC size at $\phi = 0.25$. Locate $p_c$ in the finite system properly — the peak of the mean finite-cluster size, or a finite-size-scaling crossing — and say which method you used. "Read off the plot" is the weak answer and a grader will notice.

Chapter 8 closes with the discussion: a purely local strategy lowers the threshold everywhere tested; the price is that detached nodes cap $\tilde S$ below $S$ even at $p = 1$; quantum operations are a mechanism that changes topology itself, which has no classical analogue; and the $\log N$ average path length of complex networks turns exponential decay into linear falloff. One sentence at most linking back to Part I — the projects are unrelated and the report should not pretend otherwise.

---

# Order of work

Part I is the long pole because the data does not exist yet: run the simulations, then clean, then reconstruct, then analyse. Part II is self-contained and can be written the moment the generating-function solver converges. Both scaffolds are already in place, so drafting can start on either side.

Write each chapter to its page allocation from the beginning rather than writing long and cutting. Re-render and run `check_pages.sh` after every chapter you finish; the failure mode to avoid is discovering at the end that Part I runs to nine pages.
