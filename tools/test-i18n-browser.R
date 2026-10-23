# Exercise the shipped language layer in the actual Shiny app and Chromium.
main <- function() {
  options(chromote.timeout=180)
  root <- normalizePath(getwd(), winslash="/")
  evidence <- file.path(root,"artifacts/i18n"); dir.create(evidence,recursive=TRUE,showWarnings=FALSE)
  port <- httpuv::randomPort()
  server <- callr::r_bg(function(root,port) {
    profile <- file.path(tempdir(),"ig-i18n-profile")
    Sys.setenv(IG_USER_DATA=profile)
    options(ig.recovery_dir=file.path(profile,"recovery"),ig.examples_dir=file.path(profile,"examples"))
    setwd(root); pkgload::load_all(root,quiet=TRUE,export_all=FALSE)
    shiny::runApp(IndividualGuide::run_app(),host="127.0.0.1",port=port,launch.browser=FALSE)
  },args=list(root,port),stdout=file.path(evidence,"browser-server.stdout.log"),stderr=file.path(evidence,"browser-server.stderr.log"))
  on.exit(server$kill(),add=TRUE)
  url <- paste0("http://127.0.0.1:",port)
  wait <- function(test,label) {
    deadline <- Sys.time()+90
    repeat {
      if (isTRUE(tryCatch(test(),error=function(e)FALSE))) return(invisible(TRUE))
      if (!server$is_alive()) stop(paste(readLines(file.path(evidence,"browser-server.stderr.log"),warn=FALSE),collapse="\n"))
      if(Sys.time()>deadline){
        if(exists("page",inherits=TRUE)){
          try(screenshot("browser-failure.png"),silent=TRUE)
          try(writeLines(evaluate("document.body.innerText"),file.path(evidence,"browser-failure.txt")),silent=TRUE)
        }
        stop("Language browser test timed out: ",label)
      }
      Sys.sleep(.1)
    }
  }
  wait(function() {con<-url(url);on.exit(close(con));length(suppressWarnings(readLines(con,warn=FALSE)))>0},"server")
  Sys.setenv(CHROMOTE_CHROME="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  browser <- chromote::Chromote$new()
  browser$default_timeout <- 180
  page <- chromote::ChromoteSession$new(width=1440,height=1000,parent=browser)
  on.exit({try(page$close(),silent=TRUE);try(browser$close(),silent=TRUE)},add=TRUE)
  evaluate <- function(js) {
    result<-page$Runtime$evaluate(js,returnByValue=TRUE,awaitPromise=TRUE)
    if(!is.null(result$exceptionDetails))stop(jsonlite::toJSON(result$exceptionDetails,auto_unbox=TRUE))
    result$result$value
  }
  screenshot <- function(name) writeBin(jsonlite::base64_dec(page$Page$captureScreenshot(format="png")$data),file.path(evidence,name))
  close_modal <- function() {
    wait(function()evaluate("Boolean(document.querySelector('.modal.show'))&&!bootstrap.Modal.getInstance(document.querySelector('.modal.show'))?._isTransitioning"),"dialog animation")
    evaluate("document.querySelector('.modal.show .modal-footer [data-bs-dismiss=modal],.modal.show .modal-footer [data-dismiss=modal]').click()")
    wait(function()evaluate("!document.querySelector('.modal.show')"),"close dialog")
  }
  page$go_to(url)
  wait(function()evaluate("Boolean(window.igI18n)&&Boolean(window.Shiny?.shinyapp?.$socket?.readyState===1)&&Boolean(document.getElementById('splash_fresh'))"),"language layer and welcome")
  evaluate("window.igI18n.setLanguage('fr-CA')")
  wait(function()evaluate("document.getElementById('splash_fresh').textContent.includes('Commencer avec un canevas vide')"),"French welcome")
  evaluate("localStorage.setItem('IndividualGuideLanguage','en-CA')")
  page$Page$reload(ignoreCache=TRUE)
  wait(function()evaluate("window.igI18n?.locale==='fr-CA'&&Boolean(document.getElementById('splash_fresh'))"),"last host-wide choice overrides a stale port-specific choice")
  screenshot("welcome-fr-CA.png")
  checks<-list(frenchWelcome=TRUE,rememberedBrowserLanguage=TRUE)
  evaluate("document.getElementById('splash_fresh').click()")
  wait(function()evaluate("!document.querySelector('.modal.show')"),"blank project")
  evaluate("(() => {window.igTestSocket=Shiny.shinyapp.$socket;const e=document.createElement('section');e.id='ig-language-test';e.innerHTML='<button title=\"Help\">Save project</button><input id=\"ig-test-input\" value=\"Keep $& Mean 001\" placeholder=\"Search examples\"><textarea>Save project</textarea><code>Save project</code><table class=\"dataTable\"><thead><tr><th>Source</th></tr></thead><tbody><tr><td>Mean</td></tr></tbody></table><div data-ig-choice-labels=\"true\"><select id=\"ig-test-method\"><option value=\"mean\">Mean</option><option value=\"median\">Median</option></select></div><select id=\"ig-test-column\"><option value=\"Mean\">Mean</option></select>';document.body.append(e);return true;})()")
  wait(function()evaluate("document.querySelector('#ig-language-test button').textContent==='Enregistrer le projet'"),"newly rendered French labels")
  checks$dynamicFrenchLabels<-TRUE
  evaluate("document.getElementById('ig-language-test').insertAdjacentHTML('beforeend','<span id=\"ig-test-output-kind\">model: Model object</span><span id=\"ig-test-preview-status\">✓ Complete: 3 rows × 7 columns</span>')")
  wait(function()evaluate("document.getElementById('ig-test-output-kind').textContent==='modèle : Objet du modèle'&&document.getElementById('ig-test-preview-status').textContent==='✓ Terminé : 3 lignes × 7 colonnes'"),"generated output descriptions and dimensions")
  checks$renderedOutputDescriptionsAndDimensions<-TRUE
  evaluate("document.getElementById('ig-language-test').insertAdjacentHTML('beforeend','<div class=\"ig-preflight-row\"><strong id=\"ig-test-preflight-id\">INFO · Mean · schema</strong></div>')")
  evaluate("window.igI18n.refresh();new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>resolve(true))))")
  wait(function()evaluate("document.getElementById('ig-test-preflight-id').textContent==='INFO · Mean · schema'"),"preflight identifiers")
  checks$preflightIdentifiersPreserved<-TRUE
  evaluate("(()=>{const e=document.getElementById('ig-language-test');e.insertAdjacentHTML('beforeend','<div class=\"ig-comment-title\">Source</div><div class=\"ig-comment-text\">Save project</div><div class=\"ig-log-preview-message\">Run</div><div class=\"ig-console-completions\"><button>Mean</button></div><button class=\"ig-console-history-item\">Save project</button><div id=\"history_dt\"><table class=\"dataTable\"><thead><tr><th>when</th></tr></thead><tbody><tr><td>Mean</td></tr></tbody></table></div>');})()")
  wait(function()evaluate("document.querySelector('#history_dt th').textContent==='Heure'"),"app-owned metadata headings")
  checks$commentsLogsAndMetadata<-evaluate("document.querySelector('.ig-comment-title').textContent==='Source'&&document.querySelector('.ig-comment-text').textContent==='Save project'&&document.querySelector('.ig-log-preview-message').textContent==='Run'&&document.querySelector('#history_dt td').textContent==='Mean'")
  checks$consoleSuggestionsAndHistory<-evaluate("document.querySelector('.ig-console-completions button').textContent==='Mean'&&document.querySelector('.ig-console-history-item').textContent==='Save project'")
  checks$userDataAndCode<-evaluate("document.querySelector('#ig-language-test tbody td').textContent==='Mean'&&document.querySelector('#ig-language-test th').textContent==='Source'&&document.querySelector('#ig-language-test code').textContent==='Save project'&&document.querySelector('#ig-language-test textarea').value==='Save project'&&document.getElementById('ig-test-column').selectedOptions[0].textContent==='Mean'")
  checks$choiceValuesStable<-evaluate("document.getElementById('ig-test-method').value==='mean'&&document.getElementById('ig-test-method').selectedOptions[0].textContent==='Moyenne'")
  evaluate("document.getElementById('ig-test-input').focus();document.getElementById('ig-test-input').setSelectionRange(5,9);window.igI18n.setLanguage('en-CA')")
  checks$focusAndTypedValues<-evaluate("document.activeElement.id==='ig-test-input'&&document.activeElement.value==='Keep $& Mean 001'&&document.activeElement.selectionStart===5&&document.activeElement.selectionEnd===9")
  checks$englishRestored<-evaluate("document.querySelector('#ig-language-test button').textContent==='Save project'&&document.getElementById('ig-test-method').selectedOptions[0].textContent==='Mean'&&document.querySelector('#history_dt th').textContent==='when'")
  checks$noServerReload<-evaluate("Shiny.shinyapp.$socket===window.igTestSocket&&Shiny.shinyapp.$socket.readyState===1")
  evaluate("document.getElementById('ig-language-test').remove();window.igI18n.setLanguage('fr-CA');document.getElementById('btn_settings').click()")
  wait(function()evaluate("Boolean(document.getElementById('preferences-search'))&&document.querySelector('.modal.show').textContent.includes('Valeurs globales par défaut')"),"French settings")
  checks$frenchSettings<-evaluate("document.documentElement.lang==='fr-CA'")
  evaluate("$('#preferences-search').val('plot_theme').trigger('change')")
  wait(function()evaluate("document.querySelector('#preferences-options tbody tr td')?.textContent==='plot_theme'"),"plot theme option")
  evaluate("document.querySelector('#preferences-options tbody tr button').click()")
  wait(function()evaluate("document.getElementById('preferences-input')?.selectize?.$control?.text().includes('Épuré')"),"French Selectize choices")
  checks$frenchSelectize<-evaluate("(()=>{const s=document.getElementById('preferences-input');return s.value==='clean'&&s.selectize.options.clean[s.selectize.settings.labelField]==='Clean'&&s.selectize.search('Épuré').items.some(item=>item.id==='clean');})()")
  screenshot("settings-fr-CA.png")
  close_modal()
  evaluate("document.getElementById('btn_add_task').click()")
  wait(function()evaluate("Boolean(document.getElementById('task_search'))"),"task picker")
  evaluate("$('#task_search').val('statistiques').trigger('input')")
  wait(function()evaluate("[...document.querySelectorAll('.ig-task-item')].some(e=>e.textContent.includes('Statistiques descriptives')&&getComputedStyle(e).display!=='none')"),"French task search")
  checks$frenchTaskSearch<-TRUE
  close_modal()
  evaluate("document.getElementById('btn_help').click()")
  wait(function()evaluate("Boolean(document.getElementById('help_task_search'))"),"task reference")
  evaluate("$('#help_task_search').val('statistiques').trigger('input')")
  wait(function()evaluate("[...document.querySelectorAll('.ig-help-task')].some(e=>e.textContent.includes('Statistiques descriptives')&&getComputedStyle(e).display!=='none')"),"French help search")
  checks$frenchHelpSearch<-TRUE
  evaluate("(()=>{const e=document.getElementById('ig-example-type');e.value='summary_stats';e.dispatchEvent(new Event('change'));})()")
  wait(function()evaluate("document.getElementById('ig-example-count').textContent==='6 exemples sur 22'"),"French filtered example count")
  checks$frenchExampleCount<-TRUE
  close_modal()
  evaluate("document.getElementById('btn_review').click()")
  wait(function()evaluate("document.querySelector('.ig-collab-pill')?.textContent==='Brouillon'&&document.getElementById('r_console-download').textContent.trim()==='Enregistrer la transcription'"),"French review badge and transcript download")
  checks$frenchReviewAndTranscriptLabels<-TRUE
  close_modal()
  evaluate("Shiny.setInputValue('help_example','iris',{priority:'event'})")
  wait(function()evaluate("Boolean(document.getElementById('example_discard'))||Boolean([...document.querySelectorAll('.visNetwork')].find(e=>document.getElementById('graph'+e.id)?.chart?.body?.data?.nodes?.get().some(n=>n.group==='summary_stats')))"),"example opening or unsaved-work prompt")
  if(isTRUE(evaluate("Boolean(document.getElementById('example_discard'))"))){
    wait(function()evaluate("document.getElementById('example_discard').classList.contains('shiny-bound-input')&&!bootstrap.Modal.getInstance(document.querySelector('.modal.show'))?._isTransitioning"),"bound discard action")
    evaluate("document.getElementById('example_discard').click()")
  }
  wait(function()evaluate("Boolean([...document.querySelectorAll('.visNetwork')].find(e=>document.getElementById('graph'+e.id)?.chart?.body?.data?.nodes?.get().some(n=>n.group==='summary_stats')))"),"real example flow")
  evaluate("window.igI18n.setLanguage('en-CA')")
  evaluate("(()=>{const e=[...document.querySelectorAll('.visNetwork')].find(e=>document.getElementById('graph'+e.id)?.chart?.body?.data?.nodes?.get().some(n=>n.group==='summary_stats'));window.igLanguageGraph=document.getElementById('graph'+e.id).chart;window.igLanguageCard=igLanguageGraph.body.data.nodes.get().find(n=>n.group==='summary_stats');window.igLanguageSourceImage=igLanguageCard.image;window.igLanguagePositions=JSON.stringify(igLanguageGraph.getPositions());window.igLanguageScale=igLanguageGraph.getScale();window.igReadSvg=()=>new DOMParser().parseFromString(new TextDecoder().decode(Uint8Array.from(atob(igLanguageGraph.body.data.nodes.get(igLanguageCard.id).image.split(',')[1]),c=>c.charCodeAt(0))),'image/svg+xml');window.igOriginalCardName=igReadSvg().querySelector('text[y=\"22\"]').textContent;})()")
  evaluate("window.igI18n.setLanguage('fr-CA')")
  wait(function()evaluate("igReadSvg().querySelector('text[y=\"124\"]').textContent.startsWith('Statistiques')&&igReadSvg().querySelector('text[y=\"182\"]').textContent.includes('Réussite')"),"French flow-card labels")
  checks$flowLanguagePreservesNamesAndLayout<-evaluate("igReadSvg().querySelector('text[y=\"22\"]').textContent===igOriginalCardName&&JSON.stringify(igLanguageGraph.getPositions())===igLanguagePositions&&igLanguageGraph.getScale()===igLanguageScale&&Shiny.shinyapp.$socket===igTestSocket")
  screenshot("flow-fr-CA.png")
  evaluate("window.igI18n.setLanguage('en-CA')")
  checks$flowEnglishRestored<-evaluate("igLanguageGraph.body.data.nodes.get(igLanguageCard.id).image===igLanguageSourceImage")
  evaluate("window.igI18n.setLanguage('fr-CA')")
  evaluate("document.getElementById('btn_validate_flow').click()")
  wait(function()evaluate("document.querySelector('.modal.show .modal-title')?.textContent==='Validation du flux'&&[...document.querySelectorAll('.ig-preflight-row p')].some(e=>e.textContent.startsWith('Les tâches précédentes produiront'))"),"French validation guidance")
  checks$frenchValidationGuidance<-TRUE
  validation<-evaluate("(()=>{const row=document.querySelector('.ig-preflight-row'),button=row.querySelector('button'),foreground=getComputedStyle(button).color,background=getComputedStyle(row).backgroundColor;const luminance=color=>{const rgb=color.match(/[0-9.]+/g).slice(0,3).map(n=>Number(n)/255).map(v=>v<=.04045?v/12.92:Math.pow((v+.055)/1.055,2.4));return .2126*rgb[0]+.7152*rgb[1]+.0722*rgb[2];};const a=luminance(foreground),b=luminance(background);return {header:row.querySelector('strong').textContent,foreground,background,contrast:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)};})()")
  checks$validationIdentifiersPreserved<-grepl('example_summary',validation$header,fixed=TRUE)
  checks$validationButtonContrast<-validation$contrast>=4.5
  close_modal()
  evaluate("window.igI18n.setLanguage('en-CA')")
  ok<-all(unlist(checks))
  jsonlite::write_json(list(ok=ok,checks=checks,validation=validation),file.path(evidence,"browser-verification.json"),auto_unbox=TRUE,pretty=TRUE)
  if(!ok)stop("Failed browser checks: ",paste(names(checks)[!unlist(checks)],collapse=", "))
  cat("Passed",length(checks),"real-app language browser checks.\n")
}
main()
