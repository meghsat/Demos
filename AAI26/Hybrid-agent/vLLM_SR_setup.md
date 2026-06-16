# vLLM Semantic Router Setup

## Install

```bash
curl -fsSL https://vllm-semantic-router.com/install.sh | bash
pip install huggingface_hub hf_transfer --break-system-packages
```

## Download SR Models

```bash
hf download llm-semantic-router/mmbert32k-pii-detector-merged       --local-dir models/mmbert32k-pii-detector-merged/
hf download llm-semantic-router/mmbert32k-intent-classifier-merged   --local-dir models/mmbert32k-intent-classifier-merged/
hf download llm-semantic-router/mmbert32k-jailbreak-detector-merged  --local-dir models/mmbert32k-jailbreak-detector-merged/
```

## Configure

Create a config file, then set the state root directory (config files and `models/` directory go here):

```bash
export VLLM_SR_STATE_ROOT_DIR=${HOME}/Downloads/projects/router-configs
```

## Docker setup

```bash
docker pull ghcr.io/vllm-project/semantic-router/vllm-sr:latest
```

## Run

```bash
vllm-sr serve --config $VLLM_SR_STATE_ROOT_DIR/config_9B_kimik2p6.yaml --image-pull-policy never
vllm-sr dashboard
```

---

## Troubleshooting

**Config file not picked up** — verify the path is correct and the file exists at that location.

---

## Logs

**Follow live routing decisions:**
```bash
docker logs vllm-sr-router-container --follow 2>&1 \
  | grep --line-buffered '"routing_decision"\|"model_dispatch_failed"\|"looper_execution_completed"'
```

**Confirm which upstream Envoy used (cloud vs local):**
```bash
docker exec vllm-sr-envoy-container tail -f /var/log/envoy_access.log
```

**Jailbreak/PII signal scores:**
```bash
docker logs vllm-sr-router-container --since 10m 2>&1 | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        if d.get('msg') == 'router_replay_start' and d.get('decision') == 'route_security_guard':
            print(d.get('ts'), 'jailbreak/PII confidences:', {k:v for k,v in d.get('signal_confidences',{}).items() if 'jailbreak' in k or 'pii' in k})
    except: pass
"
```

**Routing decision summary (last hour):**
```bash
docker logs vllm-sr-router-container --since 1h 2>&1 | python3 -c "
import sys, json
from collections import Counter
c = Counter()
for line in sys.stdin:
    try:
        d = json.loads(line.strip())
        if d.get('msg') == 'routing_decision':
            c[(d.get('decision','?'), d.get('selected_model','?'))] += 1
    except: pass
for (dec, model), n in c.most_common(): print(f'{n:4d}x  {dec}  →  {model}')
"
```
