'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { StringDecoder } = require('node:string_decoder');
module.exports = function createDiagnostics(directory, { maxBytes = 5 * 1024 * 1024, history = 5 } = {}) {
  fs.mkdirSync(directory, { recursive: true });
  const file = path.join(directory, 'startup.log');
  const started = Date.now();
  let bytes = 0, failed = false;
  const rotate = () => {
    for (let index = history; index >= 1; index--) {
      const destination = path.join(directory, `startup.${index}.log`);
      const source = index === 1 ? file : path.join(directory, `startup.${index - 1}.log`);
      if (fs.existsSync(destination)) fs.unlinkSync(destination);
      if (fs.existsSync(source)) fs.renameSync(source, destination);
    }
    bytes = 0;
  };
  try { rotate(); } catch (error) { failed = true; process.stderr.write(`Log rotation failed: ${error.message}\n`); }
  function write(event, details, level = 'INFO') {
    const line = `${new Date().toISOString()} +${Date.now() - started}ms [${level}] ${event}${details === undefined ? '' : ' ' + (typeof details === 'string' ? details : JSON.stringify(details))}\n`;
    try {
      if (bytes + Buffer.byteLength(line) > maxBytes) rotate();
      fs.appendFileSync(file, line); bytes += Buffer.byteLength(line);
    } catch (error) {
      if (!failed) process.stderr.write(`Startup log could not be written: ${error.message}\n`);
      failed = true;
    }
  }
  function stream(readable, label) {
    const decoder = new StringDecoder('utf8');
    let pending = '';
    const drain = () => {
      let end;
      while ((end = pending.indexOf('\n')) >= 0 || pending.length >= 16384) {
        const length = end >= 0 ? Math.min(end, 16384) : 16384;
        write(label, pending.slice(0, length).replace(/\r$/, ''));
        pending = pending.slice(length + (end === length ? 1 : 0));
      }
    };
    readable.on('data', chunk => { pending += decoder.write(chunk); drain(); });
    readable.once('end', () => { pending += decoder.end(); drain(); if (pending) write(label, pending); });
  }
  return { file, write, stream };
};
