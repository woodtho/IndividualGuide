'use strict';
// Render on the CPU: icon generation must also work on a headless CI runner.
// PNG frames in the ICO retain alpha at every supported Windows display size.
const { Resvg } = require('@resvg/resvg-js');
const fs = require('node:fs');
const path = require('node:path');
function createIcons(assets = path.join(__dirname, 'assets')) {
  const svg = fs.readFileSync(path.join(assets, 'icon.svg'), 'utf8');
  const raster = size => new Resvg(svg, { fitTo: {mode: 'width', value: size},
    font: {loadSystemFonts: false} }).render().asPng();
  fs.writeFileSync(path.join(assets, 'icon.png'), raster(512));
  const sizes = [16, 24, 32, 48, 64, 128, 256];
  const frames = sizes.map(raster);
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
  return sizes;
}
module.exports = {createIcons};
if (require.main === module) {
  createIcons();
  console.log('Created icon.png and icon.ico on the CPU (16, 24, 32, 48, 64, 128, 256 px).');
}
