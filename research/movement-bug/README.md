# Movement Bug Research Collaboration

**Bug:** Manual keyboard movement broken; right-click Walk To works.  
**Scope:** UniversalTraits + UT_CORE, PZ Build 42.16.x single-player.  
**Status:** Active investigation — narrowed to UT stack (disabling UT+UT_CORE eliminates bug).

## Folder Structure

```
research/movement-bug/
  README.md              ← this file (index + status)
  STATUS.md              ← current state of investigation, open questions, next steps
  proof/                 ← HARD PROOF only — verified facts from source code, logs, or live testing
  hypotheses/            ← theories under investigation, ranked by evidence strength
  instrumentation/       ← debug logging plans and results from live runs
  reviews/               ← agent review feedback and rebuttals
```

## Rules for This Folder

1. **proof/** entries must cite exact file:line references and include the relevant code snippet. No "I think" or "probably" — only verified facts.
2. **hypotheses/** entries must clearly separate what is proven from what is assumed. Each hypothesis must list what evidence would confirm or refute it.
3. When a hypothesis is confirmed, move its core findings to proof/ and update STATUS.md.
4. When a hypothesis is refuted, mark it refuted in-place with the evidence that killed it. Do not delete — refuted theories prevent re-investigation.
5. All agents working on this bug should read STATUS.md first and update it when done.
6. Do not treat the current trimmed active mod list as the full compatibility boundary. Use it for reproduction evidence, but design conclusions must account for the broader movement-mod class evidenced in the research notes.
