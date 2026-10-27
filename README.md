# Hotel Bookings: Terraform + Database Reliability

Terraform for an `Internet → ALB → ECS/Fargate → RDS PostgreSQL` stack on AWS
with separate `dev` and `prod` environments, plus a local PostgreSQL setup with
migrations, seed data, query indexing, and backup/restore scripts.

```
.
├── infra/
│   ├── modules/
│   │   ├── network/     VPC, public/private/database subnets, IGW, NAT, routes
│   │   ├── ecs/         ALB + SG, ECS SG, cluster, task definition, service, autoscaling
│   │   └── rds/         RDS PostgreSQL, RDS SG, subnet + parameter groups
│   ├── envs/
│   │   ├── dev/         backend.tf, variables.tf, terraform.tfvars, main.tf, ...
│   │   └── prod/
│   └── plan-only/       override for planning without AWS credentials
├── db/
│   ├── migrations/      001..003 SQL migrations (tables, FK index, reporting index)
│   └── seed/seed.sql    deterministic seed (1,000 bookings by default)
├── scripts/
│   ├── backup.sh        timestamped pg_dump + checksum + manifest
│   ├── restore.sh       restore into a fresh database and verify it
│   ├── explain.sh       EXPLAIN ANALYZE for the reporting query
│   ├── migrate.sh       migration runner used by docker compose
│   └── tf-plan.sh       fmt/init/validate/plan for one env without AWS access
├── docker-compose.yml
└── .github/workflows/   terraform.yml (PR plan), database.yml (backup/restore e2e)
```

**Prerequisites:** Terraform >= 1.6, Docker with the Compose plugin, and bash. No
local `psql`/`pg_dump` is needed because the scripts run them inside the container.

---

## Part 1–2: Terraform

### Architecture

```
                 Internet
                    │ 80 / 443
          ┌─────────▼──────────┐  public subnets (one per AZ)
          │  ALB  (sg: alb)    │  + NAT gateway(s)
          └─────────┬──────────┘
                    │ container port, from sg:alb only
          ┌─────────▼──────────┐  private subnets, no public IPs,
          │ ECS Fargate tasks  │  egress through NAT
          │   (sg: ecs)        │
          └─────────┬──────────┘
                    │ 5432, from sg:ecs only
          ┌─────────▼──────────┐  database subnets: no route to the
          │ RDS PostgreSQL 16  │  internet at all, publicly_accessible
          │   (sg: rds)        │  = false, SG has no egress rules
          └────────────────────┘
```

* **RDS is private.** It sits in dedicated database subnets whose route table
  has only the VPC-local route. Its security group admits `5432` *only* from
  the ECS service security group (an SG reference, not a CIDR).
* **No secrets in code or state.** `manage_master_user_password = true` makes
  RDS generate and store the master password in Secrets Manager. ECS injects
  `DB_USERNAME`/`DB_PASSWORD` from that secret at task start, and the
  execution role can read only that secret ARN.
* Storage is encrypted, `rds.force_ssl = 1`, slow queries over 500 ms are
  logged, and Postgres logs are exported to CloudWatch.
* The ECS service uses a deployment circuit breaker with automatic rollback
  and CPU target-tracking autoscaling. The ALB drops invalid headers and serves
  HTTPS with a TLS 1.3 policy when `certificate_arn` is set (HTTP then
  redirects).
* The app container is `nginx` from ECR Public, on ARM64 (Graviton) Fargate.

### Environments

Each of `infra/envs/dev` and `infra/envs/prod` is an independent root module
with its own `variables.tf`, `terraform.tfvars`, `backend.tf` (separate S3
bucket, state key and lock table), and provider lock file.

| Setting                | dev                     | prod                          |
|------------------------|-------------------------|-------------------------------|
| VPC / AZs              | `10.10.0.0/16`, 2 AZs   | `10.20.0.0/16`, 3 AZs         |
| NAT gateways           | 1 shared                | 1 per AZ                      |
| Fargate task size      | 0.25 vCPU / 512 MiB     | 1 vCPU / 2 GiB                |
| Tasks (min–max)        | 1–2, Fargate Spot       | 2–6, on-demand                |
| RDS instance           | `db.t4g.micro`, single-AZ | `db.r6g.large`, Multi-AZ    |
| RDS storage            | 20 GiB → 50 GiB autoscale | 100 GiB → 500 GiB autoscale |
| Backup retention (PITR)| 1 day                   | 30 days                       |
| Deletion protection    | off (RDS + ALB)         | on (RDS + ALB)                |
| Final snapshot on destroy | skipped              | taken                         |
| Apply DB changes       | immediately             | in maintenance window         |
| Performance Insights / Container Insights | off  | on                           |
| Log retention          | 7 days                  | 90 days                       |

### Terraform review

The committed backends point at S3 buckets that don't exist in your account,
so a plain `terraform init` needs real AWS access. For review without AWS,
`infra/plan-only/plan_only_override.tf` uses Terraform's
[override files](https://developer.hashicorp.com/terraform/language/files/override)
to swap in a local backend and an offline provider for the duration of the
run. The real configuration is not edited.

One command per environment:

```bash
./scripts/tf-plan.sh dev
./scripts/tf-plan.sh prod
```

The same steps by hand:

```bash
terraform fmt -check -recursive infra

cd infra/envs/dev                              # or prod
cp ../../plan-only/plan_only_override.tf .
terraform init
terraform validate
terraform plan -refresh=false
rm plan_only_override.tf                       # also git-ignored
```

Expected result: `Plan: 45 to add` for dev and `Plan: 56 to add` for prod.

**With real AWS access:** create the state bucket and DynamoDB lock table named
in `backend.tf`, then run plain `terraform init && terraform plan` in the
environment directory.

## Part 3: Terraform plan on pull requests

`.github/workflows/terraform.yml` runs on PRs touching `infra/**`:

1. `terraform fmt -check -recursive`
2. For `dev` and `prod` in parallel: `init` → `validate` → `plan -refresh=false`
3. The plan is published three ways: a sticky **PR comment** per environment
   (updated on each push), the **job summary**, and a **workflow artifact**
   (`tfplan-<env>` with the binary plan and its text rendering).

Without configuration it runs in plan-only mode. To plan against real state,
set the repository variable `AWS_PLAN_ROLE_ARN` to a read-only IAM role that
trusts GitHub OIDC. The workflow then assumes it and uses the S3 backend.

---

## Part 4–5: Local database

```bash
docker compose up -d        # or `docker compose up` in a separate terminal
docker compose logs migrate # shows applied migrations and seeded row counts
```

`db` runs PostgreSQL 16. The one-shot `migrate` service waits for it to be
healthy, then:

1. applies `db/migrations/*.sql` in order, each in a transaction, recording
   them in `schema_migrations` (re-running skips applied ones), and
2. runs `db/seed/seed.sql`, which fills empty tables only.

Seed data is deterministic (fixed `setseed`, md5-derived UUIDs):

* 1,000 bookings (change with `SEED_BOOKINGS`)
* 10 cities (`delhi` the busiest), 6 organisations, 25 hotels per city
* statuses `pending`, `confirmed`, `completed`, `cancelled`, `refunded`
* `created_at` spread over the last 120 days, so the 30-day filter matters
* lifecycle events (`booking_created`, `payment_captured`, `checked_in`, ...)
  for about 75% of bookings

Open a shell with `docker compose exec db psql -U app -d hotel_bookings`.
Settings can be overridden by copying `.env.example` to `.env`.

### Query optimisation

```sql
SELECT org_id, status, COUNT(*), SUM(amount)
FROM hotel_bookings
WHERE city = 'delhi'
  AND created_at >= NOW() - INTERVAL '30 days'
GROUP BY org_id, status;
```

Index (`db/migrations/003_index_city_created_at.sql`):

```sql
CREATE INDEX hotel_bookings_city_created_at_idx
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
```

Why this shape:

* **`city` first, `created_at` second.** Equality columns go before range
  columns. In a B-tree sorted by `(city, created_at)`, the qualifying rows,
  "delhi in the last 30 days", form one contiguous range that is read start
  to finish. With `(created_at, city)` the scan would walk every city's rows
  in the window and discard the non-delhi ones.
* **`INCLUDE (org_id, status, amount)` makes it covering.** Every column the
  query touches is in the index, so Postgres can use an **Index Only Scan**
  and skip the table heap. The seed runs `VACUUM ANALYZE` so the visibility
  map allows this; autovacuum keeps it current in normal operation. These
  columns are `INCLUDE`d rather than key columns because they are never
  searched on, so they need not affect sort order or bloat inner index pages.
* **Grouping** happens in a HashAggregate over the small, already-filtered set.
  Putting `org_id, status` into the key wouldn't produce grouped order, because
  the range on `created_at` precedes them.
* **Rejected alternatives:** separate single-column indexes give a bitmap AND
  plus heap visits. A partial index on "last 30 days" is impossible because
  `now()` is not immutable. A plain `(city)` index still reads every delhi row
  ever written.
* **Cost:** one extra index to maintain on insert, which is acceptable for a
  reporting query on an append-mostly table.
* **Type note:** `created_at` is `TIMESTAMP` (per the suggested schema) while
  `NOW()` is `timestamptz`. Postgres's cross-type B-tree operators still use
  the index, but the result depends on the session `TimeZone`. In a
  production schema I'd use `TIMESTAMPTZ`.
* In production, build it with `CREATE INDEX CONCURRENTLY` to avoid blocking writes.

Check the plan:

```bash
./scripts/explain.sh
```

With only 1,000 rows the whole table is a handful of pages, and the planner
may reasonably prefer a sequential scan. To see the index at realistic volume:

```bash
docker compose down -v
SEED_BOOKINGS=200000 docker compose up -d && docker compose logs -f migrate
./scripts/explain.sh   # expect: Index Only Scan using hotel_bookings_city_created_at_idx
```

`booking_events` also has `(booking_id, created_at)`, because Postgres does not
index foreign keys. It serves booking timelines and the `ON DELETE CASCADE`.

---

## Part 6: Backup and restore

```bash
./scripts/backup.sh
./scripts/restore.sh
```

**`backup.sh`** writes three files to `backups/`:

| File | Purpose |
|------|---------|
| `hotel_bookings_<UTC timestamp>.dump` | `pg_dump` custom format (compressed, restorable selectively) |
| `….dump.sha256` | checksum, checked before restoring |
| `….manifest` | row count and an md5 over every row of every table at backup time |

It writes to a `.partial` file and renames it only after `pg_restore --list`
can read the dump, so an interrupted backup never looks valid. It keeps the
10 newest backups (`BACKUP_KEEP`).

**`restore.sh [DUMP] [TARGET_DB]`** defaults to the newest dump and the
database `hotel_bookings_restored`. It:

1. verifies the checksum,
2. drops and recreates the target, so it is always a **fresh database**
   (it refuses to target the live `hotel_bookings`),
3. runs `pg_restore --single-transaction --exit-on-error`, so the restore is
   all-or-nothing,
4. recomputes row counts and per-table data fingerprints and compares them
   with the backup's manifest. It exits non-zero on any difference.

### Verifying the restore

`restore.sh` performs the check itself. A successful run ends like this
(hashes vary with the seed):

```
[..] checksum OK
[..] row counts and fingerprints match the backup manifest:
    hotel_bookings 1000 <md5>
    booking_events <n> <md5>
    schema_migrations 3 <md5>
[..] restore OK -> connect with: docker compose exec db psql -U app -d hotel_bookings_restored
```

A matching fingerprint means every row and every column is identical, not
just the counts. To check by hand:

```bash
# Same row counts in source and restored database
for db in hotel_bookings hotel_bookings_restored; do
  docker compose exec -T db psql -U app -d "$db" -tAc \
    "SELECT '$db', (SELECT count(*) FROM hotel_bookings), (SELECT count(*) FROM booking_events)"
done

# Same answer to the reporting query in both databases
for db in hotel_bookings hotel_bookings_restored; do
  docker compose exec -T db psql -U app -d "$db" -c \
    "SELECT org_id, status, count(*), sum(amount) FROM hotel_bookings
     WHERE city = 'delhi' AND created_at >= now() - interval '30 days'
     GROUP BY 1, 2 ORDER BY 1, 2"
done

# Schema, constraints and indexes came back too
docker compose exec db psql -U app -d hotel_bookings_restored -c '\d hotel_bookings'
./scripts/explain.sh hotel_bookings_restored
```

To prove the restore doesn't depend on the source database, change the
source after the backup and restore again. The restored copy keeps the
backed-up state:

```bash
./scripts/backup.sh
docker compose exec db psql -U app -d hotel_bookings -c "DELETE FROM hotel_bookings WHERE city = 'delhi'"
./scripts/restore.sh        # fingerprints still match the manifest; delhi rows are back in _restored
```

A corrupted dump is rejected before anything is touched (checksum mismatch).
CI exercises this in `.github/workflows/database.yml`, which runs compose up →
migrate (twice, for idempotency) → explain → backup → restore → tamper test on
every change to `db/` or `scripts/`.

### Cleanup

```bash
docker compose down -v   # removes the container and the data volume
rm -rf backups/
```
