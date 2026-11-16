#!/usr/bin/env node
// Wake on pull request events without missing any across restarts.
//
//   pr-events.mjs mark <pr>   record the PR's current state as seen
//   pr-events.mjs wait <pr>   block until the PR differs from the recorded
//                              state, then record the new state and print
//                              what changed
//
// <pr> is a number, URL, or branch that `gh pr view` accepts.
// wait options:
//   --interval <seconds>      polling interval (default 30)
//   --idle-minutes <minutes>  report idle after this long without a change
//                             since the last recorded state (default 30)
//   --max-minutes <minutes>   return early so a harness with a command
//                             timeout can call wait again (default: none)
//
// The recorded state lives under the repository's common Git directory, so
// every worktree and every restarted session shares it. One wait runs per PR.
//
// Exit codes: 0 changed, 10 idle, 11 max time reached, 3 another wait is
// running for this PR, 2 usage, 1 error. Output is one JSON line.

import { execFileSync } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const QUERY = `query($owner:String!,$name:String!,$number:Int!){
  repository(owner:$owner,name:$name){
    pullRequest(number:$number){
      state headRefOid mergeable
      commits(last:1){nodes{commit{statusCheckRollup{contexts(first:100){nodes{
        __typename
        ... on CheckRun{id name status conclusion}
        ... on StatusContext{context state}
      }}}}}}
      reviews(last:100){nodes{id state updatedAt author{login}}}
      reviewThreads(first:100){nodes{id isResolved comments(first:50){totalCount nodes{updatedAt}}}}
      comments(last:100){nodes{id updatedAt author{login}}}
    }
  }
}`;

function out(obj, code) {
  process.stdout.write(JSON.stringify(obj) + "\n");
  process.exit(code);
}

function gh(args) {
  return execFileSync(process.env.BABYSIT_PR_GH || "gh", args, {
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
  });
}

function parseArgs(argv) {
  const [command, pr, ...rest] = argv;
  const opts = { interval: 30, idleMinutes: 30, maxMinutes: Infinity };
  for (let i = 0; i < rest.length; i += 2) {
    const value = Number(rest[i + 1]);
    if (!Number.isFinite(value) || value < 0) out({ event: "usage", error: `bad value for ${rest[i]}` }, 2);
    if (rest[i] === "--interval") opts.interval = value;
    else if (rest[i] === "--idle-minutes") opts.idleMinutes = value;
    else if (rest[i] === "--max-minutes") opts.maxMinutes = value;
    else out({ event: "usage", error: `unknown option ${rest[i]}` }, 2);
  }
  if (!["mark", "wait"].includes(command) || !pr) {
    out({ event: "usage", error: "usage: pr-events.mjs mark|wait <pr> [options]" }, 2);
  }
  return { command, pr, opts };
}

function resolvePr(pr) {
  const { url } = JSON.parse(gh(["pr", "view", pr, "--json", "url"]));
  const m = url.match(/github\.com\/([^/]+)\/([^/]+)\/pull\/(\d+)/);
  if (!m) throw new Error(`cannot parse PR URL ${url}`);
  return { owner: m[1], name: m[2], number: Number(m[3]), url };
}

function stateDir() {
  if (process.env.BABYSIT_PR_STATE_DIR) return process.env.BABYSIT_PR_STATE_DIR;
  const common = execFileSync("git", ["rev-parse", "--path-format=absolute", "--git-common-dir"], {
    encoding: "utf8",
  }).trim();
  return path.join(common, "babysit-pr");
}

// Reduce the PR to the facts whose change should wake the agent. A check that
// moves from queued to in progress is not an event; its completion is.
function snapshot(ref) {
  const raw = JSON.parse(
    gh([
      "api", "graphql",
      "-f", `query=${QUERY}`,
      "-f", `owner=${ref.owner}`,
      "-f", `name=${ref.name}`,
      "-F", `number=${ref.number}`,
    ]),
  );
  const p = raw.data.repository.pullRequest;
  const checks = {};
  const contexts = p.commits.nodes[0]?.commit.statusCheckRollup?.contexts.nodes ?? [];
  for (const c of contexts) {
    // Two workflows may run checks with the same name; keep each one.
    let key = c.__typename === "CheckRun" ? c.name : c.context;
    for (let n = 2; key in checks; n += 1) key = `${c.__typename === "CheckRun" ? c.name : c.context} #${n}`;
    // A rerun is a new check run with its own id, so a rerun that ends as the
    // last one did still differs from the recorded state.
    if (c.__typename !== "CheckRun") checks[key] = c.state;
    else if (c.status !== "COMPLETED") checks[key] = "PENDING";
    else checks[key] = c.id ? `${c.conclusion}@${c.id}` : c.conclusion;
  }
  const threads = {};
  // A thread changes when it is resolved, answered, or one of its comments is edited.
  for (const t of p.reviewThreads.nodes) {
    const edited = (t.comments.nodes ?? []).map((c) => c.updatedAt).sort().pop() ?? "";
    threads[t.id] = `${t.isResolved ? "resolved" : "open"}:${t.comments.totalCount}:${edited}`;
  }
  const reviews = {};
  for (const r of p.reviews.nodes) reviews[r.id] = `${r.author?.login ?? "ghost"}:${r.state}:${r.updatedAt ?? ""}`;
  const comments = {};
  for (const c of p.comments.nodes) comments[c.id] = `${c.author?.login ?? "ghost"}:${c.updatedAt}`;
  return { state: p.state, head: p.headRefOid, mergeable: p.mergeable, checks, reviews, threads, comments };
}

// A check that starts or restarts, or mergeability GitHub has not computed
// yet, is not an event: the result that follows is. Leaving them out of the
// diff keeps the recorded state, so that result still differs from it.
function diff(before, after) {
  const changes = [];
  for (const key of ["state", "head", "mergeable"]) {
    if (key === "mergeable" && after[key] === "UNKNOWN") continue;
    if (before[key] !== after[key]) changes.push({ kind: key, from: before[key], to: after[key] });
  }
  const maps = { checks: "check", reviews: "review", threads: "thread", comments: "comment" };
  for (const [key, kind] of Object.entries(maps)) {
    const a = before[key] ?? {};
    const b = after[key] ?? {};
    for (const id of Object.keys(b)) {
      if (kind === "check" && ["PENDING", "EXPECTED"].includes(b[id])) continue;
      if (!(id in a)) changes.push({ kind, id, change: "added", to: b[id] });
      else if (a[id] !== b[id]) changes.push({ kind, id, change: "updated", from: a[id], to: b[id] });
    }
    for (const id of Object.keys(a)) if (!(id in b)) changes.push({ kind, id, change: "removed", from: a[id] });
  }
  return changes;
}

function save(file, snap) {
  const tmp = `${file}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify({ markedAt: Date.now(), snapshot: snap }));
  fs.renameSync(tmp, file);
}

function alive(pid) {
  try {
    process.kill(pid, 0);
    return true;
  } catch (e) {
    return e.code === "EPERM";
  }
}

function lock(file) {
  try {
    fs.writeFileSync(file, String(process.pid), { flag: "wx" });
  } catch (e) {
    if (e.code !== "EEXIST") throw e;
    const pid = Number(fs.readFileSync(file, "utf8"));
    if (pid && pid !== process.pid && alive(pid)) out({ event: "busy", pid }, 3);
    fs.writeFileSync(file, String(process.pid));
  }
  const release = () => {
    try {
      if (Number(fs.readFileSync(file, "utf8")) === process.pid) fs.unlinkSync(file);
    } catch {}
  };
  process.on("exit", release);
  for (const sig of ["SIGINT", "SIGTERM", "SIGHUP"]) process.on(sig, () => process.exit(130));
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  const { command, pr, opts } = parseArgs(process.argv.slice(2));
  const ref = resolvePr(pr);
  const dir = stateDir();
  fs.mkdirSync(dir, { recursive: true });
  const key = `${ref.owner}__${ref.name}__${ref.number}`;
  const file = path.join(dir, `${key}.json`);

  if (command === "mark") {
    const snap = snapshot(ref);
    save(file, snap);
    out({ event: "marked", pr: ref.url, head: snap.head, state: snap.state }, 0);
  }

  lock(path.join(dir, `${key}.lock`));
  let recorded = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
  if (!recorded) {
    save(file, snapshot(ref));
    recorded = JSON.parse(fs.readFileSync(file, "utf8"));
  }
  const started = Date.now();
  let failures = 0;
  for (;;) {
    let snap;
    try {
      snap = snapshot(ref);
      failures = 0;
    } catch (e) {
      failures += 1;
      if (failures >= 5) out({ event: "error", pr: ref.url, error: String(e.stderr || e.message).trim() }, 1);
    }
    if (snap) {
      const changes = diff(recorded.snapshot, snap);
      if (changes.length) {
        save(file, snap);
        out({ event: "changed", pr: ref.url, head: snap.head, state: snap.state, changes }, 0);
      }
    }
    const now = Date.now();
    if (now - recorded.markedAt >= opts.idleMinutes * 60_000) {
      out({ event: "idle", pr: ref.url, minutes: opts.idleMinutes }, 10);
    }
    if (now - started >= opts.maxMinutes * 60_000) out({ event: "retry", pr: ref.url }, 11);
    await sleep(opts.interval * 1000);
  }
}

main().catch((e) => out({ event: "error", error: String(e.stderr || e.message).trim() }, 1));
