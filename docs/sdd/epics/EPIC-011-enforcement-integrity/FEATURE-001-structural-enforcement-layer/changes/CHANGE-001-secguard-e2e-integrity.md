# CHANGE-001: Secguard End-to-End Integrity

> **Date**: 2026-07-11
> **Status**: Accepted

## Reason

Design review found that the structural enforcement layer existed as scripts but was not closed end to end. Claude discarded the explicit language, constructed an invalid rules path, packaging omitted enforcement scripts, unsupported `signal_source` expressions silently skipped rules, coverage counted unrelated totals, and verification treated Investigation artifacts as informational.

## Impact

| Before | After |
|--------|-------|
| Coverage inferred from aggregate finding counts | Coverage reconciles every partition assignment by stable ID |
| Investigation artifacts were optional | Confirmed findings require matching batch artifacts and Judge verdict |
| Invalid/missing rule registry produced an empty plan | Partition generation fails closed |
| Example findings could demonstrate only output plumbing | The no-answers C++ example is measured through the independent oracle |

## Requirements Changed

- REQ-001c is a hard per-finding gate, not informational metadata.
- REQ-002 counts partition assignments, not heterogeneous raw index records.
- The packaged extension must contain every script named by the command protocol.
- A rule with an invalid `signal_source` blocks partition generation.

## Migration

New scans write batch artifacts under `workers/<rule_id>/<batch_id>/` and include `rule_id`, `batch_id`, and `signal_id` provenance in findings and dismissals. Existing scan artifacts remain readable by the renderer but are not accepted as evidence for a new confirmed scan.

The deployment uses one canonical knowledge namespace at `$SECGUARDIAN_HOME/knowledge/`. Skill-local `protocols` and `standards` aliases are removed; only the `scripts` alias remains while initialization depends on it. Runtime documentation follows one direction: platform command -> dispatch protocol -> rule -> rule-local references.
