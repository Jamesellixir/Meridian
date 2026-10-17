import from contracts.models { HealthData, HealthEnvelope }

def:pub get_health -> HealthEnvelope {
    return HealthEnvelope(ok=True, data=HealthData());
}
