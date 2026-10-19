'use strict';
const path = require('node:path');

module.exports = function buildOptions(argv = process.argv.slice(2)) {
  const option = name => argv.find(value => value.startsWith(`--${name}=`))?.slice(name.length + 3);
  const target = option('target') || 'installer';
  if (!['installer', 'portable'].includes(target)) throw new Error(`Unknown desktop target: ${target}`);
  const runtime = option('runtime') || path.join(__dirname, '../../build/staging/runtime');
  const output = option('output');
  const prepackaged = option('prepackaged');
  return {
    target,
    ...(prepackaged ? { prepackaged: path.resolve(prepackaged) } : {}),
    config: {
      ...(output ? { directories: { output: path.resolve(output) } } : {}),
      // electron-builder concatenates resource arrays from different configs.
      // Keep this definition here alone so old staging can never be mixed in.
      extraResources: [{ from: path.resolve(runtime), to: 'runtime' }]
    }
  };
};
