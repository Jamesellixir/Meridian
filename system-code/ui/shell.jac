sv import from app.api { get_health, HealthData, HealthEnvelope }

def:pub FoundationShell -> JsxElement {
    has status: str = "Checking server...";
    async can with entry {
        try {
            result = await get_health();
            status = "Server connected - contract " + result.data.contract_version;
        } except Exception {
            status = "Server connection failed";
        }
    }
    return <main><h1>Meridian</h1><p>Foundation verification</p><p>{status}</p><p>Planning, approvals and workspace tools are not implemented yet.</p></main>;
}
