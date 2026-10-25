#!/usr/bin/env bash
#
# forge.sh: emit a project's build harness from the kit templates. No model in the loop.
#
#   bash scripts/forge.sh <small|orchestrated> <values.json> <target-dir>
#
# Copies every template the tier's MANIFEST.md lists, the gates named in values.json,
# the enforcement files, notify.sh and ASK_CONTRACT.md; fills every {{VAR}}; resolves
# {{#IF X}}...{{/IF}} blocks (inline or on their own lines, nested); collapses runs of
# blank lines; sets executable bits on hooks and notify.sh.
#
# Exits non-zero, writing nothing into <target-dir>, when a placeholder is left unfilled,
# a values.json key is used by no template, a gate is unknown, or the gates and their
# flags disagree. The schema of values.json is in templates/PLACEHOLDERS.md.
#
# Setup-time only (harness-forge runs it once per forge). Never call it from a hook.

set -euo pipefail

if [ $# -ne 3 ]; then
  echo "usage: forge.sh <small|orchestrated> <values.json> <target-dir>" >&2
  exit 2
fi

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

exec python3 -I - "$KIT_ROOT" "$@" <<'PY'
import json, os, re, shutil, stat, sys, tempfile

kit, tier, values_path, target = sys.argv[1:5]
errors = []

def die(msgs):
    for m in msgs:
        print("forge.sh: " + m, file=sys.stderr)
    sys.exit(1)

if tier not in ("small", "orchestrated"):
    die([f"tier must be small or orchestrated, got {tier!r}"])

try:
    with open(values_path) as fh:
        data = json.load(fh)
except Exception as e:
    die([f"cannot read {values_path}: {e}"])

if not isinstance(data, dict):
    die(["values.json must be a JSON object"])

gates = data.pop("gates", [])
if not isinstance(gates, list) or not all(isinstance(g, str) for g in gates):
    die(['"gates" must be a list of gate names'])

values = {}
for k, v in data.items():
    if not re.fullmatch(r"[A-Z][A-Z0-9_]*", k):
        errors.append(f"key {k!r} is not an UPPER_CASE placeholder name")
    elif isinstance(v, (str, bool)):
        values[k] = v
    else:
        errors.append(f"key {k}: value must be a string or a boolean, got {type(v).__name__}")

# Keys forge.sh computes itself. values.json must not set them.
GATE_FLAG = {  # gate -> the IF flag its join wiring uses
    "db-migration-review": "MIGRATION_TOOL",
    "api-contract-sync": "CONTRACT_GEN_COMMAND",
    "design-token-lint": "TOKENS_FILE",
    "mcp-scan": "MCP_SERVERS",
    "perf-profiling": "PERF_PROFILING",
    "release-runbook": "RELEASE_RUNBOOK",
}
COMPUTED = {"ORCHESTRATED", "MCP_SERVERS", "PERF_PROFILING", "RELEASE_RUNBOOK",
            "NOTIFY", "TALKING_TO_THE_USER", "TIER"}
for k in sorted(COMPUTED & values.keys()):
    errors.append(f"key {k} is computed by forge.sh (from the tier and the gates list); remove it")

gates_dir = os.path.join(kit, "templates", "gates")
known_gates = sorted(d for d in os.listdir(gates_dir) if os.path.isdir(os.path.join(gates_dir, d)))
for g in gates:
    if g not in known_gates:
        errors.append(f"unknown gate {g!r}; known: {', '.join(known_gates)}")
if len(set(gates)) != len(gates):
    errors.append("a gate is listed twice")
if tier == "small" and gates:
    errors.append("the small tier emits no gates (every manifest row is no); gates must be []")

def truthy(k):
    v = values.get(k, False)
    return v is True or (isinstance(v, str) and v.strip() != "")

values["ORCHESTRATED"] = tier == "orchestrated"
for g in ("mcp-scan", "perf-profiling", "release-runbook"):
    values[GATE_FLAG[g]] = g in gates
values["NOTIFY"] = ".claude/scripts/notify.sh"
if tier == "orchestrated":
    for g in ("db-migration-review", "api-contract-sync", "design-token-lint"):
        f = GATE_FLAG[g]
        if (g in gates) != truthy(f):
            errors.append(f"gate {g} is {'listed' if g in gates else 'not listed'} but {f} is "
                          f"{'set' if truthy(f) else 'empty'}; the join would "
                          f"{'never dispatch it' if g in gates else 'dispatch a gate that was not emitted'}")
if errors:
    die(errors)

# The Talking-to-the-user block: the kit's canonical rules, filled only if a template uses it.
def talking_block():
    path = os.path.join(kit, "COMMUNICATION.md")
    text = open(path).read()
    m = re.search(r"<!-- BEGIN TALKING-TO-THE-USER -->\n(.*?)\n<!-- END TALKING-TO-THE-USER -->", text, re.S)
    if not m:
        die([f"no TALKING-TO-THE-USER block in {path}"])
    return m.group(1)

# ---- what to emit: (template path, target path relative to the repo, executable) ----
tdir = os.path.join(kit, "templates")
state_file = values.get("STATE_FILE") if isinstance(values.get("STATE_FILE"), str) else ""
if not state_file:
    die(["STATE_FILE must be set (the build state file, e.g. PROGRESS.md)"])

manifest = open(os.path.join(tdir, tier, "MANIFEST.md")).read()
files_sec = re.search(r"^## Files\n(.*?)(?=^## |\Z)", manifest, re.S | re.M)
listed = re.findall(r"^\|\s*`([^`]+\.tmpl)`\s*\|", files_sec.group(1) if files_sec else "", re.M)
if not listed:
    die([f"templates/{tier}/MANIFEST.md lists no .tmpl files under ## Files"])

def target_for(rel):
    if rel == "CLAUDE.md.tmpl":
        return "CLAUDE.md"
    if rel == "STATE_FILE.md.tmpl":
        return state_file
    m = re.fullmatch(r"skills/([^/]+)/SKILL\.md\.tmpl", rel)
    if m:
        return f".claude/skills/{m.group(1)}/SKILL.md"
    die([f"MANIFEST lists {rel}, which has no target mapping in forge.sh"])

plan = []  # (source, target, substitute?, executable?)
for rel in listed:
    src = os.path.join(tdir, tier, rel)
    if not os.path.isfile(src):
        errors.append(f"MANIFEST lists {rel} but templates/{tier}/{rel} does not exist")
    plan.append((src, target_for(rel), True, False))
for g in gates:
    plan.append((os.path.join(gates_dir, g, "SKILL.md.tmpl"), f".claude/skills/{g}/SKILL.md", True, False))
edir = os.path.join(tdir, "enforcement")
plan.append((os.path.join(edir, "settings.json.tmpl"), ".claude/settings.json", True, False))
plan.append((os.path.join(edir, "hooks", "guard-writes.sh.tmpl"), ".claude/hooks/guard-writes.sh", True, True))
plan.append((os.path.join(edir, "hooks", "guard-bash.sh.tmpl"), ".claude/hooks/guard-bash.sh", True, True))
if truthy("FORMAT_COMMAND"):
    plan.append((os.path.join(edir, "hooks", "format.sh.tmpl"), ".claude/hooks/format.sh", True, True))
plan.append((os.path.join(edir, "githooks", "pre-commit.tmpl"), ".githooks/pre-commit", True, True))
plan.append((os.path.join(kit, "scripts", "notify.sh"), ".claude/scripts/notify.sh", False, True))
plan.append((os.path.join(kit, "ASK_CONTRACT.md"), ".claude/ASK_CONTRACT.md", False, False))
if errors:
    die(errors)

# ---- substitution ----
NAME = r"[A-Z][A-Z0-9_]*"
IF_RE = re.compile(r"\{\{#IF (" + NAME + r")\}\}((?:(?!\{\{#IF ).)*?)\{\{/IF\}\}", re.S)  # innermost first
VAR_RE = re.compile(r"\{\{(" + NAME + r")\}\}")
used = set()

def resolve_ifs(text):
    while True:
        m = IF_RE.search(text)
        if not m:
            return text
        name, body = m.group(1), m.group(2)
        used.add(name)
        s, e = m.start(), m.end()
        at_line_start = s == 0 or text[s - 1] == "\n"
        ends_line = e < len(text) and text[e] == "\n"
        if truthy(name):
            # A marker alone on its line takes its newline with it.
            if at_line_start and body.startswith("\n"):
                body = body[1:]
            if ends_line and (body.endswith("\n") or body == ""):
                e += 1
            text = text[:s] + body + text[e:]
        else:
            # A false block that filled whole lines leaves no empty line behind.
            if at_line_start and ends_line:
                e += 1
            text = text[:s] + text[e:]

def fill(text, label):
    for _ in range(4):  # a value may itself name a placeholder (e.g. DB_ISOLATION in DB_PARALLEL_RULE)
        changed = False
        def sub(m):
            nonlocal changed
            name = m.group(1)
            used.add(name)
            if name == "TALKING_TO_THE_USER":
                changed = True
                return talking_block()
            v = values.get(name)
            if isinstance(v, str):
                changed = True
                return v
            if isinstance(v, bool):
                errors.append(f"{label}: {{{{{name}}}}} is used as text but its value is a boolean")
            return m.group(0)
        text = resolve_ifs(VAR_RE.sub(sub, resolve_ifs(text)))
        if not changed:
            break
    return text

def collapse(text):
    text = re.sub(r"\n(?:[ \t]*\n){2,}", "\n\n", text)
    return text.rstrip("\n") + "\n"

# Every key referenced anywhere in an emitted template counts as used, even inside a false block.
for src, _, sub, _ in plan:
    if sub:
        raw = open(src).read()
        used.update(re.findall(r"\{\{(?:#IF )?(" + NAME + r")\}\}", raw))

stage = tempfile.mkdtemp(prefix="forge-")
written = []
try:
    for src, rel_out, sub, exe in plan:
        out = os.path.join(stage, rel_out)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        if sub:
            text = collapse(fill(open(src).read(), rel_out))
            for n, line in enumerate(text.splitlines(), 1):
                if "{{" in line and "PLACEHOLDER-LITERAL" not in line:
                    left = sorted(set(re.findall(r"\{\{[#/]?(?:IF )?(" + NAME + r")?", line)) - {""})
                    errors.append(f"{rel_out}:{n}: unfilled placeholder{'s' if len(left) != 1 else ''} "
                                  f"{', '.join(left) if left else line.strip()[:80]}")
            with open(out, "w") as fh:
                fh.write(text)
        else:
            shutil.copyfile(src, out)
        if exe:
            os.chmod(out, os.stat(out).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
        written.append(rel_out)

    unused = sorted(k for k in data.keys() if k not in used)
    for k in unused:
        errors.append(f"values.json key {k} is used by no emitted template; remove it or fix its name")
    if errors:
        die(errors)

    # All checks passed: move the staged files into the target repo.
    os.makedirs(target, exist_ok=True)
    kept = []
    for rel_out in written:
        dst = os.path.join(target, rel_out)
        if rel_out == state_file and os.path.exists(dst):
            kept.append(rel_out)  # never overwrite a state file that may hold real build state
            continue
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.copy2(os.path.join(stage, rel_out), dst)
finally:
    shutil.rmtree(stage, ignore_errors=True)

print(f"forge.sh: {tier} harness written to {target} ({len(written) - len(kept)} files)")
for rel_out in written:
    print(("  kept existing " if rel_out in kept else "  ") + rel_out)
print("  gates: " + (", ".join(gates) if gates else "none"))
PY
