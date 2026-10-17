import from uuid { uuid4 }
import from contracts.models { WorkspaceEnvelope }
import from contracts.validation { valid_id }
import from workspace.planning { StoredConfirmedPreference }
import from workspace.records { _workspace, _workspace_error }

# Personal context for conversation. Scheduling uses the separate availability rule.
def _save_soul(workspace_id: str, value: str, expected_version: int) -> WorkspaceEnvelope {
    if not valid_id(workspace_id) or len(value) > 4000 { return _workspace_error("VALIDATION_ERROR","Keep personal context within 4000 characters."); }
    for item in [root -->][?:StoredConfirmedPreference] {
        if item.workspace_id == workspace_id and item.key == "soul" {
            if item.version != expected_version and (item.confirmed or expected_version != 0) { return _workspace_error("VERSION_CONFLICT","Memory changed. Reload before saving."); }
            item.value = value.strip(); item.confirmed = bool(value.strip()); item.version += 1;
            return _workspace(workspace_id);
        }
    }
    if expected_version != 0 { return _workspace_error("VERSION_CONFLICT","Memory changed. Reload before saving."); }
    if value.strip() { root ++> StoredConfirmedPreference(id=str(uuid4()),workspace_id=workspace_id,key="soul",value=value.strip()); }
    return _workspace(workspace_id);
}
