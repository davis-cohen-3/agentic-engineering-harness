---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

STARTER_CHARACTER = 🔎 — open each reply with it while this skill is active.

Spin up a **background agent** to do the research, so you keep working while it reads.

Its job:

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. Write the findings to a single Markdown file, citing each claim's source.
3. Save it as a `finding` record in the worktree's task memory. Do NOT choose the filename yourself — run `workspace-record finding <slug>`, which creates `.workspace/history/<utc>-finding-<slug>.md` atomically and prints the path. Records are immutable; if the research is superseded, write a new one rather than editing the old.
4. Large raw evidence (a full API dump, a long transcript) goes in `.workspace/artifacts/` via `workspace-record artifact <name>` and is *linked* from the finding — artifacts are write-once, so an immutable record can never come to reference mutated evidence.
