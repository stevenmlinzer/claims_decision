-- Safe to run on an existing database and during initial setup.
BEGIN;
ALTER TABLE claims.claim
    ADD COLUMN IF NOT EXISTS claimant_is_member boolean NOT NULL DEFAULT false;

CREATE OR REPLACE FUNCTION claims.set_claimant_is_member()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.claimant_is_member := EXISTS (
        SELECT 1 FROM claims.member m
        WHERE lower(trim(m.first_name)) = lower(trim(NEW.claimant_first_name))
          AND lower(trim(m.last_name)) = lower(trim(NEW.claimant_last_name))
          AND m.birthday = NEW.claimant_birthday
    );
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS claim_set_claimant_is_member ON claims.claim;
CREATE TRIGGER claim_set_claimant_is_member
BEFORE INSERT OR UPDATE ON claims.claim
FOR EACH ROW EXECUTE FUNCTION claims.set_claimant_is_member();

-- Refresh flags if members are added, removed, or changed.
CREATE OR REPLACE FUNCTION claims.refresh_claimant_membership()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    UPDATE claims.claim c SET claimant_is_member = EXISTS (
        SELECT 1 FROM claims.member m
        WHERE lower(trim(m.first_name)) = lower(trim(c.claimant_first_name))
          AND lower(trim(m.last_name)) = lower(trim(c.claimant_last_name))
          AND m.birthday = c.claimant_birthday
    )
    WHERE c.claimant_is_member IS DISTINCT FROM EXISTS (
        SELECT 1 FROM claims.member m
        WHERE lower(trim(m.first_name)) = lower(trim(c.claimant_first_name))
          AND lower(trim(m.last_name)) = lower(trim(c.claimant_last_name))
          AND m.birthday = c.claimant_birthday
    );
    RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS member_refresh_claimant_membership ON claims.member;
CREATE TRIGGER member_refresh_claimant_membership
AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE ON claims.member
FOR EACH STATEMENT EXECUTE FUNCTION claims.refresh_claimant_membership();

UPDATE claims.claim SET claimant_is_member = false;
COMMIT;
