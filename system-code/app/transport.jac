# The only place that understands Jac's HTTP transport wrapper.
def unwrap_response(response: dict) -> dict {
    candidate = response;
    if "data" in response and isinstance(response["data"], dict) {
        candidate = response["data"];
    }
    if "result" in candidate {
        candidate = candidate["result"];
    } elif "reports" in candidate {
        reports = candidate["reports"];
        if not isinstance(reports, list) or len(reports) != 1 {
            return {"ok": False, "data": None, "error": {"code": "TRANSPORT_ERROR", "message": "Expected exactly one application report.", "retryable": False}};
        }
        candidate = reports[0];
    }
    if not isinstance(candidate, dict) or not isinstance(candidate.get("ok"), bool) or "data" not in candidate or "error" not in candidate {
        return {"ok": False, "data": None, "error": {"code": "TRANSPORT_ERROR", "message": "Invalid application envelope.", "retryable": False}};
    }
    return candidate;
}
