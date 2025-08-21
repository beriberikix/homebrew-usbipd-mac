# Archived Webhook Workflows

This directory contains workflows that were previously used for webhook-based formula updates but have been deactivated as part of the migration to homebrew-releaser.

## Migration Summary

**Date**: August 2025  
**Migration**: Webhook-based formula updates → homebrew-releaser integration

### What Changed

**Before (Webhook System)**:
- Main repository sent `repository_dispatch` webhooks to this tap repository
- `formula-update.yml` workflow handled webhook events and updated formula
- Required `WEBHOOK_TOKEN` secret and complex webhook payload handling
- Separate repositories with network communication between them

**After (Homebrew-Releaser)**:
- Main repository uses `homebrew-releaser` GitHub Action during release workflow
- Formula updates happen directly within the main repository's release process
- No webhook communication needed - direct repository access via `HOMEBREW_TAP_TOKEN`
- Simplified architecture with better reliability and error handling

### Archived Files

- **`formula-update.yml.archived`**: Main webhook handler workflow that processed `repository_dispatch` events and updated the formula based on release metadata
- **`debug-dispatch.yml.archived`**: Debug workflow for troubleshooting webhook delivery issues

### Why These Were Archived

1. **Reliability**: homebrew-releaser is more reliable than webhook delivery
2. **Simplicity**: Eliminates webhook payload parsing and error handling complexity
3. **Maintenance**: Reduces the number of repositories and workflows to maintain
4. **Security**: Uses direct repository access instead of webhook tokens

### Rollback Information

If rollback to webhook system is ever needed:

1. **Restore workflows**: Copy `.archived` files back to main workflows directory and remove `.archived` extension
2. **Update main repository**: Re-add webhook notification job to release workflow
3. **Secrets**: Ensure `WEBHOOK_TOKEN` is configured in main repository
4. **Remove homebrew-releaser**: Remove homebrew-releaser step from main repository workflow

### Current Status

- ✅ Webhooks deactivated (workflows archived)
- ✅ Homebrew-releaser active in main repository
- ✅ Formula updates working via homebrew-releaser
- ✅ No manual intervention required for releases

### References

- **Main Repository**: https://github.com/beriberikix/usbipd-mac
- **Homebrew-Releaser**: https://github.com/Justintime50/homebrew-releaser
- **Migration Documentation**: See main repository `Documentation/homebrew-releaser-setup.md`

---

**Note**: These archived workflows are preserved for historical reference and potential rollback scenarios. They should not be restored to active use without understanding the current homebrew-releaser setup.