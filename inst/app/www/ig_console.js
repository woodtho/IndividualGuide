(function () {
  'use strict';
  var histories = new Map(), tabNavigation = false;
  function entry(root) {
    var id = root.dataset.consoleId;
    if (!histories.has(id)) histories.set(id, { commands: [], index: 0, draft: '', generation: null, follow: true });
    return histories.get(id);
  }
  function fit(editor, force) {
    var maximum = Math.max(80, window.innerHeight * .28);
    // Appending to an already capped editor cannot make it shorter. Avoid
    // resetting its height and laying out the entire long draft twice.
    if (force || !editor._igCapped || editor._igMaximum !== maximum || !editor.value.startsWith(editor._igFitValue || '')) {
      editor.style.height = 'auto';
      var height = Math.min(editor.scrollHeight, maximum);
      editor.style.height = height + 'px';
      editor._igCapped = height >= maximum;
      editor._igMaximum = maximum;
    }
    editor._igFitValue = editor.value;
    window.igConsoleTools?.sync(editor);
  }
  function latest(root, force) {
    var scroll = root.querySelector('.ig-console-results'), history = entry(root);
    if (force) scroll.scrollTop = scroll.scrollHeight;
    history.follow = scroll.scrollHeight - scroll.scrollTop - scroll.clientHeight < 48;
    root.querySelector('.ig-console-latest').hidden = history.follow;
  }
  // Preserve literal output and append only new text; revisit an unfinished
  // last line so streamed errors receive the right color once complete.
  function paint(transcript, text) {
    var previous = transcript._igText || '', start = 0;
    if (text.startsWith(previous)) {
      start = previous.lastIndexOf('\n') + 1;
      var remove = previous.length - start;
      while (remove && transcript.lastChild) {
        var tail = transcript.lastChild, size = tail.textContent.length;
        if (size <= remove) { tail.remove(); remove -= size; }
        else { tail.textContent = tail.textContent.slice(0, size - remove); remove = 0; }
      }
    } else transcript.replaceChildren();
    var groups = [], group;
    text.slice(start).split(/(?<=\n)/).forEach(function (line) {
      if (!line) return;
      var kind = /^(> |\+ )/.test(line) ? 'command' : /^Error(?::| in\b)/.test(line) ? 'error' :
        /^Warning(?::| in\b)/.test(line) ? 'warning' : /^(R console|Project data|Stopped\.|\[(Earlier|Excess|Refresh))/.test(line) ? 'meta' : 'output';
      if (group?.kind === kind) group.text += line;
      else { group = { kind: kind, text: line }; groups.push(group); }
    });
    groups.forEach(function (group) {
      var name = 'ig-console-' + group.kind, tail = transcript.lastChild;
      if (tail?.className === name) tail.appendChild(document.createTextNode(group.text));
      else { var span = document.createElement('span'); span.className = name; span.textContent = group.text; transcript.appendChild(span); }
    });
    transcript._igText = text;
  }
  function submit(root, selection) {
    var editor = root.querySelector('.ig-console-editor'), run = document.getElementById(root.dataset.consoleId + '-run');
    var code = selection ? editor.value.slice(editor.selectionStart, editor.selectionEnd) : editor.value;
    if (run.disabled || !code.trim() || !window.Shiny?.shinyapp?.$socket || Shiny.shinyapp.$socket.readyState !== 1) return;
    var history = entry(root);
    if (history.commands.at(-1) !== code) history.commands.push(code);
    history.commands = history.commands.slice(-200); history.index = history.commands.length; history.draft = '';
    run.disabled = true; latest(root, true);
    Shiny.setInputValue(root.dataset.consoleId + '-request', { code: code, nonce: Date.now() }, { priority: 'event' });
    if (!selection) editor.value = '';
    window.igConsoleTools?.reset(root); fit(editor); editor.focus();
  }
  function recall(root, direction) {
    var editor = root.querySelector('.ig-console-editor'), history = entry(root);
    if (history.index === history.commands.length) history.draft = editor.value;
    history.index = Math.max(0, Math.min(history.commands.length, history.index + direction));
    editor.value = history.index === history.commands.length ? history.draft : history.commands[history.index];
    fit(editor); editor.setSelectionRange(editor.value.length, editor.value.length);
  }
  document.addEventListener('click', function (event) {
    if (!(tabNavigation && event.detail === 0 && event.target.closest?.('[role="tab"]'))) tabNavigation = false;
    var root = event.target.closest?.('.ig-console');
    if (!root) return;
    if (window.igConsoleTools?.click(event, root)) return;
    var button = event.target.closest('button');
    if (button?.id === root.dataset.consoleId + '-run') {
      event.preventDefault(); event.stopImmediatePropagation(); submit(root);
    } else if (button?.classList.contains('ig-console-latest')) latest(root, true);
    else if (event.target.classList.contains('ig-console-results')) root.querySelector('.ig-console-editor').focus();
  }, true);
  document.addEventListener('input', function (event) {
    if (event.target.matches?.('.ig-console-editor')) fit(event.target);
    var root = event.target.closest?.('.ig-console');
    if (root) window.igConsoleTools?.input(event, root);
  });
  document.addEventListener('keydown', function (event) {
    tabNavigation = (!!event.target.closest?.('[role="tab"]') &&
      ['ArrowLeft','ArrowRight','ArrowUp','ArrowDown','Home','End','Enter',' ','Delete'].includes(event.key)) ||
      (event.ctrlKey && event.altKey && ['ArrowLeft','ArrowRight','w','W'].includes(event.key));
    var root = event.target.closest?.('.ig-console');
    if (!root || event.isComposing || event.keyCode === 229) return;
    if (window.igConsoleTools?.key(event, root)) return;
    var editor = root.querySelector('.ig-console-editor'), modifier = event.ctrlKey || event.metaKey;
    if (modifier && !event.shiftKey && event.key.toLowerCase() === 'l') {
      event.preventDefault(); event.stopPropagation(); document.getElementById(root.dataset.consoleId + '-clear').click(); return;
    }
    if (event.ctrlKey && !event.shiftKey && event.key.toLowerCase() === 'c' && root.dataset.busy === 'true' &&
        !window.getSelection()?.toString() && !(document.activeElement === editor && editor.selectionStart !== editor.selectionEnd)) {
      event.preventDefault(); event.stopPropagation(); document.getElementById(root.dataset.consoleId + '-stop').click(); return;
    }
    if (event.target !== editor) return;
    if (event.key === 'Enter' && !event.shiftKey && !event.altKey) {
      event.preventDefault(); event.stopPropagation(); submit(root); return;
    }
    if (['ArrowUp', 'ArrowDown'].includes(event.key) && !modifier && !event.shiftKey) {
      var before = editor.value.slice(0, editor.selectionStart), after = editor.value.slice(editor.selectionEnd);
      if (event.altKey || (editor.selectionStart === editor.selectionEnd &&
          (event.key === 'ArrowUp' ? !before.includes('\n') : !after.includes('\n')))) {
        event.preventDefault(); event.stopPropagation(); recall(root, event.key === 'ArrowUp' ? -1 : 1);
      }
    }
    if (event.key === 'Tab' && !modifier && !event.altKey && !event.shiftKey && editor.value) {
      event.preventDefault(); event.stopPropagation();
      editor.setRangeText('  ', editor.selectionStart, editor.selectionEnd, 'end'); fit(editor);
    }
  });
  window.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.ig-console').forEach(function (root) {
      var editor = root.querySelector('.ig-console-editor'), panel = root.closest('.ig-task-panel'), lastWidth = 0;
      var wasActive = panel?.classList.contains('ig-panel-active') || false;
      window.igConsoleTools?.init(root, entry(root), { selection: function () { submit(root, true); } });
      root.querySelector('.ig-console-results').addEventListener('scroll', function () { latest(root, false); }, { passive: true });
      root.addEventListener('load', function (event) {
        if (event.target.matches?.('.ig-console-plot') && entry(root).follow) latest(root, true);
      }, true);
      new ResizeObserver(function (entries) {
        var width = entries[0].contentRect.width;
        if (width !== lastWidth) { lastWidth = width; fit(editor, true); }
      }).observe(root.querySelector('.ig-console-composer'));
      if (panel) new MutationObserver(function () {
        var active = panel.classList.contains('ig-panel-active');
        if (active === wasActive) return;
        wasActive = active;
        if (active) {
          fit(editor, true);
          // Let the shared tab-strip focus restoration finish first. Arrow-key
          // navigation between tabs keeps its focus on the tab strip.
          if (!tabNavigation) setTimeout(function () {
            if (panel.classList.contains('ig-panel-active')) editor.focus({ preventScroll: true });
          }, 0);
          tabNavigation = false;
        }
      }).observe(panel, { attributes: true, attributeFilter: ['class'] });
    });
    Shiny.addCustomMessageHandler('ig_console_completions', function (message) { window.igConsoleTools?.receive(message); });
    Shiny.addCustomMessageHandler('ig_console', function (message) {
      var transcript = document.getElementById(message.id + 'transcript');
      if (!transcript) return;
      var root = transcript.closest('.ig-console'), history = entry(root), follow = history.follow;
      if (history.generation !== null && history.generation !== message.generation) {
        history.commands = []; history.index = 0; history.draft = ''; root.querySelector('.ig-console-editor').value = '';
        window.igConsoleTools?.reset(root);
        fit(root.querySelector('.ig-console-editor')); follow = true;
      }
      history.generation = message.generation;
      if (transcript._igText !== message.text) paint(transcript, message.text);
      document.getElementById(message.id + 'status').textContent = message.status;
      root.dataset.status = message.status.toLowerCase().replace(/\s+/g, '-');
      ['run', 'refresh'].forEach(function (id) { document.getElementById(message.id + id).disabled = message.busy; });
      document.getElementById(message.id + 'stop').disabled = !message.busy;
      root.dataset.busy = String(message.busy);
      latest(root, follow);
    });
    window.jQuery(document).on('shiny:disconnected', function () {
      document.querySelectorAll('.ig-console').forEach(function (root) {
        root.querySelectorAll('button').forEach(function (button) { button.disabled = true; });
        root.querySelector('[role="status"]').textContent = 'Disconnected'; root.dataset.status = 'disconnected';
      });
    });
  });
})();
