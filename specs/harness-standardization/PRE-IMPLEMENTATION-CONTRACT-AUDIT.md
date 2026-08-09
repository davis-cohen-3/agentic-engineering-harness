> ## ⚠ SUPERSEDED — historical
>
> This audit did its job: it blocked implementation and forced the second decision pass. Every
> finding has been adjudicated and every blocking decision answered in
> [`DECISIONS-PENDING.md`](./DECISIONS-PENDING.md), which is now the authority.
>
> **Findings that were confirmed and are now decided:** installation/propagation ownership (1),
> Codex hook parity (2), orientation (3), the `wt` contract (4), the MISSION write rule (5), the
> unnormalized DEC record (6), Wave 0 omissions (7), the PR-bot claim (8), the security-review
> contradiction (9), history collision (11), cleanup semantics (12), fail-open behaviour (13), and
> the two overstatements (14).
>
> **Findings this audit got wrong:** its skill count in finding 10 says nine unversioned skills — it
> is **ten**, `hot-mac` was missed. Its finding 7 lists `simplify` and plugin/LSP conformance as Wave
> 0 gaps; `simplify` is a builtin already dispositioned, and the LSP claim was struck rather than
> implemented.
>
> **Not read here:** this audit predates the discovery that `~/.config/depot/projects.yaml` exists,
> that Claude has a `WorktreeCreate` hook, and that there are 101 secondary worktrees.
>
> Harvest evidence from it; do not execute its recommendations. *Bannered 2026-08-08.*

# Pre-implementation contract audit

**Status:** Superseded — historical. Originally blocking.  
**Reviewed:** 2026-08-08.  
**Implementation posture:** Do not begin harness, machine, Depot, worktree, workspace, or project migration work until the blocking decisions in this audit are resolved and the controlling documents are reconciled.

This report audits [CONTRACT.md](./CONTRACT.md) and the DEC-1 through DEC-15 evidence in
[HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md](./HARNESS-DEPOT-OPERATIONAL-DESIGN-REVIEW.md)
against the current machine and repository state.

It is a design review, not an implementation plan. The core operating model is coherent, but the
contract is not implementation-ready.

## Overall conclusion

Keep the central architecture:

- Depot remains a harness-agnostic operational cockpit.
- The harness owns untracked, per-worktree .workspace/ memory.
- Tracked specs are the build contract.
- docs/ contains durable repository truth only.
- Claude and Codex consume the same project intent through thin provider adapters.
- Worktrees isolate mutable task state while committed specs, issues, and PRs coordinate work.

Do not implement it yet. The missing pieces are concentrated in propagation, provider adapters,
orientation/resumption, worktree creation, mutation rules, shipping, and cleanup ownership.

## Ranked findings

### 1. Critical — no complete installation or propagation mechanism

**Type:** Missing owner / internally incomplete.

The contract does not assign ownership for:

- rewriting adopt-harness and its copy manifest;
- replacing make install-global;
- installing wt onto PATH;
- publishing the versioned harness source into ~/.agents/;
- installing project-layer skills for both providers;
- updating an already-adopted repository safely;
- collision, rollback, and idempotence behavior.

The current mechanisms would reproduce the retired harness:

- Makefile copies .claude/{skills,agents,commands} directly into Claude's home.
- adopt-harness/copy.sh still copies FLOOR.md, agent_docs/, old spec companions, and the old
  Makefile model.
- It creates neither a project .agents/skills adapter nor an equivalent complete Codex project
  surface.

Codex discovers repository skills under .agents/skills, including symlinked folders. It does not
discover a project's .claude/skills merely because that directory exists.

**Breakage:** Wave 1 can create a canonical ~/.agents/ tree that nothing knows how to update.
Newly adopted projects remain Claude-first. Project skills such as ship and wayfinder remain
invisible to Codex.

**Required decision:** Define, before Wave 1:

1. the versioned source layout inside the harness repository;
2. an atomic machine installer/updater for ~/.agents/;
3. the project adoption manifest;
4. the Codex project skill adapter;
5. update, collision, and rollback behavior.

### 2. Critical — Codex hook parity is not achieved by registration alone

**Type:** Factually wrong and operationally unsafe.

Codex supports a broadly compatible lifecycle vocabulary, but edit-hook payloads are not identical
to Claude's:

- Codex edits occur through apply_patch.
- Edit and Write aliases can match that tool.
- Codex reports the patch in tool_input.command.
- The current Claude protect-secrets and flag-comment-bloat scripts expect tool_input.file_path,
  content, or new_string.

Registered unchanged, those scripts generally no-op on Codex edits. The Bash guardrails are more
portable because both providers expose tool_input.command.

Codex also requires review and trust of each exact hook definition. A changed hook hash is skipped
until trusted. The migration sequence does not own that ceremony.

**Breakage:** The migration can report hook parity while Codex still lacks effective edit-time
secret protection and inspection.

**Required decision:** Treat portable hook logic and provider input adapters separately. Add
provider-specific fixture tests for every event and include final Codex hook trust in Wave 1.

### 3. Critical — orientation and handoff resumption have no owner

**Type:** Missing component / internally incomplete.

DEC-2 calls orientation a harness skill, but:

- no orient skill appears in the catalog;
- section 9 says only wt, ensure-workspace.sh, and grill are missing;
- Wave 0 does not author an orientation skill;
- the journey says orientation reads only MISSION.md and Git;
- the builder does not read history by default.

At the same time, history is supposed to contain the two things another session must find. Nothing
helps the next session find the latest handoff or a relevant finding. In particular, the handoff's
What did NOT work section is intentionally richer than MISSION.md.

**Breakage:** A later Claude or Codex session may see the mission and spec but miss the handoff,
repeat failed work, and never discover findings.

**Required decision:** Add a core orient skill that reads Git, MISSION.md, the active spec, the
latest handoff, and a concise finding index; or require MISSION.md to link the latest handoff.
The builder still should not read the entire history by default.

### 4. Critical — wt is not yet an executable contract

**Type:** Missing owner / incomplete interface.

The contract does not define:

- how the project argument resolves to a repository and worktree root;
- whether Depot's registry is an optional adapter or a required dependency;
- default base branch or commit behavior;
- how parallel worktrees start from a committed spec branch;
- target-directory naming and collisions;
- repositories without origin;
- repositories without a Makefile or setup target;
- repositories that have never adopted the harness;
- behavior for a non-Git directory;
- rollback when Git succeeds but setup fails;
- how wt is installed onto PATH.

Using Depot's registry unconditionally would contradict the requirement that the harness remain
usable without Depot. Accepting only a project name implies another registry that no decision owns.

The parallel-spec rule says to commit a spec before opening additional worktrees, but the shown wt
syntax has no base-ref option. An unmerged spec commit is not visible to a worktree created from
origin/main.

**Breakage:** The first journey step, fresh-machine use, unadopted repositories, and parallel T3
execution are undefined.

**Required decision:** A minimal interface should accept a repository path or optional alias, a
branch, and an optional base ref. It must validate Git, initialize .workspace/, run setup only when
configured, and have one explicit setup-failure policy.

### 5. High — the exact-two MISSION.md writes rule contradicts the journey

**Type:** Internally inconsistent.

The contract says MISSION.md is written exactly:

1. before a handoff;
2. at session end.

The journey requires additional writes:

- ensure-workspace.sh creates it;
- step 6 changes state and spec;
- moving to shipped or abandoned requires another transition.

Saying that changing state or spec is that edit does not identify which of the two moments it belongs
to. A planning session can move to building long before a handoff or session end.

Session end is also not reliably an agent-observable boundary. A provider's SessionEnd hook can run
after the model can no longer update semantic state.

**Breakage:** MISSION.md will regularly be stale despite a seemingly precise obligation.

**Required decision:** Distinguish:

- initializer creation;
- immediate state/spec transitions;
- synchronization before handoff;
- synchronization during an explicit close action;
- accepted staleness after an abrupt end.

### 6. High — the fifteen-decision record is not internally normalized

**Type:** Internally inconsistent in the resolved DEC section.

Conflicting pairs:

- DEC-2 assigns spec binding to a harness command; DEC-6 deletes every binding command.
- DEC-2 requires export before removal; DEC-8 rejects export and gives removal zero workspace
  obligation.
- DEC-3 still calls LOG.md input to scoping synthesis; DEC-5 deletes the scoping document and
  synthesis step.
- DEC-4 says spec becomes {path, commit}; DEC-6 makes it a plain path.
- DEC-4 permits reporting spec drift; DEC-6 deletes drift detection.
- DEC-4's exact-two writes rule conflicts with initialization and DEC-15 journey step 6.

The final contract repairs plain-path binding and no-export behavior, but still says orientation
reports drift after rejecting drift detection.

**Breakage:** An implementer reading the evidence section can reasonably build the wrong pointer,
export, or drift behavior.

**Required decision:** Mark stale clauses inside DEC-2, DEC-3, and DEC-4 as superseded by the later
decision. Define drift narrowly as mission/path inconsistency, or remove the term.

### 7. High — Wave 0 omits contract-required rewrites

**Type:** Migration sequence incomplete.

Missing from Wave 0:

- adopt-harness and its manifest;
- install-global;
- open-a-pr's required LOG.md-to-PR-body behavior;
- an orient skill;
- project .agents/skills discovery for Codex;
- E2E, which is promised but does not currently exist;
- a disposition for simplify;
- plugin/LSP installation or conformance;
- removal of automatic ADR creation from write-plan.

The current write-plan skill tells the agent to create qualifying ADRs automatically, contrary to
the promotion policy. The current open-a-pr skill does not read LOG.md.

**Breakage:** A completed Wave 0 could still write ADRs silently, lose decisions at shipping, and
propagate the retired structure.

### 8. High — the PR-review-bot claim is factually wrong

**Type:** Factually wrong.

Smoke Screen has a real automatic review job on PR open and synchronize. Melting v2 does not
replicate it: its Claude workflow is mention-triggered. The harness and Depot currently have no
equivalent workflow.

The Smoke Screen implementation also depends on a GitHub App and repository secrets.

**Breakage:** Journey step 10 exists only for Smoke Screen today.

**Required decision:** Make PR review an optional declared project capability, or include bot setup
and secret provisioning in every adopted project's acceptance criteria.

### 9. High — DEC-12 and DEC-14 disagree about security review

**Type:** Internally inconsistent.

DEC-12 justifies Opus because reviewer-security runs only on risk hotspots. The current agent says it
must trigger whenever a diff touches a hotspot. DEC-14 removes reviewer-security from the mandatory
flow and makes it explicitly invoked. Wave 0 changes only its model, leaving the trigger language.

**Breakage:** Agents cannot know whether a hotspot must receive security review.

**Required decision:** Recommended: generic reviewer optional; security reviewer mandatory only for
declared hotspots. If both are optional, rewrite the agent description and cost rationale.

### 10. Medium — several machine assertions are overstated

**Type:** Factually wrong, but recoverable.

Observed skill sets:

- ~/.agents/skills: 11
- ~/.codex/skills: 9 user skills
- Claude skills: 20

Their union does not exactly equal Claude's set:

- union-only: hatch-pet;
- Claude-only: hot-mac.

Eight of the nine skills under ~/.codex/skills also have identical unversioned copies under Claude.
Only hatch-pet exists solely under Codex.

Therefore:

- nine skills live only under Codex is false;
- nine skills have no versioned source is true;
- they can still be lost if provider trees are replaced without reconciliation.

Codex has no universal machine safety hooks, but Depot and Smoke Screen already register project
Codex safety hooks. No-safety-hooks-at-all is too broad.

**Required decision:** Snapshot and checksum all three trees. Describe the risk as unversioned
sources, not Codex-only files.

### 11. Medium — history is not guaranteed collision-free or fully immutable

**Type:** Internally inconsistent / under-specified.

The filename format <utc>-<type>-<slug>.md has no required timestamp precision or random component.
Two sessions can select the same type and slug within the same timestamp unit.

The contract also says MISSION.md is the only file that may be overwritten, while artifacts/ has no
mutability rule. An immutable finding linked to an overwritten artifact does not preserve immutable
evidence.

**Required decision:**

- require nanosecond precision plus a random suffix, or another collision-safe identifier;
- make artifacts write-once and uniquely named or content-addressed;
- correct an old finding through a new record referencing it.

### 12. Medium — abandoned, duplicate building, and cleanup states have no consumer

**Type:** Missing behavior; partly an intentional judgment.

Two worktrees can both claim state: building for the same spec. Nothing detects or prevents it.
Depot cannot interpret state. No harness process lists abandoned worktrees, marks a mission shipped,
or notices that a finding was later fixed.

**Breakage:** Users may believe abandoned drives cleanup when it is only informational.

**Required decision:** Explicitly state that:

- duplicate building worktrees are allowed;
- abandoned has no automation;
- cleanup is initiated manually through Depot;
- workspace findings disappear unless promoted before removal.

If that is not acceptable, DEC-8 must be reopened.

### 13. Low — no validation is defensible, but fail-open behavior is unspecified

**Type:** Defensible decision, under-justified implementation contract.

A documented shape can exist without schema enforcement. The initializer can create missing files
and orientation can parse fields tolerantly.

Still required:

- outside Git: no-op;
- existing MISSION.md: never overwrite;
- malformed frontmatter: use defaults and report textually;
- absent spec path: report, never repair.

These rules are not schema validation.

### 14. Low — two factual judgments should be softened

**Type:** Overstated.

Codex plugin enablement is described as apparently global-only, but current Codex supports trusted
project .codex/config.toml layers and project overrides. Test plugin scoping before accepting a
permanent exception.

Melting's line counts and divergence are correct, but docs/architecture.md and docs/glossary.md are
substantive condensed documents. Only docs/revisit.md is an explicit migration stub.

## Verified factual baseline

The core Depot claims are accurate:

- ADR 0004 is accepted and says Depot will not initialize, validate, repair, interpret, or require
  .workspace/.
- Control-plane V1 limits worktree creation to Git and excludes setup/workspace writes.
- Depot's CLI exposes only doctor, install, and project add.
- Worktree creation is explicitly Git-only.
- src/depot/workspace/ has no tracked source modules; only stale bytecode remains.

The machine-path claims are accurate as current-state observations:

- ~/.claude is currently a symlink to /Users/daviscohen/agents/claude.
- ~/.codex and ~/.agents are real directories.
- ~/.claude/secrets.env exists with mode 600.
- ~/.config/agents/secrets.env does not yet exist.
- the global Git ignore does not yet contain .workspace/.
- ~/.codex/hooks.json currently contains only the global rule-injection hook.

Melting's duplicate documentation is genuinely divergent and requires human per-file reconciliation.

## Skeptical end-to-end walkthrough

| Step | Current result before correction |
| --- | --- |
| wt project --branch ... | Fails: command does not exist and project/base/setup behavior is undefined. |
| Start Claude or Codex | ensure-workspace.sh does not exist. Codex hooks require trust. |
| SessionStart orientation | Current hook writes active-spec and creates specs/.context; target rewrite is required. |
| Orient me | No orientation skill exists; latest handoff/findings are not discovered. |
| Brainstorm then grill | grill does not exist; brainstorm still writes the old thoughts surface. |
| write-plan | Reads old surfaces and may create an ADR silently. |
| Set state/spec | Manually possible, but contradicts the exact-two-writes rule. |
| Build | Conceptually works once adapters and core skills are installed. |
| Handoff | Current skill writes old sessions paths; future orientation would not find the new record. |
| Check, verify, ship | Existing checks can run; open-a-pr does not preserve LOG.md decisions. |
| PR bot | Automatic only in Smoke Screen. |
| Merge and promotion | Conversational; no owner guarantees the conversation occurs. |
| Cleanup | Depot removal works, but no abandoned cleanup, export, or finding preservation occurs. |

Section 7 does not work end to end merely by creating the three components listed in section 9.

## Reconciliation gap

None of the legacy execution files should be run as written.

| File | Main conflict | Disposition |
| --- | --- | --- |
| plan/tasks.md | Uses ~/agents, thoughts.md, typed workspace history, scoping synthesis, Depot workspace commands, bind-with-commit, statuses, archive behavior, and a different order. | Rewrite completely. |
| README.md | Deletes the gate, makes ~/agents canonical, declares worktrees out of scope, deletes the injection hook, and retains active-spec binding. | Supersede as an execution index. |
| 01-strip-gate-and-floor.md | Deletes Makefile and replaces binding with another active-spec script. | Supersede; harvest only useful research. |
| 02-hooks.md | Adds an unsequenced lint hook and depends on task 01's removed-gate model. | Supersede pending a fresh optional-hook decision. |
| 03-e2e-skill.md | Behavior aligns, but E2E is absent from section 9 and Wave 0 and paths are stale. | Rewrite and add to Wave 0, or remove E2E from the contract. |
| 04-adopt-harness.md | Carries bind script and agent_docs, excludes required target surfaces, and lacks Codex project skill discovery. | Rewrite completely; make it a Wave 0 gate. |
| 05-machine-layer.md | Makes ~/agents canonical, points ~/.agents back to Claude, deletes injection, and excludes Codex hooks. | Supersede with a new Wave 1 migration/rollback spec. |
| 06-migrate-melting.md | Deletes Makefile and omits the required docs merge, workspace-doc rewrite, and PR bot. | Rewrite completely. |
| 07-migrate-depot.md | Contains useful audit evidence but uses an older target; the new contract also omits live Depot instruction/provider drift. | Rewrite and preserve the factual audit. |
| 08-migrate-smoke-screen-and-sweep.md | Deletes Makefile and combines a Smoke migration with an unsequenced machine sweep. | Rewrite and split into project migration plus later audit. |

No legacy file needs immediate deletion. Mark dangerous execution specs superseded until useful
evidence is incorporated and replacement tasks exist.

## Rejected-options audit

The contract lists fourteen rejected options.

| Rejected option | Audit |
| --- | --- |
| Depot owns .workspace/ | Sound and strongly supported. |
| Depot workspace commands | Sound; they do not exist and would create the wrong dependency. |
| Scoping document | Defensible; curated framing can live in the spec. |
| Thoughts, sessions, and context companions | Defensible only after LOG, handoff, orientation, and shipping are wired. |
| workspace_id | Sound today; there are no consumers. |
| Path plus commit pin and drift detection | Rejecting the commit pin is sound; rejecting all drift diagnostics is too broad. |
| Schema validation and repair | Sound for a lightweight model; tolerant behavior still needs definition. |
| Finding status fields | Decision defensible; reason wrong. Immutable records can coexist with append-only resolution events. |
| Locking or append protocol | Defensible accepted risk; filenames must still be collision-safe. |
| Export/archive | Judgment to reconsider. Findings and failed approaches can have value. |
| ~/agents canonical | Sound; retiring the near-identical path reduces operator risk. |
| Frequency-based layering | Sound; portability is a better criterion. |
| Local reviewer and security reviewer on every PR | Sound for generic review; inconsistent for declared security hotspots. |
| building namespace | Sound; specs/ already supplies the boundary. |

## Decisions that must be resolved before implementation

1. **Canonical publishing:** how the harness repository updates ~/.agents and projects.
2. **wt contract:** repository resolution, worktree root, base ref, setup failure, and unadopted
   repository behavior.
3. **Orientation/resumption:** which skill reads the latest handoff and relevant findings.
4. **MISSION mutation:** initialization, transitions, handoff, and closure semantics.
5. **Codex adapters:** project skills, hook payload translation, trust, agents, and rules.
6. **Shipping availability:** whether the PR bot is mandatory, optional, or limited to selected
   projects.
7. **Security policy:** mandatory on hotspots or entirely explicit.
8. **Cleanup semantics:** duplicate builders, abandoned worktrees, fixed findings, and accepted loss.

## Corrected blocker order

The blocker list in CONTRACT.md is incomplete. Wave 0 should still precede Wave 1, but because the
skills are unversioned—not because all nine exist only under Codex.

1. Snapshot and checksum ~/.agents, ~/.codex, and the current Claude tree.
2. Resolve the eight blocking decisions above.
3. Import every unique unversioned skill into the harness repository.
4. Build the canonical source layout, installer, adopter, project adapters, wt, initializer,
   orientation, grill, E2E, and shipping rewrites.
5. Verify a disposable repository with both Claude and Codex, including real hook payloads.
6. Generate a standalone machine-migration script with rollback.
7. Run it with neither provider actively using the directories being moved.
8. Review and trust final Codex hook hashes.
9. Migrate the harness repository, Depot, Melting, and Smoke Screen.
10. Run the complete journey, including a parallel-spec worktree and destructive cleanup.

## Proposed revised journey

1. Run wt with a repository path or optional alias, a branch, and an optional base ref.
2. The command creates the worktree, initializes .workspace/, and runs setup if configured.
3. Claude or Codex SessionStart ensures the workspace and injects concise orientation.
4. Orient reads Git, MISSION.md, the spec, the latest handoff, and a finding index.
5. Brainstorm and grill append decisions/questions to LOG.md.
6. write-plan writes the spec without silently creating docs or ADRs.
7. Commit the spec; parallel worktrees use that commit as their base.
8. Set state: building and spec immediately.
9. Build with TDD and diagnosis when applicable.
10. Handoff updates MISSION.md and writes an immutable history record.
11. Run checks and verification; invoke E2E and security review according to explicit policy.
12. Shipping copies settled decisions and unresolved findings into the PR.
13. The PR bot runs if the project declares that capability.
14. At merge, discuss durable promotion.
15. Set shipped or abandoned, explicitly accept or promote remaining findings, then use Depot's
    guarded removal.

## Implementation hold

No implementation or machine migration should start until:

- the eight blocking decisions have explicit answers;
- CONTRACT.md and its DEC evidence no longer disagree;
- plan/tasks.md and the legacy 01–08 files are reconciled;
- Wave 0 includes propagation, Codex adapters, orientation, shipping, and verification;
- a disposable end-to-end acceptance scenario is written.

After those conditions are met, the workflow should be coherent, lightweight, worktree-local, and
provider-neutral.
