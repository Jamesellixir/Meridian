sv import from app.api { get_health, HealthData, HealthEnvelope }
import from .planner { PlannerPanel }
def:pub FoundationShell -> JsxElement {
    has status: str = "Checking server...";
    async can with entry {
        try { result = await get_health(); status = "Server connected - contract " + result.data.contract_version; }
        except Exception { status = "Server connection failed"; }
    }
    return <main style={{"maxWidth":"880px","margin":"32px auto","padding":"24px","fontFamily":"system-ui"}}><h1>Meridian</h1><p>Local planning workspace</p><p>{status}</p><PlannerPanel /></main>;
}
