# General
- Opening a new terminal may require a password; allow time.

# Terraform
- Use small, composable modules with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`.
- Order resources logically: VPC, subnets, IGW, route tables, security groups, then services.
- Never hardcode credentials or ARNs; use variables, data sources, or environment.
- Name predictably: `project-env-component-purpose`; tag `Environment`, `Project`, `Owner`.
- Prefer implicit dependencies over `depends_on`.
- Pin providers and Terraform in `versions.tf`; use remote backend with separate state per environment.
- Quality gates: run `terraform fmt -check`, `terraform validate`, `terraform plan -out tfplan.bin`.
- Debug with `TF_LOG=INFO` and `TF_LOG_PATH=terraform.log`; inspect plan via `terraform show tfplan.bin`.

# PySpark
- Prefer DataFrame/Spark SQL; avoid Python UDFs unless necessary.
- Define explicit schemas for ingestion in production; avoid `inferSchema=true`.
- Partition intentionally and tune `spark.sql.shuffle.partitions`.
- Use `repartition()` to scale and `coalesce()` to downscale writes.
- Add structured logging; validate with `.explain(mode="formatted")` and `.printSchema()`.

# AWS Glue
- Use Glue 4.0+ and Python 3.x; use `GlueContext`.
- Pass parameters via `getResolvedOptions`; enable job bookmarks and CloudWatch logging.
- Use catalog sources with pushdown predicates; partition outputs and set S3 `TempDir`.
- Keep IAM least-privilege; encrypt S3 and logs; never hardcode secrets.
- Size DPUs conservatively; avoid unnecessary DynamicFrame/DataFrame conversions.
