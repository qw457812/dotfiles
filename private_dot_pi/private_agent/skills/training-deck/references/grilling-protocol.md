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

## Blocking questions

A question is blocking when the answer affects whether the Stage 2 handoff is safe:

- the training mission or desired behavior change
- a must-cover concept or claim
- a core audience assumption
- a conflict between user-context and researched knowledge
- a source gap for a key claim
- whether a material/example should be included
- whether a caveat can be downgraded to non-blocking

If a blocking question remains unresolved, the handoff status cannot be `ready`.

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
