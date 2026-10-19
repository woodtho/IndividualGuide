'use strict';
// A rough editing aid for English prose, not a guarantee of reading difficulty.
function readability(markdown) {
  const text = markdown.replace(/```[\s\S]*?```/g, '')
    .split(/\r?\n/).filter(line => !/^\s*(?:#|\||!\[)/.test(line)).join('\n')
    .replace(/\[([^\]]+)\]\([^)]*\)/g, '$1').replace(/`[^`]+`/g, '')
    .replace(/https?:\/\/\S+/g, '').replace(/\{#[^}]+\}/g, '')
    .replace(/^\s*\d+\.\s*/gm, '').replace(/\*+/g, '');
  const sentences = text.split(/[.!?]+(?:\s|$)/).map(s => s.trim()).filter(s => /[a-z]/i.test(s));
  const words = text.match(/[A-Za-z]+(?:['’][a-z]+)?/g) || [];
  function syllables(word) {
    word = word.toLowerCase().replace(/['’]/g, '');
    if (word.length <= 3) return 1;
    word = word.replace(/(?:[^laeiouy]es|ed|[^laeiouy]e)$/, '').replace(/^y/, '');
    return Math.max(1, (word.match(/[aeiouy]{1,2}/g) || []).length);
  }
  const syllableCount = words.reduce((count, word) => count + syllables(word), 0);
  const meanSentenceWords = words.length / Math.max(1, sentences.length);
  return {method:'Flesch-Kincaid; estimated syllables; prose excluding code, tables, headings and inline identifiers',
    words:words.length, sentences:sentences.length, syllables:syllableCount,
    averageSentenceWords:Number(meanSentenceWords.toFixed(2)),
    estimatedGrade:Number((0.39*meanSentenceWords+11.8*syllableCount/Math.max(1,words.length)-15.59).toFixed(2))};
}
module.exports = {readability};
