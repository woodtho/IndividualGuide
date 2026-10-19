/* ig_tree.js — Client-side collapse state for the project-tree sidebar.
 *
 * Shiny's renderUI replaces the entire inner HTML of #project_tree_ui on
 * every reactive update, wiping any DOM state.  We keep the canonical
 * "collapsed" set here in module scope so it survives re-renders, then
 * re-stamp .ig-collapsed on every element whose data-collapse-key is in
 * the set after each mutation.
 */
(function () {
  "use strict";

  /* Set of collapse-keys that are currently collapsed. */
  var collapsed = new Set();

  /* Current tree filter term (lowercased), kept in module scope so it
   * survives renderUI cycles just like the collapse set. */
  var filterTerm = "";

  /* Public: set the filter term and re-apply. */
  window.igFilterTree = function (term) {
    filterTerm = (term || "").trim().toLowerCase();
    applyFilter();
  };

  /* Hide tree rows that don't match the filter term. We filter the direct
   * children of each .ig-tree-task-list (task blocks, dataset rows, object
   * rows, issue rows) by their text content. Empty term clears everything.
   * Group/flow headers stay visible so navigation context is preserved. */
  function applyFilter() {
    var lists = document.querySelectorAll(".ig-tree-task-list");
    lists.forEach(function (list) {
      Array.prototype.forEach.call(list.children, function (row) {
        if (!filterTerm) {
          row.classList.remove("ig-tree-filter-hide");
          return;
        }
        var hit = (row.textContent || "").toLowerCase().indexOf(filterTerm) !== -1;
        row.classList.toggle("ig-tree-filter-hide", !hit);
      });
    });
    /* Reflect "filtering active" on the search wrapper for the clear button. */
    var wrap = document.querySelector(".ig-tree-search");
    if (wrap) wrap.classList.toggle("ig-tree-search-active", !!filterTerm);
  }

  /* Toggle a key and immediately re-stamp all elements. */
  window.igToggleCollapse = function (key) {
    if (collapsed.has(key)) {
      collapsed.delete(key);
    } else {
      collapsed.add(key);
    }
    applyCollapsed();
  };

  /* Walk every [data-collapse-key] node and add / remove .ig-collapsed.
   * Also mirror the state onto the toggle control's aria-expanded so
   * assistive technology announces expanded/collapsed (WCAG 4.1.2). */
  function applyCollapsed() {
    document.querySelectorAll("[data-collapse-key]").forEach(function (el) {
      var key = el.getAttribute("data-collapse-key");
      var isCollapsed = collapsed.has(key);
      el.classList.toggle("ig-collapsed", isCollapsed);
      var toggle = el.querySelector(".ig-tree-caret-btn, [data-collapsible]");
      if (toggle) {
        toggle.setAttribute("aria-expanded", isCollapsed ? "false" : "true");
      }
    });
  }

  /* Re-apply after every renderUI cycle.
   * We watch document.body so the observer is never replaced by Shiny.
   * Guard against DOMContentLoaded having already fired (deferred scripts). */
  function initializeResizeHandles() {
    document.querySelectorAll('.bslib-sidebar-resize-handle').forEach(function (handle) {
      var layout = handle.closest('.bslib-sidebar-layout'), sidebar = layout?.querySelector('aside.sidebar, .bslib-sidebar');
      var update = function () { handle.setAttribute('aria-valuenow', String(Math.round(sidebar?.getBoundingClientRect().width || parseFloat(getComputedStyle(layout || handle).getPropertyValue('--_sidebar-width')) || 280))); };
      update(); if (sidebar && !handle.dataset.igObserved) { handle.dataset.igObserved='true'; new ResizeObserver(update).observe(sidebar); }
    });
  }
  function setupObserver() {
    initializeResizeHandles();
    var observer = new MutationObserver(function (mutations) {
      if (mutations.some(function(m) { return Array.from(m.addedNodes).some(function(n) { return n.nodeType===1 && (n.matches('.bslib-sidebar-resize-handle') || n.querySelector('.bslib-sidebar-resize-handle')); }); })) initializeResizeHandles();
      var relevant = mutations.some(function (m) {
        return Array.from(m.addedNodes).some(function (n) {
          return (
            n.nodeType === 1 &&
            (n.hasAttribute("data-collapse-key") ||
              (n.querySelector &&
                n.querySelector("[data-collapse-key]")))
          );
        });
      });
      if (relevant) {
        applyCollapsed();
        applyFilter();
      }
    });
    observer.observe(document.body, { childList: true, subtree: true });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setupObserver);
  } else {
    setupObserver();
  }
})();
