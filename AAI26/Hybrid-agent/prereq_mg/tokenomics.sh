#!/usr/bin/env bash
# token_cost.sh -- live token and cost breakdown for the most recent OpenClaw session
#
# Usage:
#   bash token_cost.sh [agents_dir]
#
# Arguments:
#   agents_dir   Path to OpenClaw agents dir (default: ~/.openclaw/agents)
#
# Environment variables:
#   CLOUD_INPUT_PER_M    Cloud input  cost in $/million tokens  (default: 3.00)
#   CLOUD_OUTPUT_PER_M   Cloud output cost in $/million tokens  (default: 9.00)
#   LOCAL_INPUT_PER_M    Local input  cost in $/million tokens  (default: 1.00)
#   LOCAL_OUTPUT_PER_M   Local output cost in $/million tokens  (default: 3.00)
#
# Examples:
#   bash token_cost.sh
#   CLOUD_INPUT_PER_M=2.50 CLOUD_OUTPUT_PER_M=7.50 bash token_cost.sh
#   LOCAL_INPUT_PER_M=0.10 LOCAL_OUTPUT_PER_M=0.20 bash token_cost.sh
#   bash token_cost.sh ~/.openclaw/agents
python3 - "$@" << 'PY'
import sys, json, os, glob, datetime, time, subprocess

def find_agents_dir(hint=None):
    """
    Return the OpenClaw agents directory.
    If hint is given, use it directly.
    Otherwise probe common locations and pick the first that contains session files.
    """
    candidates = [
        hint,
        os.path.expanduser('~/.openclaw/agents'),
        os.path.expanduser('~/.openclaw'),
        os.path.expanduser('~/.config/openclaw/agents'),
        os.path.expanduser('~/.config/openclaw'),
    ]
    for path in candidates:
        if not path or not os.path.isdir(path):
            continue
        # Accept if it directly contains agent subdirs with sessions
        if glob.glob(os.path.join(path, '*/sessions/*.jsonl')):
            return path, None
        # Accept one level deeper (e.g. ~/.openclaw -> ~/.openclaw/agents)
        for sub in ('agents',):
            full = os.path.join(path, sub)
            if glob.glob(os.path.join(full, '*/sessions/*.jsonl')):
                return full, None
    # Nothing found -- return best candidate with error
    default = os.path.expanduser('~/.openclaw/agents')
    tried = [c for c in candidates if c]
    return None, tried

agents_dir, _not_found = find_agents_dir(sys.argv[1] if len(sys.argv) > 1 else None)

# Cost rates in $/million tokens -- override via env vars:
#   CLOUD_INPUT_PER_M=3.00 CLOUD_OUTPUT_PER_M=9.00 bash token_cost.sh
#   LOCAL_INPUT_PER_M=0.10 LOCAL_OUTPUT_PER_M=0.20 bash token_cost.sh
def _rate(name, default):
    try:
        return float(os.environ[name])
    except (KeyError, ValueError):
        return default

CLOUD_INPUT_PER_M  = _rate('CLOUD_INPUT_PER_M',  1.00)
CLOUD_OUTPUT_PER_M = _rate('CLOUD_OUTPUT_PER_M',  5.00)
LOCAL_INPUT_PER_M  = _rate('LOCAL_INPUT_PER_M',   0.10)
LOCAL_OUTPUT_PER_M = _rate('LOCAL_OUTPUT_PER_M',  0.50)

RESET = '\033[0m'
GREEN = '\033[32m'
RED   = '\033[31m'
BOLD  = '\033[1m'
DIM   = '\033[2m'
CYAN  = '\033[36m'

SR_PORT = '8899'  # vLLM semantic router port

def is_cloud_provider(provider):
    return 'fireworks' in provider.lower()

def is_router_provider(provider):
    return 'semanticrouter' in provider.lower()

def is_sr_cloud_model(model):
    """True if the SR downstream model is a cloud (Fireworks) model."""
    m = model.lower()
    return 'fireworks' in m or 'kimi' in m

def parse_iso_ts(ts_str):
    """Parse ISO timestamp string to epoch float. Returns None on failure."""
    if not ts_str:
        return None
    try:
        s = ts_str.rstrip('Z').replace(' ', 'T')
        # Handle fractional seconds of varying length
        if '.' in s:
            dt = datetime.datetime.strptime(s, '%Y-%m-%dT%H:%M:%S.%f')
        else:
            dt = datetime.datetime.strptime(s, '%Y-%m-%dT%H:%M:%S')
        return dt.timestamp()
    except Exception:
        return None

def get_event_ts(e):
    """Extract epoch timestamp from an OpenClaw JSONL event."""
    for field in ('timestamp', 'createdAt', 'created_at', 'time', 'ts'):
        v = e.get(field)
        if not v:
            continue
        if isinstance(v, (int, float)):
            return v / 1000.0 if v > 1e12 else float(v)
        if isinstance(v, str):
            t = parse_iso_ts(v)
            if t:
                return t
    return None

def find_sr_container():
    """
    Discover the vLLM SR *router* container (the one that emits llm_usage logs).
    The SR stack has several containers; the router backend is what we want --
    NOT the envoy frontend (which sits on port 8899) and NOT the dashboard/sim.

    Strategy:
      1. Scan all running containers for name/image containing 'router' or 'semantic'
         but NOT 'envoy', 'dashboard', 'sim', 'prometheus', 'grafana', 'jaeger',
         'milvus', 'postgres', 'redis'.
      2. Fallback: container publishing SR_PORT (envoy) -- still better than nothing.
    Returns a container ID string, or None if nothing found.
    """
    EXCLUDE = ('envoy', 'dashboard', 'sim', 'prometheus', 'grafana',
               'jaeger', 'milvus', 'postgres', 'redis')
    try:
        r = subprocess.run(
            ['docker', 'ps', '--format', '{{.ID}}\t{{.Image}}\t{{.Names}}'],
            capture_output=True, text=True, timeout=5
        )
        for line in r.stdout.strip().splitlines():
            parts = line.split('\t')
            if len(parts) < 3:
                continue
            cid, image, name = parts[0], parts[1].lower(), parts[2].lower()
            combined = image + ' ' + name
            if any(ex in combined for ex in EXCLUDE):
                continue
            if any(kw in combined for kw in ('vllm-sr', 'semantic-router', 'vllm_sr')):
                return cid
            # Also match if name ends with -router-container pattern
            if 'router' in name and 'vllm' in combined:
                return cid

        # Fallback: port-based discovery finds envoy -- still has some log events
        r2 = subprocess.run(
            ['docker', 'ps', '--filter', f'publish={SR_PORT}', '--format', '{{.ID}}'],
            capture_output=True, text=True, timeout=5
        )
        cid = r2.stdout.strip().splitlines()
        if cid:
            return cid[0]
    except Exception:
        pass
    return None

def get_sr_docker_events():
    """
    Pull llm_usage events from the SR docker container logs.
    Discovers the container dynamically by port (8899) or image/name keyword.
    Returns list of dicts sorted by ts:
      {ts, model, cost, prompt_tokens, completion_tokens, request_id}
    Returns [] if docker is unavailable or no SR container is found.
    """
    container = find_sr_container()
    if not container:
        return []

    events = []
    try:
        result = subprocess.run(
            ['docker', 'logs', container, '--tail', '10000'],
            capture_output=True, text=True, timeout=10
        )
        output = result.stdout + result.stderr  # some docker versions write to stderr
        for line in output.splitlines():
            if '"llm_usage"' not in line:
                continue
            try:
                d = json.loads(line)
            except Exception:
                continue
            if d.get('msg') != 'llm_usage':
                continue
            ts = parse_iso_ts(d.get('ts', ''))
            if ts is None:
                continue
            events.append({
                'ts':                ts,
                'model':             d.get('model', ''),
                'cost':              float(d.get('cost', 0)),
                'prompt_tokens':     int(d.get('prompt_tokens', 0)),
                'completion_tokens': int(d.get('completion_tokens', 0)),
                'request_id':        d.get('request_id', ''),
            })
    except Exception:
        pass
    return sorted(events, key=lambda e: e['ts'])

def extract_text(content):
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        return ' '.join(
            x.get('text', '') for x in content
            if isinstance(x, dict) and x.get('type') == 'text'
        ).strip()
    return ''

def is_context_injection(text):
    return text.startswith('[Context:') or text.startswith('<<<')

def is_subagent_session(path):
    """
    Return True if this session file is a spawned subagent session rather than
    a real user-facing session. Subagent sessions have only [Subagent Context]
    or context-injection as their user turns -- no real human prompts.
    """
    try:
        with open(path) as f:
            for line in f:
                try:
                    e = json.loads(line.strip())
                except Exception:
                    continue
                if e.get('type') != 'message':
                    continue
                m = e.get('message', {})
                if m.get('role') != 'user':
                    continue
                text = extract_text(m.get('content', ''))
                if not text:
                    continue
                if is_context_injection(text):
                    continue
                if text.startswith('[Subagent Context]'):
                    continue
                # Found a real human prompt -- not a subagent session
                return False
    except Exception:
        pass
    return True  # No real user turns found

def find_latest_session(agents_dir):
    sessions = []
    for path in glob.glob(os.path.join(agents_dir, '*/sessions/*.jsonl')):
        if '.trajectory.' in path:
            continue
        if is_subagent_session(path):
            continue
        parts = path.split(os.sep)
        try:
            agent_name = parts[parts.index('agents') + 1]
        except (ValueError, IndexError):
            agent_name = '?'
        mtime = os.path.getmtime(path)
        sessions.append({
            'path':      path,
            'agent':     agent_name,
            'full_id':   os.path.basename(path).replace('.jsonl', ''),
            'mtime':     mtime,
            'mtime_str': datetime.datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M'),
        })
    if not sessions:
        return None
    return max(sessions, key=lambda s: s['mtime'])

def get_subagent_cloud_usage(path):
    """
    Read a subagent session file and return the total cloud (fireworks) token
    usage as (input_tokens, output_tokens).  input_tokens is the maximum seen
    across all assistant turns (context grows per turn); output_tokens is the
    sum (each turn adds new output).
    """
    max_in, total_out = 0, 0
    try:
        with open(path) as f:
            for line in f:
                try:
                    e = json.loads(line.strip())
                except Exception:
                    continue
                if e.get('type') != 'message':
                    continue
                m = e.get('message', {})
                if m.get('role') != 'assistant':
                    continue
                if not is_cloud_provider(m.get('provider', '')):
                    continue
                usage = m.get('usage', {})
                in_tok  = usage.get('input', 0)
                out_tok = usage.get('output', 0)
                if in_tok > max_in:
                    max_in = in_tok
                total_out += out_tok
    except Exception:
        pass
    return max_in, total_out


def enrich_hybrid_turns(turns, agents_dir, agent_name):
    """
    For each CLOUD_HYBRID turn, find the matching subagent session file
    (same agent, timestamp within the turn window) and replace the estimated
    cloud token counts with actual kimi usage figures.
    """
    hybrid_turns = [t for t in turns if t['routing'] == 'CLOUD_HYBRID']
    if not hybrid_turns:
        return

    session_dir = os.path.join(agents_dir, agent_name, 'sessions')
    subagent_files = []
    for path in glob.glob(os.path.join(session_dir, '*.jsonl')):
        if '.trajectory.' in path:
            continue
        if not is_subagent_session(path):
            continue
        subagent_files.append((os.path.getmtime(path), path))
    subagent_files.sort()

    if not subagent_files:
        return

    available = list(subagent_files)  # consumed one-by-one to prevent double-matching

    is_last_turn_idx = {id(t): (i == len(hybrid_turns) - 1) for i, t in enumerate(hybrid_turns)}

    for turn in hybrid_turns:
        t_start  = turn.get('turn_ts') or 0
        t_end    = turn.get('end_ts') or (t_start + 300)
        is_last  = is_last_turn_idx.get(id(turn), False)
        # Subagent file is created/written while the spawn runs, so its mtime
        # should fall between the spawn call and the next user turn (+buffer).
        # For the last turn there is no next-turn bound, so use 600s (kimi-k2p6
        # can take several minutes for long code generation tasks).
        window_start = t_start - 10
        window_end   = t_end + (600 if is_last else 300)

        best_path  = None
        best_delta = float('inf')
        best_idx   = None
        for idx, (mtime, path) in enumerate(available):
            if window_start <= mtime <= window_end:
                delta = abs(mtime - t_end)
                if delta < best_delta:
                    best_delta = delta
                    best_path  = path
                    best_idx   = idx

        if best_path is not None:
            available.pop(best_idx)  # remove so next HYBRID turn can't reuse it
            in_tok, out_tok = get_subagent_cloud_usage(best_path)
            if in_tok > 0 or out_tok > 0:
                turn['cloud_in_actual']  = in_tok
                turn['cloud_out_actual'] = out_tok


def parse_session(path):
    events = []
    try:
        with open(path) as f:
            for line in f:
                line = line.strip()
                if not line: continue
                try: events.append(json.loads(line))
                except: pass
    except: pass

    turn_starts = []
    for i, e in enumerate(events):
        if e.get('type') != 'message': continue
        m = e.get('message', {})
        if m.get('role') != 'user': continue
        text = extract_text(m.get('content', ''))
        if text and not is_context_injection(text):
            ts = get_event_ts(e)
            turn_starts.append((text[:70], i, ts))

    turns = []
    for t_idx, (prompt, start_i, turn_ts) in enumerate(turn_starts):
        end_i    = turn_starts[t_idx + 1][1]  if t_idx + 1 < len(turn_starts) else len(events)
        next_ts  = turn_starts[t_idx + 1][2]  if t_idx + 1 < len(turn_starts) else None

        assistants, spawn_events = [], []
        last_assistant_ts = None
        for i in range(start_i, end_i):
            e = events[i]
            if e.get('type') != 'message': continue
            m = e.get('message', {})
            if m.get('role') != 'assistant': continue
            content = m.get('content', [])
            if not isinstance(content, list): content = []
            tool_calls = [c.get('name') for c in content if isinstance(c, dict) and c.get('type') == 'toolCall']
            assistants.append((i, m, tool_calls))
            last_assistant_ts = get_event_ts(e)
            if 'sessions_spawn' in tool_calls:
                spawn_events.append((i, m))

        if not assistants:
            continue

        _, final_m, _ = assistants[-1]
        provider   = final_m.get('provider', '')
        usage      = final_m.get('usage', {})
        turn = {
            'prompt':     prompt,
            'provider':   provider,
            'out_tokens': usage.get('output', 0),
            'in_tokens':  usage.get('input', 0),
            'turn_ts':    turn_ts,
            'end_ts':     next_ts or (last_assistant_ts or turn_ts),
        }

        if is_cloud_provider(provider):
            turn['routing'] = 'CLOUD_DIRECT'
        elif spawn_events:
            turn['routing']          = 'CLOUD_HYBRID'
            turn['spawn_i']          = spawn_events[0][0]
            turn['spawn_router_in']  = spawn_events[0][1].get('usage', {}).get('input', 0)
            turn['spawn_router_out'] = spawn_events[0][1].get('usage', {}).get('output', 0)
        elif is_router_provider(provider):
            turn['routing'] = 'ROUTER'
        else:
            turn['routing'] = 'LOCAL'

        turns.append(turn)

    # Enrich ROUTER turns with SR docker log data when timestamps are available
    router_turns = [t for t in turns if t['routing'] == 'ROUTER']
    if router_turns:
        sr_events = get_sr_docker_events()
        if sr_events:
            available_sr = list(sr_events)  # consumed per-turn to prevent double-matching
            for turn in router_turns:
                t_start = turn.get('turn_ts')
                t_end   = turn.get('end_ts')
                if t_start is None:
                    continue
                # SR may log slightly before the user turn starts (-5s) or after
                # the final assistant response.  We use t_end as the boundary
                # (next user turn start or last assistant ts), capping at
                # t_start + 600 to prevent cross-session bleeding when sessions
                # are hours apart.  Add a 10s tail for log flush latency.
                win_start = t_start - 5
                win_end   = min((t_end or t_start) + 10, t_start + 600)

                # Collect all matching events from the available pool
                matched_idx = [
                    i for i, ev in enumerate(available_sr)
                    if win_start <= ev['ts'] <= win_end
                ]
                if not matched_idx:
                    continue
                matched = [available_sr[i] for i in matched_idx]

                # Remove matched events from available pool so next turn can't reuse them
                for i in reversed(matched_idx):
                    available_sr.pop(i)

                # Aggregate: group into cloud vs local by model name
                cloud_ev = [ev for ev in matched if is_sr_cloud_model(ev['model'])]
                local_ev = [ev for ev in matched if not is_sr_cloud_model(ev['model'])]

                # Prefer cloud if present (mixed turn = cloud), otherwise local
                if cloud_ev:
                    dominant = cloud_ev
                    turn['routing'] = 'SR_CLOUD'
                    turn['sr_model'] = cloud_ev[-1]['model']
                else:
                    dominant = local_ev
                    turn['routing'] = 'SR_LOCAL'
                    turn['sr_model'] = local_ev[-1]['model']

                turn['sr_cost']       = sum(ev['cost'] for ev in dominant)
                turn['sr_prompt_tok'] = sum(ev['prompt_tokens'] for ev in dominant)
                turn['sr_comp_tok']   = sum(ev['completion_tokens'] for ev in dominant)

    return turns

def print_report(session_info, turns):
    print(f"Agent   : {BOLD}{session_info['agent']}{RESET}")
    print(f"Session : {session_info['full_id']}")
    print(f"Modified: {session_info['mtime_str']}")
    print()
    print(f"{'PROMPT':<42} {'ROUTING':<16} {'COST':>10}")
    print("-" * 72)

    total_local  = 0
    total_cloud  = 0

    for turn in turns:
        routing = turn['routing']

        if routing == 'LOCAL':
            in_tok      = turn['in_tokens']
            out_tok     = turn['out_tokens']
            actual_cost = (in_tok  / 1_000_000) * LOCAL_INPUT_PER_M + \
                          (out_tok / 1_000_000) * LOCAL_OUTPUT_PER_M
            label       = f"{GREEN}LOCAL{RESET}"
            cost_str    = f"{GREEN}${actual_cost:.4f}{RESET}"
            total_local += 1

        elif routing == 'CLOUD_DIRECT':
            in_tok      = turn['in_tokens']
            out_tok     = turn['out_tokens']
            actual_cost = (in_tok  / 1_000_000) * CLOUD_INPUT_PER_M + \
                          (out_tok / 1_000_000) * CLOUD_OUTPUT_PER_M
            label       = f"{RED}CLOUD{RESET}"
            cost_str    = f"{RED}${actual_cost:.4f}{RESET}"
            total_cloud += 1

        elif routing == 'CLOUD_HYBRID':
            if 'cloud_in_actual' in turn:
                in_tok      = turn['cloud_in_actual']
                out_tok     = turn['cloud_out_actual']
                actual_cost = (in_tok  / 1_000_000) * CLOUD_INPUT_PER_M + \
                              (out_tok / 1_000_000) * CLOUD_OUTPUT_PER_M
                cost_str    = f"{RED}${actual_cost:.4f}{RESET}"
            else:
                actual_cost = None
                cost_str    = f"{RED}?{RESET}"
            label       = f"{RED}HYBRID{RESET}"
            total_cloud += 1

        elif routing == 'SR_LOCAL':
            in_tok      = turn.get('sr_prompt_tok', turn['in_tokens'])
            out_tok     = turn.get('sr_comp_tok',   turn['out_tokens'])
            sr_cost     = turn.get('sr_cost', 0.0)
            actual_cost = sr_cost if sr_cost > 0 else \
                          (in_tok / 1_000_000) * LOCAL_INPUT_PER_M + \
                          (out_tok / 1_000_000) * LOCAL_OUTPUT_PER_M
            model_tag   = turn.get('sr_model', '').split('-')[0][:8]
            label       = f"{GREEN}LOCAL({model_tag}){RESET}"
            cost_str    = f"{GREEN}${actual_cost:.4f}{RESET}"
            total_local += 1

        elif routing == 'SR_CLOUD':
            actual_cost = turn.get('sr_cost', 0.0)
            model_tag   = turn.get('sr_model', '').split('/')[-1][:8]
            label       = f"{RED}CLOUD({model_tag}){RESET}"
            cost_str    = f"{RED}${actual_cost:.4f}{RESET}"
            total_cloud += 1

        else:  # ROUTER -- no docker data
            label    = f"{CYAN}ROUTER{RESET}"
            cost_str = f"{CYAN}?{RESET}"

        print(f"{turn['prompt'][:41]:<42} {label:<24} {cost_str:>20}")

    print("-" * 72)
    print()

    local_turns  = sum(1 for t in turns if t['routing'] in ('LOCAL', 'SR_LOCAL'))
    cloud_turns  = sum(1 for t in turns if t['routing'] in ('CLOUD_DIRECT', 'SR_CLOUD'))
    hybrid_turns = sum(1 for t in turns if t['routing'] == 'CLOUD_HYBRID')
    router_turns = sum(1 for t in turns if t['routing'] == 'ROUTER')

    summary_parts = []
    if local_turns:  summary_parts.append(f"{GREEN}{local_turns} LOCAL{RESET}")
    if cloud_turns:  summary_parts.append(f"{RED}{cloud_turns} CLOUD{RESET}")
    if hybrid_turns: summary_parts.append(f"{RED}{hybrid_turns} HYBRID{RESET}")
    if router_turns: summary_parts.append(f"{CYAN}{router_turns} ROUTER(?){RESET}")
    print(f"{BOLD}Summary{RESET}  {len(turns)} turns  ({' / '.join(summary_parts)})")

    local_cost = sum(
        (t.get('sr_cost', 0.0) if t['routing'] == 'SR_LOCAL' else
         (t['in_tokens'] / 1_000_000) * LOCAL_INPUT_PER_M +
         (t['out_tokens'] / 1_000_000) * LOCAL_OUTPUT_PER_M)
        for t in turns if t['routing'] in ('LOCAL', 'SR_LOCAL')
    )
    cloud_cost = 0.0
    for t in turns:
        r = t['routing']
        if r == 'CLOUD_DIRECT':
            cloud_cost += (t['in_tokens']  / 1_000_000) * CLOUD_INPUT_PER_M + \
                          (t['out_tokens'] / 1_000_000) * CLOUD_OUTPUT_PER_M
        elif r == 'CLOUD_HYBRID' and 'cloud_in_actual' in t:
            in_tok  = t['cloud_in_actual']
            out_tok = t['cloud_out_actual']
            cloud_cost += (in_tok  / 1_000_000) * CLOUD_INPUT_PER_M + \
                          (out_tok / 1_000_000) * CLOUD_OUTPUT_PER_M
        elif r == 'SR_CLOUD':
            cloud_cost += t.get('sr_cost', 0.0)
    print(f"  Local cost : {GREEN}${local_cost:.4f}{RESET}")
    print(f"  Cloud cost : {RED}${cloud_cost:.4f}{RESET}")
    print(f"  Total      : {BOLD}${local_cost + cloud_cost:.4f}{RESET}")
    print()
    print(f"{DIM}Rates: LOCAL ${LOCAL_INPUT_PER_M}/M in · ${LOCAL_OUTPUT_PER_M}/M out · CLOUD ${CLOUD_INPUT_PER_M}/M in · ${CLOUD_OUTPUT_PER_M}/M out{RESET}")

if agents_dir is None:
    print("No OpenClaw session files found. Tried:")
    for p in _not_found:
        print(f"  {p}")
    print("Pass the agents dir explicitly: bash token_cost.sh <path>")
    print("Hint: look for a directory containing  */sessions/*.jsonl")
    sys.exit(1)

selected = find_latest_session(agents_dir)
if not selected:
    print(f"No session files found under {agents_dir}")
    sys.exit(0)

try:
    while True:
        # always re-resolve the latest session in case a new one started
        latest = find_latest_session(agents_dir)
        if latest:
            selected = latest
        turns = parse_session(selected['path'])
        enrich_hybrid_turns(turns, agents_dir, selected['agent'])
        try:
            selected['mtime'] = os.path.getmtime(selected['path'])
            selected['mtime_str'] = datetime.datetime.fromtimestamp(
                selected['mtime']).strftime('%Y-%m-%d %H:%M')
        except: pass
        print('\033[2J\033[H', end='', flush=True)
        print_report(selected, turns)
        print(f"{DIM}(updates every 3s, Ctrl+C to exit){RESET}   ", flush=True)
        time.sleep(3)
except KeyboardInterrupt:
    print(f"\n{RESET}")
PY
