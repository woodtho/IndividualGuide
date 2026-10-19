'use strict';
const fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto'), zlib=require('node:zlib');
const root=path.resolve(__dirname,'..'), source=path.join(root,'docs/book');
const out=path.resolve(process.env.BOOK_OUTPUT_DIR||path.join(root,'build/book'));
const meta=JSON.parse(fs.readFileSync(path.join(source,'data/app-reference.json'),'utf8'));
const manifest=JSON.parse(fs.readFileSync(path.join(out,'manifest.json'),'utf8'));
const html=fs.readFileSync(path.join(out,'Individual-Guide-Handbook.html'),'utf8');
const book=fs.readFileSync(path.join(out,'Individual-Guide-Handbook.md'),'utf8');
const plain=fs.readFileSync(path.join(out,'pdf-text.txt'),'utf8').replace(/\s+/g,' ');
const checks={};
const arr=v=>v==null?[]:Array.isArray(v)?v:[v];
const hash=(file,algo='sha256')=>crypto.createHash(algo).update(fs.readFileSync(file)).digest('hex');
function check(name, condition, detail) { checks[name]={ok:Boolean(condition),...(detail===undefined?{}:{detail})}; if(!condition)throw new Error('Book verification failed: '+name+(detail?': '+JSON.stringify(detail):'')); }
function escape(text){return text.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');}
check('complete_reader_edition',meta.task_count===58&&meta.examples.length===22,{words:manifest.words,tasks:meta.task_count,examples:meta.examples.length});
const authored=fs.readdirSync(path.join(source,'chapters')).filter(f=>f.endsWith('.md')).sort().map(f=>fs.readFileSync(path.join(source,'chapters',f),'utf8')).join('\n\n');
check('assembled_book_matches_current_chapters',book.startsWith(authored));
for(const task of meta.registry){
  const token='{#task-'+task.id+'}';
  check('task_'+task.id+'_unique',authored.split(token).length===2);
  const start=authored.indexOf(token)+token.length, next=authored.indexOf('\n## ',start), body=authored.slice(start,next<0?undefined:next);
  check('task_'+task.id+'_action_and_check',/\b(?:[Cc]hoose|[Ss]elect|[Aa]dd)\b/.test(body)&&/\b[Rr]un\b/.test(body)&&/\b(?:[Cc]heck|[Ii]nspect|[Cc]ompare|[Rr]ead)\b/.test(body));
  check('task_'+task.id+'_PDF',plain.includes(task.label));
}
const lessons=JSON.parse(fs.readFileSync(path.join(source,'data/example-lessons.json'),'utf8'));
const covered=new Set();let steps=0;
for(const example of meta.examples){
  check('example_'+example.id+'_archive',hash(path.join(root,'inst/examples',example.id,'project.igpx'),'md5')===example.archive_md5);
  check('example_'+example.id+'_chapter',book.includes('{#example-'+example.id+'}')&&html.includes('id="example-'+example.id+'"'));
  for(const type of arr(example.task_types))covered.add(type);
  check('example_'+example.id+'_practical_lesson',['data','check','try'].every(field=>typeof lessons[example.id]?.[field]==='string'&&book.includes(lessons[example.id][field])));
  check('example_'+example.id+'_task_links',arr(example.task_types).every(type=>book.slice(book.indexOf('{#example-'+example.id+'}')).split(/\n##? /)[0].includes('](#task-'+type+')')));
  check('example_'+example.id+'_saved_successful_work',example.tasks.every(task=>task.status==='success'));
  steps+=example.tasks.length;
}
check('all_enabled_task_types_have_real_examples',meta.registry.every(t=>covered.has(t.id))&&covered.size===58);
check('all_165_saved_example_steps',steps===165&&manifest.exampleSteps===165);
check('lesson_source_identity',hash(path.join(source,'data/example-lessons.json'))===manifest.lessonsSha256);
check('plain_language_no_R_prerequisite',book.includes('without knowing R')&&book.includes('No typing of R code is needed'));
check('public_installation_sources',book.includes('https://github.com/woodtho/IndividualGuide/releases/latest')&&book.includes('https://cran.r-project.org/')&&book.includes('https://cloud.r-project.org')&&book.includes('https://pandoc.org/installing.html'));
check('released_GitHub_package_install',/remotes::install_github\(\s*"woodtho\/IndividualGuide",\s*ref = "v0\.4\.0"/.test(book)&&book.includes('dependencies = NA'));
check('installation_explains_where_and_next_launch',book.includes('Do not type the `>` itself')&&book.includes('You do not need to reinstall packages each day'));
check('no_developer_setup_or_default_dump',!/(?:pkgload::|devtools::|renv::|R CMD (?:build|INSTALL)|build\/staging|tools\/build-standalone|saved defaults|source checkout|source_md5|\.defaults_r)/i.test(book));
check('no_private_machine_paths',!/(?:aThom|OneDrive|C:[\\/]Users[\\/])/i.test(book));
check('examples_filter_and_report_logging_instructions',book.includes('**task type** filter')&&book.includes('Include pipeline log in the report')&&book.includes('Pipeline execution log'));
const readability=require('./book-readability.cjs').readability(book);
check('approximate_eighth_grade_prose',readability.words>1000&&readability.estimatedGrade<=9,readability);
const ids=Array.from(html.matchAll(/\bid="([^"]+)"/g),m=>m[1]);
check('unique_static_HTML_ids',new Set(ids).size===ids.length);
const missing=Array.from(html.matchAll(/href="#([^"]*)"/g),m=>decodeURIComponent(m[1])).filter(id=>id&&!ids.includes(id));
check('all_internal_HTML_links_resolve',missing.length===0,missing);
check('HTML_is_offline',!/<(?:script|link|img)\b[^>]*(?:src|href)=["']https?:\/\//i.test(html));
check('no_unresolved_template_variables',!html.includes('$table-of-contents$')&&!html.includes('$body$'));
check('release_edition_identity',book.includes('0.4.0-Setup-Windows-x64.exe')&&meta.package_version==='0.4.0');
check('no_todo_or_placeholder_sections',!/^\s*(?:TODO|TBD|FIXME|Coming soon|Chapter placeholder)\b/im.test(book));
for(const [relative,expected]of Object.entries(meta.source_md5))check('source_'+relative,hash(path.join(root,relative),'md5')===expected);
for(const chapter of manifest.chapters)check('chapter_'+chapter.name,hash(path.join(source,'chapters',chapter.name))===chapter.sha256);
check('metadata_identity',hash(path.join(source,'data/app-reference.json'))===manifest.metadataSha256);
function zip(file){
  const data=fs.readFileSync(file);let end=-1;
  for(let i=data.length-22;i>=Math.max(0,data.length-65557);i--)if(data.readUInt32LE(i)===0x06054b50){end=i;break;}
  if(end<0)throw new Error('Missing ZIP end record');
  const count=data.readUInt16LE(end+10), files=new Map();let cursor=data.readUInt32LE(end+16);
  for(let i=0;i<count;i++){
    if(data.readUInt32LE(cursor)!==0x02014b50)throw new Error('Invalid ZIP directory');
    const method=data.readUInt16LE(cursor+10), size=data.readUInt32LE(cursor+20), expected=data.readUInt32LE(cursor+24), nameLength=data.readUInt16LE(cursor+28), extra=data.readUInt16LE(cursor+30), comment=data.readUInt16LE(cursor+32), local=data.readUInt32LE(cursor+42);
    const name=data.subarray(cursor+46,cursor+46+nameLength).toString('utf8');
    const start=local+30+data.readUInt16LE(local+26)+data.readUInt16LE(local+28), bytes=data.subarray(start,start+size);
    const content=method===0?bytes:method===8?zlib.inflateRawSync(bytes):null;
    if(!content||content.length!==expected)throw new Error('Invalid ZIP payload: '+name);
    files.set(name,content);cursor+=46+nameLength+extra+comment;
  }return files;
}
const epub=zip(path.join(out,'Individual-Guide-Handbook.epub'));
check('EPUB_container',epub.get('mimetype')?.toString()==='application/epub+zip'&&epub.has('META-INF/container.xml'));
const broken=[];let chapters=0;
for(const [name,bytes]of epub){
  if(!/\.(xhtml|html|opf|ncx)$/.test(name))continue;
  if(/\.(xhtml|html)$/.test(name))chapters++;
  for(const match of bytes.toString('utf8').matchAll(/(?:src|href)="([^"]+)"/g)){
    const [ref,fragment]=match[1].split('#');if(/^[a-z][\w+.-]*:|^\/\//i.test(ref))continue;
    const resolved=ref?path.posix.normalize(path.posix.join(path.posix.dirname(name),decodeURIComponent(ref))):name;
    if(!epub.has(resolved))broken.push({name,ref,resolved});
    else if(fragment&&!new RegExp('\\bid=["\\\']'+escape(decodeURIComponent(fragment))+'["\\\']').test(epub.get(resolved).toString('utf8')))broken.push({name,ref,fragment,resolved});
  }
}
check('EPUB_resources_resolve',broken.length===0,broken);
check('EPUB_has_book_chapters',chapters>=20,chapters);
const docx=zip(path.join(out,'Individual-Guide-Handbook.docx'));
check('DOCX_package',docx.has('[Content_Types].xml')&&docx.has('word/document.xml'));
check('DOCX_all_four_figures',Array.from(docx.keys()).filter(name=>/^word\/media\//.test(name)).length>=4);
const xml=docx.get('word/document.xml').toString('utf8').replace(/<[^>]+>/g,' ').replace(/\s+/g,' ');
check('DOCX_has_task_and_example_guide',xml.includes('Cluster Analysis')&&xml.includes('Choose an example project')&&xml.includes('Pipeline execution log'));
const wordXML=docx.get('word/document.xml').toString('utf8');
const bookmarks=new Set(Array.from(wordXML.matchAll(/<w:bookmarkStart\b[^>]*w:name="([^"]+)"/g),match=>match[1]));
const missingBookmarks=Array.from(wordXML.matchAll(/<w:hyperlink\b[^>]*w:anchor="([^"]+)"/g),match=>match[1]).filter(anchor=>!bookmarks.has(anchor));
check('DOCX_internal_links_resolve',missingBookmarks.length===0,missingBookmarks);
for(const ext of ['html','epub','docx'])check('clean_'+ext+'_conversion_log',!fs.readFileSync(path.join(out,'Individual-Guide-Handbook.'+ext+'.build.log'),'utf8').trim());
const rendered=JSON.parse(fs.readFileSync(path.join(out,'render-verification.json'),'utf8'));
const calculated=JSON.parse(fs.readFileSync(path.join(out,'calculation-verification.json'),'utf8'));
check('render_matches_current_HTML_and_PDF',rendered.htmlSha256===hash(path.join(out,'Individual-Guide-Handbook.html'))&&rendered.pdf.sha256===hash(path.join(out,'Individual-Guide-Handbook.pdf')));
check('calculations_match_current_book',calculated.markdownSha256===hash(path.join(out,'Individual-Guide-Handbook.md')));
check('real_browser_and_PDF_checks',rendered.ok===true&&rendered.pdf.pages>=20&&rendered.anchors.missing.length===0&&rendered.anchors.duplicate.length===0, {pages:rendered.pdf.pages,layouts:rendered.layouts});
check('task_reference_navigation_reaches_heading',rendered.taskReferenceVisible===true);
check('PDF_fonts_embedded',arr(rendered.pdf.fonts).every(font=>font.embedded===true));
check('worked_R_tutorial_passed',calculated.ok===true&&Object.values(calculated.checks).every(Boolean),{RBlocks:calculated.RBlocks,checks:Object.keys(calculated.checks).length});
check('PDF_contains_reading_and_installation',plain.includes('Installation and first launch')&&plain.includes('Contents')&&plain.includes('Individual Guide'));
check('PDF_has_readable_text',rendered.pdf.textCharacters>40000&&rendered.pdf.nonemptyPages===rendered.pdf.pages);
const internalPDFLinks=(fs.readFileSync(path.join(out,'Individual-Guide-Handbook.pdf')).toString('latin1').match(/\/Dest\b|\/S\s*\/GoTo\b/g)||[]).length;
check('PDF_contains_internal_navigation',internalPDFLinks>=58,internalPDFLinks);
manifest.outputs=['md','html','pdf','epub','docx'].map(ext=>{const file='Individual-Guide-Handbook.'+ext;return{file,bytes:fs.statSync(path.join(out,file)).size,sha256:hash(path.join(out,file))};});
fs.writeFileSync(path.join(out,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
const result={ok:true,title:meta.title,edition:meta.edition,words:manifest.words,readability,taskTypes:58,exampleProjects:22,savedExampleSteps:steps,
  PDFPages:rendered.pdf.pages,checksPassed:Object.keys(checks).length,checks,artifacts:manifest.outputs,verifiedAt:new Date().toISOString()};
fs.writeFileSync(path.join(out,'verification.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({ok:result.ok,words:result.words,tasks:58,examples:22,steps,PDFPages:result.PDFPages,checksPassed:result.checksPassed},null,2));
