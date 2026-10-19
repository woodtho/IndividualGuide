# execute_fns.R — Standalone execute functions for run_task_from_store
#
# Each function signature:  execute_TYPE(p, tables)
#   p      = named list of task parameters (from store$tasks[[id]]$params)
#   tables = named list of data frames     (from isolate(store$tables))
#
# Returns: list(data = <data.frame or NULL>, error = <NULL or character>)
#
# These are top-level (not inside any moduleServer closure), so they can be
# called by the queue processor without first opening the task panel.
# The module-local execute_* functions (which close over `store`) shadow these
# within their respective moduleServer scopes — no conflict.

# ══════════════════════════════════════════════════════════════════════════════
# DATA TASKS
# ══════════════════════════════════════════════════════════════════════════════











# ── A1: Remove Duplicates ──────────────────────────────────────────────────────


# ── A2: Keep / Drop Columns ────────────────────────────────────────────────────


# ── A3: Rename Columns ─────────────────────────────────────────────────────────


# ── A4: First / Last N Rows ────────────────────────────────────────────────────


# ── A5: Replace Missing Values ─────────────────────────────────────────────────


# ── A6: Derive (Add) Columns ───────────────────────────────────────────────────


# ── A7: Recode Values ──────────────────────────────────────────────────────────


# ── A8: Change Column Types ────────────────────────────────────────────────────


# ══════════════════════════════════════════════════════════════════════════════
# DESCRIBE TASKS
# ══════════════════════════════════════════════════════════════════════════════








# ══════════════════════════════════════════════════════════════════════════════
# SCRIPT TASK
# ══════════════════════════════════════════════════════════════════════════════





# ══════════════════════════════════════════════════════════════════════════════
# REPORT TASK
# ══════════════════════════════════════════════════════════════════════════════


# Per-item renderer choices offered in the Report panel.
REPORT_RENDER_CHOICES <- c(
  "Auto (by type)"         = "auto",
  "Static table (kable)"   = "kable",
  "Interactive table (DT)" = "datatable",
  "Figure"                 = "figure",
  "Text print"             = "print"
)
