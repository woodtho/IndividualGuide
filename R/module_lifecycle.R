# Dynamic task panels have a lifetime shorter than the root Shiny session.
# Use each module's existing session proxy to end its reactive domain when a
# project is replaced or its task is deleted. Shiny observers then auto-destroy.

#' Register an independently disposable task module reactive domain.
#' @keywords internal
#' @param session Owning Shiny module session.
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
ig_module_lifecycle <- function(session, id) {
  callbacks <- list()
  ended <- FALSE
  parent_on_ended <- session$onEnded
  parent_on_flushed <- session$onFlushed
  deregister <- NULL
  end <- function() {
    if (ended) return(invisible(NULL))
    ended <<- TRUE
    pending <- callbacks
    callbacks <<- list()
    for (callback in pending) callback()
    if (is.function(deregister)) deregister()
    session$userData$ig_module_enders[[id]] <- NULL
    invisible(NULL)
  }
  # makeScope() creates this proxy for moduleServer(); modifying its override
  # table preserves the original namespace, inputs, outputs and parent session.
  # [[.session_proxy resolves public fields through its parent. Read the actual
  # proxy storage directly or input/output/ns overrides would be discarded.
  overrides <- .subset2(session, "overrides")
  overrides$onEnded <- function(callback) {
    if (ended) {
      callback()
      return(function() invisible(NULL))
    }
    key <- ig_new_id("ended")
    callbacks[[key]] <<- callback
    function() { callbacks[[key]] <<- NULL }
  }
  overrides$isEnded <- function() ended
  overrides$onFlushed <- function(fun, once = FALSE) {
    parent_on_flushed(function() if (!ended) fun(), once = once)
  }
  assign("overrides", overrides, envir = session)
  if (is.null(session$userData$ig_module_enders)) session$userData$ig_module_enders <- list()
  session$userData$ig_module_enders[[id]] <- end
  deregister <- parent_on_ended(end)
  invisible(end)
}

#' Start a task module with a disposable reactive domain.
#' @keywords internal
#' @param id Identifier of the module, task, flow, or catalogue entry being addressed.
#' @param session Owning Shiny module session.
#' @param module Shiny module server function to run in a disposable domain.
ig_module_server <- function(id, module, session = shiny::getDefaultReactiveDomain()) {
  original <- body(module)
  body(module) <- bquote({
    ig_module_lifecycle(session, .(id))
    .(original)
  })
  shiny::moduleServer(id, module, session = session)
}

#' Dispose task module observers when deleting tasks or replacing a project.
#' @keywords internal
#' @param session Owning Shiny module session.
#' @param task_id Task identifier; NULL when no stored task is being edited.
ig_end_task_modules <- function(session, task_id = NULL) {
  enders <- session$userData$ig_module_enders %||% list()
  ids <- names(enders)
  if (!is.null(task_id)) ids <- ids[endsWith(ids, paste0("_", task_id))]
  for (id in ids) enders[[id]]()
  invisible(NULL)
}

# A NULL selection after binding means the user cleared it; before binding it
# means saved configuration still needs restoring.
store_inputs_ready <- function(store, task_id) {
  if (is.null(task_id)) return(FALSE)
  reader <- isolate(store$params_fns[[task_id]])
  ready <- attr(reader, "ready")
  is.function(ready) && isTRUE(ready())
}
