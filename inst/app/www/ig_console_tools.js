/* Editing tools use the existing textarea and isolated console worker. */
(function () {
  'use strict';
  var states = new WeakMap(), serial = 0;
  function state(root) { return states.get(root); }
  function close(root) {
    var data = state(root), editor = root.querySelector('.ig-console-editor');
    root.querySelector('.ig-console-completions').hidden = true;
    editor.removeAttribute('aria-activedescendant');
    if (data) { clearTimeout(data.timer); data.timer = null; data.items = []; data.request = null; }
  }
  function highlight(editor) {
    var pre = editor.parentElement.querySelector('.ig-console-highlight');
    if (!pre || pre._code === editor.value) return;
    pre._code = editor.value;
    var fragment = document.createDocumentFragment(), code = editor.value, limit = Math.min(code.length, 20000);
    var prefix = code.slice(0, limit);
    // Beyond the highlighting limit the remainder is plain text. Keep the
    // existing token nodes when only that tail changes (large pasted scripts).
    if (pre._prefix === prefix && pre._tail?.parentNode === pre) {
      pre._tail.data = code.slice(limit) + '\n';
      return;
    }
    var i = 0, quote = '', keywords = new Set(['if','else','for','in','while','repeat','function','next','break','TRUE','FALSE','NULL','NA','NaN','Inf']);
    function token(text, kind) {
      if (!kind) fragment.appendChild(document.createTextNode(text));
      else { var span = document.createElement('span'); span.className = 'ig-r-' + kind; span.textContent = text; fragment.appendChild(span); }
    }
    while (i < limit) {
      var start = i, char = code[i], kind = '';
      if (char === '#') { while (i < limit && code[i] !== '\n') i++; kind = 'comment'; }
      else if (char === '"' || char === "'" || char === '`') {
        quote = char; i++;
        while (i < limit) { if (code[i] === '\\') i += 2; else if (code[i++] === quote) break; }
        kind = 'string';
      } else if (/[A-Za-z_.]/.test(char)) {
        while (i < limit && /[A-Za-z0-9_.]/.test(code[i])) i++;
        kind = keywords.has(code.slice(start,i)) ? 'keyword' : '';
      } else if (/[0-9]/.test(char)) {
        var number = code.slice(i,limit).match(/^(?:0[xX][0-9a-fA-F]+(?:\.[0-9a-fA-F]*)?(?:[pP][+-]?[0-9]+)?|[0-9]+(?:\.[0-9]*)?(?:[eE][+-]?[0-9]+)?)[Li]?/);
        i += number[0].length;
        kind = 'number';
      } else { i++; if (/[<>=+*/^|&!:$~-]/.test(char)) kind = 'operator'; }
      i = Math.min(i, limit);
      token(code.slice(start,i), kind);
    }
    var tail = document.createTextNode(code.slice(limit) + '\n'); fragment.appendChild(tail);
    pre.replaceChildren(fragment); pre._prefix = prefix; pre._tail = tail;
  }
  function sync(editor) {
    highlight(editor);
    var pre = editor.parentElement.querySelector('.ig-console-highlight');
    if (pre) pre.style.transform = 'translate(' + -editor.scrollLeft + 'px,' + -editor.scrollTop + 'px)';
  }
  function prefix(editor) {
    var before = editor.value.slice(0, editor.selectionStart);
    var match = before.match(/((?:`[^`]*`|[A-Za-z0-9._]+)(?:(?:::|\$)(?:`[^`]*`|[A-Za-z0-9._]*))*)$/);
    return match ? match[1] : '';
  }
  function request(root) {
    var data = state(root), editor = root.querySelector('.ig-console-editor');
    if (editor.selectionStart !== editor.selectionEnd || !window.Shiny?.shinyapp?.$socket || Shiny.shinyapp.$socket.readyState !== 1) return;
    var word = prefix(editor), nonce = ++serial;
    data.request = { nonce: nonce, prefix: word, position: editor.selectionStart };
    Shiny.setInputValue(root.dataset.consoleId + '-complete', { prefix: word, nonce: nonce }, { priority: 'event' });
  }
  function choose(root, index) {
    var data = state(root), editor = root.querySelector('.ig-console-editor'), item = data.items[index];
    if (!item || !data.request) return;
    if (editor.selectionStart !== editor.selectionEnd || editor.selectionStart !== data.request.position || prefix(editor) !== data.request.prefix) { close(root); return; }
    var start = data.request.position - data.request.prefix.length, end = data.request.position;
    editor.setRangeText(item.insert, start, end, 'end'); close(root);
    editor.dispatchEvent(new Event('input', { bubbles: true })); editor.focus();
  }
  function select(root, index) {
    var data = state(root), popup = root.querySelector('.ig-console-completions'), editor = root.querySelector('.ig-console-editor');
    data.index = Math.max(0, Math.min(data.items.length - 1, index));
    popup.querySelectorAll('[role=option]').forEach(function (button, i) {
      button.setAttribute('aria-selected', String(i === data.index));
      if (i === data.index) { editor.setAttribute('aria-activedescendant', button.id); button.scrollIntoView({ block: 'nearest' }); }
    });
  }
  function history(root, open) {
    var panel = root.querySelector('.ig-console-history-panel'); panel.hidden = !open;
    if (!open) { root.querySelector('.ig-console-editor').focus(); return; }
    renderHistory(root); root.querySelector('.ig-console-history-search').focus();
  }
  function renderHistory(root) {
    var data = state(root), search = root.querySelector('.ig-console-history-search').value.toLowerCase();
    var results = root.querySelector('.ig-console-history-results'); results.replaceChildren();
    data.history.commands.slice().reverse().filter(function (code) { return code.toLowerCase().includes(search); }).forEach(function (code) {
      var button = document.createElement('button'); button.type = 'button'; button.className = 'ig-console-history-item';
      button.textContent = code; button.title = code;
      button.addEventListener('click', function () {
        var editor = root.querySelector('.ig-console-editor'); editor.value = code; history(root, false);
        editor.dispatchEvent(new Event('input', { bubbles: true })); editor.setSelectionRange(code.length,code.length);
      }); var item = document.createElement('div'); item.setAttribute('role','listitem'); item.appendChild(button); results.appendChild(item);
    });
    if (!results.childElementCount) { var empty = document.createElement('p'); empty.textContent = 'No matching commands.'; results.appendChild(empty); }
  }
  window.igConsoleTools = {
    init: function (root, commands, actions) {
      states.set(root, { history: commands, actions: actions, items: [], index: 0, request: null, timer: null });
      // Observe real size changes after layout. Reading offsetHeight after
      // replacing tokens forced a full syntax-overlay layout on each input.
      var composer = root.querySelector('.ig-console-composer');
      new ResizeObserver(function (entries) {
        var box = entries[0].borderBoxSize?.[0];
        var height = box ? box.blockSize : composer.offsetHeight;
        root.style.setProperty('--console-entry-height', (height + 12) + 'px');
      }).observe(composer);
      var editor = root.querySelector('.ig-console-editor'); editor.addEventListener('scroll', function () { sync(editor); }, { passive: true }); sync(editor);
    },
    sync: sync,
    input: function (event, root) {
      var data = state(root);
      if (event.target.matches('.ig-console-history-search')) { renderHistory(root); return; }
      if (!event.target.matches('.ig-console-editor') || event.isComposing) return;
      var word = prefix(event.target), visible = !root.querySelector('.ig-console-completions').hidden;
      if (visible || word.endsWith('$') || word.endsWith('::')) {
        clearTimeout(data.timer); data.timer = setTimeout(function () { request(root); }, 90);
      }
    },
    click: function (event, root) {
      var button = event.target.closest('button'), data = state(root);
      if (!button || !data) return false;
      if (button.classList.contains('ig-console-history-toggle')) history(root, root.querySelector('.ig-console-history-panel').hidden);
      else if (button.classList.contains('ig-console-history-close')) history(root, false);
      else if (button.classList.contains('ig-console-run-selection')) data.actions.selection();
      else if (button.classList.contains('ig-console-create-script')) {
        var editor = root.querySelector('.ig-console-editor');
        var code = editor.value.slice(editor.selectionStart, editor.selectionEnd) || editor.value || data.history.commands.at(-1) || '';
        if (code.trim()) Shiny.setInputValue('console_create_script', { code: code, nonce: ++serial }, { priority: 'event' });
      } else return false;
      event.preventDefault(); event.stopImmediatePropagation(); return true;
    },
    key: function (event, root) {
      var data = state(root), editor = root.querySelector('.ig-console-editor'), popup = root.querySelector('.ig-console-completions');
      if (!data) return false;
      var handled = false;
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === 'r') { history(root, true); handled = true; }
      else if (event.key === 'Escape' && (!popup.hidden || !root.querySelector('.ig-console-history-panel').hidden)) { close(root); history(root, false); handled = true; }
      else if (event.target === editor) {
        if (['ArrowLeft','ArrowRight','Home','End','PageUp','PageDown'].includes(event.key)) close(root);
        if (!popup.hidden && ['ArrowDown','ArrowUp','Enter','Tab'].includes(event.key)) {
          if (event.key === 'ArrowDown' || event.key === 'ArrowUp') select(root, data.index + (event.key === 'ArrowDown' ? 1 : -1));
          else choose(root, data.index);
          handled = true;
        } else if ((event.ctrlKey || event.metaKey) && event.shiftKey && event.key === 'Enter') { data.actions.selection(); handled = true; }
        else if ((event.ctrlKey || event.metaKey) && (event.code === 'Space' || event.key === ' ')) { request(root); handled = true; }
        else if (event.key === 'Tab' && !event.shiftKey && !event.ctrlKey && !event.metaKey && prefix(editor)) { request(root); handled = true; }
      }
      if (handled) { event.preventDefault(); event.stopPropagation(); } return handled;
    },
    receive: function (message) {
      var editor = document.getElementById(message.id + 'editor'), root = editor?.closest('.ig-console'), data = root && state(root);
      if (!data?.request || data.request.nonce !== message.nonce || prefix(editor) !== message.prefix || editor.selectionStart !== data.request.position) return;
      var popup = root.querySelector('.ig-console-completions'); popup.replaceChildren(); data.items = message.items || [];
      if (!data.items.length) { close(root); return; }
      data.items.forEach(function (item, i) {
        var button = document.createElement('button'); button.type = 'button'; button.tabIndex = -1;
        button.id = message.id + 'completion-' + i; button.setAttribute('role', 'option');
        button.textContent = item.label; button.title = item.kind;
        button.addEventListener('mousedown', function (event) { event.preventDefault(); });
        button.addEventListener('click', function () { choose(root, i); }); popup.appendChild(button);
      });
      popup.hidden = false; select(root,0);
    },
    reset: function (root) { close(root); root.querySelector('.ig-console-history-panel').hidden = true; }
  };
})();
