# Verify Schema CREATE Privilege - Infrastructure Team

**Date:** 2025-12-10  
**Status:** VERIFICATION NEEDED  
**Priority:** CRITICAL

---

## Issue

Migration is still failing with:
```
ERROR: permission denied for schema public
LINE 1: CREATE TABLE "ar_internal_metadata" ("key" character varying...
```

---

## Verification Required

Please verify the following SQL commands return the expected results:

### 1. Check CREATE Privilege
```sql
SELECT has_schema_privilege('sira_community_admin', 'public', 'CREATE');
-- Expected: TRUE (or 't')
```

### 2. Check Schema Ownership
```sql
SELECT nspname, nspowner::regrole as owner 
FROM pg_namespace 
WHERE nspname = 'public';
-- Expected: owner should be 'sira_community_admin'
```

### 3. Check User Attributes
```sql
\du sira_community_admin
-- Expected: Should show SUPERUSER or Attributes: Superuser
```

### 4. List All Schema Privileges
```sql
SELECT 
    grantee,
    privilege_type
FROM information_schema.role_schema_grants
WHERE schema_name = 'public' 
  AND grantee = 'sira_community_admin';
-- Expected: Should include 'CREATE' in privilege_type
```

---

## If Privilege Is Missing

Execute:
```sql
-- As superuser (postgres or admin)
GRANT CREATE ON SCHEMA public TO sira_community_admin;

-- Verify
SELECT has_schema_privilege('sira_community_admin', 'public', 'CREATE');
-- Should return: TRUE
```

---

## Alternative: Grant ALL Privileges

If CREATE alone doesn't work, try granting ALL:
```sql
GRANT ALL ON SCHEMA public TO sira_community_admin;
```

---

## Important Notes

1. The grant must be executed **as a superuser** (postgres user or another superuser)
2. After granting, the user may need to reconnect for privileges to take effect
3. Ownership alone is NOT sufficient - CREATE must be explicitly granted
4. Verify the grant was applied correctly using the queries above

---

## Next Steps

1. ✅ Infrastructure team verifies privilege with queries above
2. ✅ If missing, grant CREATE privilege
3. ✅ Verify grant was applied
4. ✅ Retry migration



