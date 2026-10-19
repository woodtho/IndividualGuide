'use strict';
// The pinned builder gives makensis four minutes, which is insufficient when
// it directly compresses the full R/browser runtime. Extend only that child;
// keep the builder's normal behavior for all other tools.
const path = require('node:path');
const { spawn } = require('node:child_process');
const util = require('builder-util');
const original = util.spawnAndWriteWithOutput;
util.spawnAndWriteWithOutput = (command, args, input, options = {}) => {
  if (path.basename(command).toLowerCase() !== 'makensis.exe')
    return original(command, args, input, options);
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { ...options, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let stdout = '', stderr = '', timedOut = false;
    const timer = setTimeout(() => { timedOut = true; child.kill(); }, 20 * 60 * 1000);
    child.stdout.setEncoding('utf8'); child.stderr.setEncoding('utf8');
    child.stdout.on('data', data => { stdout += data; });
    child.stderr.on('data', data => { stderr += data; });
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', code => {
      clearTimeout(timer);
      if (timedOut) reject(new Error('NSIS compilation exceeded twenty minutes.'));
      else if (code !== 0) reject(new Error(`NSIS compilation failed (${code}).\n${stdout}\n${stderr}`));
      else resolve({ stdout, stderr });
    });
    child.stdin.on('error', error => { if (error.code !== 'EPIPE') reject(error); });
    child.stdin.end(input, 'utf8');
  });
};
const { build, Platform, Arch } = require('electron-builder');
const { target, ...options } = require('./build-options.cjs')();
build({ targets: Platform.WINDOWS.createTarget([target === 'installer' ? 'nsis' : 'portable'], Arch.x64),
  ...options, publish: 'never' })
  .catch(error => { console.error(error); process.exitCode = 1; });
