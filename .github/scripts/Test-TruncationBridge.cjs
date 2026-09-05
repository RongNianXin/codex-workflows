// Headless logic regression; reads only repository source and synthetic fixtures.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '../..');
const directory = path.join(root, '实用小工具/Codex会话交接评估');
const read = name => fs.readFileSync(path.join(directory, name), 'utf8').replace(/\r\n/g, '\n');
const original = read('browser-compatibility-check.html');
const page = read('truncation-compatibility-lab.html');
const parser = original.slice(original.indexOf('function parseCompatibility('), original.indexOf('window.parseCompatibility='));
assert.ok(parser.startsWith('function parseCompatibility('));
assert.ok(page.includes(parser), 'Embedded parser must match existing parser verbatim');
const nodes = new Map();
const context = vm.createContext({ TextDecoder, Uint8Array, window: {}, document: {
  querySelectorAll: () => [],
  getElementById: id => { if (!nodes.has(id)) nodes.set(id, {}); return nodes.get(id); }
} });
vm.runInContext(page.match(/<script>([\s\S]*?)<\/script>/)[1], context);
vm.runInContext('const referenceParser = parseCompatibility; window.calls = 0; parseCompatibility = (...args) => { window.calls++; return referenceParser(...args); };', context);
const corpus = JSON.parse(read('compatibility-fixtures.json'));
assert.equal(corpus.synthetic, true);
let count = 0;
for (const sample of corpus.cases) {
  context.window.calls = 0;
  const actual = JSON.parse(JSON.stringify(context.window.analyzeBridge(sample.segments.map(segment => ({
    name: segment.name, bytes: Buffer.from(segment.text, 'utf8')
  })))));
  assert.equal(actual.parserCalls, context.window.calls, sample.name + ': actual parser invocations');
  const expected = sample.comparison.browser;
  if (expected.ok) {
    assert.equal(actual.stage, 'parsed', sample.name);
    assert.deepEqual(actual.result, expected.result, sample.name);
    for (const [key, value] of Object.entries(sample.truth || {})) {
      assert.deepEqual(key === 'totals' ? actual.result.turns.map(turn => turn.total) : actual.result[key], value, sample.name);
    }
  } else if (sample.name === 'malformed-token-record') {
    assert.equal(actual.stage, 'integrity_blocked');
    assert.equal(actual.parserCalls, 0);
    assert.equal(actual.missingTokens, null);
  } else {
    assert.equal(actual.stage, 'parser_rejected', sample.name);
    assert.equal(actual.reason, expected.error, sample.name);
  }
  count++;
}
console.log(`Truncation bridge corpus: PASS (${count} synthetic cases; original parser text verified)`);
