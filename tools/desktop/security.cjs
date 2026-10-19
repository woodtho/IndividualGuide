'use strict';
const crypto = require('node:crypto');
const fs = require('node:fs');
module.exports = function security({ file, confirm }) {
  let trusted = [];
  try { trusted = JSON.parse(fs.readFileSync(file, 'utf8')).filter(x => /^[a-f0-9]{64}$/.test(x)).slice(-100); } catch {}
  const digest = async target => {
    const hash=crypto.createHash('sha256');
    for await (const chunk of fs.createReadStream(target)) hash.update(chunk);
    return hash.digest('hex');
  };
  function rememberHash(hash) {
    trusted = trusted.filter(x => x !== hash).concat(hash).slice(-100);
    fs.writeFileSync(file, JSON.stringify(trusted));
  }
  return {
    remember: async target => rememberHash(await digest(target)),
    async trust(target) {
      if (typeof target !== 'string' || !fs.existsSync(target) || !fs.statSync(target).isFile()) return false;
      const hash = await digest(target);
      if (trusted.includes(hash)) return true;
      if (!await confirm(target)) return false;
      // A file changed while the dialog was open requires a fresh decision.
      if (await digest(target) !== hash) return false;
      rememberHash(hash); return true;
    }
  };
};
