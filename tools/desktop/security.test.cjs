'use strict';
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs'), os = require('node:os'), path = require('node:path');
test('project trust is content-bound, persistent, cancellable and detects dialog-time changes', async () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(),'ig-trust-test-'));
  try {
    const file = path.join(root,'known.igpx'), cache = path.join(root,'trusted.json');
    fs.writeFileSync(file,'first'); let accepts = false, prompts = 0;
    let security = require('./security.cjs')({file:cache,confirm:async()=>{ prompts++; return accepts; }});
    assert.equal(await security.trust(file), false); accepts = true;
    assert.equal(await security.trust(file), true); assert.equal(await security.trust(file), true);
    assert.equal(prompts,2);
    security = require('./security.cjs')({file:cache,confirm:async()=>{ throw Error('should be remembered'); }});
    assert.equal(await security.trust(file), true);
    fs.writeFileSync(file,'changed');
    security = require('./security.cjs')({file:cache,confirm:async()=>{fs.writeFileSync(file,'changed again');return true;}});
    assert.equal(await security.trust(file), false);
  } finally { fs.rmSync(root,{recursive:true,force:true}); }
});
