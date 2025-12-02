# Install Script .env Path Resolution Bug

## Objective
Fix the install script error where Step 6 ("Running Services") fails with ".env file not found in project root" immediately after Step 5 successfully saves the .env file. This is a path resolution bug preventing the install from completing.

## Root Cause **[CONFIRMED]**

**File:** `scripts/06_run_services.sh`
**Lines:** 9, 15, 22, 34
**Issue:** Script uses **relative paths** without defining `SCRIPT_DIR`/`PROJECT_ROOT` variables

**Evidence:**
- Step 5 output: `[SUCCESS] Service configuration complete. .env updated at /home/bailey/Documents/n8n System/n8n-install/.env`
- Step 6 output: `[ERROR] .env file not found in project root.`
- Script runs from unknown working directory, looks for `.env` in wrong location

**Broken code (06_run_services.sh:9):**
```bash
if [ ! -f ".env" ]; then  # ❌ Relative path!
  log_error ".env file not found in project root."
```

**Working pattern (03_generate_secrets.sh:15-18):**
```bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
OUTPUT_FILE="$PROJECT_ROOT/.env"  # ✅ Absolute path
```

**Fix:** Add `SCRIPT_DIR` and `PROJECT_ROOT` definitions, use absolute paths

## Changes

### Backend (Scripts):
- **File:** `scripts/install.sh` (or script called by install.sh for Step 6)
  - **Function:** Step 6 "Running Services" section
  - **Issue:** Likely using relative path `.env` without proper `cd` to project root, or missing quotes around paths with spaces
  - **Fix:** Ensure script uses `${PROJECT_ROOT}/.env` with proper quoting and verifies working directory

- **Files to investigate:**
  - `scripts/install.sh` - Main installer
  - `scripts/06_start_services.sh` (if exists) - Step 6 script
  - Any script sourcing `.env` in Step 6

### Testing
**Manual testing (since no automated tests):**

1. **Reproduce the bug:**
   - Run `sudo bash ./scripts/install.sh` on a system with path containing spaces
   - Verify it fails at Step 6 with ".env file not found"

2. **After fix:**
   - Run install script on clean system (path with spaces)
   - Verify Step 6 proceeds without .env error
   - Verify services actually start

3. **Smoke test:**
   - Check `.env` file exists: `ls -la .env`
   - Check services running: `docker compose -p localai ps`
   - Run status reporter: `bash scripts/status_report.sh`

4. **Edge cases:**
   - Path with spaces: `/home/user/n8n install/`
   - Path without spaces: `/opt/n8n-install/`
   - Relative vs absolute paths

## Acceptance Criteria

- [ ] Install script completes all 7 steps without .env file errors
- [ ] Services start successfully after Step 6
- [ ] Works with paths containing spaces (quoted properly)
- [ ] Works with standard paths without spaces
- [ ] `.env` file location logged consistently across all steps
- [ ] No regression: existing installs still work

## Rollout

**Deployment:**
- Fix is a script change only (no service disruption)
- Users can update via `git pull` and re-run installer if needed
- No data loss risk

**Testing before merge:**
1. Test on VM with path containing spaces
2. Test on VM with standard path
3. Verify clean install completes end-to-end

**Rollback plan:**
- Revert commit if script breaks in new ways
- Script changes are non-destructive (no data loss)
- Users can restore previous script version via git

## Next Steps

1. Examine `scripts/install.sh` Step 6 section
2. Identify exact line causing ".env file not found" error
3. Fix path resolution and quoting
4. Test on both path scenarios
5. Update this AIP with findings and solution
6. Update Feature Registry
7. Consider adding to regression tests in `scripts/validate_install.sh`
