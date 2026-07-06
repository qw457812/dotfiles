# Strict Grilling Protocol

Use strict grilling whenever a user decision is needed.

## Rules

1. Ask exactly one question at a time.
2. Provide your recommended/default answer.
3. Give a brief reason for the recommendation.
4. Wait for the user's response before asking the next question.
5. Do not ask questions answerable by inspecting existing files, artifacts, or research results.
6. Do not ask nice-to-have questions that do not affect mission, audience, storyline, delivery, content scope, examples, visual intent, or handoff readiness.

## Question selection

Resolve prerequisite decisions before dependent ones:

1. Workspace path / slug
2. Training language
3. Duration and delivery setting
4. Core Seed
5. Audience assumptions
6. Content candidates and gaps
7. User examples
8. Demo / interaction plan
9. Vision Lock
10. Slide-by-slide Lock

## Blocking questions

A question is blocking when the answer affects whether the Stage 2 handoff is safe:

- the training mission or desired behavior change
- a must-cover concept or claim
- a core audience assumption
- a conflict between user-context and researched knowledge
- a source gap for a key claim
- whether a material/example should be included
- the title, teaching purpose, content, or order of any locked slide
- whether a caveat can be downgraded to non-blocking

If a blocking question remains unresolved, the handoff status cannot be `ready`.

## Slide-by-slide confirmation

When locking deck structure, ask about exactly one slide at a time. Present the current slide number and proposed slide contract, then wait for confirmation before presenting the next slide.

A slide contract includes:

- slide number
- slide title
- teaching purpose
- on-slide content
- speaker-note emphasis
- visual IDs
- demo / interaction cue, if any
- source IDs / user-context

After a slide is confirmed, do not revise it later unless a dependency or user request requires reopening it.

## Recommended answer style

Use this shape:

```md
### Question
<one focused question>

### My recommended answer
<default answer>

Reason: <brief reason>
```

If the user rejects the recommendation, accept their decision unless it creates a source conflict or handoff risk. Surface conflicts explicitly.
