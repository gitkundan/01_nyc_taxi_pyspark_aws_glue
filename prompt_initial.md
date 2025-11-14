Below is a fully fleshed, unambiguous instruction set for generating a production‑ready mono‑repo that implements the approved design decisions. This document is intended to be handed to a separate LLM that will generate all scaffolding, code, and documentation accordingly.

Title: Production-grade NYC Taxi mono-repo: Terraform IaC, AWS Glue 5.0 PySpark ETL, Glue DQ, SCD2, CI/CD, Step Functions orchestration, logging/observability, lineage, local_dev via Jupyter PySpark, Make-driven automation[9][10][11]

Objective
- Build a mono-repo that ingests NYC TLC Yellow trip Parquet data, enforces schema and data quality across bronze/silver/gold, transforms using AWS Glue 5.0 (Spark 3.5.x, Python 3.11), orchestrates end-to-end via Step Functions + EventBridge (08:00 UTC daily), implements SCD Type 2 for dimensions, publishes Athena-friendly gold, produces materialized views and analyst SQL, wires stub OpenLineage emission to Marquez, and ships with CI/CD (GitHub Actions with OIDC), alarms via SNS, and clear environment promotion. Local development runs purely on the quay.io/jupyter/pyspark-notebook image against local Parquet files, controlled by Make targets.[10][12][9]

Hard requirements and global conventions
- Dataset scope: NYC TLC Yellow only; limit to modern schema years; incorporate newer columns like cbd_congestion_fee and keep them nullable for older periods.[9]
- Column naming: all lowercase snake_case across layers; handle legacy column aliases by canonicalizing in bronze (or silver if needed) and standardizing names there.[9]
- Timezone and partitions: use UTC canonicalization; partition bronze/silver/gold by year/month/day based on event pickup timestamp; late-arriving records must land in the original event-day partition.[9]
- Glue runtime: Glue 5.0, Spark 3.5.x, Python 3.11; set Spark defaults: partitionOverwriteMode=dynamic, adaptive execution enabled, dynamic allocation enabled, shuffle.partitions 200, parquet compression snappy, adequate memory overhead; expose job args for dataset, date window, and idempotent run keys.[11][10]
- Orchestration: Step Functions state machine with CrawlRaw → BronzeJob → BronzeDQ → SilverJob → SilverDQ → GoldDims → GoldFacts → GoldDQ → Publish → Success; DQ choice states branch to quarantine or block; EventBridge cron runs daily at 08:00 UTC; provide a simple manual trigger path in Step Functions console.[12]
- Retries/backoff: use IntervalSeconds=10, MaxAttempts=3, BackoffRate=2.0 for Glue/Lambda/States retry configurations to balance resilience and cost.[13][14]
- IAM simplification: do not configure KMS; grant Glue job role full S3 access limited to data lake buckets and code bucket prefixes; block public access on buckets; require SSE-S3; VPC endpoints not required.[15]
- GitHub OIDC CI/CD: define per-environment roles with trust on repo + branches; develop→dev with plan/apply + artifact upload + Step Functions test execution; master→uat with manual approval gate and sns:Publish/CloudWatch metrics; release/*→prod with protected branch, manual approval, and resource-scoped permissions; publish minimal defaults.[16][17][18]
- Lineage: provide an OpenLineage stub for Glue Spark with extra JAR wiring and environment variables; disabled by default behind a config flag; target backend Marquez; keep endpoint/auth as placeholders.[19]
- Surrogate keys: compute deterministic SKs by hashing canonical natural keys: normalize to lower(trim), represent null as “\N”, concatenate with “|” in canonical order, hash with SHA256, hex encode; use consistently across layers. [20]
- DQ enforcement: use Glue DQDL rulesets per layer with agreed defaults; custom DQ runs as Spark SQL inside Glue and blocks the pipeline on failure; quarantine path stores failed records under s3://.../quarantine/<layer>/year=.../month=.../day=... and emits SNS.[21][22]
- Scheduling: single EventBridge cron schedule at 08:00 UTC daily with cron(0 8 * * ? *).[12]
- Local development: no S3/MinIO/LocalStack; use quay.io/jupyter/pyspark-notebook with local folder mounts only; run code against local Parquet files via Make and spark-submit or notebooks; provide Make targets to bootstrap local data, run tests, and run jobs locally.[10]

Repository structure
- Use the structure originally specified, but reflect the following specifics:
  - src/common: session/bootstrap, Glue context builder, catalog utilities, lineage stub, type checks, logging config, and custom exception types.[10]
  - src/bronze: bronze ingestion job, canonical schema JSON for modern yellow, DQ rules in dq/bronze_dq_rules.yaml.
  - src/silver: silver denormalization job; transformations for datetime normalization, cleansing, enrichment; schema; dq/silver_dq_rules.yaml.
  - src/gold: star schema job; dimensions: dim_location, dim_vendor; facts: fact_trips; schemas; dq/gold_dq_rules.yaml. Include SCD2 implementations:
    - src/gold/dimensions/scd2_row_based.py: row-by-row join/update/delete logic.[20]
    - src/gold/dimensions/scd2_merge_based.py: MERGE-based batch method suitable for Spark SQL over partitions.[23]
  - src/orchestration: Step Functions state machine ASL JSON and job dependency map; trigger_setup.md explaining EventBridge cron and state machine inputs.[12]
  - src/lineage: OpenLineage_emitter.py as a stub wrapper to set Spark listener only when enabled; lineage_mapping.yaml for dataset naming norms.[19]
  - infrastructure/terraform:
    - modules: s3_data_lake, glue_job, glue_catalog, glue_dq, iam, step_functions, lambda, cloudwatch_logs, eventbridge, athena, sns_alarms.
    - env: local_dev.tfvars, dev.tfvars, uat.tfvars, prod.tfvars that set naming, tags, and schedule toggles.
    - main.tf, variables.tf, outputs.tf with environment-scoped resources; OIDC roles and policies aligned with branch mapping.[17][16]
  - configs: job_runtime_config.yaml, logging.yaml controlling structured JSON logs and log levels.
  - environments: local_dev.yaml, dev.yaml, uat.yaml, prod.yaml,

Very Important :
  Do not run any files
create the necessary files and folder

## Propmt