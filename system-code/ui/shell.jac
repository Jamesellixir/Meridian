import "./dashboard.css";
import "./chat.css";
sv import from app.api { get_health, HealthData, HealthEnvelope }
import from .planner { PlannerPanel }

def:pub FoundationShell -> JsxElement {
    has status: str = "Checking server...";
    async can with entry {
        try {
            result = await get_health();
            status = "Server connected - contract " + result.data.contract_version if result.ok else "Server connection failed";
        } except Exception { status = "Server connection failed"; }
    }
    return <PlannerPanel connection_status={status} />;
}
import "./delight.css";
