# BusRoute+ Database Folder (MySQL 8.0+)

This folder contains a complete, ordered MySQL database setup for the BusRoute+ / Chennai Bus Radar project.

## Files and execution order

1. `01_schema.sql` — creates the database and all tables.
2. `02_functions_views.sql` — creates analytical views.
3. `03_seed.sql` — inserts sample Chennai routes, stops, buses and fares.
4. `04_procedures.sql` — stored procedures for route search, fare calculation and nearest stops.
5. `05_triggers.sql` — stop-verification and trust-score triggers.
6. `06_advanced_queries.sql` — JOINs, aggregation, window functions, anomaly analysis and examples.
7. `07_fastapi_database.sql` — compatibility note and test queries; see warning below.

## Recommended setup

Run files `01` through `06` in order in MySQL Workbench or the MySQL command-line client. The schema and seed scripts are designed for a fresh development database named `busroute_plus`.

**Important:** `07_fastapi_database.sql` is a supplementary file from the earlier response, not needed for the main setup. It contains `CREATE TABLE IF NOT EXISTS` statements and sample inserts. Do not run it after the complete setup unless you have reviewed it; duplicate table definitions and schema differences are possible.

Sample data is approximate and for development/demo only. It is not an official timetable or live GPS feed.

## MySQL command-line example

```bash
mysql -u root -p < 01_schema.sql
mysql -u root -p busroute_plus < 02_functions_views.sql
mysql -u root -p busroute_plus < 03_seed.sql
mysql -u root -p busroute_plus < 04_procedures.sql
mysql -u root -p busroute_plus < 05_triggers.sql
mysql -u root -p busroute_plus < 06_advanced_queries.sql
```

Stored routines/triggers use `DELIMITER`, supported by MySQL Workbench and the MySQL command-line client.
