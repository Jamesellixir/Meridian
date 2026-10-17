# Register server endpoints and their DTOs explicitly in the entry module.
import from app.api { get_health, HealthData, HealthEnvelope }

cl {
    import from ui.shell { FoundationShell }
    def:pub app -> JsxElement { return <FoundationShell />; }
}
