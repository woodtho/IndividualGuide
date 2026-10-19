'use strict';
// Render the editable SVG with the same Chromium engine as the desktop app.
// PNG frames in the ICO retain alpha at every supported Windows display size.
const { app, BrowserWindow } = require('electron');
const fs = require('node:fs');
const path = require('node:path');
app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const assets = path.join(__dirname, 'assets');
  const svg = fs.readFileSync(path.join(assets, 'icon.svg'), 'utf8');
  const window = new BrowserWindow({ width: 512, height: 512, useContentSize: true,
    show: false, frame: false, transparent: true,
    webPreferences: { sandbox: true, contextIsolation: true, nodeIntegration: false,
      offscreen: true } });
  await window.loadURL('data:text/html;charset=utf-8,' + encodeURIComponent(
    '<html><body style="margin:0;overflow:hidden;background:transparent">' + svg + '</body></html>'));
  const rendered = await window.webContents.capturePage();
  if (rendered.isEmpty()) throw new Error('Icon rendering produced an empty image.');
  const raster = rendered.resize({ width: 512, height: 512, quality: 'best' });
  fs.writeFileSync(path.join(assets, 'icon.png'), raster.toPNG());
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const frames = sizes.map(size => raster.resize({ width: size, height: size, quality: 'best' }).toPNG());
  const directory = Buffer.alloc(6 + 16 * sizes.length);
  directory.writeUInt16LE(1, 2);
  directory.writeUInt16LE(sizes.length, 4);
  let offset = directory.length;
  sizes.forEach((size, index) => {
    const entry = 6 + 16 * index;
    directory[entry] = size === 256 ? 0 : size;
    directory[entry + 1] = directory[entry];
    directory.writeUInt16LE(1, entry + 4);
    directory.writeUInt16LE(32, entry + 6);
    directory.writeUInt32LE(frames[index].length, entry + 8);
    directory.writeUInt32LE(offset, entry + 12);
    offset += frames[index].length;
  });
  fs.writeFileSync(path.join(assets, 'icon.ico'), Buffer.concat([directory, ...frames]));
  console.log('Created icon.png and icon.ico (16, 24, 32, 48, 64, 128, 256 px).');
  window.destroy();
  app.quit();
}).catch(error => { console.error(error); app.exit(1); });
