---
paths:
  - "**/migrations/**"
  - "**/migrate/**"
  - "**/*.sql"
---

# Migrations are append-only

**Never modify a migration that may already be applied.** It's a historical record of a schema
change that has run in other environments — editing it makes their state diverge from yours, and
the drift surfaces far from the change.

To alter the schema, add a **new** migration. To fix a bad migration that already shipped, write
a forward migration that corrects it — don't rewrite history.
