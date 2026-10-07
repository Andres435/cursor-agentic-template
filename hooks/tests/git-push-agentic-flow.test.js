#!/usr/bin/env node
"use strict";

/**
 * Tests for the git push gate (hooks/core/push-gate.js) through both IDE bridges.
 * Non-push commands must not spawn PowerShell. A push from a workflow clone whose
 * Assert-AgenticFlow fails must be denied, whichever Claude shell tool runs it.
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const HOOK = path.join(__dirname, "..", "..", "adapters", "cursor", "hooks", "git-push-agentic-flow.js");
const WORKFLOW_ROOT = path.resolve(__dirname, "..", "..");
const { pushDirs, workflowRoot } = require("../core/push-gate.js");

// A throwaway git repo that is not the workflow repo (stands in for a product repo).
const OTHER_REPO = fs.mkdtempSync(path.join(os.tmpdir(), "push-gate-"));
spawnSync("git", ["-C", OTHER_REPO, "init", "-q"]);

// The Claude adapter speaks PreToolUse; the Cursor one speaks beforeShellExecution.
const CLAUDE_HOOK = path.join(__dirname, "..", "..", "adapters", "claude", "hooks", "git-push-agentic-flow.js");

function runHook(inputObj, extraArgs, timeout) {
  const hook = inputObj.tool_input ? CLAUDE_HOOK : HOOK;
  const args = [hook].concat(extraArgs || []);
  const result = spawnSync(process.execPath, args, {
    input: JSON.stringify(inputObj),
    encoding: "utf8",
    timeout: timeout || 8000,
  });
  if (result.error) throw result.error;
  const out = String(result.stdout || "").trim();
  let json = null;
  if (out) {
    try {
      json = JSON.parse(out);
    } catch {
      json = null;
    }
  }
  return { status: result.status, json, stdout: out, stderr: result.stderr };
}

let passed = 0;
let failed = 0;

function test(name, fn) {
  try {
    fn();
    console.log("  ✓ " + name);
    passed++;
  } catch (err) {
    console.error("  ✗ " + name);
    console.error("    " + err.message);
    failed++;
  }
}

console.log("git-push-agentic-flow.js smoke tests");

test("allows git status (Cursor)", () => {
  const out = runHook({ command: "git status" });
  assert.strictEqual(out.json.permission, "allow");
});

test("allows git commit (Cursor) — push matcher only", () => {
  const out = runHook({ command: 'git commit -m "wip"' });
  assert.strictEqual(out.json.permission, "allow");
});

test("ignores git status (Claude PreToolUse)", () => {
  const out = runHook({
    tool_input: { command: "git status" },
    hook_event_name: "PreToolUse",
  });
  assert.strictEqual(out.stdout, "");
  assert.strictEqual(out.status, 0);
});

test("pushDirs ignores git push that is not a command", () => {
  assert.deepStrictEqual(pushDirs('echo "git push origin HEAD"', OTHER_REPO), []);
  assert.deepStrictEqual(pushDirs("git log --grep=push", OTHER_REPO), []);
});

test("pushDirs follows cd and git -C", () => {
  assert.deepStrictEqual(pushDirs("git push", OTHER_REPO), [OTHER_REPO]);
  assert.deepStrictEqual(pushDirs(`cd "${WORKFLOW_ROOT}" && git push`, OTHER_REPO), [WORKFLOW_ROOT]);
  assert.deepStrictEqual(pushDirs(`git -C "${WORKFLOW_ROOT}" push origin HEAD`, OTHER_REPO), [WORKFLOW_ROOT]);
});

test("workflowRoot recognises only the workflow clone", () => {
  assert.strictEqual(workflowRoot(OTHER_REPO), null);
  assert.strictEqual(workflowRoot(path.join(WORKFLOW_ROOT, "scripts")), WORKFLOW_ROOT);
});

test("allows a push from another repo without running the assert (Claude)", () => {
  const started = Date.now();
  const out = runHook({
    tool_input: { command: "git push origin HEAD" },
    hook_event_name: "PreToolUse",
    cwd: OTHER_REPO,
  });
  assert.strictEqual(out.stdout, "");
  assert.strictEqual(out.status, 0);
  assert.ok(Date.now() - started < 5000, "should not have spawned the PowerShell assert");
});

test("allows a push from another repo (Cursor)", () => {
  const out = runHook({ command: "git push", cwd: OTHER_REPO });
  assert.strictEqual(out.json.permission, "allow");
});

// A fake workflow clone whose Assert-AgenticFlow always fails, so a push from it must be
// denied. It lives under this repo's gitignored tmp/ because an application allowlist may
// only let .ps1 files run inside the repos (an os.tmpdir() script would be blocked, not failed).
const FAILING_PARENT = path.join(WORKFLOW_ROOT, "tmp", "hook-tests");
fs.mkdirSync(FAILING_PARENT, { recursive: true });
const FAILING_FLOW = fs.mkdtempSync(path.join(FAILING_PARENT, "failing-flow-"));
spawnSync("git", ["-C", FAILING_FLOW, "init", "-q"]);
fs.mkdirSync(path.join(FAILING_FLOW, ".claude-plugin"), { recursive: true });
fs.writeFileSync(path.join(FAILING_FLOW, ".claude-plugin", "plugin.json"), "{}\n");
fs.mkdirSync(path.join(FAILING_FLOW, "scripts", "ticket"), { recursive: true });
fs.writeFileSync(
  path.join(FAILING_FLOW, "scripts", "ticket", "Assert-AgenticFlow.ps1"),
  "param([string]$Root)\nWrite-Output '[FAIL] Agentic flow: 1 violation(s): fixture-violation'\nexit 1\n"
);
const HAS_PWSH = !spawnSync("pwsh", ["-NoProfile", "-Command", "exit 0"], { timeout: 15000 }).error;

function testNeedsPwsh(name, fn) {
  if (HAS_PWSH) return test(name, fn);
  console.log("  - " + name + " (skipped: no pwsh on PATH)");
}

test("failsClosed is true only for a push from a workflow clone", () => {
  const { failsClosed } = require("../core/push-gate.js");
  assert.strictEqual(failsClosed("git push", FAILING_FLOW), true);
  assert.strictEqual(failsClosed("git push", OTHER_REPO), false);
  assert.strictEqual(failsClosed("git status", FAILING_FLOW), false);
});

testNeedsPwsh("denies a Cursor push from a clone whose assert fails", () => {
  const out = runHook({ command: "git push origin HEAD", cwd: FAILING_FLOW }, [], 60000);
  assert.strictEqual(out.json && out.json.permission, "deny", "expected deny, got: " + out.stdout);
  assert.match(out.json.user_message, /agentic-flow/i);
  assert.match(out.json.user_message, /fixture-violation/);
});

testNeedsPwsh("denies a Claude Bash-tool push from that clone", () => {
  const out = runHook(
    { tool_name: "Bash", tool_input: { command: "git push" }, hook_event_name: "PreToolUse", cwd: FAILING_FLOW },
    [],
    60000
  );
  assert.strictEqual(out.json && out.json.hookSpecificOutput.permissionDecision, "deny", "got: " + out.stdout);
});

testNeedsPwsh("denies a Claude PowerShell-tool push (Set-Location; git push) from that clone", () => {
  const out = runHook(
    {
      tool_name: "PowerShell",
      tool_input: { command: `Set-Location -LiteralPath "${FAILING_FLOW}"; git push origin HEAD` },
      hook_event_name: "PreToolUse",
      cwd: OTHER_REPO,
    },
    [],
    60000
  );
  assert.strictEqual(out.json && out.json.hookSpecificOutput.permissionDecision, "deny", "got: " + out.stdout);
  assert.match(out.json.hookSpecificOutput.permissionDecisionReason, /fixture-violation/);
});

test("Claude hooks.json routes PowerShell-tool commands to both git hooks", () => {
  const cfg = JSON.parse(
    fs.readFileSync(path.join(WORKFLOW_ROOT, "adapters", "claude", "hooks", "hooks.json"), "utf8")
  );
  const groups = cfg.hooks.PreToolUse.filter((g) => new RegExp("^(?:" + g.matcher + ")$").test("PowerShell"));
  const commands = groups.flatMap((g) => g.hooks.map((h) => h.command));
  assert.strictEqual(commands.length, 1, "one node process per shell call, got: " + commands.join(", "));
  assert.match(commands[0], /git-guard\.js/);
});

testNeedsPwsh("git-guard: a commit question does not hide a push deny in the same command", () => {
  const { decide } = require(path.join(WORKFLOW_ROOT, "adapters", "claude", "hooks", "git-guard.js"));
  const out = decide({
    tool_name: "Bash",
    tool_input: { command: 'git commit -m "no ticket" && git push' },
    cwd: FAILING_FLOW,
  });
  assert.strictEqual(out && out.hookSpecificOutput.permissionDecision, "deny");
  assert.match(out.hookSpecificOutput.permissionDecisionReason, /fixture-violation/);
});

test("git-guard: a command without git exits without running either guard", () => {
  const { decide } = require(path.join(WORKFLOW_ROOT, "adapters", "claude", "hooks", "git-guard.js"));
  assert.strictEqual(decide({ tool_name: "PowerShell", tool_input: { command: "Get-ChildItem" }, cwd: FAILING_FLOW }), null);
});

test("Cursor matchers fire for git -C and git -c forms", () => {
  const cfg = JSON.parse(fs.readFileSync(path.join(WORKFLOW_ROOT, "hooks.json"), "utf8"));
  const byScript = (name) => cfg.hooks.beforeShellExecution.find((h) => h.command.includes(name)).matcher;
  const push = new RegExp(byScript("git-push-agentic-flow.js"));
  const commit = new RegExp(byScript("git-commit-ticket.js"));
  assert.ok(push.test('git -C "C:\\repos\\workflow" push origin HEAD'));
  assert.ok(push.test("git -c core.sshCommand=ssh push"));
  assert.ok(commit.test('git -C x commit -m "y"'));
  assert.ok(!push.test("git status"));
});

// A product repo on a ticket branch. Its manifest lives in this clone's plans/ (user-local,
// gitignored), the way a real ticket's does; the test removes it afterwards.
// Ticket ids come from profile.json ticketPrefix, as the gate reads them.
const TICKET = (() => {
  try {
    return String(JSON.parse(fs.readFileSync(path.join(WORKFLOW_ROOT, "profile.json"), "utf8")).ticketPrefix || "TICKET-");
  } catch {
    return "TICKET-";
  }
})() + "99997";
const TICKET_REPO = fs.mkdtempSync(path.join(os.tmpdir(), "push-ticket-"));
spawnSync("git", ["-C", TICKET_REPO, "init", "-q", "-b", TICKET]);
spawnSync("git", ["-C", TICKET_REPO, "-c", "user.email=t@example.com", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "init"]);
const TICKET_MANIFEST = path.join(WORKFLOW_ROOT, "plans", TICKET + "-manifest.json");

test("allows a ticket-branch push when the ticket has no manifest here", () => {
  const out = runHook({ command: "git push", cwd: TICKET_REPO });
  assert.strictEqual(out.json.permission, "allow");
});

testNeedsPwsh("denies a ticket-branch push whose work has no verify receipt (prepush)", () => {
  fs.writeFileSync(
    TICKET_MANIFEST,
    JSON.stringify({ mode: "branch", workType: "bug", affectedRepos: [{ repo: "app", local: true, path: TICKET_REPO }] })
  );
  try {
    const out = runHook(
      { tool_name: "PowerShell", tool_input: { command: "git push -u origin " + TICKET }, hook_event_name: "PreToolUse", cwd: TICKET_REPO },
      [],
      60000
    );
    const h = out.json && out.json.hookSpecificOutput;
    assert.strictEqual(h && h.permissionDecision, "deny", "got: " + out.stdout);
    assert.ok(h.permissionDecisionReason.includes(TICKET + " is not ready to leave this machine"), h.permissionDecisionReason);
    assert.match(h.permissionDecisionReason, /no verify results/);
  } finally {
    fs.rmSync(TICKET_MANIFEST, { force: true });
  }
});

fs.rmSync(OTHER_REPO, { recursive: true, force: true });
fs.rmSync(FAILING_FLOW, { recursive: true, force: true });
fs.rmSync(TICKET_REPO, { recursive: true, force: true });

console.log("\n" + passed + " passed, " + failed + " failed");
process.exit(failed ? 1 : 0);
