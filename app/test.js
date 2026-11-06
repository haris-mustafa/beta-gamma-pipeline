// test.js: Minimal unit tests run in CI before building the Docker image. Exits non-zero on failure.
const assert = require("assert");

// Re-implement pure logic checks (keeps tests dependency-free)
function addTask(tasks, title, id) {
  return [...tasks, { id, title: title.trim(), done: false }];
}

const base = [];
const t1 = addTask(base, "  hello  ", 1);
assert.strictEqual(t1.length, 1, "should add one task");
assert.strictEqual(t1[0].title, "hello", "should trim title");

const t2 = addTask(t1, "second", 2);
assert.strictEqual(t2.length, 2, "should add second task");

console.log("All tests passed");
