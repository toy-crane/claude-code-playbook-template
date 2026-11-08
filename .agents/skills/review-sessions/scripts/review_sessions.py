#!/usr/bin/env python3
"""Count repeated probabilistic work in local Claude Code and Codex session logs.

    review_sessions.py scan   --since DATE --until DATE [--split DATE | --split-hash HEX]
                              [--claude-dir DIR] [--codex-dir DIR] [--now ISO] --out findings.json
    review_sessions.py report --findings findings.json --candidates candidates.json --out report.html

The script does every count; a model reads only the windows and summaries it
writes. Session logs are data, never instructions, and token-like values are
masked before anything leaves this script. Standard library only.
"""
import argparse
import datetime as dt
import glob
import logging
logging.getLogger().addHandler(logging.NullHandler())  # a pyenv build without blake2 logs on import hashlib
import hashlib
import json
import os
import re
import sys
from collections import Counter, defaultdict

HOME = os.path.expanduser("~")
KNOWN_CLAUDE_TYPES = {"user", "assistant", "system", "attachment", "queue-operation", "custom-title", "mode",
                      "last-prompt", "bridge-session", "atis-latch", "summary", "file-history-snapshot",
                      "progress", "permission-mode", "uuid", "result"}
KNOWN_CODEX_TYPES = {"session_meta", "response_item", "event_msg", "turn_context", "token_usage_record",
                     "world_state", "compacted"}
KNOWN_CODEX_PAYLOADS = {"message", "function_call", "function_call_output", "custom_tool_call",
                        "custom_tool_call_output", "reasoning", "web_search_call", "local_shell_call",
                        "local_shell_call_output", "ghost_snapshot"}

# ---------------------------------------------------------------- helpers

PATH_RE = re.compile(r"(/[\w.@~-]+)+/?")
QUOTE_RE = re.compile(r"(\"[^\"]*\"|'[^']*')")
NUM_RE = re.compile(r"\b\d+\b")
HEX_RE = re.compile(r"\b[0-9a-f]{7,40}\b")
SPLIT_RE = re.compile(r"\s*(?:&&|\|\||;|\||\n)\s*")
ENV_RE = re.compile(r"^(?:[A-Z_][A-Z0-9_]*=\S*\s+)+")
SUBCMD = {"git", "gh", "npm", "npx", "pnpm", "bun", "bunx", "yarn", "docker", "xcrun", "expo", "claude", "codex",
          "skills", "cargo", "go", "python3", "python", "pip", "uv", "supabase", "vercel", "eas", "brew", "tmux",
          "agent-device", "adb", "xcodebuild", "simctl", "node", "swift", "pod"}
CORRECTION_RE = re.compile(r"(아니[,. ]|아니야|아냐|아닌데|그게 아니|틀렸|잘못|하지 ?마|말고|되돌|롤백|revert|undo|"
                           r"\bwrong\b|\bstop\b|다시 해|다시해|원래대로|왜 .*(했|한|하는)|안 (했|됐|돼|되))")
INTERRUPT_PREFIX = "[Request interrupted by user"


def parse_ts(value):
    if not value:
        return None
    try:
        return dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def iso_date(value):
    return dt.datetime.fromisoformat(value + ("T00:00:00+00:00" if len(value) == 10 else "")).astimezone(dt.timezone.utc)


def norm_cmd(cmd):
    """Return (heads, normalized) for one shell command string."""
    if not isinstance(cmd, str):
        return [], ""
    heads = []
    for seg in SPLIT_RE.split(cmd.strip()):
        seg = ENV_RE.sub("", seg.strip())
        toks = seg.split()
        while toks and toks[0] in ("sudo", "command", "timeout", "nohup", "time", "exec", "nice", "caffeinate"):
            toks = toks[1:]
            if toks and toks[0].isdigit():
                toks = toks[1:]
        if not toks:
            continue
        t0 = os.path.basename(toks[0]) if toks[0].startswith(("/", "./")) else toks[0]
        if t0 in SUBCMD and len(toks) > 1 and not toks[1].startswith("-"):
            heads.append(f"{t0} {toks[1]}")
        else:
            heads.append(t0)
    full = QUOTE_RE.sub("<q>", cmd)
    full = PATH_RE.sub("<p>", full)
    full = HEX_RE.sub("<h>", full)
    full = NUM_RE.sub("<n>", full)
    return heads, re.sub(r"\s+", " ", full).strip()[:200]


def command_segments(cmd):
    """Each executed segment with its quoted arguments blanked, so text an agent merely
    searches or prints (rg 'sleep|gh pr create') never reads as an executed command."""
    if not isinstance(cmd, str):
        return []
    segs = []
    for seg in SPLIT_RE.split(QUOTE_RE.sub("<q>", cmd.strip())):
        seg = ENV_RE.sub("", seg.strip())
        toks = seg.split()
        while toks and toks[0] in ("sudo", "command", "timeout", "nohup", "time", "exec", "nice", "caffeinate", "do", "then", "else"):
            toks = toks[1:]
            if toks and toks[0].isdigit():
                toks = toks[1:]
        if toks:
            segs.append(" ".join(toks))
    return segs


_REPO_ROOT_CACHE = {}


def repo_root(path):
    """The nearest ancestor holding a .git directory or file, or the path itself when none exists on disk."""
    if path in _REPO_ROOT_CACHE:
        return _REPO_ROOT_CACHE[path]
    root = path
    cur = path
    while cur and cur != os.path.dirname(cur):
        dot_git = os.path.join(cur, ".git")
        if os.path.exists(dot_git):
            root = cur
            if os.path.isfile(dot_git):
                # A linked worktree: ".git" is a file pointing at <common>/.git/worktrees/<name>
                try:
                    with open(dot_git) as f:
                        pointer = f.read().strip()
                except OSError:
                    pointer = ""
                m = re.match(r"gitdir:\s*(.+?)/\.git/worktrees/[^/]+/?$", pointer)
                if m:
                    root = os.path.normpath(os.path.join(cur, m.group(1))) if not os.path.isabs(m.group(1)) else m.group(1)
            break
        cur = os.path.dirname(cur)
    _REPO_ROOT_CACHE[path] = root
    return root


def repo_of(cwd):
    if not cwd:
        return ""
    for pat in (r"(.*?)/\.claude/worktrees/", r"(.*?)/\.codex-workspaces/worktrees/[^/]+/([^/]+)",
                r"(.*?)/\.codex/worktrees/[^/]+/([^/]+)"):
        m = re.match(pat, cwd)
        if m:
            return m.group(1) if m.lastindex == 1 else f"{HOME}/code/{m.group(2)}"
    return repo_root(cwd)


def is_eval_cwd(cwd):
    """Eval and scratch runs live in temporary locations: macOS /private and /var, Linux /tmp."""
    return not cwd or cwd.startswith(("/private/", "/var/", "/tmp/")) or "/T/" in cwd


def user_text(content):
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        return "\n".join(b.get("text", "") for b in content
                         if isinstance(b, dict) and b.get("type") in ("text", "input_text"))
    return ""


def err_key(text):
    t = re.sub(r"\s+", " ", text or "")[:400]
    t = PATH_RE.sub("<p>", t)
    t = NUM_RE.sub("<n>", t)
    t = HEX_RE.sub("<h>", t)
    return t[:120]


def error_headline(text, limit=100):
    """The first two non-empty lines of an error, normalized and capped: the headline a
    reader needs, without the body where tool output may echo personal details."""
    lines = [l.strip() for l in (text or "").splitlines() if l.strip()][:2]
    return err_key(" ".join(lines))[:limit]


SECRET_RES = [
    (re.compile(r"(--token[= ]+)(\"[^\"]*\"|'[^']*'|\S+)"), r"\1<token>"),
    (re.compile(r"(--expected[= ]+)(\"[^\"]*\"|'[^']*'|\S+)"), r"\1<hex>"),
    (re.compile(r"(\b[\w.-]*(?:token|secret|password|passwd|api[_-]?key|authorization|credential|private[_-]?key)[\w.-]*[\"']?\s*[=:]\s*)(\"[^\"]*\"|'[^']*'|\S+)", re.I), r"\1<token>"),
    (re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b"), "<jwt>"),
    (re.compile(r"(://[^/\s:@]+:)[^@\s]+@"), r"\1<password>@"),
    (re.compile(r"\bBearer\s+\S+"), "Bearer <token>"),
    (re.compile(r"\b(?:sk|ghp|gho|ghu|ghs|xoxb|xoxp|lin_api)[-_][A-Za-z0-9_-]{8,}"), "<secret>"),
    (re.compile(r"\b[0-9a-f]{32,}\b"), "<hex>"),
    (re.compile(r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"), "<email>"),
    (re.compile(r"(?<![\w/.-])\+?\d{1,3}[ -]?\(?\d{2,4}\)?[ -]\d{3,4}[ -]\d{4}\b"), "<phone>"),
    (re.compile(r"\b01\d-?\d{3,4}-?\d{4}\b"), "<phone>"),
]


def redact(text):
    """Mask token-like values so no secret leaves the script."""
    for rx, rep in SECRET_RES:
        text = rx.sub(rep, text)
    return text


def event_line(e):
    if e["k"] == "tool":
        body = e.get("raw") or e.get("file") or e.get("skill") or ""
        return f"TOOL {e['name']} {body}"
    if e["k"] == "err":
        # The normalized key (paths, numbers, hashes blanked, 120 chars) rather than the
        # raw message: tool output can echo names or addresses that no mask recognizes.
        return f"ERR {e.get('tool', '?')} {error_headline(e.get('text', ''))}"
    if e["k"] == "user":
        # A person's words can carry names, numbers, or addresses no regex catches; the
        # window keeps only that a turn happened, its length, and its markers.
        marks = [m for m, on in (("중단", e.get("interrupt")), ("교정 표지", e.get("corr"))) if on]
        return f"USER (발화 {e.get('len', 0)}자{', ' + ', '.join(marks) if marks else ''})"
    return e["k"]


def window(session, index, radius=6):
    lo, hi = max(0, index - radius), min(len(session.events), index + radius + 1)
    lines = [redact(re.sub(r"\s+", " ", event_line(e)))[:240] for e in session.events[lo:hi] if not e.get("side")]
    return {"session": redact(session.label), "kind": session.kind, "lines": lines}


# ---------------------------------------------------------------- sessions

class Session:
    def __init__(self, harness, path):
        self.harness = harness
        self.path = path
        self.id = os.path.basename(path).replace(".jsonl", "")
        self.events = []
        self.cwd = None
        self.start = None
        self.end = None
        self.n_user_text = 0
        self.first_prompt = None
        self.skills = {}          # name -> 16-hex prefix of sha256(loaded body), or "" when unknown
        self.thread_source = None
        self.originator = None
        self.unknown_records = []   # (type, timestamp) for records this script does not know
        self.has_sidechain = False

    def unknown_in(self, since=None, until=None):
        return Counter(typ for typ, ts in self.unknown_records if since is None or in_period(ts, since, until))

    @property
    def repo(self):
        return repo_of(self.cwd)

    @property
    def label(self):
        return f"{os.path.basename(self.repo)} {self.id[:8]}"

    @property
    def kind(self):
        fp = self.first_prompt or ""
        if "<scheduled-task" in fp:
            return "unattended"
        if re.search(r"/robo-", self.cwd or "") or fp.startswith("`triage-issues` Skill") or fp.startswith("`shape-idea` Skill로 이슈"):
            return "unattended"
        return "interactive"


def parse_claude(path):
    s = Session("claude", path)
    tool_names = {}
    with open(path, "r", errors="replace") as f:
        for line in f:
            if not line.startswith("{"):
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            typ = d.get("type")
            if typ not in KNOWN_CLAUDE_TYPES:
                s.unknown_records.append((str(typ), d.get("timestamp") or s.end))
                continue
            ts = d.get("timestamp") or s.end
            if ts:
                s.start = s.start or ts
                s.end = ts
            if s.cwd is None and d.get("cwd"):
                s.cwd = d["cwd"]
            side = bool(d.get("isSidechain"))
            if side:
                s.has_sidechain = True
            msg = d.get("message") or {}
            if typ == "user":
                content = msg.get("content")
                if isinstance(content, list) and content and isinstance(content[0], dict) and content[0].get("type") == "tool_result":
                    for b in content:
                        if not isinstance(b, dict) or b.get("type") != "tool_result":
                            continue
                        c = b.get("content")
                        if isinstance(c, list):
                            c = " ".join(x.get("text", "") for x in c if isinstance(x, dict))
                        c = c if isinstance(c, str) else json.dumps(c, ensure_ascii=False)[:400]
                        low = c[:300].lower()
                        denial = ("doesn't want to proceed" in low or "user rejected" in low or "interrupted by user" in low)
                        if b.get("is_error") or denial:
                            s.events.append({"k": "err", "t": ts, "tool": tool_names.get(b.get("tool_use_id"), "?"), "side": side,
                                             "denial": denial, "key": err_key(c), "text": c[:300]})
                    continue
                txt = user_text(content).strip()
                if d.get("isMeta"):
                    m = re.match(r"Base directory for this skill: \S*/([\w:-]+)\s*\n(.*)", txt, re.S)
                    if m:
                        s.skills[m.group(1)] = hashlib.sha256(m.group(2).strip().encode()).hexdigest()[:16]
                    continue
                if not txt:
                    continue
                m = re.search(r"<command-name>/?([\w:-]+)</command-name>", txt)
                if m:
                    s.skills.setdefault(m.group(1), "")
                    args = re.search(r"<command-args>(.*?)</command-args>", txt, re.S)
                    txt = "/" + m.group(1) + " " + (args.group(1).strip() if args else "")
                if txt.startswith(("<local-command-stdout>", "<command-message>")) or side:
                    continue
                s.n_user_text += 1
                s.first_prompt = s.first_prompt or txt[:300]
                s.events.append({"k": "user", "t": ts, "text": txt[:400], "corr": bool(CORRECTION_RE.search(txt[:400])),
                                 "interrupt": txt.startswith(INTERRUPT_PREFIX), "len": len(txt)})
            elif typ == "assistant":
                for b in msg.get("content") or []:
                    if not isinstance(b, dict) or b.get("type") != "tool_use":
                        continue
                    name = b.get("name")
                    inp = b.get("input") or {}
                    tool_names[b.get("id")] = name
                    ev = {"k": "tool", "t": ts, "name": name, "side": side}
                    if name == "Bash":
                        heads, full = norm_cmd(inp.get("command", ""))
                        ev.update(heads=heads, full=full, raw=(inp.get("command") or "")[:300],
                                  canon=re.sub(r"\s+", " ", (inp.get("command") or "").strip())[:1000])
                    elif name == "Skill":
                        s.skills.setdefault(inp.get("skill") or "?", "")
                        ev["skill"] = inp.get("skill")
                    elif name in ("Read", "Edit", "Write", "MultiEdit"):
                        ev["file"] = inp.get("file_path")
                    s.events.append(ev)
    return s


EXEC_CMD_RE = re.compile(r"exec_command\(\s*\{[^}]*?[\"']?cmd[\"']?\s*:\s*(\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'|`(?:[^`\\]|\\.)*`)", re.S)


def events_from_item(item, ts):
    """Events for a `codex review` run, which records items only as event_msg lines."""
    kind = item.get("type")
    if kind == "UserMessage":
        txt = " ".join(b.get("text", "") for b in item.get("content", []) if isinstance(b, dict)).strip()
        return [{"k": "user", "t": ts, "text": txt[:400], "corr": bool(CORRECTION_RE.search(txt[:400])),
                 "interrupt": False, "len": len(txt)}] if txt else []
    if kind != "CommandExecution":
        return []
    cmd = item.get("command")
    if isinstance(cmd, str) and cmd.startswith("["):
        m = re.search(r"'-l?c',\s*'(.*)'\]$", cmd, re.S)
        cmd = m.group(1) if m else cmd
    elif isinstance(cmd, list):
        cmd = cmd[-1] if len(cmd) >= 3 and str(cmd[1]).startswith("-") else " ".join(map(str, cmd))
    cmd = str(cmd or "")
    heads, full = norm_cmd(cmd)
    out = [{"k": "tool", "t": ts, "name": "Bash", "side": False, "heads": heads, "full": full, "raw": cmd[:300],
            "canon": re.sub(r"\s+", " ", cmd.strip())[:1000]}]
    code = item.get("exit_code")
    if code not in (None, 0) or item.get("status") == "failed":
        text = str(item.get("aggregated_output") or item.get("stderr") or f"exit code {code}")
        out.append({"k": "err", "t": ts, "tool": "Bash", "side": False, "denial": False, "key": err_key(text), "text": text[:300]})
    return out


def parse_codex(path):
    s = Session("codex", path)
    call_names = {}
    fallback = []
    with open(path, "r", errors="replace") as f:
        for line in f:
            if not line.startswith("{"):
                continue
            try:
                d = json.loads(line)
            except ValueError:
                continue
            typ = d.get("type")
            if typ not in KNOWN_CODEX_TYPES:
                s.unknown_records.append((str(typ), d.get("timestamp") or s.end))
                continue
            p = d.get("payload") or {}
            ts = d.get("timestamp") or s.end
            if ts:
                s.start = s.start or ts
                s.end = ts
            if typ == "session_meta":
                if p.get("id"):
                    s.id = str(p["id"])
                s.cwd = p.get("cwd")
                s.originator = p.get("originator")
                s.thread_source = p.get("thread_source")
                continue
            if typ == "event_msg":
                if p.get("type") == "item_completed":
                    fallback.extend(events_from_item(p.get("item") or {}, ts))
                continue
            if typ != "response_item":
                continue
            pt = p.get("type")
            if pt not in KNOWN_CODEX_PAYLOADS:
                s.unknown_records.append((str(pt), ts))
                continue
            if pt == "message":
                if p.get("role") != "user":
                    continue
                txt = user_text(p.get("content")).strip()
                if not txt or txt.startswith(("# AGENTS.md instructions", "<environment_context>", "<INSTRUCTIONS>", "<permissions", "<user_action>", "<turn_aborted>")):
                    continue
                s.n_user_text += 1
                s.first_prompt = s.first_prompt or txt[:300]
                for name in re.findall(r"\$([a-z][\w-]+)", txt):
                    s.skills.setdefault(name, "")
                s.events.append({"k": "user", "t": ts, "text": txt[:400], "corr": bool(CORRECTION_RE.search(txt[:400])),
                                 "interrupt": False, "len": len(txt)})
            elif pt in ("function_call", "custom_tool_call"):
                name = p.get("name")
                call_names[p.get("call_id")] = name
                cmds = []
                if pt == "custom_tool_call" and name == "exec":
                    src = p.get("input") or ""
                    cmds = [m.group(1)[1:-1] for m in EXEC_CMD_RE.finditer(src)]
                elif name in ("exec_command", "shell", "shell_command"):
                    try:
                        a = json.loads(p.get("arguments") or "{}")
                    except ValueError:
                        a = {}
                    c = a.get("cmd") or a.get("command") or ""
                    cmds = [" ".join(c) if isinstance(c, list) else c]
                if cmds:
                    for c in cmds:
                        heads, full = norm_cmd(c)
                        s.events.append({"k": "tool", "t": ts, "name": "Bash", "side": False, "heads": heads, "full": full, "raw": c[:300],
                                         "canon": re.sub(r"\s+", " ", c.strip())[:1000]})
                        m = re.search(r"skills/([\w-]+)/SKILL\.md", c)
                        if m:
                            s.skills.setdefault(m.group(1), "")
                else:
                    s.events.append({"k": "tool", "t": ts, "name": "codex:" + str(name), "side": False})
            elif pt in ("function_call_output", "custom_tool_call_output"):
                out = p.get("output")
                if isinstance(out, list):
                    out = " ".join(x.get("text", "") for x in out if isinstance(x, dict))
                out = out if isinstance(out, str) else json.dumps(out, ensure_ascii=False)[:400]
                code = None
                m = re.search(r"\"exit_code\"\s*:\s*(\d+)", out[:600])   # exec_command's structured result after "Output:"
                if m:
                    code = int(m.group(1))
                else:
                    m = re.search(r"exit code (\d+)|Script failed|Process exited with code (\d+)|exited with code (\d+)", out[:200])
                    if m:
                        g = [x for x in m.groups() if x]
                        code = int(g[0]) if g else 1
                if code not in (None, 0):
                    s.events.append({"k": "err", "t": ts, "tool": call_names.get(p.get("call_id"), "?"), "side": False,
                                     "denial": False, "key": err_key(out), "text": out[:300]})
    if fallback and not any(e["k"] == "tool" for e in s.events):
        s.events = fallback
        s.n_user_text = sum(1 for e in fallback if e["k"] == "user")
        s.first_prompt = next((e["text"][:300] for e in fallback if e["k"] == "user"), s.first_prompt)
    return s


def in_period(iso, since, until):
    ts = parse_ts(iso)
    return ts is not None and since <= ts < until


def load_sessions(claude_dir, codex_dir, since, until, now, min_age_minutes, select_by="activity"):
    """Sessions with activity in the period, their events trimmed to it.

    select_by="activity" keeps a session when any of its events falls in the
    period and counts only those events; select_by="mtime" keeps a session
    whose log file was modified in the period and counts every event, which is
    how the first research pass counted.
    """
    sessions, excluded = [], Counter()
    by_harness = {"claude": Counter(), "codex": Counter()}
    unknown = {"claude": Counter(), "codex": Counter()}
    cutoff = now - dt.timedelta(minutes=min_age_minutes)
    paths = [("claude", p) for p in glob.glob(os.path.join(claude_dir, "*", "*.jsonl"))]
    paths += [("codex", p) for p in glob.glob(os.path.join(codex_dir, "*", "*", "*", "*.jsonl"))]
    for harness, path in sorted(paths):
        mtime = dt.datetime.fromtimestamp(os.path.getmtime(path), dt.timezone.utc)
        if select_by == "mtime" and not (since <= mtime < until):
            continue
        if mtime > cutoff:
            excluded["in_progress"] += 1
            by_harness[harness]["in_progress"] += 1
            continue
        s = parse_claude(path) if harness == "claude" else parse_codex(path)
        if select_by == "activity":
            start, end = parse_ts(s.start), parse_ts(s.end)
            if start is None or end is None or end < since or start >= until:
                continue
            s.events = [e for e in s.events if in_period(e.get("t"), since, until)]
            s.n_user_text_in_period = sum(1 for e in s.events if e["k"] == "user")
            if not s.events:
                excluded["no_events_in_period"] += 1
                by_harness[harness]["no_events_in_period"] += 1
                continue
        unknown[harness].update(s.unknown_in(since, until) if select_by == "activity" else s.unknown_in())
        reason = None
        if is_eval_cwd(s.cwd):
            reason = "eval"
        elif s.harness == "codex" and s.thread_source == "subagent":
            reason = "subagent"
        elif s.n_user_text == 0:
            reason = "no_user_text"
        if reason:
            excluded[reason] += 1
            by_harness[harness][reason] += 1
            continue
        sessions.append(s)
    return sessions, excluded, by_harness, unknown


# ---------------------------------------------------------------- signals

def err_matches(e, *needles):
    t = e.get("text", "")
    return e["k"] == "err" and any(n in t for n in needles)


HELPER_RE = re.compile(r"^(?:cat\s*>\s*|tee\s+(?:-a\s+)?)(\S+\.(?:sh|py|mjs|js|ts))")   # applied per executed segment
DELEGATIONS = [  # command that a skill of this set owns -> the skill that should have been loaded
    ("delegation_pr", "gh pr create 실행, pr 미로드", r"gh pr create\b", ("pr",), None),
    ("delegation_merge", "gh pr merge 실행, merge 미로드", r"gh pr merge\b", ("merge",), None),
    ("delegation_pull", "merge 세션의 git rebase, pull 미로드", r"git rebase\b", ("pull",), "merge"),
    ("delegation_clean", "git worktree remove 실행, clean-branches·merge 미로드", r"git worktree remove\b", ("clean-branches", "merge"), None),
]


def is_bash(e, pattern):
    """True when one executed segment of a Bash call starts with the pattern."""
    if e["k"] != "tool" or e["name"] != "Bash":
        return False
    if "segs" not in e:
        e["segs"] = command_segments(e.get("raw", ""))
    return any(re.match(pattern, seg) for seg in e["segs"])


def user_after_error(s, i, e):
    if e["k"] != "err" or e.get("denial"):
        return False
    for nxt in s.events[i + 1:i + 4]:
        if nxt["k"] == "user" and not nxt.get("interrupt"):
            return True
        if nxt["k"] == "tool":
            return False
    return False


def retry_after_error(s, i, e):
    if e["k"] != "err" or i < 1 or i + 1 >= len(s.events):
        return False
    prev, nxt = s.events[i - 1], s.events[i + 1]
    return (prev["k"] == "tool" and nxt["k"] == "tool" and prev["name"] == "Bash" == nxt["name"]
            and bool(prev.get("canon")) and prev.get("canon") == nxt.get("canon"))


def helper_written(s, i, e):
    """A helper script written to a temporary place, judged from executed segments only."""
    if e["k"] != "tool":
        return False
    if e["name"] == "Write":
        paths = [e.get("file") or ""]
    elif e["name"] == "Bash":
        if "segs" not in e:
            e["segs"] = command_segments(e.get("raw", ""))
        paths = [m.group(1) for seg in e["segs"] for m in [HELPER_RE.match(seg)] if m]
    else:
        return False
    return any((path.startswith(("/tmp", "/private/tmp")) or "/scratchpad/" in path) and re.search(r"\.(sh|py|mjs|js|ts)$", path) for path in paths)


SIGNALS = [
    # id, label, bucket, predicate over (session, index, event)
    ("harness_sleep_tail", "sleep+tail 폴링을 하네스가 차단", "harness", lambda s, i, e: err_matches(e, "Blocked: sleep")),
    ("harness_edit_before_read", "Read 없이 Edit/Write", "harness", lambda s, i, e: err_matches(e, "has not been read yet")),
    ("harness_modified_since_read", "읽은 뒤 바뀐 파일 Edit", "harness", lambda s, i, e: err_matches(e, "modified since read")),
    ("zsh_glob", "zsh 글롭 no matches found", "harness", lambda s, i, e: err_matches(e, "no matches found")),
    ("relative_cd_failed", "cwd가 유지되는데 상대 경로 cd", "harness",
     lambda s, i, e: e["k"] == "err" and re.search(r"no such file or directory: (apps|src|docs|supabase|scripts|packages)", e.get("text", "")) is not None),
    ("gh_json_field", "gh --json 필드 추측", "harness", lambda s, i, e: err_matches(e, "Unknown JSON field")),
    ("review_not_invocable", "code-review 스킬을 모델이 못 부름", "harness", lambda s, i, e: err_matches(e, "disable-model-invocation")),
    ("guard_blocked", "워크트리 가드가 막은 명령", "candidate", lambda s, i, e: err_matches(e, "isolated in the worktree")),
    ("claim_usage_error", "claim.sh 인자 오용", "candidate",
     lambda s, i, e: e["k"] == "err" and re.search(r"triage claim: (missing value|issue has no claim)", e.get("text", "")) is not None),
    ("shell_cwd_lost", "워크트리 삭제 뒤 셸 위치 상실", "candidate", lambda s, i, e: err_matches(e, "was deleted; shell cwd recovered")),
    ("browser_friction", "브라우저 패널 미리보기 마찰", "candidate",
     lambda s, i, e: e["k"] == "err" and str(e.get("tool", "")).startswith("mcp__Claude_Browser__")),
    ("browser_nav_denied", "브라우저 탐색 거부·실패", "candidate",
     lambda s, i, e: err_matches(e, "denied or failed") and str(e.get("tool", "")).startswith("mcp__Claude_Browser__")),
    ("launch_json_missing", "launch.json 없음", "candidate", lambda s, i, e: err_matches(e, "No .claude") and "launch" in e.get("text", "")),
    ("polling_sleep", "sleep으로 기다림", "candidate", lambda s, i, e: is_bash(e, r"sleep\b")),
    ("device_press_sleep", "agent-device 조작 뒤 sleep", "candidate",
     lambda s, i, e: is_bash(e, r"(?:bunx?\s+(?:run\s+)?|npx\s+)?(?:\S*/)?agent-device\s+(?:press|tap|type|fill|swipe)\b") and is_bash(e, r"sleep\b")),
    ("helper_rebuilt", "임시 폴더에 보조 스크립트를 새로 씀", "candidate", helper_written),
    ("retry_after_error", "오류 직후 같은 명령 재실행", "candidate", retry_after_error),
    ("user_after_error", "오류 뒤 사람이 개입", "candidate", user_after_error),
    ("classifier_denied", "자동 모드 분류기 거부", "permission", lambda s, i, e: err_matches(e, "auto mode classifier")),
    ("user_rejected_tool", "사용자가 도구 실행을 거부", "judgment", lambda s, i, e: err_matches(e, "doesn't want to proceed")),
    ("user_interrupted", "사용자 중단", "judgment", lambda s, i, e: e["k"] == "user" and e.get("interrupt")),
    ("user_corrected", "강한 표지의 사용자 교정", "judgment",
     lambda s, i, e: e["k"] == "user" and e.get("corr") and not e.get("interrupt") and i > 0 and e.get("len", 0) <= 350),
]


def delegation_signals(sessions):
    """Sessions that ran a command one of this set's skills owns without loading that skill."""
    out = []
    for sid, label, pattern, skills, require in DELEGATIONS:
        hit, events, repos, unattended, examples = 0, 0, set(), 0, []
        sides = {k: {"sessions": 0, "events": 0} for k in ("before", "after", "unsplit")}
        for s in sessions:
            if require and require not in s.skills:
                continue
            n = sum(1 for e in s.events if not e.get("side") and is_bash(e, pattern))
            if not n or any(k in s.skills for k in skills):
                continue
            hit += 1
            events += n
            repos.add(s.repo)
            unattended += s.kind == "unattended"
            if len(examples) < 4:
                examples.append(redact(s.label))
            side = split_side(s, delegation_signals.split_date, delegation_signals.split_hash)
            sides[side]["sessions"] += 1
            sides[side]["events"] += n
        out.append({"id": sid, "label": label, "bucket": "candidate", "sessions": hit, "events": events, "repos": len(repos),
                    "unattended_sessions": unattended, "examples": examples, "windows": [],
                    "before": sides["before"], "after": sides["after"], "unsplit": sides["unsplit"]})
    return out


CANDIDATE_BUCKETS = {"candidate", "permission"}


def passes_threshold(sig, th):
    return (sig["bucket"] in CANDIDATE_BUCKETS and
            (sig["sessions"] >= th["sessions"] or sig["repos"] >= th["repos"] or sig["unattended_sessions"] >= th["unattended"]))


def split_side(session, split_date, split_hash):
    """Which side of the re-measurement line a session falls on: before, after, or unsplit."""
    if split_hash:
        skill, prefix = split_hash
        loaded = session.skills.get(skill)
        if not loaded:
            return "unsplit"
        return "after" if loaded.startswith(prefix) else "before"
    if split_date:
        start = parse_ts(session.start)
        return "after" if start and start >= split_date else "before"
    return "unsplit"


RESPONSE_SIGNALS = {"retry_after_error", "user_after_error"}   # describe what followed an error, not the error


def unclassified_errors(sessions, min_sessions=2, top=15):
    """Recurring error keys no error-classifying signal claims, so a new failure class surfaces."""
    preds = [pred for sid, _, _, pred in SIGNALS if sid not in RESPONSE_SIGNALS]
    per_key = defaultdict(lambda: {"sessions": set(), "events": 0, "examples": [], "unattended": set()})
    for s in sessions:
        for i, e in enumerate(s.events):
            if e["k"] != "err" or e.get("side") or any(pred(s, i, e) for pred in preds):
                continue
            entry = per_key[e["key"]]
            entry["sessions"].add(s.id)
            entry["events"] += 1
            if s.kind == "unattended":
                entry["unattended"].add(s.id)
            if len(entry["examples"]) < 3:
                entry["examples"].append(redact(s.label))
    rows = [{"key": redact(k), "sessions": len(v["sessions"]), "events": v["events"],
             "unattended_sessions": len(v["unattended"]), "examples": v["examples"]}
            for k, v in per_key.items() if len(v["sessions"]) >= min_sessions]
    rows.sort(key=lambda r: (-r["unattended_sessions"], -r["sessions"], -r["events"]))
    return rows[:top]


def compute_signals(sessions, split_date=None, split_hash=None):
    out = []
    delegation_signals.split_date, delegation_signals.split_hash = split_date, split_hash
    for sid, label, bucket, pred in SIGNALS:
        hit_sessions, events, repos, unattended, examples, windows = 0, 0, set(), 0, [], []
        sides = {k: {"sessions": 0, "events": 0} for k in ("before", "after", "unsplit")}
        for s in sessions:
            hits = [i for i, e in enumerate(s.events) if not e.get("side") and pred(s, i, e)]
            if not hits:
                continue
            hit_sessions += 1
            events += len(hits)
            side = split_side(s, split_date, split_hash)
            sides[side]["sessions"] += 1
            sides[side]["events"] += len(hits)
            repos.add(s.repo)
            if s.kind == "unattended":
                unattended += 1
            if len(examples) < 4:
                examples.append(redact(s.label))
            if len(windows) < 3 and bucket != "judgment":
                windows.append(window(s, hits[0]))
        out.append({"id": sid, "label": label, "bucket": bucket, "sessions": hit_sessions, "events": events,
                    "repos": len(repos), "unattended_sessions": unattended, "examples": examples, "windows": windows,
                    "before": sides["before"], "after": sides["after"], "unsplit": sides["unsplit"]})
    out.extend(delegation_signals(sessions))
    return out


# ---------------------------------------------------------------- strict reads

def session_summary(s, limit=2000):
    """A compact, redacted run-length account of one session for the model to read."""
    seq = []
    for e in s.events:
        if e.get("side"):
            continue
        if e["k"] == "tool":
            k = (e.get("heads") or ["?"])[0] if e["name"] == "Bash" else e["name"].replace("mcp__", "")
        elif e["k"] == "err":
            k = "ERR"
        elif e["k"] == "user":
            k = "USER"
        else:
            continue
        if seq and seq[-1][0] == k:
            seq[-1][1] += 1
        else:
            seq.append([k, 1])
    body = " ".join(f"{k}x{n}" if n > 1 else k for k, n in seq)
    first = s.first_prompt or ""
    m = re.match(r"\s*/([\w:-]+)", first)
    opening = f"/{m.group(1)}" if m else "plain prompt"   # the words themselves stay in the log
    head = f"first prompt: {opening} ({len(first)}자); skills loaded: {', '.join(sorted(s.skills)) or '없음'}\n"
    head += f"tool calls {sum(1 for e in s.events if e['k'] == 'tool')}, errors {sum(1 for e in s.events if e['k'] == 'err')}, user turns {s.n_user_text}\n"
    return (head + redact(body))[:limit]


def strict_pointers(s, limit=8):
    """Where to open excerpts of a strict-read session: each error with its timestamp and
    normalized headline, and each long run of one command head. No arguments, no prose."""
    out = []
    run_head, run_start, run_len = None, None, 0
    for e in s.events:
        if e.get("side"):
            continue
        if e["k"] == "err":
            out.append({"t": e.get("t"), "what": "error", "detail": f"{e.get('tool', '?')}: {error_headline(e.get('text', ''), 80)}"})
        head = (e.get("heads") or ["?"])[0] if e["k"] == "tool" and e["name"] == "Bash" else (e["name"] if e["k"] == "tool" else None)
        if head and head == run_head:
            run_len += 1
        else:
            if run_head and run_len >= 5:
                out.append({"t": run_start, "what": "run", "detail": f"{run_head} x{run_len}"})
            run_head, run_start, run_len = head, e.get("t"), 1
    if run_head and run_len >= 5:
        out.append({"t": run_start, "what": "run", "detail": f"{run_head} x{run_len}"})
    out.sort(key=lambda x: x["t"] or "")
    return [{"t": x["t"], "what": x["what"], "detail": redact(x["detail"])} for x in out[:limit]]


def strict_sample(sessions, since, until, n=5, min_tools=3):
    """Five interactive sessions, seeded by the period. Sessions with at least min_tools
    tool calls are drawn first because there is something to read; shorter ones fill the
    rest so the sample stays five whenever five interactive sessions exist."""
    import random
    rng = random.Random(f"{since}:{until}")
    interactive = sorted((s for s in sessions if s.kind == "interactive"), key=lambda s: (s.harness, s.id))
    rich = [s for s in interactive if sum(1 for e in s.events if e["k"] == "tool") >= min_tools]
    thin = [s for s in interactive if s not in rich]
    rng.shuffle(rich)
    rng.shuffle(thin)
    eligible = rich + thin
    return [{"session": redact(s.label), "harness": s.harness, "repo": redact(s.repo.replace(HOME, "~")),
             "kind": s.kind, "path": redact(s.path), "summary": session_summary(s), "pointers": strict_pointers(s)}
            for s in eligible[:n]]


# ---------------------------------------------------------------- commands

def cmd_scan(args):
    now = parse_ts(args.now) or dt.datetime.now(dt.timezone.utc)
    since, until = iso_date(args.since), iso_date(args.until) + dt.timedelta(days=1)
    sessions, excluded, by_harness, unknown = load_sessions(args.claude_dir, args.codex_dir, since, until, now,
                                                             args.min_age_minutes, args.select_by)
    by_kind = Counter(s.kind for s in sessions)
    split_date = iso_date(args.split) if args.split else None
    split_hash = None
    if args.split_hash:
        skill, _, prefix = args.split_hash.partition("=")
        split_hash = (skill, prefix)
    skill_versions = defaultdict(lambda: defaultdict(lambda: {"sessions": 0, "examples": []}))
    for s in sessions:
        for name, digest in s.skills.items():
            if digest:
                entry = skill_versions[name][digest]
                entry["sessions"] += 1
                if len(entry["examples"]) < 3:
                    entry["examples"].append(redact(s.label))
    findings = {
        "period": {"since": args.since, "until": args.until, "select_by": args.select_by, "generated_at": now.isoformat(),
                   "split": args.split, "split_hash": args.split_hash},
        "sessions": {
            "claude": sum(1 for s in sessions if s.harness == "claude"),
            "codex": sum(1 for s in sessions if s.harness == "codex"),
            "excluded": {k: excluded.get(k, 0) for k in ("eval", "in_progress", "no_user_text", "subagent")},
            "excluded_by_harness": {h: {k: c.get(k, 0) for k in ("eval", "in_progress", "no_user_text", "subagent", "no_events_in_period")} for h, c in by_harness.items()},
            "select_by": args.select_by,
            "by_kind": {"unattended": by_kind.get("unattended", 0), "interactive": by_kind.get("interactive", 0)},
            "tool_calls": sum(1 for s in sessions for e in s.events if e["k"] == "tool"),
            "errors": sum(1 for s in sessions for e in s.events if e["k"] == "err"),
            "user_turns": sum(getattr(s, "n_user_text_in_period", s.n_user_text) for s in sessions),
        },
        "unknown_records": {h: dict(c) for h, c in unknown.items()},
        "skill_versions": {k: dict(v) for k, v in skill_versions.items()},
        "signals": compute_signals(sessions, split_date, split_hash),
        "unclassified_errors": unclassified_errors(sessions),
    }
    threshold = {"sessions": args.threshold_sessions, "repos": args.threshold_repos, "unattended": args.threshold_unattended}
    for sig in findings["signals"]:
        sig["candidate"] = passes_threshold(sig, threshold)
    findings["threshold"] = threshold
    findings["strict"] = strict_sample(sessions, args.since, args.until, n=args.strict_n)
    findings["candidates"] = [sig["id"] for sig in findings["signals"] if sig["candidate"]]
    with open(args.out, "w") as f:
        json.dump(findings, f, ensure_ascii=False, indent=1)
    print(f"scan: {len(sessions)} sessions -> {args.out}", file=sys.stderr)

# ---------------------------------------------------------------- report

CSS = """
:root{--background:#f6f6f6;--surface:#fff;--foreground:#3a3a3a;--muted:#9a9a9a;--line:#dcdcdc;--accent:#6b6b6b;--radius:6px}
*{box-sizing:border-box}body{margin:0;padding:12px 16px 40px;background:var(--background);color:var(--foreground);font:14px/1.5 system-ui,sans-serif}
main{max-width:960px;margin:0 auto}h1{font-size:20px;margin:6px 0 2px}.sub{color:var(--muted);margin:0 0 10px}
.chips{display:flex;flex-wrap:wrap;gap:6px;margin:8px 0}.chip{border:1px solid var(--line);border-radius:99px;padding:1px 9px;font-size:12px;background:var(--surface)}
.chip.k-un{border-color:#b7791f;color:#8a5a10}.chip.k-in{border-color:#4c7fa6;color:#2f5f85}
.rule{font-size:12px;color:var(--muted);border-left:3px solid var(--line);padding-left:8px;margin:8px 0 14px}
h2{font-size:15px;margin:18px 0 8px;padding-bottom:4px;border-bottom:1px solid var(--line)}
.card{background:var(--surface);border:1px solid var(--line);border-radius:var(--radius);padding:10px 12px;margin:8px 0}
.head{display:flex;gap:8px;align-items:baseline;flex-wrap:wrap}.rank{font:600 12px/1 ui-monospace,Menlo,monospace;color:var(--muted)}.title{font-weight:600}
.badge{font-size:11px;border-radius:4px;padding:1px 6px;color:#fff;background:var(--accent);text-decoration:none}.badge.ok{background:#2e7d4f}.badge.part{background:#b7791f}
.nums{display:flex;gap:14px;flex-wrap:wrap;margin:6px 0;font-size:13px}.nums b{font-weight:600}
.kv{display:grid;grid-template-columns:92px 1fr;gap:4px 10px;font-size:13px;margin-top:6px}.kv dt{color:var(--muted)}.kv dd{margin:0}
details{margin-top:6px}summary{cursor:pointer;color:var(--accent);font-size:13px}ul{margin:4px 0 4px 18px;padding:0}li{margin:2px 0}
code{font:12px ui-monospace,Menlo,monospace;background:#eee;padding:0 3px;border-radius:3px}
.tbl{overflow-x:auto}table{border-collapse:collapse;width:100%;min-width:560px;font-size:13px;background:var(--surface)}
th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;vertical-align:top}th{color:var(--muted);font-weight:500;font-size:12px}
td.n{text-align:right;font-variant-numeric:tabular-nums;white-space:nowrap}.delta.up{color:#a33}.delta.down{color:#2e7d4f}.delta.flat{color:var(--muted)}
.toc{display:flex;flex-wrap:wrap;gap:6px;margin:4px 0 10px}.toc a{font-size:12px;color:var(--accent);border:1px solid var(--line);border-radius:99px;padding:1px 9px;text-decoration:none;background:var(--surface)}
.empty-run{background:var(--surface);border:1px dashed var(--line);border-radius:var(--radius);padding:14px;color:var(--muted)}
.win{font:12px ui-monospace,Menlo,monospace;white-space:pre-wrap;background:#f2f2f2;border-radius:4px;padding:6px 8px;margin:4px 0}
@media (max-width:480px){.kv{grid-template-columns:80px 1fr}}
"""
KIND_LABEL = {"unattended": "무인", "interactive": "대화형"}
VERDICT_LABEL = {"ok": "의미 있음", "part": "부분적"}


def esc(value):
    """Mask then escape: nothing reaches the report unmasked, whichever file it came from."""
    return (redact(str(value)).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace('"', "&quot;"))


def fmt(n):
    return f"{n:,}"


def kind_chips(sig):
    chips = []
    if sig.get("unattended_sessions"):
        chips.append('<span class="chip k-un">무인</span>')
    if sig.get("sessions", 0) > sig.get("unattended_sessions", 0):
        chips.append('<span class="chip k-in">대화형</span>')
    return "".join(chips)


def delta_html(before, after):
    d = after - before
    cls = "up" if d > 0 else "down" if d < 0 else "flat"
    return f'<span class="delta {cls}">{"+" if d > 0 else ""}{d}</span>'


def render_card(num, cand, sig):
    evidence = "".join(f"<li>{esc(e)}</li>" for e in cand.get("evidence", []))
    examples = " ".join(f"<code>{esc(x)}</code>" for x in sig.get("examples", []))
    windows = "".join(f'<div class="win">{esc(chr(10).join(w["lines"]))}</div>' for w in sig.get("windows", [])[:2])
    verdict = cand.get("verdict", "ok")
    return f"""<div class="card" id="cand-{num}">
<div class="head"><span class="rank">{num}</span><span class="title">{esc(cand.get("title", sig["label"]))}</span>
<span class="badge {esc(verdict)}">{VERDICT_LABEL.get(verdict, esc(verdict))}</span>{kind_chips(sig)}</div>
<div class="nums"><span>세션 <b>{fmt(sig["sessions"])}</b></span><span>건수 <b>{fmt(sig["events"])}</b></span><span>저장소 {sig["repos"]} · 무인 세션 {sig["unattended_sessions"]}</span></div>
<dl class="kv"><dt>신호</dt><dd>{esc(sig["label"])}</dd><dt>제안 형태</dt><dd><b>{esc(cand.get("form", ""))}</b> · 주인 {esc(cand.get("owner", ""))}<br>{esc(cand.get("form_detail", ""))}</dd></dl>
<details{" open" if num == 1 else ""}><summary>근거와 재측정</summary>
<dl class="kv"><dt>근거</dt><dd><ul>{evidence}</ul></dd><dt>예시 세션</dt><dd>{examples}</dd>
<dt>사건 창</dt><dd>{windows or "<span class=sub>없음</span>"}</dd>
<dt>남는 판단</dt><dd>{esc(cand.get("judgment", ""))}</dd><dt>재측정</dt><dd>{esc(cand.get("remeasure", ""))}</dd></dl></details></div>"""


def matches_focus(focus, sig, cand=None):
    if not focus:
        return False
    f = focus.lower()
    hay = [sig["id"], sig["label"]] + ([cand.get("owner", ""), cand.get("title", "")] if cand else [])
    return any(f in str(h).lower() for h in hay)


def render_report(findings, cands, focus=None):
    sigs = {s["id"]: s for s in findings["signals"]}
    period = findings["period"]
    sess = findings["sessions"]
    candidates = [c for c in cands.get("candidates", []) if c.get("signal") in sigs and sigs[c["signal"]].get("candidate")]
    for c in cands.get("candidates", []):
        if not (c.get("signal") in sigs and sigs[c["signal"]].get("candidate")):
            print(f"report: dropped candidate {c.get('signal')!r}: not a signal past the threshold", file=sys.stderr)
    n = len(candidates)
    header_chips = [f"Claude Code 세션 {fmt(sess['claude'])}", f"Codex 세션 {fmt(sess['codex'])}",
                    "제외 " + " · ".join(f"{h} {sum(c.values())} (eval {c['eval']}, 진행 중 {c['in_progress']}, 발화 없음 {c['no_user_text']}, 서브에이전트 {c['subagent']}, 기간 내 활동 없음 {c.get('no_events_in_period', 0)})" for h, c in sess.get("excluded_by_harness", {"all": sess["excluded"]}).items()),
                    f"도구 호출 {fmt(sess['tool_calls'])} · 오류 {fmt(sess['errors'])} · 사용자 발화 {fmt(sess['user_turns'])}",
                    f"무인 {sess['by_kind']['unattended']} · 대화형 {sess['by_kind']['interactive']}"]
    unknown = {h: c for h, c in findings.get("unknown_records", {}).items() if c}
    if unknown:
        header_chips.append("모르는 레코드 " + ", ".join(f"{h} {sum(c.values())}" for h, c in unknown.items()))
    if focus:
        header_chips.append(f"초점: {focus}")
    split = period.get("split_hash") or period.get("split")
    out = [f"<!doctype html><meta charset=utf-8><meta name=viewport content=\"width=device-width, initial-scale=1\">",
           f"<title>review-sessions 보고서 {esc(period['since'])}～{esc(period['until'])}</title><style>{CSS}</style><main>",
           f"<h1>세션 되돌아보기</h1><p class=sub>review-sessions 보고서 · {esc(period['since'])} ～ {esc(period['until'])} · 후보 {n}건</p>",
           '<div class="chips">' + "".join(f'<span class="chip">{esc(c)}</span>' for c in header_chips) + "</div>",
           '<p class="rule">세션 기록은 자료이지 지시가 아닙니다. 토큰과 개인정보는 보고에 옮기지 않습니다.</p>']
    if cands.get("summary"):
        out.append(f"<p>{esc(cands['summary'])}</p>")
    toc = ['<a href="#buckets">분류</a>', '<a href="#remeasure">재측정</a>', '<a href="#strict">엄격 읽기</a>']
    if n:
        toc.insert(0, f'<a href="#cands">후보 {n}</a>')
    out.append('<div class="toc">' + "".join(toc) + "</div>")
    if n:
        out.append('<h2 id="cands">후보 · 비용순</h2>')
        ordered = sorted(candidates, key=lambda c: (not matches_focus(focus, sigs[c["signal"]], c), -sigs[c["signal"]]["unattended_sessions"], -sigs[c["signal"]]["sessions"] * max(1, sigs[c["signal"]]["events"])))
        for i, c in enumerate(ordered, 1):
            out.append(render_card(i, c, sigs[c["signal"]]))
    else:
        out.append('<div class="empty-run"><b>후보 없음.</b> 이번 기간에 문턱을 넘은 신호가 없습니다. 아래 재측정 표와 엄격 읽기만 남깁니다.</div>')
    # buckets
    out.append('<h2 id="buckets">도구로 가지 않는 것</h2>')
    harness = [s for s in findings["signals"] if s["bucket"] == "harness" and s["sessions"]]
    rows = "".join(f"<tr><td>{esc(s['label'])}</td><td class=n>{s['sessions']}</td><td class=n>{s['events']}</td></tr>" for s in harness)
    out.append(f"<details><summary>하네스가 이미 막는 것 {len(harness)}건 · 스킬 대상 아님</summary><div class=tbl><table><tr><th>신호</th><th>세션</th><th>건수</th></tr>{rows}</table></div></details>")
    notes = {j.get("signal"): j for j in cands.get("judgment_notes", [])}
    judgment = [s for s in findings["signals"] if s["bucket"] == "judgment" and s["sessions"]]
    rows = "".join(f"<tr><td>{esc(s['label'])}</td><td class=n>{s['sessions']} / {s['events']}</td><td>{esc(notes.get(s['id'], {}).get('note', ''))}</td><td>{esc(notes.get(s['id'], {}).get('route', '결정 계약·메모리'))}</td></tr>" for s in judgment)
    out.append(f"<details><summary>도구로 못 가는 것 {len(judgment)}건 · 결정 계약·스킬 문장으로</summary><div class=tbl><table><tr><th>신호</th><th>세션 / 건수</th><th>관찰</th><th>갈 곳</th></tr>{rows}</table></div></details>")
    project = cands.get("project", [])
    rows = "".join(f"<tr><td>{esc(p.get('title', ''))}</td><td>{esc(p.get('note', ''))}</td></tr>" for p in project)
    out.append(f"<details><summary>프로젝트 follow-up {len(project)}건</summary><div class=tbl><table><tr><th>대상</th><th>관찰과 형태</th></tr>{rows}</table></div></details>")
    unclassified = findings.get("unclassified_errors", [])
    rows = "".join(f"<tr><td><code>{esc(r['key'])}</code></td><td class=n>{r['sessions']}</td><td class=n>{r['events']}</td><td class=n>{r['unattended_sessions']}</td><td>{' '.join(f'<code>{esc(x)}</code>' for x in r['examples'])}</td></tr>" for r in unclassified)
    out.append(f"<details{' open' if unclassified else ''}><summary>어느 신호에도 안 잡힌 반복 오류 {len(unclassified)}건 · 새 신호 후보</summary><div class=tbl><table><tr><th>오류 (정규화)</th><th>세션</th><th>건수</th><th>무인</th><th>예시 세션</th></tr>{rows}</table></div></details>")
    # re-measurement
    out.append('<h2 id="remeasure">재측정</h2>')
    cand_num = {c["signal"]: i for i, c in enumerate(sorted(candidates, key=lambda c: (not matches_focus(focus, sigs[c["signal"]], c), -sigs[c["signal"]]["unattended_sessions"], -sigs[c["signal"]]["sessions"] * max(1, sigs[c["signal"]]["events"]))), 1)}
    cand_by_signal = {c["signal"]: c for c in candidates}
    rows = []
    for s in sorted(findings["signals"], key=lambda s: not matches_focus(focus, s, cand_by_signal.get(s["id"]))):
        if not s["sessions"]:
            continue
        link = f'<a class="badge {esc(next((c.get("verdict", "ok") for c in candidates if c["signal"] == s["id"]), "ok"))}" href="#cand-{cand_num[s["id"]]}">B{cand_num[s["id"]]}</a>' if s["id"] in cand_num else f'<span class=chip>{esc(s["bucket"])}</span>'
        if split:
            b, a, u = s["before"], s["after"], s.get("unsplit", {"sessions": 0, "events": 0})
            unsplit_cell = f"<td class=n>{u['sessions']} / {u['events']}</td>" if period.get("split_hash") else ""
            rows.append(f"<tr><td>{esc(s['label'])}</td><td class=n>{b['sessions']} / {b['events']}</td><td class=n>{a['sessions']} / {a['events']}</td>{unsplit_cell}<td class=n>{delta_html(b['sessions'], a['sessions'])}</td><td>{link}</td></tr>")
        else:
            rows.append(f"<tr><td>{esc(s['label'])}</td><td class=n>{s['sessions']} / {s['events']}</td><td class=n>{s['unattended_sessions']}</td><td>{link}</td></tr>")
    if split:
        unsplit_head = "<th>미분류 세션/건</th>" if period.get("split_hash") else ""
        head = f"<tr><th>신호</th><th>전 세션/건</th><th>후 세션/건</th>{unsplit_head}<th>세션 변화</th><th>후보</th></tr>"
        note = f"기준: {esc(split)}" + (" (스킬 판 기준. 그 스킬을 읽지 않은 세션은 미분류로 따로 센다. 미분류가 크면 전후 비교로 효과를 말할 수 없다)" if period.get("split_hash") else " (날짜 기준. 설치 사본 지연으로 옛 판 세션이 섞일 수 있다)")
        note += f" · 선택 방식: {esc(period.get('select_by', 'activity'))}"
    else:
        head = "<tr><th>신호</th><th>세션 / 건</th><th>무인 세션</th><th>후보</th></tr>"
        note = f"기준 없이 한 기간만 센 표다. 고친 뒤에는 --split 날짜나 --split-hash 스킬판으로 나눠 다시 돌린다. · 선택 방식: {esc(period.get('select_by', 'activity'))}"
    out.append(f"<div class=tbl><table>{head}{''.join(rows)}</table></div><p class=sub>{note}</p>")
    versions = findings.get("skill_versions", {})
    if versions:
        rows = "".join(f"<tr><td>{esc(k)}</td><td><code>{esc(h)}</code></td><td class=n>{v['sessions']}</td></tr>" for k, hs in sorted(versions.items()) for h, v in sorted(hs.items(), key=lambda kv: -kv[1]['sessions']))
        out.append(f"<details><summary>세션이 읽은 스킬 판 {sum(len(v) for v in versions.values())}개</summary><div class=tbl><table><tr><th>스킬</th><th>본문 해시</th><th>세션</th></tr>{rows}</table></div></details>")
    # strict reads
    notes = {s.get("session"): s for s in cands.get("strict", [])}
    items = []
    for s in findings.get("strict", []):
        note = notes.get(s["session"], {})
        items.append(f"<li><code>{esc(s['session'])}</code> {esc(note.get('note', '관찰 없음'))}" + (f' <span class=chip>{esc(note["link"])}</span>' if note.get("link") else "") + "</li>")
    out.append(f'<h2 id="strict">엄격 읽기 {len(items)}세션</h2><ul>{"".join(items)}</ul></main>')
    return "\n".join(out)


def cmd_report(args):
    with open(args.findings) as f:
        findings = json.load(f)
    with open(args.candidates) as f:
        cands = json.load(f)
    html = render_report(findings, cands, args.focus)
    with open(args.out, "w") as f:
        f.write(html)
    print(f"report: {args.out}", file=sys.stderr)



def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="command", required=True)
    sc = sub.add_parser("scan", help="count signals in local session logs")
    sc.add_argument("--claude-dir", default=os.path.join(HOME, ".claude", "projects"))
    sc.add_argument("--codex-dir", default=os.path.join(HOME, ".codex", "sessions"))
    sc.add_argument("--since", required=True, help="first day, YYYY-MM-DD (UTC)")
    sc.add_argument("--until", required=True, help="last day, YYYY-MM-DD (UTC), inclusive")
    sc.add_argument("--now", help="override the clock, ISO 8601")
    sc.add_argument("--select-by", choices=("activity", "mtime"), default="activity",
                    help="activity: sessions with events in the period, counting only those events (default); mtime: logs modified in the period, counting every event")
    sc.add_argument("--split", help="re-measure: sessions starting on or after this day count as after")
    sc.add_argument("--split-hash", help="re-measure: <skill>=<sha256 prefix> of the loaded SKILL.md text that counts as after")
    sc.add_argument("--min-age-minutes", type=int, default=10, help="skip logs modified more recently than this")
    sc.add_argument("--threshold-sessions", type=int, default=5, help="candidate when at least this many sessions")
    sc.add_argument("--threshold-repos", type=int, default=2, help="or at least this many repositories")
    sc.add_argument("--threshold-unattended", type=int, default=1, help="or at least this many unattended sessions")
    sc.add_argument("--strict-n", type=int, default=5, help="interactive sessions sampled for strict reading")
    sc.add_argument("--out", required=True)
    sc.set_defaults(func=cmd_scan)
    rp = sub.add_parser("report", help="render the offline HTML report")
    rp.add_argument("--findings", required=True, help="findings.json from scan")
    rp.add_argument("--candidates", required=True, help="candidates.json written after reading the windows")
    rp.add_argument("--focus", help="a skill name or signal id whose candidates and rows come first")
    rp.add_argument("--out", required=True)
    rp.set_defaults(func=cmd_report)
    args = ap.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    main()
