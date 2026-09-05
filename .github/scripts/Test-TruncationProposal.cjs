// Experimental integrity model only. No production imports, file discovery or token calculation.
const assert = require('node:assert/strict');
const { createHash } = require('node:crypto');
const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const decoder = () => new TextDecoder('utf-8', { fatal: true });
const bytes = text => Buffer.from(text, 'utf8');
const row = n => JSON.stringify({ type: 'event_msg', payload: { type: 'token_count', info: { total_token_usage: { total_tokens: n } } } });
const schemaSupported = record => record && !Array.isArray(record) &&
  record.type === 'event_msg' && record.payload?.type === 'token_count' &&
  Number.isSafeInteger(record.payload.info?.total_token_usage?.total_tokens) &&
  record.payload.info.total_token_usage.total_tokens >= 0;

function inspect(input) {
  // Split raw bytes first: a UTF-8 character may itself be only partially written.
  const lines = []; let start = 0;
  for (let i = 0; i < input.length; i++) {
    if (input[i] === 10) { lines.push({ raw: input.subarray(start, i), terminated: true }); start = i + 1; }
  }
  if (start < input.length) lines.push({ raw: input.subarray(start), terminated: false });
  const nonempty = lines.map((line, index) => ({ ...line, index }))
    .filter(line => !line.raw.every(b => [9, 13, 32].includes(b)));
  const issues = []; let recognizedRecords = 0;
  for (const line of nonempty) {
    let record;
    try { record = JSON.parse(decoder().decode(line.raw)); }
    catch {
      const historical = nonempty.some(next => next.index > line.index);
      issues.push({ line: line.index + 1, kind: historical ? 'history_invalid' :
        line.terminated ? 'terminated_invalid' : 'tail_unresolved' });
      continue;
    }
    if (!schemaSupported(record)) issues.push({ line: line.index + 1, kind: 'format_unsupported' });
    else recognizedRecords++;
  }
  const status = !nonempty.length ? 'empty' : issues.some(i => i.kind === 'history_invalid') ? 'history_invalid' :
    issues.some(i => i.kind === 'format_unsupported') ? 'format_unsupported' :
    issues.some(i => i.kind === 'terminated_invalid') ? 'terminated_invalid' :
    issues.length ? 'tail_unresolved' : 'records_valid';
  return { status, issues, recognizedRecords, eligibleForAnalysis: status === 'records_valid',
    // A valid syntax snapshot still has not been assessed by the real analyzer.
    completeAssessment: false, missingTokens: issues.length ? null : undefined };
}

function snapshot(input, options = {}) {
  return { input, task: options.task || 'fictional-task-a', segment: options.segment || 'segment-a',
    parser: options.parser || 'proposal-1', modified: options.modified || 1,
    fingerprint: hash(input), assessment: inspect(input) };
}
function compare(previous, next) {
  const sameScope = previous.task === next.task && previous.segment === next.segment;
  const sameVersion = previous.parser === next.parser;
  const sameContent = previous.fingerprint === next.fingerprint;
  const prefix = next.input.length >= previous.input.length && next.input.subarray(0, previous.input.length).equals(previous.input);
  const cache = sameScope && sameVersion && sameContent ? 'reuse_snapshot' : 'invalidate';
  let transition = 'new_snapshot';
  if (!sameScope) transition = 'different_source';
  else if (!prefix) transition = 'rewritten';
  else if (sameContent) transition = previous.assessment.status === 'tail_unresolved' ? 'still_unresolved' : 'unchanged';
  else if (previous.assessment.status === 'tail_unresolved' && next.assessment.status === 'records_valid') transition = 'tail_completed';
  else if (next.assessment.status === 'tail_unresolved') transition = 'still_unresolved';
  return { transition, cache, writerLiveness: 'unknown', recompute: cache === 'invalidate' };
}

const results = [];
function test(name, fn) { fn(); results.push({ name, result: 'PASS' }); }
const valid = bytes(row(100));
const cut = valid.subarray(0, valid.length - 2);
function state(name, input, expected) {
  test(name, () => {
    const result = inspect(input); assert.equal(result.status, expected);
    assert.equal(result.eligibleForAnalysis, expected === 'records_valid');
    assert.equal(result.completeAssessment, false);
    if (result.issues.length) assert.equal(result.missingTokens, null);
  });
}
state('valid_without_final_newline', valid, 'records_valid');
state('valid_lf', bytes(row(100) + '\n'), 'records_valid');
state('valid_crlf', bytes(row(100) + '\r\n'), 'records_valid');
state('empty', bytes(''), 'empty');
state('blank_only', bytes(' \r\n\t'), 'empty');
state('tail_cut', cut, 'tail_unresolved');
state('terminated_cut', Buffer.concat([cut, bytes('\n')]), 'terminated_invalid');
state('middle_damage', Buffer.concat([cut, bytes('\n'), valid]), 'history_invalid');
state('damage_then_blank_lines', Buffer.concat([cut, bytes('\n\n')]), 'terminated_invalid');
state('valid_json_wrong_schema', bytes('{"unrelated":true}'), 'format_unsupported');
state('valid_json_null', bytes('null'), 'format_unsupported');
state('valid_json_array', bytes('[]'), 'format_unsupported');
state('invalid_complete_syntax_without_newline', bytes('{wrong}'), 'tail_unresolved');
test('tail_completion', () => {
  const r = compare(snapshot(cut), snapshot(valid));
  assert.deepEqual(r, { transition: 'tail_completed', cache: 'invalidate', writerLiveness: 'unknown', recompute: true });
});
test('unchanged_cut_is_not_proof_of_corruption', () => {
  const r = compare(snapshot(cut), snapshot(cut, { modified: 999 }));
  assert.equal(r.transition, 'still_unresolved'); assert.equal(r.cache, 'reuse_snapshot');
  assert.equal(snapshot(cut).assessment.eligibleForAnalysis, false);
});
test('growth_without_completion', () => {
  const r = compare(snapshot(cut.subarray(0, cut.length - 5)), snapshot(cut));
  assert.equal(r.transition, 'still_unresolved'); assert.equal(r.cache, 'invalidate');
});
test('same_size_and_time_rewrite', () => {
  const replaced = bytes(row(200)); assert.equal(replaced.length, valid.length);
  const r = compare(snapshot(valid), snapshot(replaced));
  assert.equal(r.transition, 'rewritten'); assert.equal(r.cache, 'invalidate');
});
test('shorter_file', () => assert.equal(compare(snapshot(valid), snapshot(cut)).transition, 'rewritten'));
test('parser_version_invalidates_cache', () => assert.equal(compare(snapshot(valid), snapshot(valid, { parser: 'proposal-2' })).cache, 'invalidate'));
test('same_bytes_different_task', () => assert.equal(compare(snapshot(valid), snapshot(valid, { task: 'fictional-task-b' })).transition, 'different_source'));
test('same_bytes_different_segment', () => assert.equal(compare(snapshot(valid), snapshot(valid, { segment: 'segment-b' })).cache, 'invalidate'));
test('mtime_only_change_is_not_content_change', () => assert.equal(compare(snapshot(valid), snapshot(valid, { modified: 2 })).cache, 'reuse_snapshot'));
test('partial_utf8_character_then_completion', () => {
  const full = bytes(JSON.stringify({ type: 'event_msg', payload: { type: 'token_count', info: { total_token_usage: { total_tokens: 1 } }, note: '虚构' } }));
  const part = full.subarray(0, full.indexOf(bytes('虚')) + 1);
  assert.equal(inspect(part).status, 'tail_unresolved');
  assert.equal(compare(snapshot(part), snapshot(full)).transition, 'tail_completed');
});
test('invalid_utf8_in_history', () => {
  assert.equal(inspect(Buffer.concat([Buffer.from([0xff]), bytes('\n'), valid])).status, 'history_invalid');
});
test('line_numbers_and_partial_records', () => {
  const r = inspect(Buffer.concat([valid, bytes('\n\n'), cut]));
  assert.equal(r.issues[0].line, 3); assert.equal(r.recognizedRecords, 1); assert.equal(r.missingTokens, null);
});
test('old_segment_not_fixed_by_new_segment', () => {
  const segments = [snapshot(cut), snapshot(valid, { segment: 'segment-b' })];
  assert.equal(segments.every(s => s.assessment.eligibleForAnalysis), false);
});
test('independent_task_not_blocked', () => {
  const tasks = { a: [snapshot(cut)], b: [snapshot(valid, { task: 'fictional-task-b' })] };
  assert.equal(tasks.a.every(s => s.assessment.eligibleForAnalysis), false);
  assert.equal(tasks.b.every(s => s.assessment.eligibleForAnalysis), true);
});
test('completion_with_other_damage_is_not_success', () => {
  const r = compare(snapshot(cut), snapshot(Buffer.concat([valid, bytes('\n{wrong}\n')])));
  assert.notEqual(r.transition, 'tail_completed');
});
console.log(JSON.stringify({ model: 'experimental-only', synthetic: true, count: results.length, results }, null, 2));
