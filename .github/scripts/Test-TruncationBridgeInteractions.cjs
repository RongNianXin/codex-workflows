// Uses an existing Playwright installation and existing Edge; never installs browsers.
// Inputs come exclusively from the page's built-in synthetic sample generator.
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const assert = require('node:assert/strict');
const { chromium } = require('playwright');
const root = path.resolve(__dirname, '../..');

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  try {
    const page = await browser.newPage();
    const errors = [];
    let requests = 0;
    page.on('pageerror', error => errors.push(error.message));
    page.on('request', request => { if (/^https?:/.test(request.url())) requests++; });
    await page.goto(pathToFileURL(path.join(root, '实用小工具/Codex会话交接评估/truncation-compatibility-lab.html')).href);
    const texts = await page.evaluate(() => ({ ...samples }));
    const input = (kind, name = kind + '.jsonl') => ({ name, mimeType: 'application/x-ndjson', buffer: Buffer.from(texts[kind]) });
    const checks = [];
    const passed = name => checks.push(name);
    const result = () => page.locator('#result').textContent();
    const dom = () => page.evaluate(() => Object.fromEntries(['gate', 'result', 'issues', 'notice'].map(id => [id, document.getElementById(id).textContent])));
    const total = async expected => assert.equal(JSON.parse(await result()).turns[0].total, expected);
    const cleared = async () => assert.match(await result(), /未生成统计/);
    async function choose(files, wait = true) {
      const chooser = page.waitForEvent('filechooser');
      await page.locator('#files').click();
      await (await chooser).setFiles(files);
      if (wait) await page.waitForFunction(() => !document.getElementById('files').disabled);
    }
    await page.evaluate(() => {
      window.realRead = File.prototype.arrayBuffer;
      window.readMode = 'normal';
      window.pendingReads = [];
      window.parserInvocations = 0;
      const parser = parseCompatibility;
      parseCompatibility = (...args) => { window.parserInvocations++; return parser(...args); };
      File.prototype.arrayBuffer = function () {
        if (window.readMode === 'fail' || (window.readMode === 'fail-b' && this.name === 'b.jsonl')) {
          return Promise.reject(new Error('synthetic read failure'));
        }
        if (window.readMode === 'defer') {
          return new Promise((resolve, reject) => window.pendingReads.push({ file: this, resolve, reject }));
        }
        return window.realRead.call(this);
      };
      window.finishRead = async (name, fail) => {
        const index = window.pendingReads.findIndex(item => item.file.name === name);
        if (index < 0) throw new Error('Missing controlled read: ' + name);
        const [item] = window.pendingReads.splice(index, 1);
        if (fail) item.reject(new Error('synthetic late failure'));
        else item.resolve(await window.realRead.call(item.file));
        // Drain the promise continuation of the actual change handler before assertions.
        await new Promise(resolve => setTimeout(resolve, 0));
      };
    });
    const mode = value => page.evaluate(value => { window.readMode = value; }, value);
    const reset = () => page.locator('#reset').click();
    const finish = (name, fail = false) => page.evaluate(({ name, fail }) => window.finishRead(name, fail), { name, fail });
    const waiting = name => page.waitForFunction(name => window.pendingReads.some(item => item.file.name === name), name);

    await choose([input('a')]); await total(100); passed('one segment: 100');
    await choose([input('a'), input('b')]); await total(130); passed('add segment: recompute 130');
    const full = await result();
    await choose([input('b'), input('a')]); assert.equal(await result(), full); passed('reverse selection: same result');
    const beforeRepeat = await page.evaluate(() => window.parserInvocations);
    await choose([input('a'), input('b')]); assert.equal(await result(), full);
    assert.equal(await page.evaluate(() => window.parserInvocations), beforeRepeat + 1); passed('repeat selection: reparse without accumulation');
    await choose([input('a')]); await total(100); passed('remove segment: old contribution removed');
    const beforeBlock = await page.evaluate(() => window.parserInvocations);
    await choose([input('a'), input('cut')]); await cleared();
    assert.equal(await page.evaluate(() => window.parserInvocations), beforeBlock); passed('add incomplete segment: clear and block parser');
    await choose([input('a'), input('b')]); await total(130); passed('remove incomplete segment: recover');
    await choose([input('a', 'same.jsonl'), input('b', 'same.jsonl')]); await cleared();
    assert.match(await page.locator('#issues').textContent(), /duplicate_segment_name/); passed('duplicate filenames: reject without old statistics');
    await choose([input('a')]); const beforeEmpty = await dom();
    await page.locator('#files').setInputFiles([]); assert.deepEqual(await dom(), beforeEmpty); passed('empty selection: preserve current snapshot');

    await mode('fail'); const beforeFailure = await page.evaluate(() => window.parserInvocations);
    await choose([input('a')]); await cleared(); assert.match(await page.locator('#notice').textContent(), /synthetic read failure/);
    assert.equal(await page.evaluate(() => window.parserInvocations), beforeFailure); passed('first file read failure: no stale result or parser call');
    await mode('normal'); await choose([input('a'), input('b')]);
    await mode('fail-b'); await choose([input('a'), input('b')]); await cleared(); passed('second file read failure: no partial aggregate');
    await mode('normal'); await choose([input('a')]); await total(100); passed('read failure recovery');
    await choose([{ name: 'large.jsonl', mimeType: 'application/x-ndjson', buffer: Buffer.alloc(2 * 1048576 + 1) }]);
    await cleared(); assert.match(await page.locator('#notice').textContent(), /超过/); passed('oversized selection clears old statistics');

    await choose([input('a'), input('b')]);
    await mode('defer'); await choose([input('a', 'old-reset.jsonl')], false); await waiting('old-reset.jsonl');
    await cleared(); assert.equal(await page.locator('#files').isDisabled(), true); passed('pending read immediately clears old statistics and locks chooser');
    await reset(); const resetState = await dom(); await finish('old-reset.jsonl');
    assert.deepEqual(await dom(), resetState); assert.equal(await page.locator('#files').isDisabled(), false); passed('late success after reset: ignored');

    await choose([input('a', 'old-success.jsonl')], false); await waiting('old-success.jsonl');
    await reset(); await mode('normal'); await choose([input('a'), input('b')]); const newState = await dom();
    await finish('old-success.jsonl'); assert.deepEqual(await dom(), newState); await total(130); passed('old success cannot overwrite newer success');

    await mode('defer'); await choose([input('a', 'old-failure.jsonl')], false); await waiting('old-failure.jsonl');
    await reset(); await mode('normal'); await choose([input('a')]); const afterNew = await dom();
    await finish('old-failure.jsonl', true); assert.deepEqual(await dom(), afterNew); passed('old failure cannot overwrite newer success');

    await mode('defer'); await choose([input('a', 'old-overlap.jsonl')], false); await waiting('old-overlap.jsonl');
    await reset(); await choose([input('b', 'new-overlap.jsonl')], false); await waiting('new-overlap.jsonl');
    const pendingState = await dom(); await finish('old-overlap.jsonl');
    assert.deepEqual(await dom(), pendingState); assert.equal(await page.locator('#files').isDisabled(), true); passed('old finally cannot unlock newer pending read');
    await finish('new-overlap.jsonl'); await total(130); assert.equal(await page.locator('#files').isDisabled(), false); passed('new pending read completes normally');

    await mode('defer'); await choose([input('a', 'last-failure.jsonl')], false); await waiting('last-failure.jsonl');
    await reset(); const finalReset = await dom(); await finish('last-failure.jsonl', true);
    assert.deepEqual(await dom(), finalReset); passed('late failure after reset: ignored');
    assert.equal(await page.evaluate(() => window.pendingReads.length), 0); passed('all controlled reads settled');
    assert.equal(errors.length, 0); assert.equal(requests, 0); passed('zero page errors and HTTP requests');
    console.log(JSON.stringify({ browser: browser.version(), count: checks.length, checks, errors, requests }, null, 2));
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
