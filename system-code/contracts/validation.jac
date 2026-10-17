import re;
import from datetime { datetime }
import from zoneinfo { ZoneInfo }
import from contracts.models { GoalRequest, GoalSpec, EventRecord, Envelope, success, failure }

def valid_id(value: str) -> bool {
    return re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,127}", value) is not None;
}

def validate_goal_request(request: GoalRequest) -> Envelope {
    text = request.text.strip();
    if not text or len(text) > 4000 {
        return failure("VALIDATION_ERROR", "Goal text must contain 1 to 4000 characters.");
    }
    if not valid_id(request.workspace_id) or not valid_id(request.request_id) {
        return failure("VALIDATION_ERROR", "Workspace and request IDs must be valid identifiers.");
    }
    return success({"text": text, "workspace_id": request.workspace_id, "request_id": request.request_id});
}

def validate_goal_spec(spec: GoalSpec) -> Envelope {
    if spec.intent not in ["plan_session", "clarify", "unsupported", "chat"] {
        return failure("VALIDATION_ERROR", "Unknown planning intent.");
    }
    if not spec.title.strip() or len(spec.title) > 200 or spec.duration_minutes < 0 or spec.duration_minutes > 480 {
        return failure("VALIDATION_ERROR", "Invalid goal title or duration.");
    }
    if spec.intent == "chat" and not spec.reply.strip() { return failure("VALIDATION_ERROR", "Chat needs a reply."); }
    if spec.intent == "plan_session" and spec.duration_minutes < 1 {
        return failure("VALIDATION_ERROR", "A session needs a positive duration.");
    }
    if len(spec.constraints) > 16 or len(spec.missing_information) > 8 {
        return failure("VALIDATION_ERROR", "Too many constraints or clarification questions.");
    }
    if spec.intent == "clarify" and not spec.missing_information {
        return failure("VALIDATION_ERROR", "Clarification must identify missing information.");
    }
    return success({"intent": spec.intent});
}

def validate_event(event: EventRecord) -> Envelope {
    if not valid_id(event.id) or not valid_id(event.workspace_id) or not event.title.strip() or len(event.title) > 200 or event.version < 1 {
        return failure("VALIDATION_ERROR", "Invalid event identity, title or version.");
    }
    try {
        ZoneInfo(event.timezone);
        start = datetime.fromisoformat(event.start);
        end = datetime.fromisoformat(event.end);
        if start.utcoffset() is None or end.utcoffset() is None or end <= start {
            return failure("VALIDATION_ERROR", "Event timestamps need offsets and end must follow start.");
        }
    } except Exception {
        return failure("VALIDATION_ERROR", "Invalid ISO timestamp or timezone.");
    }
    return success({"id": event.id});
}

def validate_review(proposal_id: str, revision: int, payload_hash: str, decision: str) -> Envelope {
    if not valid_id(proposal_id) or revision < 1 or re.fullmatch(r"[0-9a-f]{64}", payload_hash) is None or decision not in ["approve", "reject"] {
        return failure("VALIDATION_ERROR", "Review requires a proposal, positive revision, SHA-256 hash and approve/reject decision.");
    }
    return success({"proposal_id": proposal_id, "revision": revision, "decision": decision});
}
