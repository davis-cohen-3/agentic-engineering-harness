# Skill catalog research — 2026-08-07

## Question

How should the harness combine Matt Pocock's engineering skills, Lada Kesseler's TDD skill,
the existing harness skills, Claude Code's bundled capabilities, and project-specific workflow
conventions without making every session heavy?

## Primary sources

- [Matt Pocock's skills repository](https://github.com/mattpocock/skills)
- [Matt's plugin manifest](https://github.com/mattpocock/skills/blob/main/.claude-plugin/plugin.json)
- [Matt's `grill-with-docs`](https://github.com/mattpocock/skills/blob/main/skills/engineering/grill-with-docs/SKILL.md)
- [Matt's `wayfinder`](https://github.com/mattpocock/skills/blob/main/skills/engineering/wayfinder/SKILL.md)
- [Matt's `teach`](https://github.com/mattpocock/skills/blob/main/skills/productivity/teach/SKILL.md)
- [Matt's `ask-matt` routing](https://github.com/mattpocock/skills/blob/main/skills/engineering/ask-matt/SKILL.md)
- [Lexler / Lada Kesseler's TDD skill](https://github.com/lexler/skill-factory/tree/main/output_skills/testing/tdd)
- [Claude Code commands](https://code.claude.com/docs/en/commands)
- [Claude Code skills](https://code.claude.com/docs/en/slash-commands)
- [Anthropic's official plugin marketplace](https://github.com/anthropics/claude-plugins-official)

## Findings

### Matt Pocock

Matt's current collection is designed for progressive disclosure: skill descriptions are cheap at
startup and full instructions load only when a skill is used. The collection also separates
user-invoked workflows from model-invoked reusable discipline. Its managed Claude plugin and its
editable `skills.sh` installation are different distribution models; the harness should not install
both copies.

The user's requested skills fit as follows:

| Skill | Proposed layer | Reason |
|---|---|---|
| `grilling`, `grill-me` | machine/core | General interview primitive and stateless planning interview. |
| `grill-with-docs` | project/core | Reads the repo's authority, writes the project glossary and ADRs. |
| `wayfinder` | project/area | Needs an issue tracker and is only for large, foggy efforts. |
| `teach` | area/optional | Creates a stateful teaching workspace; not normal coding context. |
| `setup-matt-pocock-skills` | project bootstrap | Configures tracker and domain-document paths once per repo. |
| `domain-modeling` | project/model-invoked | Vocabulary and ADR discipline used beneath other workflows. |
| `research`, `prototype`, `code-review` | project/optional | Useful, but their side effects and cost belong in project policy. |
| `ask-matt`, `writing-for-agents`, `handoff`, `wait-what` | machine/core or optional | Routing, agent-document guidance, context handoff, and clarification. |

`grill-with-docs` should be the normal front door for a codebase change; `wayfinder` is an on-ramp
only when the work is too large or unclear for one session. `teach` should remain explicitly
user-invoked.

### Lexler TDD

The upstream TDD skill is under `output_skills/testing/tdd/`, has no runtime dependencies, and
includes `references/zombies.md`. It adds compile-first stubs, one-test-at-a-time red/green/refactor,
and a check for tests that never genuinely went red.

The existing harness TDD skill already has the right local exclusions for docs/config/mechanical
edits and includes the ZOMBIES reference. These should be merged into one canonical `tdd` skill,
not installed under a second name. The source repository is Apache-2.0, so copied or substantially
derived text must preserve attribution and license information.

### Claude Code capabilities

- `/simplify` is bundled in Claude Code and should be used directly; do not add a competing custom
  simplifier by default.
- `/debug` is the built-in runtime diagnosis flow. The harness's existing `diagnose` skill is more
  disciplined for hard bugs, so the two should be routed rather than duplicated.
- There is no official `e2e-test` skill name. `/run`, `/verify`, and the optional Playwright plugin
  cover live-app verification. Keep E2E user-invoked and separate from the normal test suite.
- There is no official `/ship` or `/make-pr`. Anthropic's `commit-commands` has an explicit
  `/commit-push-pr`; the harness should expose one explicit final workflow, not two overlapping
  commands.
- `frontend-design` is an official plugin and belongs in a UI-capable project's optional area pack,
  not in the universal core.
- Claude Code has built-in `/security-review` and official `security-guidance` / `claude-security`
  plugins. High-risk orchestrators should use Opus; cheap inventory passes can remain on cheaper
  models.
- LSP is delivered through language-specific official plugins and activates automatically. Install
  only the language servers a project actually uses.

### Existing project/workspace conventions

The existing Melting v2 contract points agents to `docs/INDEX.md`, implementation docs, the relevant
spec, and (when Depot initializes it) untracked `.workspace/workspace.md`. Depot's ADRs establish
`.workspace/` as optional provider-neutral worktree memory, distinct from operational state. This
belongs in project/workspace documentation and root `AGENTS.md` routing, not in a vendor skill.

## Merge constraints

1. Keep the machine/root contract small; skill bodies remain on-demand.
2. Keep project-specific tracker, glossary, ADR, command, and worktree paths in project docs.
3. Merge overlapping skills by canonical name rather than installing duplicates.
4. Mark side-effectful workflows (`wayfinder`, `teach`, shipping, E2E, security scans) as
   user-invoked.
5. Make the normal ship path run the project's standard test/typecheck suite and explicitly omit
   E2E unless the user asks for it.
