-- Run once on existing databases; also runs during fresh database initialization.
BEGIN;

-- Composite keys ensure linked evidence or damage belongs to the same claim.
CREATE UNIQUE INDEX IF NOT EXISTS claim_evidence_id_claim_id_key
    ON claims.claim_evidence (id, claim_id);
CREATE UNIQUE INDEX IF NOT EXISTS claim_damage_id_claim_id_key
    ON claims.claim_damage (id, claim_id);

CREATE TABLE IF NOT EXISTS claims.claim_document (
    id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    claim_id INT NOT NULL REFERENCES claims.claim(id),
    evidence_id INT,
    damage_id INT,
    document_type TEXT NOT NULL,
    file_name TEXT NOT NULL,
    content_type TEXT NOT NULL,
    file_content BYTEA NOT NULL,
    description TEXT,
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT claim_document_evidence_claim_fk
        FOREIGN KEY (evidence_id, claim_id)
        REFERENCES claims.claim_evidence (id, claim_id),
    CONSTRAINT claim_document_damage_claim_fk
        FOREIGN KEY (damage_id, claim_id)
        REFERENCES claims.claim_damage (id, claim_id)
);

CREATE INDEX IF NOT EXISTS claim_document_claim_id_idx
    ON claims.claim_document (claim_id);
COMMIT;
