# MediaWiki Helm Chart - TODO List

This document tracks future improvements and deferred production-readiness items for the MediaWiki Helm chart.

## Recently Completed

### Label Selector Fixes (Security/Correctness)
**Status:** COMPLETED (2026-01-03)
**Priority:** Critical
**Issue:** Network policies and PDBs were using overly broad label selectors that didn't distinguish between MediaWiki and MariaDB pods

**Root Cause:**
Both MediaWiki and MariaDB pods share the label `app.kubernetes.io/name: mediawiki` (because they're part of the same chart). The MariaDB network policy was accidentally matching MediaWiki pods, blocking ingress traffic to port 8080/8443.

**Labels that distinguish components:**
- MediaWiki pod: `app.kubernetes.io/component: mediawiki`
- MariaDB pod: `app.kubernetes.io/component: primary/secondary` AND `app.kubernetes.io/part-of: mariadb`

**Files Fixed:**
- `templates/mariadb/networkpolicy.yaml` - Added `app.kubernetes.io/part-of: mariadb` to podSelector (line 21)
- `templates/networkpolicy.yaml` - Added `app.kubernetes.io/component: mediawiki` to podSelector (line 20) and fixed egress rule to use `app.kubernetes.io/part-of: mariadb` instead of `app.kubernetes.io/name: mariadb` (line 42)
- `templates/pdb.yaml` - Added `app.kubernetes.io/component: mediawiki` to podSelector (line 26)

**Verified Correct:**
- `templates/deployment.yaml` - Already has component selector ✓
- `templates/mariadb/primary/statefulset.yaml` - Already has component selectors ✓
- `templates/mariadb/secondary/statefulset.yaml` - Already has component selectors ✓
- `templates/mariadb/primary/pdb.yaml` - Already has component selector ✓
- `templates/mariadb/secondary/pdb.yaml` - Already has component selector ✓

**Best Practice Established:**
Always use `app.kubernetes.io/component` or `app.kubernetes.io/part-of` labels in selectors when multiple pod types exist in the same chart with the same `app.kubernetes.io/name`.

---

## High Priority

### 1. Read-Only Root Filesystem (Security Hardening)
**Status:** DONE
**Priority:** High
**Issue:** MariaDB pod currently has `readOnlyRootFilesystem: false` to allow writes to `/tmp`

**Action Required:**
- Isolate `/tmp` as a separate writable volume (emptyDir)
- Revert root filesystem to read-only (`readOnlyRootFilesystem: true`)
- Test for additional directories that may require write access
- Update both primary and secondary MariaDB configurations

**Files to modify:**
- `values.yaml` lines 1151, 1591 (containerSecurityContext)
- `templates/mariadb/primary/statefulset.yaml` (add emptyDir volume for /tmp)
- `templates/mariadb/secondary/statefulset.yaml` (add emptyDir volume for /tmp)

**Note:** This may reveal additional issues that need to be addressed. Not intrinsically problematic but is an enabler in the context of other security weaknesses.

### 2. Backup Automation
**Status:** Deferred
**Priority:** High
**Issue:** Manual backup scripts exist but are not integrated into the chart

**Action Required:**
- Generalize existing backup scripts for broader use
- Implement as Kubernetes CronJob in the chart
- Add configuration options to values.yaml:
  ```yaml
  backup:
    enabled: true
    schedule: "0 3 * * 0,3"  # Twice weekly
    retention: 7  # days
    destination: "s3://backups/"
    s3:
      bucket: "mediawiki-backups"
      region: "us-east-1"
      credentialsSecret: "s3-credentials"
  ```

**Files to create:**
- `templates/backup-cronjob.yaml`
- Backup script ConfigMap or container

**Related:** Automated backup verification (see #4)

### 3. Disaster Recovery Documentation
**Status:** Not started
**Priority:** High

**Action Required:**
- Document Recovery Time Objective (RTO): Target 1-4 hours
- Document Recovery Point Objective (RPO): Target <1 hour data loss
- Create step-by-step restore procedures
- Test restore process and document actual times
- Create runbook for disaster scenarios:
  - Database corruption
  - Complete cluster failure
  - Accidental data deletion
  - Storage failure

**Files to create:**
- `docs/DISASTER_RECOVERY.md`
- `docs/BACKUP_RESTORE.md`

## Medium Priority

### 4. MariaDB TLS Implementation
**Status:** Disabled (missing dependency)
**Priority:** Medium
**Issue:** TLS auto-generation requires Bitnami common chart library that isn't included as a dependency

**Current Error:**
```
template: no template "common.certs.sans" associated with template "gotpl"
```

**Action Required (choose one approach):**

**Option A: Add Common Chart Dependency (Recommended)**
1. Add to `Chart.yaml`:
   ```yaml
   dependencies:
     - name: common
       repository: oci://registry-1.docker.io/bitnamicharts
       version: 2.x.x
   ```
2. Run `helm dependency update`
3. Re-enable TLS in values.yaml

**Option B: Manual Certificate Management**
1. Generate certificates manually or use cert-manager
2. Create Kubernetes secret with certificates
3. Configure `tls.existingSecret` in values.yaml

**Option C: Implement Custom Certificate Generation**
1. Create custom template `_certs.tpl` with certificate generation logic
2. Replace dependency on `common.certs.sans` template
3. Re-enable TLS

**Files involved:**
- `Chart.yaml` (add dependency)
- `values.yaml` line 878 (currently disabled)
- `templates/mariadb/tls-secret.yaml` (uses missing template)
- `templates/mariadb/cert.yaml` (uses missing template)

**Note:** For single-node cluster, TLS between pods on same node provides minimal security benefit. Communication never leaves the node and stays within Kubernetes internal network. This is lower priority unless deploying to multi-node cluster or if compliance requires encryption in transit.

### 5. Automated Backup Verification
**Status:** Not started
**Priority:** Medium
**Dependencies:** Requires #2 (Backup Automation) to be completed first

**Action Required:**
- Create automated restore testing job
- Verify backup integrity after each backup
- Alert on backup failures
- Periodically test full restore to temporary namespace

**Files to create:**
- `templates/backup-verify-cronjob.yaml`

### 6. MariaDB Replication (High Availability)
**Status:** Deferred until multi-node cluster
**Priority:** Medium (Low for current single-node deployment)
**Current State:** Chart supports replication but disabled in values.yaml

**Action Required (when moving to multi-node cluster):**
```yaml
mariadb:
  architecture: replication  # Currently: standalone
  primary:
    replicaCount: 1
  secondary:
    replicaCount: 1  # Add at least 1 replica
```

**Files to modify:**
- `values.yaml` line 789 (architecture)
- `values.yaml` lines 1420-1427 (secondary.replicaCount)

**Note:** Currently running on single-node k8s cluster, so replication provides minimal benefit. Revisit when migrating to multi-node cluster.

### 7. Slow Query Logging
**Status:** Deferred
**Priority:** Medium
**Issue:** Currently disabled, preventing analysis of slow queries

**Action Required:**
```yaml
# values.yaml line 988
mariadb:
  primary:
    configuration: |-
      slow_query_log=1  # Currently: 0
      long_query_time=0.5  # Capture queries > 500ms
```

**Files to modify:**
- `values.yaml` lines 988-989, 1444-1445 (primary and secondary configs)

**Related:** Consider adding log aggregation/analysis

### 8. RBAC for MariaDB
**Status:** Deferred
**Priority:** Medium
**Current State:** Templates exist but disabled by default

**Action Required:**
```yaml
# values.yaml line 1855
mariadb:
  rbac:
    create: true  # Currently: false
```

**Files to modify:**
- `values.yaml` line 1855

**Note:** Review and update role permissions in `templates/mariadb/rbac.yaml` if needed

## Low Priority / Future Enhancements

### 9. MediaWiki High Availability
**Status:** Deferred until multi-node cluster
**Priority:** Low (for current single-node deployment)
**Dependencies:** Requires ReadWriteMany storage class

**Action Required:**
```yaml
# values.yaml
replicaCount: 2  # Currently: 1
persistence:
  accessModes:
    - ReadWriteMany  # Currently: ReadWriteOnce
```

**Considerations:**
- Requires shared storage (NFS, CephFS, or cloud provider shared volumes)
- May need session affinity configuration
- Need to test MediaWiki behavior with multiple replicas

### 10. Transparent Data Encryption (TDE)
**Status:** Not started
**Priority:** Low
**Use Case:** Encryption at rest for sensitive deployments

**Action Required:**
```yaml
mariadb:
  tde:
    enabled: true
    secretsStoreProvider:
      enabled: true
      provider: vault
```

**Files to modify:**
- `values.yaml` line 907
- Requires external secrets manager (Vault, AWS Secrets Manager, etc.)

### 11. Structured Logging
**Status:** Not started
**Priority:** Low

**Action Required:**
- Add logging configuration to values.yaml
- Configure log level (debug, info, warning, error)
- Enable structured logging (JSON format)
- Integrate with log aggregation system

**Files to modify:**
- `values.yaml` (add new logging section)
- May require MediaWiki LocalSettings.php customization

### 12. Resource Monitoring and Auto-scaling
**Status:** Not started
**Priority:** Low

**Action Required:**
- Configure Horizontal Pod Autoscaler (HPA) for MediaWiki
- Set up custom metrics (if needed)
- Define scaling thresholds based on CPU/memory or custom metrics

**Files to create:**
- `templates/hpa.yaml`

### 13. Network Policy Refinement
**Status:** Deferred
**Priority:** Low
**Current State:** Network policies restricted but may need fine-tuning

**Action Required:**
- Test network connectivity with restricted policies
- Add explicit egress rules for external services (DNS, external APIs)
- Document required network access
- Consider adding Ingress Controller specific rules

**Files to modify:**
- `values.yaml` lines 2489, 2492 (currently set to restrictive defaults)
- May need to add `extraIngress` or `extraEgress` rules

### 14. Service LoadBalancer IP Restrictions
**Status:** Not configured
**Priority:** Low
**Security:** Would restrict access to specific IP ranges

**Action Required:**
```yaml
service:
  loadBalancerSourceRanges:
    - "10.0.0.0/8"      # Private network
    - "203.0.113.0/24"   # Office/VPN IP range
```

**Files to modify:**
- `values.yaml` line 510

**Note:** Since this is for personal use, may not be necessary. Document for future reference.

## Completed Items

- ✅ Password enforcement (auto-managed by Helm lookup)
- ✅ Explicit resource requests/limits for MediaWiki
- ✅ Explicit resource requests/limits for MariaDB
- ✅ Enable metrics for MediaWiki and MariaDB
- ✅ Enable and configure startup probe for MediaWiki
- ✅ Change liveness probe from TCP to HTTP
- ✅ Improve readiness probe timings
- ⚠️ TLS for MariaDB - Attempted but disabled due to missing chart dependency (see #4)
- ✅ Restrict network policies (allowExternal: false, allowExternalEgress: false)
- ✅ Migrate from Bitnami MariaDB to official MariaDB image
- ✅ Update security contexts for official MariaDB image (UID 999)
- ✅ Update health probes to use mariadb-admin
- ✅ Fix read-only filesystem issues for MariaDB

## Notes

- Storage size (8Gi) is adequate for current use case (3MB compressed backup, 12MB SQL dump)
- Single-node Kubernetes cluster deployment
- Personal use deployment (not multi-tenant)
- User has existing backup scripts to be integrated later

## Review Schedule

- **Quarterly Review:** Reassess priorities based on deployment experience
- **Before Production Migration:** Complete all High Priority items
- **Before Multi-Node Migration:** Complete #6 (MariaDB Replication) and #9 (MediaWiki HA)
