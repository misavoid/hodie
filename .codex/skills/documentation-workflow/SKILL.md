# documentation-workflow

## Purpose
Enforce the repository documentation workflow in `docs/` using `_plan` and `_done` files. Plans live in `docs/plan/` and completed docs live in `docs/done/`. This skill is the single source of truth for documentation process rules.

## Trigger Conditions
Apply this skill whenever work includes any of the following:
- Creating, editing, renaming, or reviewing files in `docs/`
- Updating plans, shipped notes, open loops, or follow-ups
- Completing work that changes documented status or next steps
- Requests to update docs, write plans, or mark work as done

## Required Workflow
Follow this checklist in order:

1. Scope
- Identify the documentation topic and matching file prefix in `docs/`.

2. Read context
- Read the active `docs/plan/<topic>_plan.md` when present.
- Read the newest related `docs/done/<topic>*_done.md` when present.

3. Create technical change doc
- For every technical decision or technical change, create a dedicated doc file in `docs/`.
- Use `docs/done/*_done.md` for shipped/completed changes and `docs/plan/*_plan.md` for planned/in-progress work.

4. Edit minimally
- Change only files required for the current task.
- Preserve existing structure and headings unless structure changes are required.

5. Maintain timestamp
- Ensure each edited workflow doc contains `> Last updated: YYYY-MM-DD` near the top.
- Set it to the actual edit date of that change.

6. Record outcomes
- Write decisions, status updates, and follow-ups in the relevant doc.
- Keep open loops in the doc where execution should continue.

7. Close plan when complete
- If a plan is fully shipped, move/rename `docs/plan/<topic>_plan.md` to `docs/done/<topic>_done.md`.
- If partially complete, keep `_plan.md` and update remaining tasks explicitly.

8. Report with citations
- Cite doc filenames explicitly in handoff reports.
- State where follow-ups and open loops were recorded.

## Naming Conventions
- Active work: `docs/plan/<topic>_plan.md`
- Completed work: `docs/done/<topic>_done.md`
- Keep `<topic>` stable; do not create near-duplicate topic names without a scope split.

## Last Updated Rules
- Required line near the top of each workflow doc: `> Last updated: YYYY-MM-DD`
- Update this line whenever the file changes meaningfully.
- Use ISO format only; never relative dates.

## Completion and Rename Criteria
Move/rename `docs/plan/<topic>_plan.md` to `docs/done/<topic>_done.md` only when all are true:
- Planned scope is shipped or intentionally finalized.
- Remaining tasks are none, or explicitly moved to another `_plan.md`.
- Follow-ups and open loops are recorded in the correct destination doc.
- `Last updated` is current.

## Handoff and Reporting Rules
Every documentation-related handoff must include:
- Docs read
- Docs changed
- Whether `_plan` to `_done` rename occurred
- Where follow-ups and open loops now live
- Explicit filename citations for each referenced doc

## Guardrails
- Do not modify `data/`, `sources/`, `.env`, or runtime state for documentation-only work.
- Do not rewrite unrelated sections for cleanup.
- Do not delete historical `_done` files unless explicitly requested.
- Keep edits scoped, accurate, and reversible.

## Definition of Done
Documentation is complete only if all are true:
- Relevant `_plan` and latest `_done` context were reviewed.
- A dedicated `docs/` file exists for each technical decision or technical change made in the task.
- Changed docs in `docs/` have correct `> Last updated: YYYY-MM-DD` lines.
- Status, outcomes, and follow-ups are recorded in the right doc.
- `_plan` was renamed to `_done` only when completion criteria were met.
- Final report cites exact doc filenames and follow-up location.
