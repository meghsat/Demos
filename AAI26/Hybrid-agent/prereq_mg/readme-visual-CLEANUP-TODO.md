# Workshop Readme — Manual Cleanup Checklist

This is the manual work to do AFTER the visual-cue pass. I kept all your original
content intact and only added banner cues + a workspace map. The items below are the
dedup / restructure recommendations you asked for — do these by hand so you stay in
control of wording.

## 0. Required before anything renders

- [ ] **Upload the 5 banner PNGs** from `Downloads/workshop-banners/` to S3 (same
      bucket/flow you use for the screenshots):
      `band-browser.png`, `band-terminal.png`, `band-newtab.png`, `band-tui.png`,
      `band-newsession.png`
- [ ] **Replace the `{{BANNER_URL}}` placeholder** in `readme-visual.md` with the S3
      folder URL where you uploaded them. One find-and-replace covers all cues.
      (If the portal upload tool renames files to hashes, instead replace each
      `{{BANNER_URL}}/band-xxx.png` with that image's individual hashed URL.)
- [ ] Confirm the banners render at full width in the portal preview. If the portal
      strips the `![alt](url)` width, they'll still show — they're sized 2400x240 so
      they scale down cleanly.

## 1. Duplicate content to consolidate

- [ ] **Duplicate "Tip: Paste button" note.** It appears twice (top of Lab Setup, and
      again right after the "Introduce yourself" step). Keep the first one, delete the
      second — or move a single copy into the new "Your Workshop Workspace" section.
- [ ] **Repeated `openclaw tui --session workshop` launch block** appears 3x (Setup
      step 7, Act 1 before 1a, Act 1b). Now that the workspace map explains "Terminal 2
      is your TUI tab", the 2nd and 3rd copies can become a short "return to Terminal 2"
      line instead of repeating the full command + Paste button.
- [ ] **Repeated Lemonade "View > Logs" screenshot + instruction** appears 3x (Setup,
      Meet the Startup Agent, and referenced again in 1b/HR). Consider keeping it once
      in the workspace/browser setup and referencing it afterward.
- [ ] **Repeated vLLM SR + Lemonade dashboard URLs** (localhost:8700 / :13305) are
      pasted in multiple places. Fine to keep, but the "Meet the Startup Agent"
      dashboard block largely repeats the Setup block — trim to a one-line reminder.
- [ ] **`/model` picker instructions repeat 4x** across HR/Benefits sections with the
      same two screenshots. Consider a single "How to switch models" callout early on,
      then just say "switch to Kimi K2.6 / MoM via `/model`".

## 2. Numbering / structure inconsistencies

- [ ] Lab Setup uses a single 1-7 list, but Act 1 / HR sections restart at **1., 2.**
      locally. Decide on one scheme (global step numbers, or per-section 1/2/3) so
      participants don't confuse "step 1" of HR with "step 1" of Setup.
- [ ] The Startup Agent agents are numbered **1-4 (HR, Benefits, Finance, Legal)** but
      Finance/Legal drop the "Try Cloud first / Now try Router" two-step pattern that
      HR/Benefits use. Either add the pattern to Finance/Legal or note why they differ.
- [ ] "In a second terminal" wording in the Challenges section (tokenomics) should now
      say **Terminal 3 — Tokenomics Monitor** to match the workspace map.

## 3. Wording to align with the new workspace model

- [ ] Replace remaining ambiguous "in a fresh terminal" / "in a new terminal" phrases
      with the specific tab name (Terminal 1 / 2 / 3). I added banner captions for the
      main ones; sweep the body text for leftovers.
- [ ] The `workshop2` step still says "in a new terminal" in the body text while the
      banner says "start a new session (in Terminal 2)". Pick one — recommended:
      reuse Terminal 2, exit the old session, start `workshop2`. Update body text to match.
- [ ] Decide whether config-set / gateway restart / `cat SOUL.md` truly need a
      separate tab, or can run in Terminal 1. I mapped them to Terminal 1 — verify the
      start scripts don't block that tab. If they do, promote Terminal 1 usage to a
      4th tab and update the map + rule-of-thumb count.

## 4. Nice-to-haves (optional)

- [ ] Add a tiny legend row (the 5 bands) as an image strip in the portal sidebar if
      the platform supports it, so the key is always visible.
- [ ] Consider a "You are here" mini-map per Act (Browser / T1 / T2 / T3 highlighted).
- [ ] If the portal supports it, wrap each band + its command block in a bordered
      container so it's visually obvious the band belongs to the step beneath it.

## Files produced this pass

- `readme-visual.md` — enhanced workshop doc (original `readme (6).md` left untouched)
- `workshop-banners/band-*.png` — the 5 cue banners to upload
- `readme-visual-CLEANUP-TODO.md` — this checklist
