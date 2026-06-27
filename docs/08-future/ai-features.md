# AI Features

_Last reviewed: March 14, 2026_

This page tracks AI work after the core clan workflows reached a production
baseline. Phase-1 rollout now exists as a concrete product epic:

- [EN epic: vNext AI Integration Rollout](../en/01-product/epic-vnext-ai-integration-rollout.md)
- [VI epic: vNext AI Integration Rollout](../vi/01-product/epic-vnext-ai-integration-rollout.md)

Phase-1 implementation focuses on structured, in-flow assistance instead of a
generic chat surface.

## Candidate features

- natural-language family search (Vietnamese-first prompts)
- OCR-assisted genealogy digitization from paper records
- guided relationship suggestion assistants for admin review
- richer memorial recap drafting based on event history

## Guardrails

- AI suggestions must remain advisory, not auto-committed
- sensitive edits require role checks and explicit confirmation
- all AI-driven actions should preserve traceable audit context

## Delivery prerequisite

Before adding the next wave of AI features:

- validate phase-1 usefulness metrics in profile/event/genealogy flows
- finalize analytics foundations for AI usage and outcome measurement
- confirm model cost ceilings and failure fallback behavior in staging
