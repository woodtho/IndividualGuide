# Exercise the real parent UI and cross-origin Shiny iframe in Chromium.
main <- function() {
  Sys.setlocale("LC_CTYPE", ".UTF-8")
  root <- normalizePath(getwd(), winslash = "/")
  evidence <- file.path(root, "artifacts/shiny-apps"); dir.create(evidence, recursive = TRUE, showWarnings = FALSE)
  unlink(file.path(evidence,"browser-verification.json"))
  practice <- tempfile("external apps with spaces-"); dir.create(practice)
  broken <- file.path(practice, "broken"); dir.create(broken)
  dir.create(file.path(practice,"Mean"))
  file.copy(file.path(root,"inst/shiny-apps/iris-explorer/app.R"),file.path(practice,"Mean/app.R"))
  writeLines('stop("Practice startup failure")', file.path(broken, "app.R"))
  port <- httpuv::randomPort()
  server <- callr::r_bg(function(root, port, practice) {
    setwd(root); pkgload::load_all(root, quiet = TRUE, export_all = FALSE)
    profile <- tempfile("ig-app-browser-profile-")
    Sys.setenv(IG_USER_DATA = profile)
    options(ig.recovery_dir = file.path(profile, "recovery"),
      ig.file_roots = c(Examples = file.path(root, "inst/shiny-apps"), Practice = practice))
    shiny::runApp(IndividualGuide::run_app(), host = "127.0.0.1", port = port, launch.browser = FALSE)
  }, args = list(root, port, practice), stdout = file.path(evidence,"parent.stdout.log"), stderr = file.path(evidence,"parent.stderr.log"))
  on.exit({server$kill(); unlink(practice, recursive = TRUE)}, add = TRUE)
  Sys.setenv(CHROMOTE_CHROME = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe")
  options(chromote.timeout = 120)
  browser <- chromote::Chromote$new(browser = chromote::Chrome$new(args = c(
    chromote::default_chrome_args(), "--no-first-run", "--no-default-browser-check", "--disable-sync", "--disable-background-networking")))
  browser$default_timeout <- 120
  page <- chromote::ChromoteSession$new(width = 1440, height = 1000, parent = browser)
  on.exit({try(page$close(), silent=TRUE);try(browser$close(),silent=TRUE)}, add = TRUE)
  js <- function(script, context = NULL) {
    args <- list(expression = script, returnByValue = TRUE, awaitPromise = TRUE)
    if (!is.null(context)) args$contextId <- context
    result <- do.call(page$Runtime$evaluate, args)
    if (!is.null(result$exceptionDetails)) stop(jsonlite::toJSON(result$exceptionDetails,auto_unbox=TRUE))
    result$result$value
  }
  shot <- function(name) writeBin(jsonlite::base64_dec(page$Page$captureScreenshot(format="png")$data),file.path(evidence,name))
  wait <- function(test, label, timeout = 90) {
    deadline <- Sys.time()+timeout
    repeat {
      if(isTRUE(tryCatch(test(),error=function(error)FALSE)))return(invisible(TRUE))
      if(Sys.time()>deadline) {
        try(shot("failure.png"),silent=TRUE)
        try(writeLines(js("document.body.innerText"),file.path(evidence,"failure.txt")),silent=TRUE)
        stop("App browser test timed out: ",label)
      }
      Sys.sleep(.1)
    }
  }
  url <- paste0("http://127.0.0.1:",port,"/")
  wait(function() {connection<-url(url);on.exit(close(connection));length(suppressWarnings(readLines(connection,warn=FALSE)))>0},"parent HTTP")
  page$go_to(url)
  wait(function()js("Boolean(window.igShinyApps&&window.Shiny?.shinyapp?.$socket?.readyState===1&&document.getElementById('splash_shiny_apps'))"),"welcome launcher")
  checks <- list()
  writeLines(js("document.getElementById('sf_shiny_app').outerHTML"),file.path(evidence,"picker-binding.txt"))
  js("window._hostTestSocket=Shiny.shinyapp.$socket;document.getElementById('splash_shiny_apps').click()")
  wait(function()js("!document.getElementById('ig-shiny-apps').hidden&&!document.getElementById('shiny-modal')"),"launcher from welcome")
  checks$welcomeAndPersistentChrome <- TRUE
  stopifnot(isTRUE(js("(()=>{const luminance=color=>{const rgb=color.match(/[\\d.]+/g).slice(0,3).map(Number).map(x=>x/255).map(x=>x<=.04045?x/12.92:((x+.055)/1.055)**2.4);return rgb[0]*.2126+rgb[1]*.7152+rgb[2]*.0722;};const bg=luminance(getComputedStyle(document.getElementById('ig-shiny-apps')).backgroundColor);return ['sf_shiny_app','sf_shiny_folder'].every(id=>{const fg=luminance(getComputedStyle(document.getElementById(id)).color);return (Math.max(bg,fg)+.05)/(Math.min(bg,fg)+.05)>=4.5;});})()")))
  checks$readablePickerControls <- TRUE
  js("document.getElementById('sf_shiny_app').click()")
  wait(function()js("Boolean(document.querySelector('.sF-modalContainer.in'))"),"actual file picker")
  shot("file-picker.png")
  js("document.querySelector('.sF-modalContainer #sF-cancelButton').click()")
  wait(function()js("!document.querySelector('.sF-modalContainer')"),"cancel actual picker")
  checks$realPickerAndCancel <- TRUE
  choose <- function(root, parts, folder = FALSE) {
    payload <- if(folder)list(root=root,path=as.list(c("",parts))) else list(root=root,files=list(as.list(parts)))
    id <- if(folder)"sf_shiny_folder" else "sf_shiny_app"
    js(sprintf("Shiny.setInputValue(%s,%s,{priority:'event'})",jsonlite::toJSON(id,auto_unbox=TRUE),jsonlite::toJSON(payload,auto_unbox=TRUE)))
  }
  run <- function() {
    js("document.getElementById('ig-app-trust').checked=true;document.getElementById('ig-app-trust').dispatchEvent(new Event('change'));document.getElementById('ig-app-run').click()")
    wait(function()js("!igShinyApps.pending&&igShinyApps.state.phase==='ready'&&!document.getElementById('ig-app-frame').hidden"),"guest ready")
  }
  guest_page <- NULL
  guest <- function(code) {
    targets <- browser$Target$getTargets()$targetInfos
    guest_url <- js("igShinyApps.state.url")
    target <- Filter(function(target)identical(target$type,"iframe") &&
      startsWith(target$url,guest_url), targets)[[1L]]
    if(is.null(guest_page) || !identical(guest_page$targetId,target$targetId))
      guest_page <<- chromote::ChromoteSession$new(parent=browser,targetId=target$targetId)
    result <- guest_page$Runtime$evaluate(expression=code,returnByValue=TRUE,awaitPromise=TRUE)
    if(!is.null(result$exceptionDetails))stop(jsonlite::toJSON(result$exceptionDetails,auto_unbox=TRUE))
    result$result$value
  }
  js("document.getElementById('sf_shiny_app').click()")
  wait(function()js("Boolean(document.querySelector('.sF-modalContainer.in .sF-directory'))"),"file picker directory list")
  js("[...document.querySelectorAll('.sF-modalContainer .sF-directory')].find(e=>e.querySelector('.sF-file-name')?.textContent.trim()==='iris-explorer').dispatchEvent(new MouseEvent('dblclick',{bubbles:true}))")
  wait(function()js("[...document.querySelectorAll('.sF-modalContainer .sF-file')].some(e=>e.querySelector('.sF-file-name')?.textContent.trim()==='app.R')"),"app.R in actual file picker")
  js("[...document.querySelectorAll('.sF-modalContainer .sF-file')].find(e=>e.querySelector('.sF-file-name')?.textContent.trim()==='app.R').dispatchEvent(new MouseEvent('click',{bubbles:true}))")
  wait(function()js("!document.querySelector('.sF-modalContainer #sF-selectButton').disabled"),"file selection enabled")
  js("document.querySelector('.sF-modalContainer #sF-selectButton').click()")
  wait(function()js("document.getElementById('ig-app-path').textContent.endsWith('iris-explorer')"),"file validated")
  stopifnot(isTRUE(js("document.getElementById('ig-app-run').disabled")))
  run()
  first_pid <- js("igShinyApps.state.pid")
  wait(function()guest("document.getElementById('count')?.textContent==='150 flowers'"),"real guest reactive output")
  guest("document.getElementById('species').value='setosa';document.getElementById('species').dispatchEvent(new Event('change',{bubbles:true}))")
  wait(function()guest("document.getElementById('count').textContent==='50 flowers'"),"guest input")
  checks$singleFileAndInteractiveGuest <- TRUE
  checks$actualFileSelection <- TRUE
  shot("running-en-CA.png")
  js("document.getElementById('ig-app-back').click();document.getElementById('ig-tree-search-input').value='keep my workspace'")
  stopifnot(isTRUE(js("document.getElementById('ig-shiny-apps').hidden&&Shiny.shinyapp.$socket===_hostTestSocket")))
  js("document.getElementById('btn_shiny_apps').click()")
  wait(function()guest("document.getElementById('species').value==='setosa'&&document.getElementById('count').textContent==='50 flowers'"),"guest retained across workspace switch")
  stopifnot(identical(js("igShinyApps.state.pid"),first_pid))
  checks$mainAlwaysAvailableAndGuestNotReloaded <- TRUE
  js("igI18n.setLanguage('fr-CA')")
  wait(function()js("document.getElementById('ig-app-close').textContent.includes('Fermer')"),"French chrome")
  stopifnot(isTRUE(guest("document.getElementById('species').value==='setosa'")))
  guest("document.getElementById('language').value='fr';document.getElementById('language').dispatchEvent(new Event('change',{bubbles:true}))")
  wait(function()guest("document.getElementById('count').textContent==='150 fleurs'"),"guest own language")
  shot("running-fr-CA.png")
  stopifnot(isTRUE(js("Shiny.shinyapp.$socket===_hostTestSocket")))
  checks$bilingualChromeAndIndependentGuestLanguage <- TRUE
  js("document.getElementById('ig-app-open').click()")
  shot("launcher-fr-CA.png")
  js("document.getElementById('sf_shiny_app').click()")
  wait(function()js("Boolean(document.querySelector('.sF-modalContainer.in .sF-breadcrumps'))"),"French file picker")
  js("(()=>{const s=document.querySelector('.sF-modalContainer .sF-breadcrumps');[...s.options].find(o=>o.value==='Practice').selected=true;s.dispatchEvent(new Event('change',{bubbles:true}));})()")
  wait(function()js("[...document.querySelectorAll('.sF-modalContainer .sF-file-name')].some(e=>e.textContent.trim()==='Mean')"),"literal folder name in French picker")
  stopifnot(isTRUE(js("document.querySelector('.sF-file-header').textContent.includes('Nom')&&!document.querySelector('.sF-fileList').textContent.includes('Moyenne')")))
  js("document.querySelector('.sF-modalContainer #sF-cancelButton').click()")
  wait(function()js("!document.querySelector('.sF-modalContainer')"),"cancel French picker")
  checks$frenchPickerPreservesFileNames <- TRUE
  js("document.getElementById('sf_shiny_folder').click()")
  wait(function()js("Boolean(document.querySelector('.sF-modalContainer.in'))"),"actual folder picker")
  js("document.querySelector('.sF-modalContainer #sF-cancelButton').click()")
  wait(function()js("!document.querySelector('.sF-modalContainer')"),"cancel folder picker")
  checks$actualFolderPicker <- TRUE
  choose("Examples",c("local-sales","ui.R"))
  wait(function()js("document.getElementById('ig-app-error').textContent.includes('app.R')"),"invalid selection")
  stopifnot(identical(js("igShinyApps.state.pid"),first_pid))
  checks$invalidChoiceKeepsRunningApp <- TRUE
  choose("Examples","local-sales",folder=TRUE)
  wait(function()js("document.getElementById('ig-app-path').textContent.endsWith('local-sales')"),"folder validated")
  run()
  stopifnot(!first_pid %in% ps::ps_pids())
  wait(function()guest("document.getElementById('total')?.textContent==='Total: 450'"),"two-file relative helper and CSV")
  guest("document.getElementById('minimum').value='160';document.getElementById('minimum').dispatchEvent(new Event('change',{bubbles:true}))")
  wait(function()guest("document.getElementById('total').textContent==='Total: 180'"),"two-file reactive result")
  checks$folderSwitchStopsOldProcessAndLoadsRelativeFiles <- TRUE
  second_pid <- js("igShinyApps.state.pid")
  js("document.getElementById('ig-app-close').click();document.getElementById('ig-app-cancel-close').click()")
  stopifnot(identical(js("igShinyApps.state.pid"),second_pid))
  js("document.getElementById('ig-app-close').click();document.getElementById('ig-app-confirm-close').click()")
  wait(function()js("igShinyApps.state.phase==='idle'"),"close app")
  stopifnot(!second_pid %in% ps::ps_pids())
  checks$closeAndCancel <- TRUE
  choose("Practice",c("broken","app.R"));wait(function()js("document.getElementById('ig-app-path').textContent.endsWith('broken')"),"broken app selected")
  js("document.getElementById('ig-app-trust').checked=true;document.getElementById('ig-app-trust').dispatchEvent(new Event('change'));document.getElementById('ig-app-run').click()")
  wait(function()js("igShinyApps.state.phase==='failed'&&document.getElementById('ig-app-log-text').textContent.includes('Practice startup failure')"),"actionable startup log")
  checks$failureLeavesControlsAvailable <- TRUE
  choose("Examples",c("iris-explorer","app.R"));wait(function()js("document.getElementById('ig-app-path').textContent.endsWith('iris-explorer')"),"retry app selected");run()
  wait(function()guest("document.getElementById('count')?.textContent==='150 flowers'"),"guest before browser hang")
  js("window._hostTestGuestHostname=new URL(igShinyApps.state.url).hostname")
  pending_guest <- guest_page$Runtime$evaluate(expression="while(true){}",wait_=FALSE)
  promises::catch(pending_guest,function(error)NULL)
  Sys.sleep(.25)
  js("document.getElementById('ig-app-back').click()")
  stopifnot(isTRUE(js("document.getElementById('ig-shiny-apps').hidden&&Shiny.shinyapp.$socket===_hostTestSocket")))
  js("document.getElementById('btn_shiny_apps').click();document.getElementById('ig-app-close').click();document.getElementById('ig-app-confirm-close').click()")
  wait(function()js("igShinyApps.state.phase==='idle'&&!igShinyApps.pending"),"close frozen browser guest")
  run()
  stopifnot(isTRUE(js("new URL(igShinyApps.state.url).hostname!==_hostTestGuestHostname")))
  wait(function()guest("document.getElementById('count')?.textContent==='150 flowers'"),"new browser guest after frozen app")
  checks$browserRecoversFromHungGuest <- TRUE
  js("document.getElementById('ig-app-back').click()")
  stopifnot(isTRUE(js("document.getElementById('ig-tree-search-input').value==='keep my workspace'&&Shiny.shinyapp.$socket===_hostTestSocket")))
  js("document.getElementById('btn_shiny_apps').click()")
  final_pid <- js("igShinyApps.state.pid")
  server$kill()
  wait(function()!final_pid %in% ps::ps_pids(),"supervised child cleanup after parent stops")
  checks$parentAndChildLifecycle <- TRUE
  jsonlite::write_json(list(ok=TRUE,checks=checks),file.path(evidence,"browser-verification.json"),pretty=TRUE,auto_unbox=TRUE)
  cat("Passed",length(checks),"real Shiny app browser checks.\n")
}
main()
