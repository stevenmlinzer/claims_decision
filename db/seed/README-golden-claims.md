# Golden claims test data

`golden-claims.sql` creates five fictional claims and records their generated IDs in `test_fixtures.golden_claims`. Each has one damage estimate, one evidence record, and two synthetic text documents. The script does not delete existing data. Once all five fixtures exist, running it again is a no-op. If the registry is incomplete, it stops for inspection.

| Scenario | Expected membership flag | Purpose |
| --- | --- | --- |
| member_collision | true | Member match, collision, supporting police report |
| member_weather | true | Member match, weather damage, supporting witness |
| conflicting_accounts | true | Member match, evidence contradicts reported account |
| unmatched_claimant | false | No matching member; rejection candidate |
| missing_birthday | false | Missing birthday; identity needs review |

The incident dates are chosen inside a policy period for the selected member, but a policy-period match alone does not prove coverage. The database has no claim-to-policy or vehicle link, so these fixtures do not establish which vehicle was involved or whether the loss is covered. Their descriptions and documents are fictional and are not coverage determinations.

## Load into an existing development database

Apply `db/init/03-claim-member-match.sql`, then `db/init/04-claim-documents.sql`, then `db/seed/golden-claims.sql` using `psql` with `ON_ERROR_STOP=1`, connected to the intended database. The database must contain sample members 1, 2, and 3 with birthdays and valid policy periods, as supplied by the project's sample data. Back up the database and verify the target before applying migrations. These files are not automatically applied to an existing PostgreSQL volume.

For an already-running Compose database, from the project directory, after configuring the required Compose environment:

```sh
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/init/03-claim-member-match.sql
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/init/04-claim-documents.sql
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/seed/golden-claims.sql
```

Verify:

```sql
SELECT f.scenario, c.id, c.claimant_is_member,
       (SELECT count(*) FROM claims.claim_damage d WHERE d.claim_id = c.id) AS damages,
       (SELECT count(*) FROM claims.claim_evidence e WHERE e.claim_id = c.id) AS evidence,
       (SELECT count(*) FROM claims.claim_document d WHERE d.claim_id = c.id) AS documents
FROM test_fixtures.golden_claims f
JOIN claims.claim c ON c.id = f.claim_id
ORDER BY f.scenario;
```

A fresh database initialized by Compose runs migrations 03 and 04 automatically, after which the seed script must still be run explicitly. PostgreSQL image initialization scripts do not rerun on an existing data volume.

## Additional witness and party-account cases

After the original five cases, run `db/seed/golden-witness-cases.sql` with the same `psql -v ON_ERROR_STOP=1` command pattern. It adds eight claims, each with separate claimant, plaintiff, witness and investigator evidence records, four synthetic source documents and a mechanic invoice. It is safe to rerun: registered cases are skipped. The original seed script can also be rerun after the expansion.

```sh
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/seed/golden-witness-cases.sql
```

Read `witness-evaluation-guide.md` only on the evaluation side; it contains provisional evidence-handling expectations, not final coverage labels. This additional script also adds separate claimant and plaintiff accounts to the original five cases.

## Identity and policy cases

After `golden-claims.sql`, run `db/seed/golden-coverage-cases.sql` to add four fictional identity, vehicle and policy cases. They use reserved negative fixture member and policy IDs and fail rather than overwrite an existing record with one of those IDs. The script skips already registered scenarios on rerun. See `coverage-evaluation-guide.md` for evaluator-only expectations.

```sh
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/seed/golden-coverage-cases.sql
```

The incident vehicle/policy relationship appears in narrative evidence because the schema does not yet provide a direct claim-to-vehicle or claim-to-policy link.

## Vehicle value, hit-and-run and conflicting fault cases

The current `db/init/01-schema.sql` allows unknown plaintiff details when creating a fresh database. For an existing database, ensure the five plaintiff name and address fields are nullable before running the loss seed. After `golden-claims.sql`, run `db/seed/golden-loss-cases.sql`. It adds three fictional claims, uses reserved negative fixture member and policy IDs, and skips registered cases on rerun. The hit-and-run claim records the other party as unknown using NULL values and has no invented plaintiff statement. See `loss-evaluation-guide.md` for evaluator-only expectations.

```sh
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/seed/golden-loss-cases.sql
```

## Police-report contradictions

After `golden-claims.sql`, run `db/seed/golden-police-cases.sql` to add two fictional cases in which a police report contradicts, respectively, the claimant and the plaintiff. The scenarios use reserved negative fixture member and policy IDs and skip already registered scenarios on rerun. See `police-evaluation-guide.md` for evaluator-only expectations.

```sh
sudo docker compose exec -T db psql -U capstone -d capstone -v ON_ERROR_STOP=1 < db/seed/golden-police-cases.sql
```
