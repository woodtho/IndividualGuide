# app_ui.R — Top-level UI for Individual Guide.
#
# UI model
# ─────────
# Left sidebar is a file-system-like project tree. The process flow network
# visualizer lives in its own main workspace tab.
#
# The main area has TWO layers:
#   1. A dynamic tab strip — one pill per open task panel.
#   2. A panel container — ALL open panels live in the DOM at once, toggled
#      via JS CSS-class toggle (.ig-panel-active).  This preserves Shiny input
#      state when switching tabs.

# ── Theme ──────────────────────────────────────────────────────────────────────
# App styling lives in a single stylesheet: inst/app/www/styles.css (linked in
# the head below). It used to be duplicated in a styles.scss compiled into the
# theme — the two copies drifted (the scss re-shipped colours that styles.css
# had already fixed for WCAG contrast), so the scss was removed.
ig_theme <- function() {
  bslib::bs_theme(
    version    = 5,
    bg         = "#1a1a2e",
    fg         = "#e0e0f0",
    primary    = "#3653d8",
    secondary  = "#6c757d",
    success    = "#2d6a4f",
    warning    = "#c77b3b",
    danger     = "#8b1a4a",
    # Font files are shipped with www/styles.css so first launch works offline.
    base_font  = "Inter",
    code_font  = "JetBrains Mono",
    `border-radius` = "6px"
  )
}

# ── UI ─────────────────────────────────────────────────────────────────────────
app_ui <- function() bslib::page_sidebar(
  theme    = ig_theme(),
  lang     = "en-CA",       # Updated in place by the selected presentation language.
  fillable = TRUE,
  title    = div(
    class = "d-flex align-items-center gap-3 w-100",
    strong("Individual Guide"),
    ig_language_picker(),
    tags$button(id = "btn_shiny_apps", type = "button", class = "btn btn-sm ig-header-btn",
      title = "Open Shiny apps", `aria-label` = "Open Shiny apps", icon("window-maximize")),
    div(id = "ig-run-status", class = "ig-run-status", hidden = NA,
      span(id = "ig-run-description", role = "status", `aria-live` = "polite"),
      tags$progress(id = "ig-run-progress", max = 1, value = 0, `aria-label` = "Run progress"),
      span(id = "ig-run-elapsed"),
      tags$button(id = "ig-stop-run", type = "button", class = "btn btn-sm btn-outline-danger", "Stop")),
    div(class = "d-flex gap-2 ms-3",
      actionButton("btn_add_task", "Add Task", icon = icon("plus"),
        class = "btn btn-sm btn-primary ig-add-task-btn")
    ),
    div(class = "ms-auto d-flex gap-2 ig-desktop-menu-controls",
      uiOutput("undo_btn_ui", class = "ig-undo-btn-wrap", inline = TRUE),
      actionButton("btn_save",  "", icon = icon("floppy-disk"),
        class = "btn btn-sm ig-header-btn", title = "Save project",
        `aria-label` = "Save project"),
      actionButton("btn_open",  "", icon = icon("folder-open"),
        class = "btn btn-sm ig-header-btn", title = "Open project",
        `aria-label` = "Open project"),
      actionButton("btn_search", "", icon = icon("magnifying-glass"),
        class = "btn btn-sm ig-header-btn", title = "Global search",
        `aria-label` = "Global search"),
      uiOutput("hdr_comments_btn", inline = TRUE),
      uiOutput("hdr_review_btn", inline = TRUE),
      actionButton("btn_history", "", icon = icon("clock-rotate-left"),
        class = "btn btn-sm ig-header-btn", title = "Change history",
        `aria-label` = "Change history"),
      actionButton("btn_project_tools", "", icon = icon("briefcase"),
        class = "btn btn-sm ig-header-btn", title = "Project tools: versions, files, run records and task list",
        `aria-label` = "Project tools"),
      actionButton("btn_validate_flow", "", icon = icon("list-check"),
        class = "btn btn-sm ig-header-btn", title = "Validate active flow", `aria-label` = "Validate active flow"),
      actionButton("btn_help", "", icon = icon("circle-question"),
        class = "btn btn-sm ig-header-btn", title = "Help",
        `aria-label` = "Help"),
      actionButton("btn_shortcuts", "", icon = icon("keyboard"),
        class = "btn btn-sm ig-header-btn", title = "Keyboard shortcuts",
        `aria-label` = "Keyboard shortcuts"),
      actionButton("btn_settings", "", icon = icon("gear"),
        class = "btn btn-sm ig-header-btn", title = "Settings",
        `aria-label` = "Settings")
    )
  ),

  # ── Sidebar ────────────────────────────────────────────────────────────────
  sidebar = bslib::sidebar(
    id = "main_sidebar", width = 290,
    open = TRUE, padding = "0",

    # Project pane — file-system tree
    div(id = "ig-sb-pane-project", class = "ig-sb-pane ig-sb-active",
      # Static search box (lives OUTSIDE the re-rendered tree so its value and
      # focus survive renderUI cycles). Filters the tree client-side.
      div(class = "ig-tree-search",
        tags$span(class = "ig-tree-search-icon", icon("magnifying-glass")),
        tags$input(
          id = "ig-tree-search-input", type = "text",
          class = "ig-tree-search-field", placeholder = "Filter tasks & data\u2026",
          `aria-label` = "Filter the project tree",
          autocomplete = "off", spellcheck = "false",
          oninput = "igFilterTree(this.value)"
        ),
        tags$button(class = "ig-tree-search-clear", type = "button",
          title = "Clear filter", `aria-label` = "Clear filter",
          onclick = "var i=document.getElementById('ig-tree-search-input'); i.value=''; igFilterTree('');",
          icon("xmark"))
      ),
      uiOutput("project_tree_ui"),
      # Hidden shinyFiles pickers — triggered programmatically (ig_click) from the
      # header Open/Save buttons and the splash. They return real on-disk paths so
      # Save can overwrite the project in place.
      div(class = "d-none", `aria-hidden` = "true",
        shinyFiles::shinyFilesButton("sf_open", "Open",
          title = "Open Individual Guide project", multiple = FALSE,
          icon = icon("folder-open")),
        shinyFiles::shinySaveButton("sf_save_as", "Save as",
          title = "Save project as", filename = "project",
          filetype = list("Individual Guide project" = "igpx"),
          icon = icon("floppy-disk"))
      )
    )
  ),

  # ── JS helpers ───────────────────────────────────────────────────────────────
  ig_shiny_apps_ui(),
  tags$head(
    tags$link(rel = "stylesheet", href = "www/styles.css"),
    tags$script(src = "www/i18n/core.js"),
    tags$script(src = "www/ig_i18n.js"),
    tags$script(src = "www/ig_tree.js"),
    tags$script(src = "www/ig_desktop.js"),
    tags$script(src = "www/ig_shiny_apps.js"),
    tags$script(src = "www/ig_run.js"),
    tags$script(src = "www/ig_console_tools.js"),
    tags$script(src = "www/ig_console.js"),
    # Built-in busy feedback: spinners on recalculating outputs and a pulse
    # banner during long computations (no-op on shiny versions without it)
    if ("useBusyIndicators" %in% getNamespaceExports("shiny"))
      shiny::useBusyIndicators(),
    tags$script(HTML("
      // Ace debounces edits. Flush them before actions read current settings.
      function igFlushEditors() {
        document.querySelectorAll('.shiny-ace.shiny-bound-input').forEach(function(el) {
          var editor = $(el).data('aceEditor');
          if (editor) Shiny.setInputValue(el.id, editor.getValue(), {priority:'event'});
        });
      }
      document.addEventListener('click', function(e) {
        if (e.target instanceof Element && e.target.closest('button, [onclick], a[download]')) igFlushEditors();
      }, true);
      // -- Panel show/hide + ARIA state --------------------------------------
      // .ig-task-panel starts as display:none (CSS); .ig-panel-active -> flex.
      // _igTabKeyNav: true when the switch was keyboard-initiated so focus can
      // be restored to the newly-active tab pill after renderUI replaces the DOM.
      // -- Skip navigation link ----------------------------------------------
      // Injected as the first child of <body> so it is the very first Tab stop
      // on every page load, regardless of bslib's rendered DOM order.
      // Pressing Enter on the link moves focus to #all-panels (the tab-panel
      // container); tabindex=-1 on that element makes it programmatically
      // focusable without adding it to the natural tab order.
      (function() {
        var skip = document.createElement('a');
        skip.href    = '#all-panels';
        skip.className = 'ig-skip-nav';
        skip.textContent = 'Skip to main content';
        if (document.body) {
          document.body.insertBefore(skip, document.body.firstChild);
        } else {
          document.addEventListener('DOMContentLoaded', function() {
            document.body.insertBefore(skip, document.body.firstChild);
          });
        }
      })();

      // -- Global busy indicator --------------------------------------------
      // Shows a thin animated bar at the top of the viewport whenever Shiny
      // is processing a server round trip (e.g. adding a task, running a
      // flow). Many such operations have no on-screen output to attach a
      // per-output spinner to, so without this the UI can look frozen for a
      // couple of seconds. A short show-delay avoids flicker for near-instant
      // operations, and a minimum visible time avoids a flash for very quick
      // ones once it has appeared.
      (function() {
        var bar = document.createElement('div');
        bar.className = 'ig-busy-bar';
        function mount() { document.body.appendChild(bar); }
        if (document.body) mount();
        else document.addEventListener('DOMContentLoaded', mount);

        var showTimer  = null;
        var shownAt    = null;
        var MIN_VISIBLE_MS = 300;
        var SHOW_DELAY_MS  = 250;

        $(document).on('shiny:busy', function() {
          window.clearTimeout(showTimer);
          showTimer = window.setTimeout(function() {
            bar.classList.add('ig-busy-bar--active');
            shownAt = Date.now();
          }, SHOW_DELAY_MS);
        });
        $(document).on('shiny:idle', function() {
          window.clearTimeout(showTimer);
          if (!bar.classList.contains('ig-busy-bar--active')) return;
          var elapsed = Date.now() - shownAt;
          var wait    = Math.max(0, MIN_VISIBLE_MS - elapsed);
          window.setTimeout(function() {
            bar.classList.remove('ig-busy-bar--active');
          }, wait);
        });
      })();

      window._igTabKeyNav = false;

      function igActiveTab() {
        return document.querySelector(
          '#ig-tab-strip [role=\"tab\"][aria-selected=\"true\"]'
        );
      }

      function igFocusTab(tabId) {
        var attempts = 0;
        function tryFocus() {
          var pill = tabId ?
            document.getElementById('tabpill_' + tabId) :
            document.querySelector('#ig-tab-strip [role=\"tab\"][aria-selected=\"true\"]');
          if (pill) {
            pill.focus();
            pill.scrollIntoView({block: 'nearest', inline: 'nearest'});
            return;
          }
          attempts += 1;
          if (attempts < 20) {
            window.setTimeout(tryFocus, 25);
          }
        }
        window.setTimeout(tryFocus, 0);
      }

      Shiny.addCustomMessageHandler('ig_switch_tab', function(tabId) {
        document.querySelectorAll('.ig-task-panel').forEach(function(el) {
          var active = el.dataset.tabId === tabId;
          el.classList.toggle('ig-panel-active', active);
          // Keep aria-hidden in sync - screen readers use this, not display:none.
          el.setAttribute('aria-hidden', active ? 'false' : 'true');
        });
        if (tabId === 'flow') {
          setTimeout(function() { window.dispatchEvent(new Event('resize')); }, 0);
        }
        // Restore focus after renderUI has replaced the tab-strip DOM.
        // By the time ig_switch_tab fires, output$tab_strip_ui has already
        // been re-applied (outputs precede messages in a Shiny flush), so the
        // new pill with aria-selected='true' / tabindex='0' is in the DOM.
        if (window._igTabKeyNav) {
          window._igTabKeyNav = false;
          igFocusTab(tabId);
        }
      });

      Shiny.addCustomMessageHandler('ig_focus_tab', function(tabId) {
        igFocusTab(tabId);
      });

      Shiny.addCustomMessageHandler('ig_module_ready', function(message) {
        var panel = null;
        var changed = performance.now();
        var editorFlushed = false;
        var prefix = message.id.slice(0, -'ig_ready'.length);
        var observer = new MutationObserver(function() { changed = performance.now(); });
        function inputChanged(e) {
          if (e.name && e.name.indexOf(prefix) === 0) changed = performance.now();
        }
        $(document).on('shiny:inputchanged', inputChanged);
        function cleanup() {
          observer.disconnect();
          $(document).off('shiny:inputchanged', inputChanged);
        }
        function settle() {
          if (!panel) {
            panel = document.getElementById(message.panel);
            if (panel) {
              observer.observe(panel, {subtree:true, childList:true, attributes:true});
              changed = performance.now();
            }
          }
          if (panel && !panel.isConnected) { cleanup(); return; }
          var busy = document.documentElement.classList.contains('shiny-busy');
          var recalculating = panel && Array.from(panel.querySelectorAll('.recalculating')).some(function(el) {
            return el.getClientRects().length > 0;
          });
          if (panel && !busy && !recalculating && performance.now() - changed >= 150) {
            if (!editorFlushed) {
              igFlushEditors();
              editorFlushed = true;
              changed = performance.now();
            } else {
              cleanup();
              panel.dataset.igReadyToken = message.token;
              Shiny.setInputValue(message.id, message.token, {priority: 'event'});
              return;
            }
          }
          setTimeout(settle, 25);
        }
        settle();
      });

      // visNetwork replaces its inner DOM during redraws. Release its old
      // select bindings before that replacement so Shiny can bind the new
      // controls without retaining duplicate input registrations.
      $(document).on('shiny:value', function(e) {
        if (e.target && e.target.classList && e.target.classList.contains('visNetwork')) {
          Shiny.unbindAll(e.target);
        }
      });

      // -- Theme mode -------------------------------------------------------
      Shiny.addCustomMessageHandler('ig_theme_mode', function(mode) {
        document.documentElement.setAttribute('data-ig-theme', mode || 'dark');
      });

      // -- Unsaved-changes indicator ----------------------------------------
      // Amber dot on the Save button while the project has unsaved changes,
      // and a native confirm dialog if the user tries to leave the page.
      window._igDirty = false;
      Shiny.addCustomMessageHandler('ig_dirty', function(dirty) {
        window._igDirty = !!dirty;
        window.dispatchEvent(new Event('ig:dirty'));
        var btn = document.getElementById('btn_save');
        if (btn) {
          btn.classList.toggle('ig-dirty', window._igDirty);
          btn.title = window._igDirty ?
            'Save project (unsaved changes)' : 'Save project';
        }
      });
      window.addEventListener('beforeunload', function(e) {
        if (window._igDirty) {
          e.preventDefault();
          e.returnValue = '';
        }
      });

      // -- Keyboard activation for custom role=button elements --------------
      // Fires for any .ig-key-activate element (sidebar tree items, etc.).
      // Guard: if the keydown originated from a natively interactive child
      // (button, a, input, ...) let the browser handle it - calling
      // e.preventDefault() on the bubble would cancel the native Enter->click
      // before it fires, silently breaking those controls.
      $(document).on('keydown', '.ig-key-activate', function(e) {
        if (e.key === 'Enter' || e.key === ' ') {
          if (e.target !== this &&
              $(e.target).is('button, a, input, select, textarea')) return;
          e.preventDefault();
          this.click();
        }
      });

      // -- ARIA tablist keyboard navigation ----------------------------------
      // Implements the W3C APG automatic-selection tablist pattern.
      // Selection follows focus - arrow keys navigate AND activate.
      //
      //   ArrowRight / ArrowLeft - move to adjacent tab and activate it
      //   Home / End             - jump to first / last tab
      //   Enter / Space          - activate the focused tab (fires onclick ->
      //                            Shiny tab_clicked, same as a mouse click)
      //   Delete                 - close the focused tab (if closeable)
      //   Tab                    - leaves tablist naturally; the browser moves
      //                            focus to the panel's first focusable child
      //
      $(document).on('keydown', '#ig-tab-strip [role=\"tab\"]', function(e) {
        var tablist = $(this).closest('[role=\"tablist\"]');
        var tabs    = tablist.find('[role=\"tab\"]');
        var idx     = tabs.index(this);
        var nextIdx = null;

        if (e.key === 'ArrowRight' || e.key === 'ArrowDown') {
          nextIdx = (idx + 1) % tabs.length;
        } else if (e.key === 'ArrowLeft' || e.key === 'ArrowUp') {
          nextIdx = (idx - 1 + tabs.length) % tabs.length;
        } else if (e.key === 'Home') {
          nextIdx = 0;
        } else if (e.key === 'End') {
          nextIdx = tabs.length - 1;
        } else if (e.key === 'Delete') {
          // Close the focused tab if it exposes a close button.
          var closeBtn = $(this).find('.ig-tab-close')[0];
          if (closeBtn) {
            e.preventDefault();
            window._igTabKeyNav = true;
            closeBtn.click();
          }
          return;
        } else if (e.key === 'Enter' || e.key === ' ') {
          // Treat Enter/Space identically to a mouse click on the tab pill.
          // This fires onclick -> Shiny.setInputValue('tab_clicked', ...) so the
          // server round-trip runs and ig_switch_tab restores focus correctly.
          // (For an already-active tab the server call is a no-op; focus stays
          // on the pill.  Press Tab to move into the panel content.)
          e.preventDefault();
          window._igTabKeyNav = true;
          this.click();
          return;
        } else {
          return; // pass all other keys through unmodified
        }

        e.preventDefault();
        window._igTabKeyNav = true;
        // Trigger the onclick of the target pill -> Shiny.setInputValue ->
        // server activates tab -> renderUI re-renders -> ig_switch_tab restores focus.
        tabs.eq(nextIdx)[0].click();
      });

      // -- App-wide tab shortcuts --------------------------------------------
      // Avoid intercepting keys while the user is editing a form field.
      // Ctrl+Alt+Left/Right: previous/next tab
      // Ctrl+Alt+W: close active task tab
      // Ctrl+Alt+F: process flow tab
      // Ctrl+Alt+K: code tab
      // Ctrl+Alt+N: add task
      // Ctrl+Alt+R: run the active flow
      // Ctrl+Alt+S: save the project
      // Ctrl+Alt+Z: undo the last destructive action
      // Ctrl+Alt+/: keyboard shortcuts reference
      $(document).on('keydown', function(e) {
        if (!e.ctrlKey || !e.altKey || e.metaKey) return;
        if ($(e.target).is('input, select, textarea, [contenteditable=\"true\"]')) return;
        igFlushEditors();

        var tablist = $('#ig-tab-strip [role=\"tablist\"]');
        var tabs = tablist.find('[role=\"tab\"]');
        if (!tabs.length) return;
        var active = igActiveTab();
        var idx = tabs.index(active);

        if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') {
          e.preventDefault();
          var step = e.key === 'ArrowRight' ? 1 : -1;
          var nextIdx = (idx + step + tabs.length) % tabs.length;
          window._igTabKeyNav = true;
          tabs.eq(nextIdx)[0].click();
        } else if (e.key.toLowerCase() === 'w') {
          var closeBtn = active ? $(active).find('.ig-tab-close')[0] : null;
          if (closeBtn) {
            e.preventDefault();
            window._igTabKeyNav = true;
            closeBtn.click();
          }
        } else if (e.key.toLowerCase() === 'f') {
          e.preventDefault();
          window._igTabKeyNav = true;
          Shiny.setInputValue('shortcut_open_tab', 'flow', {priority:'event'});
        } else if (e.key.toLowerCase() === 'k') {
          e.preventDefault();
          window._igTabKeyNav = true;
          Shiny.setInputValue('shortcut_open_tab', 'code', {priority:'event'});
        } else if (e.key.toLowerCase() === 'c') {
          e.preventDefault();
          window._igTabKeyNav = true;
          Shiny.setInputValue('shortcut_open_tab', 'console', {priority:'event'});
        } else if (e.key.toLowerCase() === 'n') {
          e.preventDefault();
          $('#btn_add_task').trigger('click');
        } else if (e.key.toLowerCase() === 'r') {
          e.preventDefault();
          Shiny.setInputValue('shortcut_run_flow', Math.random(), {priority:'event'});
        } else if (e.key.toLowerCase() === 's') {
          e.preventDefault();
          $('#btn_save').trigger('click');
        } else if (e.key.toLowerCase() === 'z') {
          e.preventDefault();
          Shiny.setInputValue('shortcut_undo', Math.random(), {priority:'event'});
        } else if (e.key === '/' || e.key === '?') {
          e.preventDefault();
          Shiny.setInputValue('shortcut_help', Math.random(), {priority:'event'});
        }
      });

      // -- Programmatic click (trigger hidden shinyFiles pickers) ------------
      // If a Bootstrap modal (e.g. the splash) is open, Bootstrap won't show a
      // second modal until it has finished hiding - so close it first and click
      // only after 'hidden.bs.modal', otherwise the picker silently fails to open.
      Shiny.addCustomMessageHandler('ig_click', function(id) {
        var el = document.getElementById(id);
        if (!el) return;
        var openModal = document.querySelector('#shiny-modal.show, .modal.show');
        if (openModal && window.jQuery) {
          window.jQuery(openModal).one('hidden.bs.modal', function() { el.click(); });
          window.jQuery(openModal).modal('hide');
        } else {
          el.click();
        }
      });

      // -- Clipboard ---------------------------------------------------------
      Shiny.addCustomMessageHandler('ig_copy_text', function(text) {
        navigator.clipboard.writeText(text);
      });

      // -- Task picker: collapsible group toggle -----------------------------
      window.igPickerToggle = function(id) {
        var el = document.getElementById(id);
        if (!el) return;
        var nowCollapsed = el.classList.toggle('ig-picker-collapsed');
        var hdr = el.previousElementSibling;
        if (hdr) {
          var caret = hdr.querySelector('.ig-tree-caret');
          if (caret) caret.classList.toggle('ig-picker-open');
          hdr.setAttribute('aria-expanded', nowCollapsed ? 'false' : 'true');
        }
      };

      // -- Help: task reference filter ---------------------------------------
      $(document).on('input', '#help_task_search', function() {
        var q = $(this).val().toLowerCase();
        $('.ig-help-task').each(function() {
          var label = ($(this).attr('data-label') || '').toLowerCase();
          $(this).toggle(!q || label.indexOf(q) > -1);
        });
        $('.ig-help-cat').each(function() {
          $(this).toggle(!q || $(this).find('.ig-help-task:visible').length > 0);
        });
      });

      // -- Task picker: search filter (works with collapsible groups) ---------
      // Matches are computed from data-label, NOT jQuery :visible - items
      // inside a collapsed (display:none) body are never ':visible', which
      // used to hide collapsed categories from search results entirely.
      $(document).on('input', '#task_search', function() {
        var q = $(this).val().toLowerCase();
        $('.ig-picker-group').each(function() {
          var grp = $(this);
          var matches = 0;
          grp.find('.ig-task-item').each(function() {
            var hit = !q ||
              ($(this).attr('data-label') || '').toLowerCase().indexOf(q) > -1;
            $(this).toggle(hit);
            if (hit) matches++;
          });
          grp.toggle(!q || matches > 0);

          var body  = grp.find('.ig-picker-group-body');
          var hdr   = grp.find('.ig-picker-group-header');
          var caret = hdr.find('.ig-tree-caret');
          if (q && matches > 0) {
            // expand so the hits are actually visible
            body.removeClass('ig-picker-collapsed');
            caret.removeClass('ig-picker-open');
            hdr.attr('aria-expanded', 'true');
          } else if (!q) {
            // query cleared - restore the group's default collapse state
            var open = grp.attr('data-default-expanded') === 'true';
            body.toggleClass('ig-picker-collapsed', !open);
            caret.toggleClass('ig-picker-open', !open);
            hdr.attr('aria-expanded', open ? 'true' : 'false');
          }
        });
      });
    "))
  ),

  # ── MAIN AREA: tab strip + panel container ────────────────────────────────
  div(
    class = "ig-workspace",

    div(id = "ig-tab-strip",
      uiOutput("tab_strip_ui")),

    div(
      id       = "all-panels",
      class    = "ig-panel-container",
      tabindex = "-1",

      div(class = "ig-task-panel ig-panel-active", id = "panel_flow",
        role              = "tabpanel",
        `aria-labelledby` = "tabpill_flow",
        `aria-hidden`     = "false",
        `data-tab-id`     = "flow",
        canvas_ui("canvas")),

      div(class = "ig-task-panel", id = "panel_code",
        role              = "tabpanel",
        `aria-labelledby` = "tabpill_code",
        `aria-hidden`     = "true",
        `data-tab-id`     = "code",
        code_panel_ui("code")),
      div(class = "ig-task-panel", id = "panel_console",
        role = "tabpanel", `aria-labelledby` = "tabpill_console",
        `aria-hidden` = "true", `data-tab-id` = "console",
        console_ui("r_console"))
    )
  )
)
