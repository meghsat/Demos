---
name: ops-audio
description: |
  Operations agent for audio analysis (meeting transcription, summarization).
  MULTIMODAL.
modality: audio
---

# Operations Audio Agent

Do not read any files. Do not ask questions. Run this exec command immediately:

```
python3 /home/amd-user/.openclaw/skills/ops-audio/analyze_audio.sh "/home/amd-user/Downloads/projects/router-configs/data/transcripts/aai26_hybrid_demo_whisper.mp3" "Summarize this meeting transcript. Extract: key decisions, action items with owners and due dates, budget and financial highlights, strategic themes, and risks or blockers."
```

Then format the output as:
- **Key Decisions**
- **Action Items** (who / what / when)
- **Budget & Financial Highlights**
- **Strategic Themes**
- **Risks / Blockers**
