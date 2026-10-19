(function () {
  'use strict';
  var state = {}, timer;
  function elapsed() {
    var element = document.getElementById('ig-run-elapsed');
    if (!element) return;
    var seconds = state.started ? Math.max(0, Math.floor((Date.now() - state.started) / 1000)) : 0;
    element.textContent = Math.floor(seconds / 60) + ':' + String(seconds % 60).padStart(2, '0');
  }
  window.addEventListener('DOMContentLoaded', function () {
    var status = document.getElementById('ig-run-status'), stop = document.getElementById('ig-stop-run');
    Shiny.addCustomMessageHandler('ig_run_state', function (value) {
      state = value; window.igRunState = value;
      status.hidden = !value.running && value.outcome === 'idle';
      var total = value.total || 0, completed = value.completed || 0;
      document.getElementById('ig-run-description').textContent = value.running ?
        (value.label ? value.label + ' · ' : '') + completed + '/' + total + ' completed' :
        ({ stopped: 'Run stopped', failed: 'Run finished with errors', finished: 'Run finished' }[value.outcome] || 'Ready');
      var progress = document.getElementById('ig-run-progress');
      progress.max = Math.max(1, total); progress.value = completed;
      stop.hidden = !value.running; stop.disabled = false; stop.textContent = 'Stop';
      stop.title = value.interruptible ? 'Cancel the current background analysis and remaining tasks' : 'Stop before the next task; the current R call must finish';
      clearInterval(timer); elapsed();
      if (value.running) timer = setInterval(elapsed, 1000);
      window.dispatchEvent(new CustomEvent('ig:run-state', { detail: value }));
    });
    stop.addEventListener('click', function () {
      if (!state.running || stop.disabled) return;
      stop.disabled = true; stop.textContent = state.interruptible ? 'Cancelling…' : 'Stopping after task…';
      Shiny.setInputValue('stop_run', Date.now(), { priority: 'event' });
    });
    window.jQuery(document).on('shiny:disconnected', function () {
      clearInterval(timer); stop.disabled = true;
      if (state.running) document.getElementById('ig-run-description').textContent = 'R server disconnected';
    });
  });
})();
