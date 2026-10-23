(function () {
  'use strict';
  let state, languageSignature = '', editorTimer;
  function editors() {
    if (!state) return;
    const p = state.app, signature = JSON.stringify([p.editor_font_size,p.editor_tab_size,p.editor_soft_tabs,p.editor_wrap,p.editor_line_numbers,p.editor_show_invisibles,p.editor_highlight_line]);
    document.querySelectorAll('.shiny-ace,.ace_editor').forEach(element => {
      const editor = window.jQuery?.(element).data('aceEditor') || element.env?.editor;
      if (!editor || editor._igPreferenceSignature === signature) return;
      editor._igPreferenceSignature = signature;
      editor.setFontSize(p.editor_font_size);
      editor.session.setTabSize(p.editor_tab_size);
      editor.session.setUseSoftTabs(p.editor_soft_tabs);
      editor.session.setUseWrapMode(p.editor_wrap);
      editor.renderer.setShowGutter(p.editor_line_numbers);
      editor.setShowInvisibles(p.editor_show_invisibles);
      editor.setHighlightActiveLine(p.editor_highlight_line);
      editor.resize();
    });
  }
  async function language() {
    if (!state || !window.igI18n) return;
    const global = state.language_global;
    const desired = state.language_project || global ? state.app.language : null;
    const signature = JSON.stringify([global,desired]);
    if (signature === languageSignature && (!desired || window.igI18n.locale === desired)) return;
    languageSignature = signature;
    if (global) await window.igI18n.setDefaultLanguage(global);
    if (desired) {
      await window.igI18n.setLanguage(desired, true, {persist:false});
      await window.igDesktop?.setPresentationLanguage?.(desired);
    }
  }
  function apply(value) {
    state = value;
    window.igPreferences = value.app;
    document.documentElement.style.setProperty('--ig-console-font-size', value.app.console_font_size + 'px');
    document.documentElement.dataset.igReduceMotion = String(value.app.reduce_motion);
    editors(); language();
  }
  window.addEventListener('ig:language-changed', language);
  window.addEventListener('DOMContentLoaded', function () {
    Shiny.addCustomMessageHandler('ig_preferences', apply);
    window.jQuery?.(document).on('shiny:value shiny:bound', function () { clearTimeout(editorTimer); editorTimer = setTimeout(editors, 100); });
    new MutationObserver(records => {
      if (records.some(record => [...record.addedNodes].some(node => node.nodeType === 1 && (node.matches('.shiny-ace,.ace_editor') || node.querySelector('.shiny-ace,.ace_editor'))))) {
        clearTimeout(editorTimer); editorTimer = setTimeout(editors, 100);
      }
    }).observe(document.body, {childList:true,subtree:true});
  });
})();
