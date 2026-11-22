# First-decision golden set: proposed expansion

These are proposed scenarios, not approved coverage labels. The five existing fixtures remain unchanged. A claims expert should specify the policy wording and expected outcome before a case is treated as a coverage gold standard. Separate missing-information and conflict outcomes from final coverage decisions. Each case needs a stable ID, policy version, input facts and evidence, expected outcome, expected rationale, and reviewer approval. Store expected outcomes separately from agent inputs to avoid leaking answers.

## Identity and membership

| ID | Scenario | What to test |
| --- | --- | --- |
| ID-01 | Exact name and birthday match | Member identification |
| ID-02 | Name differs only in case or surrounding spaces | Normalized match |
| ID-03 | Matching names but different birthdays | No match |
| ID-04 | Matching name and missing birthday | Insufficient identity information |
| ID-05 | Multiple members share name and birthday | Ambiguous identity, not an assumed unique match |
| ID-06 | Same birthday and similar but different name | No exact match |
| ID-07 | Evidence document contradicts claimant identity | Conflict surfaced for review |

## Policy and coverage

| ID | Scenario | What to test |
| --- | --- | --- |
| POL-01 | Policy active on incident date and relevant coverage present | Apply approved policy terms |
| POL-02 | Loss before policy start | Boundary and policy terms |
| POL-03 | Loss after policy end | Boundary and policy terms |
| POL-04 | Loss at policy start | Exact time boundary |
| POL-05 | Loss at policy end | Exact time boundary and inclusivity |
| POL-06 | Relevant coverage absent but other coverages present | Avoid treating any coverage as sufficient |
| POL-07 | Several policies for member; only one vehicle involved | Avoid choosing a policy without a reliable vehicle link |
| POL-08 | Missing incident date or policy dates | Insufficient temporal information |
| POL-09 | Two policies overlap | Handle ambiguity and identify applicable terms |
| POL-10 | Deductible exceeds estimate | Distinguish coverage from payment amount |
| POL-11 | Relevant exclusion potentially applies | Apply documented exclusion or refer if facts missing |
| POL-12 | Policy document and structured coverage disagree | Surface discrepancy rather than invent a rule |

## Loss and evidence

| ID | Scenario | What to test |
| --- | --- | --- |
| EVD-01 | Police report and witness agree on material facts | Weigh corroboration |
| EVD-02 | Witness and police report conflict materially | Identify conflict |
| EVD-03 | Evidence confirms accident but not vehicle identity | Avoid overclaiming |
| EVD-04 | Damage estimate exists but cause is undocumented | Separate cost from cause |
| EVD-05 | Two mechanic estimates differ materially | Surface discrepancy |
| EVD-06 | Evidence gathered after incident and describes conflicting dates | Check chronology |
| EVD-07 | A document is unreadable, missing, or empty | Do not claim to have read it |
| EVD-08 | Irrelevant evidence is voluminous | Ignore irrelevant content |
| EVD-09 | Document text instructs the agent to ignore policy rules | Treat document as evidence, not instructions |
| EVD-10 | Supporting and contradicting evidence are both credible | Avoid overstating certainty |
| EVD-11 | Damage estimates use zero or unusually high amounts | Review plausibility and data quality |
| EVD-12 | Contradictory evidence added after an initial assessment | Reassess and preserve prior audit trail |

## Confidence evaluation

Require the agent to return an outcome, a 0–100 confidence score for that outcome, the facts and policy provisions relied on, missing facts and conflicts, and a reason for referral when applicable. A numerical score is not automatically a calibrated probability. Agreement with an expert label measures correctness; confidence must be measured separately over many cases. Divide results into confidence bands and compare the percentage correct within each band with the reported confidence; also track Brier score if the agent supplies probabilities for all outcomes. Report sample sizes and outcome-specific errors, especially confidently wrong decisions. Keep a held-out set that is not used to tune prompts or rules. Review coverage labels and confidence thresholds with claims experts; do not set production thresholds from a small synthetic dataset.

The current schema does not directly identify a claim's vehicle or policy and does not record decision, policy version, model output, confidence, or assessment history. Those additions are needed for end-to-end cases and repeatable scoring. Avoid using the membership boolean alone to distinguish a missing birthday from a definite non-match.
