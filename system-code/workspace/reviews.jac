import json;
import hashlib;
import hmac;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.runtimelib.exceptions { WriteConflict }
import from uuid { uuid4 }
import from contracts.models { RunEnvelope, ReceiptRecord }
import from workspace.runs { StoredRun, _view, _error, _activity, _now }
import from workspace.records { StoredReceipt, _receipts }
import from workspace.actions { _execute }

def _digest(kind: str, payload: dict) -> str {
    return hashlib.sha256(json.dumps({"kind":kind,"payload":payload},sort_keys=True,separators=(",",":"),ensure_ascii=False).encode("utf-8")).hexdigest();
}

def _review_exact(proposal_id: str, revision: int, payload_hash: str, decision: str) -> RunEnvelope {
    for run in [root -->][?:StoredRun] {
        proposals = json.loads(run.proposals_json);
        for proposal in proposals {
            if proposal["id"] != proposal_id { continue; }
            if proposal.get("revision",1) != revision or not hmac.compare_digest((proposal["payload_hash"] as str).encode("utf-8"),payload_hash.encode("utf-8")) or not hmac.compare_digest(_digest(proposal["kind"],proposal["payload"]).encode("utf-8"),payload_hash.encode("utf-8")) {
                return _error("STALE_PROPOSAL","Reviewed content or revision no longer matches.");
            }
            if proposal["status"] == "committed" {
                if decision != "approve" { return _error("INVALID_STATE","A committed action cannot be rejected."); }
                return _view(run);
            }
            if proposal["status"] == "rejected" and decision == "reject" { return _view(run); }
            if run.status not in ["waiting_for_approval","waiting_for_input"] or proposal["status"] != "pending" {
                return _error("STALE_PROPOSAL","This action is not pending approval.");
            }
            if decision == "reject" {
                proposal["status"] = "rejected";
                run.status = "waiting_for_input"; run.questions_json = json.dumps(["Action rejected. Replan the pending actions or cancel this run."]);
            } else {
                result = _execute(run.workspace_id,run.id,proposal);
                if not result.ok {
                    assert result.error is not None;
                    return _error(result.error.code,result.error.message);
                }
                assert result.data is not None;
                output = result.data["record_id"];
                receipt = ReceiptRecord(id=str(uuid4()),workspace_id=run.workspace_id,proposal_id=proposal_id,
                    record_ids=[output],committed_at=_now(),idempotency_key=proposal_id + ":" + str(revision));
                root ++> StoredReceipt(record=receipt,run_id=run.id);
                proposal["status"] = "committed";
                if output not in run.output_ids { run.output_ids = run.output_ids + [output]; }
            }
            run.proposals_json = json.dumps(proposals); run.version += 1;
            event_proposals = [p for p in proposals if p["kind"] in ["create_event","update_event"]];
            if not run.needs_replan and event_proposals and event_proposals[-1]["status"] == "committed" and all(p["status"] in ["committed","stale"] for p in proposals) {
                run.status = "completed"; run.questions_json = "[]";
            }
            _activity(run,"review_proposal",decision + " " + proposal["kind"]);
            # Jac 0.34.24 can wrap this conflict in RuntimeError before its HTTP mapper.
            # Explicitly abort the losing unit of work; never replay a partial mutation.
            try { commit(); }
            except Exception as conflict {
                if not isinstance(conflict,WriteConflict) and not str(conflict).startswith("WriteConflict:") { raise; }
                context = Jac.get_context();
                context.mem.abort(); context.pending_effects.clear(); context.read_versions.clear(); context.diagnostics.clear();
                return _error("VERSION_CONFLICT","Another request committed first. Reload and retry the exact approval to recover its receipt.");
            }
            return _view(run);
        }
    }
    return _error("NOT_FOUND","Proposal not found.");
}
