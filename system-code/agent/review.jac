import from contracts.models { RunEnvelope }
import from contracts.validation { validate_review }
import from workspace.runs { _error }
import from workspace.reviews { _review_exact }

def _review(proposal_id: str, revision: int, payload_hash: str, decision: str) -> RunEnvelope {
    validation = validate_review(proposal_id,revision,payload_hash,decision);
    if not validation.ok { return _error("VALIDATION_ERROR","Supply the exact proposal ID, revision, hash and approve/reject decision."); }
    return _review_exact(proposal_id,revision,payload_hash,decision);
}
