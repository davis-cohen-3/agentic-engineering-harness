---
name: grill-with-docs
description: A relentless interview to sharpen a plan or design, which also creates docs (ADR's and glossary) as we go.
disable-model-invocation: true
---

Run a `/grilling` session, using the `/domain-modeling` skill.

Before the first question:

- Read the repository's agent instructions and documentation index when they exist.
- Identify the canonical glossary, current-implementation documentation, ADR/decision path, and product/design authority.
- Read the relevant code and documentation so factual questions are investigated rather than delegated to the user.

During the interview:

- Use the repository's existing terminology and challenge conflicts with its canonical glossary.
- Keep current code, intended product behavior, and local implementation decisions distinct.
- Record resolved terms and qualifying decisions in their owning documents; do not create parallel context or decision files.

Before ending:

- Reconcile the resolved model against the relevant code.
- Review the changed documents for claims that are false, duplicated, or owned elsewhere.
- Report changed files and unresolved code/specification/documentation conflicts.
