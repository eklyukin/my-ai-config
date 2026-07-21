# Audit Logging Patterns

Reference for creating AuditLog nodes in Neuronet cron jobs and applications.

## AuditLog Node Schema

```cypher
(:AuditLog {
  entityLabel: String,     // "Employee", "Account", "Team", etc.
  entityName: String,      // Human-readable ID: e.name, a.name, t.name
  field: String,           // Property modified: "desired_tax_salary", "industry"
  action: String,          // Operation: "compound_daily_salary", "label_promotion"
  modifiedBy: String,      // Actor: "cron:job-name", "n8n:1234", "manual:user"
  modifiedAt: DateTime,    // datetime() — always UTC
  previousValue: String,   // Before value (null for CREATE, "[REDACTED]" for sensitive)
  newValue: String         // After value (null for DELETE, "[REDACTED]" for sensitive)
})
```

## Pattern 1: Inline Audit (Per-Node)

Best for: jobs that modify specific properties on individual nodes.

```cypher
MATCH (e:Employee {email: $email})
WITH e, e.desired_tax_salary AS oldVal
SET e.desired_tax_salary = e.desired_tax_salary * $multiplier
WITH e, oldVal, e.desired_tax_salary AS newVal
CREATE (e)-[:HAS_AUDIT]->(audit:AuditLog {
    entityLabel: 'Employee',
    entityName: e.name,
    field: 'desired_tax_salary',
    action: 'compound_daily_salary',
    modifiedBy: $auditActor,
    modifiedAt: datetime(),
    previousValue: toString(oldVal),
    newValue: toString(newVal)
})
RETURN e.email, oldVal, newVal
```

## Pattern 2: Batch Audit (Summary)

Best for: jobs that modify many nodes (>10K) where per-node audit would be too expensive.

```cypher
// Phase 1: Count before
MATCH (a:Account)-[:HAS_GAME|IS_DEVELOPER|IS_PUBLISHER]-(:Game)
WHERE a.industry IS NULL
WITH count(DISTINCT a) AS beforeCount

// Phase 2: Mutate
MATCH (a:Account)-[:HAS_GAME|IS_DEVELOPER|IS_PUBLISHER]-(:Game)
WHERE a.industry IS NULL
SET a.industry = 'Gaming'
WITH beforeCount, count(a) AS modified

// Phase 3: Create summary audit
CREATE (audit:AuditLog {
    entityLabel: 'Account',
    entityName: 'batch:' + toString(modified) + ' accounts',
    field: 'industry',
    action: 'enrich_account_industry',
    modifiedBy: $auditActor,
    modifiedAt: datetime(),
    previousValue: 'null',
    newValue: 'Gaming'
})
RETURN modified, beforeCount
```

## Pattern 3: Label Promotion Audit

Best for: jobs that add canonical labels to staging nodes.

```cypher
MATCH (raw:zzz_salesforce_account)
WHERE NOT raw:Account
SET raw:Account
WITH raw, count(*) AS promoted
CREATE (audit:AuditLog {
    entityLabel: 'Account',
    entityName: 'batch:' + toString(promoted) + ' promoted',
    field: 'label',
    action: 'label_promotion',
    modifiedBy: $auditActor,
    modifiedAt: datetime(),
    previousValue: 'zzz_salesforce_account',
    newValue: 'Account'
})
RETURN promoted
```

## Pattern 4: Relationship Creation Audit

```cypher
MATCH (p:Person), (e:IndustryEvent)
WHERE /* matching logic */
CREATE (p)-[:ATTENDED]->(e)
WITH p, e
CREATE (p)-[:HAS_AUDIT]->(audit:AuditLog {
    entityLabel: 'Person',
    entityName: p.name,
    field: 'ATTENDED',
    action: 'link_events_to_people',
    modifiedBy: $auditActor,
    modifiedAt: datetime(),
    previousValue: null,
    newValue: e.name
})
```

## Batch vs Per-Node Tradeoffs

| Approach | When | Pros | Cons |
|----------|------|------|------|
| **Per-node** | <10K mutations | Full audit trail, rollback-ready | Slow, high storage |
| **Batch summary** | >10K mutations | Fast, minimal storage | No per-entity rollback |
| **Hybrid** | Mixed | Sample per-node + batch summary | More complex |

## Actor Convention

| Pattern | Source |
|---------|--------|
| `cron:{JOB_NAME}` | Cloud Run cron job (`cron:update-desired-tax-salary`) |
| `n8n:{WORKFLOW_ID}` | n8n workflow (`n8n:1234`) |
| `manual:{USER}` | Manual operation (`manual:a.evseev`) |
| `api:{SERVICE}` | API call (`api:customgpt`) |

## Cron Job Audit Trail Queries

```cypher
// All audit entries for a specific cron job
MATCH (a:AuditLog)
WHERE a.modifiedBy = 'cron:update-desired-tax-salary'
RETURN a ORDER BY a.modifiedAt DESC LIMIT 20

// Audit volume by cron job (top 15)
MATCH (a:AuditLog)
WHERE a.modifiedBy STARTS WITH 'cron:'
WITH a.modifiedBy AS actor, count(a) AS total,
     max(a.modifiedAt) AS lastRun
RETURN actor, total, toString(lastRun) AS lastRun
ORDER BY total DESC LIMIT 15

// Recent mutations across all cron jobs (last 24h)
MATCH (a:AuditLog)
WHERE a.modifiedBy STARTS WITH 'cron:'
  AND a.modifiedAt > datetime() - duration('P1D')
RETURN a.modifiedBy AS actor, a.entityLabel AS label,
       a.action, count(*) AS mutations
ORDER BY mutations DESC

// Verify a new job's audit trail after first run
MATCH (a:AuditLog)
WHERE a.modifiedBy = $actor
RETURN count(a) AS total, max(a.modifiedAt) AS lastRun,
       collect(DISTINCT a.entityLabel) AS labels,
       collect(DISTINCT a.action) AS actions

// Find jobs with no audit logs (potential missing audit)
// Compare against known cron job list
MATCH (w:Workflow {type: 'cloud_run_cron'})
WHERE w.write_access = true
OPTIONAL MATCH (a:AuditLog {modifiedBy: 'cron:' + w.id})
WITH w.id AS job, count(a) AS auditCount
WHERE auditCount = 0
RETURN job AS jobs_without_audit
```

## Sensitive Properties

Never store raw values in `previousValue`/`newValue` for:
- `tax_salary`, `desired_tax_salary`
- `ssn`, `social_security_number`
- `password`, `api_key`, `token`
- Bank account numbers

Use `"[REDACTED]"` instead:
```cypher
previousValue: '[REDACTED]',
newValue: '[REDACTED]'
```

## Retention

600K+ AuditLog nodes as of Feb 2026, growing ~5-10K/day. High-volume actors:
- `cron:score-contact-recency`: 212K entries
- `cron:link-meeting-attendees`: 164K entries
- `cron:enrich-account-industry`: 150K entries
- `cron:enrich-meeting-follow-ups`: 59K entries

Consider archiving to BigQuery after 90 days for long-term queryability without graph bloat.
