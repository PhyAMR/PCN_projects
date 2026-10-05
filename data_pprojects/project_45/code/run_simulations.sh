#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Project 45 - EvoSim data generation
#
# Runs the EvoSim simulations needed to cover the analysis objectives in
# project_45.md and stores all raw outputs under project_45/data/raw/.
# This script does NOT reconstruct, define, or analyse any network. It only
# produces the raw EvoSim trajectory data that downstream scripts will consume.
#
# Layout produced:
#   data/raw/smoke_modern/             plumbing sanity check (3 epochs)
#   data/raw/rich_punctuated/          main run, 120 epochs, multispecies
#   data/raw/rich_punctuated_10x/      long-horizon run, 1200 epochs
#   data/raw/ablation_rich/            scenario comparison (legacy / RAF /
#                                      open chemistry / hybrid), rebased on
#                                      the rich multispecies config
#
# Usage:
#   bash code/run_simulations.sh                     # everything
#   bash code/run_simulations.sh --skip-long         # skip the 1200-epoch run
#   bash code/run_simulations.sh --skip-ablation     # skip the scenario sweep
#   bash code/run_simulations.sh --only smoke        # one target only
#
# Each subdirectory ends up with the standard EvoSim outputs documented in
# data_tools/evosim_source/docs/OUTPUTS.md (simulation_log.csv, organism
# trajectories, type_abundance.csv, lineages.csv, reaction_network.json,
# catalysis_events.csv, dynamic_metabolic_fluxes.csv, raf_persistence.csv,
# theory_summary.json, etc.).
# -----------------------------------------------------------------------------

set -euo pipefail

# --- Paths -------------------------------------------------------------------
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"
EVOSIM_DIR="${REPO_ROOT}/data_tools/evosim_source"
DATA_DIR="${PROJECT_ROOT}/data/raw"
ABLATION_SPEC="${PROJECT_ROOT}/code/configs/ablation_rich.json"

mkdir -p "${DATA_DIR}"

# --- Flags -------------------------------------------------------------------
RUN_SMOKE=1
RUN_RICH=1
RUN_LONG=1
RUN_ABLATION=1
ONLY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-smoke)    RUN_SMOKE=0;    shift ;;
    --skip-rich)     RUN_RICH=0;     shift ;;
    --skip-long)     RUN_LONG=0;     shift ;;
    --skip-ablation) RUN_ABLATION=0; shift ;;
    --only)          ONLY="$2";      shift 2 ;;
    -h|--help)
      sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

if [[ -n "${ONLY}" ]]; then
  RUN_SMOKE=0; RUN_RICH=0; RUN_LONG=0; RUN_ABLATION=0
  case "${ONLY}" in
    smoke)    RUN_SMOKE=1 ;;
    rich)     RUN_RICH=1 ;;
    long)     RUN_LONG=1 ;;
    ablation) RUN_ABLATION=1 ;;
    *) echo "Unknown --only target: ${ONLY}" >&2; exit 2 ;;
  esac
fi

# --- Environment -------------------------------------------------------------
cd "${EVOSIM_DIR}"

if [[ ! -d ".venv" ]]; then
  echo "[setup] Creating virtualenv at ${EVOSIM_DIR}/.venv"
  python3 -m venv .venv
  # shellcheck disable=SC1091
  source .venv/bin/activate
  python -m pip install --upgrade pip
  python -m pip install -e .
else
  # shellcheck disable=SC1091
  source .venv/bin/activate
fi

export PYTHONPATH="src"

# --- Helpers -----------------------------------------------------------------
run_single() {
  local label="$1" config="$2" outdir="$3"
  echo
  echo "============================================================"
  echo "[run] ${label}"
  echo "  config : ${config}"
  echo "  output : ${outdir}"
  echo "============================================================"
  mkdir -p "${outdir}"
  python -m evosim.simulation.runner \
    --config "${config}" \
    --output-dir "${outdir}" \
    --engine modern \
    --quiet
  echo "[done] ${label}"
  if [[ -f "${outdir}/engine_integrity_report.json" ]]; then
    echo "[integrity] ${outdir}/engine_integrity_report.json"
  fi
  if [[ -f "${outdir}/biological_event_report.json" ]]; then
    echo "[bio-events] ${outdir}/biological_event_report.json"
  fi
}

run_ablation() {
  local label="$1" spec="$2" outdir="$3"
  echo
  echo "============================================================"
  echo "[run] ${label} (ablation matrix)"
  echo "  spec   : ${spec}"
  echo "  output : ${outdir}"
  echo "============================================================"
  mkdir -p "${outdir}"
  python -m evosim.experiments.ablation \
    --spec "${spec}" \
    --output-dir "${outdir}"
  python -m evosim.analysis.theory "${outdir}" --experiment
  echo "[done] ${label}"
}

# --- Runs --------------------------------------------------------------------
if [[ "${RUN_SMOKE}" -eq 1 ]]; then
  run_single "smoke_modern (sanity check)" \
    "configs/smoke_modern_metabolic_config.json" \
    "${DATA_DIR}/smoke_modern"
fi

if [[ "${RUN_RICH}" -eq 1 ]]; then
  run_single "rich_punctuated (main run, 120 epochs)" \
    "configs/rich_punctuated_multispecies_config.json" \
    "${DATA_DIR}/rich_punctuated"
fi

if [[ "${RUN_LONG}" -eq 1 ]]; then
  run_single "rich_punctuated_10x (long horizon, 1200 epochs)" \
    "configs/rich_punctuated_10x_config.json" \
    "${DATA_DIR}/rich_punctuated_10x"
fi

if [[ "${RUN_ABLATION}" -eq 1 ]]; then
  if [[ ! -f "${ABLATION_SPEC}" ]]; then
    echo "[error] Missing ablation spec: ${ABLATION_SPEC}" >&2
    exit 3
  fi
  run_ablation "ablation_rich (legacy / RAF / open chemistry / hybrid)" \
    "${ABLATION_SPEC}" \
    "${DATA_DIR}/ablation_rich"
fi

echo
echo "All requested EvoSim runs complete."
echo "Outputs are under: ${DATA_DIR}"
