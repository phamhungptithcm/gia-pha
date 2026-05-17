# [Epic] vNext AI Integration Rollout for BeFam

_Last reviewed: April 12, 2026_

## Short conclusion

AI can be a standout BeFam feature only when it is embedded into real clan
workflows, not shipped as a generic chat tab.

The highest-value AI jobs for BeFam are:

- improving profile quality and recognizability
- drafting event and memorial copy faster
- explaining duplicate-genealogy risk before admins override creation

## Firebase AI service assessment

### Firebase AI Logic

Best for:

- low-risk client-side drafting
- lightweight in-app AI moments
- app-level AI monitoring

Not the primary rollout choice for BeFam:

- genealogy data is sensitive
- governance flows need server-side role checks and auditability

### Genkit on Firebase Functions

Best fit for phase 1:

- server-side control
- structured outputs
- audit logging
- safe fallback behavior
- minimal architecture disruption for the current Flutter + Firebase stack

### Firebase Machine Learning

Useful later, especially for:

- OCR of scanned genealogy pages
- document digitization
- image preprocessing before data entry

This is more of a phase-2 data-ingestion investment than a phase-1 retention
feature.

## Sprint rollout

### Sprint A1 - AI foundation on Firebase Functions

Implemented:

- backend AI callable layer in `firebase/functions/src/ai/callables.ts`
- runtime flags for model selection and safe enablement
- phase-1 default model set to `gemini-2.5-flash-lite` for cost control
- heuristic fallback when AI is unavailable or not configured

### Sprint A2 - AI profile quality reviewer

Implemented:

- `reviewProfileDraftAi`
- profile editor integration
- structured summary, strengths, missing items, risks, and next steps

### Sprint A3 - AI event copy drafting

Implemented:

- `draftEventCopyAi`
- event editor integration
- suggested title, description, and reminder timing

### Sprint A4 - AI duplicate genealogy explanation

Implemented:

- `explainDuplicateGenealogyAi`
- duplicate-risk explanation before override
- review checklist for admins

## Why this can become a standout feature

Yes, if BeFam keeps AI:

- task-specific
- short and actionable
- advisory only
- inside existing workflows

No, if AI becomes:

- a generic chat surface
- auto-committing data
- detached from the user’s current task

## Retention impact

The strongest retention upside is likely for:

- profile completion
- memorial/event operations
- admin genealogy setup flows

These are higher-intent moments than a standalone assistant surface.

## Required guardrails

- AI suggestions remain advisory
- sensitive writes still require explicit confirmation
- server-side role checks remain authoritative
- every AI flow keeps a safe fallback path

## Recommended next phase

- Vietnamese natural-language family search
- OCR-assisted genealogy record digitization
- relationship suggestion assistant for admin review
