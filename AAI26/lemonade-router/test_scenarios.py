"""
Workshop test script - Lemonade Semantic Router startup scenarios.

Registers each scenario policy and exercises it with prompts that demonstrate
the routing decision. Prints which model handled each request and why.

Usage:
    python test_scenarios.py                  # test all scenarios
    python test_scenarios.py --scenario 1     # test only scenario 1
    python test_scenarios.py --register-only  # register policies without running prompts
    python test_scenarios.py --skip-register  # assume policies already registered
"""

import argparse
import json
import os
import sys
from pathlib import Path

try:
    from openai import OpenAI
except ImportError:
    sys.exit("openai package not found — run: pip install openai")

import urllib.request
import urllib.error

BASE_URL = "http://localhost:13305/api/v1"
SCRIPT_DIR = Path(__file__).parent
MAX_TOKENS = 80

# ─────────────────────────────────────────────────────────────────────────────
# Scenario definitions: each has a policy file + a list of test cases
# ─────────────────────────────────────────────────────────────────────────────

SCENARIOS = [
    {
        "id": 1,
        "name": "PII Detection — HR Agent",
        "description": "Names, emails, salaries, and SSNs stay on local hardware. Complex analysis goes to capable model.",
        "policy_file": "scenario_1_pii.json",
        "model": "user.Startup-HR-Router",
        "cases": [
            {
                "name": "General HR question (no PII)",
                "prompt": "What is the typical vesting schedule for startup equity grants?",
                "metadata": None,
                "expect": "Qwen3.5-9B-GGUF (default — no PII, no complex trigger)",
            },
            {
                "name": "Onboarding with PII — name + salary + email",
                "prompt": "Onboard Maya Chen, Senior AI Engineer, starts July 1, salary $175K, equity 0.8%, email maya.chen@startup.ai",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (PII: salary $ amount + email regex)",
            },
            {
                "name": "SSN in request",
                "prompt": "Update employee SSN 123-45-6789 in the HR system for tax filing.",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (PII: SSN regex)",
            },
            {
                "name": "Complex retention analysis (no PII)",
                "prompt": "Analyze attrition trends across engineering and product teams over the last 3 quarters and recommend retention strategies.",
                "metadata": None,
                "expect": "Qwen3.5-9B-GGUF (complex analysis keywords)",
            },
        ],
    },
    {
        "id": 2,
        "name": "Complexity Tiering — Finance Agent",
        "description": "Three-tier routing: fast model for simple lookups, balanced for calculations, powerful for deep financial modeling.",
        "policy_file": "scenario_2_complexity.json",
        "model": "user.Startup-Finance-Router",
        "cases": [
            {
                "name": "Simple lookup",
                "prompt": "What is our current MRR?",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (short + 'what is' → simple-lookup rule)",
            },
            {
                "name": "Medium calculation",
                "prompt": "Calculate our burn rate given $2.4M monthly expenses and $180K in revenue.",
                "metadata": None,
                "expect": "Qwen3.5-9B-GGUF (calculate keyword → medium-analysis rule)",
            },
            {
                "name": "Deep financial model",
                "prompt": "Build a Monte Carlo model for our runway forecast incorporating variable churn, hiring ramp, and two fundraising scenarios.",
                "metadata": None,
                "expect": "fireworks.kimi-k2p6 (Monte Carlo keyword → deep-financial-modeling rule → cloud)",
            },
            {
                "name": "Cap table dilution modeling",
                "prompt": "Model cap table dilution across three term sheet scenarios: Series A at $40M pre-money, $45M, and $50M, assuming 15% option pool top-up.",
                "metadata": None,
                "expect": "fireworks.kimi-k2p6 (cap table dilution keyword → cloud)",
            },
        ],
    },
    {
        "id": 3,
        "name": "Domain Classification — Multi-Agent Dispatcher",
        "description": "Routes to different models based on detected domain: legal→powerful, HR/benefits→fast, engineering→balanced, finance→balanced.",
        "policy_file": "scenario_3_domain.json",
        "model": "user.Startup-Domain-Router",
        "cases": [
            {
                "name": "Legal — GDPR compliance",
                "prompt": "What GDPR compliance requirements apply to us as an AI vendor storing EU customer data?",
                "metadata": None,
                "expect": "fireworks.kimi-k2p6 (GDPR keyword → legal-compliance rule → cloud)",
            },
            {
                "name": "Legal — non-compete enforceability",
                "prompt": "Can we enforce non-compete clauses for employees in California under state contract law?",
                "metadata": None,
                "expect": "fireworks.kimi-k2p6 (non-compete + contract → legal-compliance rule → cloud)",
            },
            {
                "name": "HR benefits RAG",
                "prompt": "When does my 401(k) vesting cliff kick in?",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (401(k) + vesting → hr-benefits-rag rule)",
            },
            {
                "name": "Engineering — code generation",
                "prompt": "Write a Python function to calculate compound interest with monthly contributions.",
                "metadata": None,
                "expect": "Qwen3.5-9B-GGUF (function keyword → engineering-code rule)",
            },
            {
                "name": "Finance — burn analysis",
                "prompt": "What is our current runway given the Q2 burn rate?",
                "metadata": None,
                "expect": "fireworks.kimi-k2p6 (burn rate + runway → finance-analysis rule → cloud)",
            },
        ],
    },
    {
        "id": 4,
        "name": "Metadata Consent Gates — Privacy Control Plane",
        "description": "Application-layer consent flags passed in metadata control routing without touching prompt content.",
        "policy_file": "scenario_4_metadata_consent.json",
        "model": "user.Startup-Consent-Router",
        "cases": [
            {
                "name": "No consent metadata → local (fail-closed)",
                "prompt": "Summarize the employee's performance review.",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (no consent key → no-consent-recorded rule)",
            },
            {
                "name": "Consent explicitly denied → local",
                "prompt": "Draft a performance improvement plan for the engineering lead.",
                "metadata": {"data_consent": "denied"},
                "expect": "Qwen3-1.7B-GGUF (consent=denied → consent-explicitly-denied rule)",
            },
            {
                "name": "Task class = hr → local regardless of prompt",
                "prompt": "What is the standard notice period for senior engineers?",
                "metadata": {"task_class": "hr"},
                "expect": "Qwen3-1.7B-GGUF (task_class=hr → hr-sensitive-task rule)",
            },
            {
                "name": "Consent granted → capable model",
                "prompt": "Summarize our top-of-funnel hiring metrics and recommend improvements.",
                "metadata": {"data_consent": "granted"},
                "expect": "Qwen3.5-9B-GGUF (consent=granted → consented-general rule)",
            },
        ],
    },
    {
        "id": 5,
        "name": "Combined Startup Router — All Rules Together",
        "description": "Full policy: PII first (hard-local), legal→powerful, simple-RAG→fast, complex-analysis→powerful, benefits→fast, code→balanced.",
        "policy_file": "scenario_5_combined_startup.json",
        "model": "user.Startup-Full-Router",
        "cases": [
            {
                "name": "HR onboarding with PII → local (first rule wins)",
                "prompt": "Onboard Jordan Lee, ML Platform Engineer, starts August 1, salary $162K, equity 0.6%, email jordan.lee@startup.ai",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (PII rule fires first — salary $162K + email)",
            },
            {
                "name": "Consent denied + coding prompt → local (PII rule wins)",
                "prompt": "Write a Python function to export employee salary data to CSV.",
                "metadata": {"data_consent": "denied"},
                "expect": "Qwen3-1.7B-GGUF (consent=denied triggers PII rule before code rule)",
            },
            {
                "name": "GDPR compliance → powerful",
                "prompt": "What GDPR obligations apply to an AI vendor under EU privacy law?",
                "metadata": None,
                "expect": "Qwen3.5-35B-A3B-Q4-K-M-GGUF (GDPR → legal-to-powerful rule)",
            },
            {
                "name": "Benefits RAG — simple and short → fast local",
                "prompt": "Does the handbook cover parental leave?",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (short + 'does the' → simple-rag-lookup rule)",
            },
            {
                "name": "Retention forecast modeling → cloud",
                "prompt": "One of our engineers got a competitor offer in Q1 and we took no action. Based on what worked best historically, what retention intervention should we make now and what does it cost us through year end?",
                "metadata": None,
                "expect": "fireworks.kimi-k2p6 (retention analysis + recommend intervention → complex-analysis rule → cloud)",
            },
            {
                "name": "Script automation → balanced",
                "prompt": "Write a script to automate weekly Slack reminders for pending expense reports.",
                "metadata": None,
                "expect": "Qwen3.5-9B-GGUF (script + automate → code-generation rule)",
            },
            {
                "name": "401k vesting question → fast local",
                "prompt": "When does the 401k vesting cliff kick in for new hires?",
                "metadata": None,
                "expect": "Qwen3-1.7B-GGUF (401k + vesting → benefits-hr-policy rule)",
            },
        ],
    },
]

# ─────────────────────────────────────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────────────────────────────────────

def register_policy(policy_path: Path) -> bool:
    with open(policy_path, "rb") as f:
        data = f.read()
    req = urllib.request.Request(
        f"{BASE_URL.rstrip('/v1').rstrip('api')}/api/v1/pull",
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    # Build URL correctly
    url = "http://localhost:13305/api/v1/pull"
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read().decode()
            return resp.status in (200, 201)
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        print(f"    ERROR {e.code}: {body[:200]}")
        return False
    except Exception as e:
        print(f"    ERROR: {e}")
        return False


def run_case(client: "OpenAI", model: str, case: dict) -> dict:
    extra_body = {"route_trace": True}
    if case.get("metadata"):
        extra_body["metadata"] = case["metadata"]

    raw = client.chat.completions.with_raw_response.create(
        model=model,
        messages=[{"role": "user", "content": case["prompt"]}],
        max_tokens=MAX_TOKENS,
        temperature=0.0,
        extra_body=extra_body,
    )
    header_route = raw.headers.get("x-lemonade-route", "<missing>")
    body = raw.http_response.json()
    decision = body.get("x_lemonade_route", {})
    return {
        "header_route": header_route,
        "route_to": decision.get("route_to", "<missing>"),
        "matched_rule": decision.get("matched_rule", "<missing>"),
        "default_used": decision.get("default_used", False),
        "outputs": decision.get("outputs", {}),
        "trace": decision.get("trace", []),
    }


def print_case_result(case: dict, result: dict):
    matched = result["matched_rule"]
    routed_to = result["route_to"]
    outputs = result["outputs"]

    model_short = routed_to.split("/")[-1] if routed_to else routed_to
    rule_label = f"rule: {matched}" if not result["default_used"] else "default"
    reason = outputs.get("reason", "")
    tier = outputs.get("tier", "")

    print(f"    prompt   : {case['prompt'][:80]}{'...' if len(case['prompt']) > 80 else ''}")
    if case.get("metadata"):
        print(f"    metadata : {case['metadata']}")
    print(f"    → routed to  : {model_short}  [{rule_label}]")
    if reason:
        print(f"    → reason     : {reason}", end="")
        if tier:
            print(f"  tier={tier}", end="")
        print()
    print(f"    → expected   : {case['expect']}")
    trace = result.get("trace", [])
    if trace:
        print("    trace:")
        for t in trace:
            score = f" score={t['score']:.3f}" if "score" in t else ""
            print(f"      {'✓' if t['result'] else '✗'} {t['condition']}{score}")


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--scenario", type=int, choices=[s["id"] for s in SCENARIOS],
                    help="Run only this scenario number")
    ap.add_argument("--register-only", action="store_true",
                    help="Register policies but don't run prompts")
    ap.add_argument("--skip-register", action="store_true",
                    help="Skip policy registration (assume already registered)")
    ap.add_argument("--base-url", default=BASE_URL)
    args = ap.parse_args()

    client = OpenAI(base_url=args.base_url, api_key="lemonade")
    scenarios = [s for s in SCENARIOS if args.scenario is None or s["id"] == args.scenario]

    for scenario in scenarios:
        print()
        print("=" * 72)
        print(f"  SCENARIO {scenario['id']}: {scenario['name']}")
        print(f"  {scenario['description']}")
        print("=" * 72)

        policy_path = SCRIPT_DIR / scenario["policy_file"]

        if not args.skip_register:
            print(f"\n  [register] {scenario['policy_file']}")
            ok = register_policy(policy_path)
            if not ok:
                print("  FAILED to register — skipping scenario")
                continue
            print(f"  [register] OK → model={scenario['model']}")

        if args.register_only:
            continue

        print()
        for i, case in enumerate(scenario["cases"], 1):
            print(f"  [{i}/{len(scenario['cases'])}] {case['name']}")
            try:
                result = run_case(client, scenario["model"], case)
                print_case_result(case, result)
            except Exception as e:
                print(f"    ERROR: {e}")
            print()

    print("\nDone.")


if __name__ == "__main__":
    main()
