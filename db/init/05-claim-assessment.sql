-- Apply to an existing database or run as part of fresh initialization.
BEGIN;

-- Multiple assessments per claim preserve reassessments as separate records.
CREATE TABLE IF NOT EXISTS claims.claim_assessment (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id INT NOT NULL REFERENCES claims.claim(id),
    recommendation TEXT NOT NULL CHECK (recommendation IN ('cover', 'do_not_cover', 'refer_for_human_review')),
    certainty_score NUMERIC(5,2) NOT NULL CHECK (certainty_score BETWEEN 0 AND 100),
    explanation TEXT NOT NULL,
    -- Snapshots or identifiers of the member, policy, facts, and documents considered.
    information_considered JSONB NOT NULL CHECK (jsonb_typeof(information_considered) = 'object'),
    -- Each item should identify its source and explain its relevance.
    supporting_evidence JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(supporting_evidence) = 'array'),
    conflicting_evidence JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(conflicting_evidence) = 'array'),
    policy_provisions JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(policy_provisions) = 'array'),
    missing_information JSONB NOT NULL DEFAULT '[]'::jsonb CHECK (jsonb_typeof(missing_information) = 'array'),
    referral_reason TEXT,
    model_version TEXT NOT NULL,
    policy_version TEXT NOT NULL,
    assessed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT claim_assessment_referral_reason CHECK (
        recommendation <> 'refer_for_human_review' OR length(trim(coalesce(referral_reason, ''))) > 0
    )
);
CREATE INDEX IF NOT EXISTS claim_assessment_claim_id_assessed_at_idx
    ON claims.claim_assessment (claim_id, assessed_at DESC, id DESC);

COMMENT ON COLUMN claims.claim_assessment.certainty_score IS
    'Agent-reported certainty from 0 to 100; not necessarily a calibrated probability.';
COMMENT ON TABLE claims.claim_assessment IS
    'First-decision assessments for human review and evaluation; multiple rows per claim allow reassessments.';
COMMIT;
