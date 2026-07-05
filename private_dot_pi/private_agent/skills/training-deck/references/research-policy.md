# Research Policy

Training decks are not research dumps. Research exists to calibrate the trainer's intended message, fill gaps, and provide trustworthy grounding for definitions, mechanisms, evolution, caveats, and examples.

## Default

Research is required when the training includes external concepts, technical definitions, product capabilities, best practices, tool ecosystems, historical evolution, or public claims.

Research may be skipped only when the topic is purely internal and the user explicitly says external grounding is unnecessary.

## Research inputs

Research from three inputs:

1. **Core Seed** — what the trainer already wants to share.
2. **Audience Need** — prerequisite concepts, confusions, examples, and role-specific needs.
3. **High-trust baseline** — official or first-party sources that define the topic's terms, mechanisms, and boundaries.

## Trust tiers

Prefer sources in this order:

1. Official / first-party docs, standards, product docs, release notes.
2. Source repositories and implementation documentation.
3. High-quality practitioner material from credible experts.
4. User-context: trainer experience, internal practice, local examples.

User-context can be core content, but must not be presented as an external fact.

## Source IDs

Use stable slug IDs, not positional IDs like `R1`:

```md
anthropic-building-effective-agents
openai-function-calling
model-context-protocol-docs
```

Every external fact used in `DECK_BRIEF.md` must cite a source ID that exists in `RESOURCES.md`.

## Knowledge types

Classify claims as:

- **Fact** — supported by high-trust external sources.
- **Practitioner judgment** — credible opinion or field practice; cite source and mark as judgment.
- **User-context** — trainer experience or internal practice; can be central, but label it.

## Sufficiency gate

Research is sufficient only when:

- core definitions have trustworthy sources or are marked as user-context/practitioner framing;
- key claims in the brief have source IDs;
- mechanisms and evolution are grounded in official/first-party or implementation sources where available;
- caveats and uncertainties are recorded;
- every source gap is classified as blocking or non-blocking.

Do not use a fixed source count as the gate.

## User-context conflicts

When user-context conflicts with researched knowledge, do not silently rewrite either side. Surface the conflict during Core Lock and ask the user to choose one resolution:

- `align` — rewrite the user-context to match high-trust sources.
- `frame` — keep it as personal/practitioner framing.
- `caveat` — keep it with limitations or counterexamples.
- `remove` — move it out of the main deck.

## Example elicitation

Use research examples to prompt the trainer's own examples. Research examples do not replace user-confirmed examples.

## Scratch notes

`research-notes/` may store raw notes and drafts. These notes are scratch only and must not enter `handoff/` or be imported into `ppt-master`.
