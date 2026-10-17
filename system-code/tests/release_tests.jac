import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.testing { JacTestClient }
import from datetime { datetime, timedelta }
import from checks.integration_helpers { rpc, fake_model, model_patch }

def planned(client: JacTestClient) -> dict {
    with model_patch(client,fake_model()) {
        run = rpc(client,"start_goal",{"text":"Plan two hours next week","workspace_id":"review","request_id":"goal"})["data"]["run"];
        run = rpc(client,"advance_run",{"run_id":run["id"],"expected_version":run["version"],"request_id":"one"})["data"]["run"];
        return rpc(client,"advance_run",{"run_id":run["id"],"expected_version":run["version"],"request_id":"two"})["data"];
    }
}

def review(client: JacTestClient, proposal: dict, decision: str = "approve") -> dict {
    return rpc(client,"review_proposal",{"proposal_id":proposal["id"],"revision":proposal["revision"],"payload_hash":proposal["payload_hash"],"decision":decision});
}

test "forgotten availability stales pending event but does not duplicate other outputs" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            rpc(client,"save_preference",{"workspace_id":"review","value":"anytime","request_id":"remember"});
            data = planned(client);
            original = rpc(client,"get_workspace",{"workspace_id":"review"})["data"]["preferences"][0];
            assert rpc(client,"forget_preference",{"preference_id":original["id"],"expected_version":original["version"]})["ok"];
            event = [p for p in data["proposals"] if p["kind"] == "create_event"][0];
            assert not review(client,event)["ok"];
            for p in data["proposals"] {
                if p["kind"] != "create_event" { assert review(client,p)["ok"]; }
            }
            loaded = rpc(client,"get_run",{"run_id":data["run"]["id"]})["data"];
            assert loaded["run"]["status"] != "completed";
            assert rpc(client,"get_workspace",{"workspace_id":"review"})["data"]["preferences"] == [];
            revised = rpc(client,"replan_run",{"run_id":data["run"]["id"],"expected_version":loaded["run"]["version"]});
            assert revised["ok"];
            assert len([p for p in revised["data"]["proposals"] if p["status"] == "pending"]) == 1;
        } finally { client.close(); }
    }
}

test "manual target edit blocks stale update approval and cancellation preserves committed data" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            data = planned(client);
            for p in data["proposals"] { assert review(client,p)["ok"]; }
            state = rpc(client,"get_run",{"run_id":data["run"]["id"]})["data"];
            revised = rpc(client,"replan_run",{"run_id":data["run"]["id"],"expected_version":state["run"]["version"]})["data"];
            update = [p for p in revised["proposals"] if p["status"] == "pending"][0];
            event = rpc(client,"get_workspace",{"workspace_id":"review"})["data"]["events"][0];
            edit = rpc(client,"save_event",{"workspace_id":"review","title":"Manual edit","start":event["start"],"end":event["end"],"request_id":"manual-edit","event_id":event["id"],"expected_version":event["version"]});
            assert edit["ok"];
            failed = review(client,update);
            assert not failed["ok"] and failed["error"]["code"] == "VERSION_CONFLICT";
            cancelled = rpc(client,"cancel_run",{"run_id":data["run"]["id"],"expected_version":revised["run"]["version"]});
            assert cancelled["ok"];
            assert len(cancelled["data"]["receipts"]) == 3;
            assert all(p["status"] in ["committed","stale"] for p in cancelled["data"]["proposals"]);
            assert len(rpc(client,"get_workspace",{"workspace_id":"review"})["data"]["events"]) == 1;
        } finally { client.close(); }
    }
}

test "no morning slot asks for a constraint change without moving the committed event" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            data = planned(client);
            for p in data["proposals"] { assert review(client,p)["ok"]; }
            original = rpc(client,"get_workspace",{"workspace_id":"review"})["data"]["events"][0];
            day = datetime.fromisoformat(original["start"]);
            moved = rpc(client,"save_event",{"workspace_id":"review","title":"Afternoon meetup","start":day.replace(hour=13).isoformat(),"end":day.replace(hour=15).isoformat(),"request_id":"afternoon","event_id":original["id"],"expected_version":1});
            assert moved["ok"];
            for offset in range(5) {
                start = day.replace(hour=9) + timedelta(days=offset);
                busy = rpc(client,"save_event",{"workspace_id":"review","title":"Morning busy","start":start.isoformat(),"end":start.replace(hour=12).isoformat(),"request_id":"busy-" + str(offset)});
                assert busy["ok"], str(busy);
            }
            assert rpc(client,"save_preference",{"workspace_id":"review","value":"morning","request_id":"morning"})["ok"];
            run = rpc(client,"get_run",{"run_id":data["run"]["id"]})["data"]["run"];
            result = rpc(client,"replan_run",{"run_id":run["id"],"expected_version":run["version"]});
            assert result["ok"] and result["data"]["run"]["status"] == "waiting_for_input";
            assert not any(p["status"] == "pending" for p in result["data"]["proposals"]);
            workspace = rpc(client,"get_workspace",{"workspace_id":"review"})["data"];
            event = [e for e in workspace["events"] if e["id"] == original["id"]][0];
            assert event["start"] == day.replace(hour=13).isoformat() and event["version"] == 2;
            assert len(workspace["tasks"]) == 1 and len(workspace["notes"]) == 1;
        } finally { client.close(); }
    }
}

test "exact approvals commit once with durable receipts and complete only after all actions" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            data = planned(client);
            forged = dict(data["proposals"][0]); forged["payload_hash"] = "0" * 64;
            assert not review(client,forged)["ok"];
            for proposal in data["proposals"] {
                accepted = review(client,proposal);
                assert accepted["ok"], str(accepted);
                assert review(client,proposal)["data"]["receipts"][-1]["id"] == accepted["data"]["receipts"][-1]["id"];
            }
            assert accepted["data"]["run"]["status"] == "completed";
            workspace = rpc(client,"get_workspace",{"workspace_id":"review"})["data"];
            assert len(workspace["events"]) == 1 and len(workspace["tasks"]) == 1 and len(workspace["notes"]) == 1;
            assert len(workspace["receipts"]) == 3;
        } finally { client.close(); }
    }
}

test "rejection performs no write and a newly busy slot blocks approval" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            data = planned(client);
            rejected = review(client,data["proposals"][0],"reject");
            assert rejected["ok"] and rejected["data"]["proposals"][0]["status"] == "rejected";
            assert not review(client,data["proposals"][0])["ok"];
            event = [p for p in data["proposals"] if p["kind"] == "create_event"][0];
            payload = event["payload"];
            busy = rpc(client,"save_event",{"workspace_id":"review","title":"Busy","start":payload["start"],"end":payload["end"],"request_id":"busy"});
            assert busy["ok"], str(busy);
            conflict = review(client,event);
            assert not conflict["ok"] and conflict["error"]["code"] == "CALENDAR_CONFLICT", str(conflict);
            workspace = rpc(client,"get_workspace",{"workspace_id":"review"})["data"];
            assert workspace["notes"] == [] and workspace["receipts"] == [];
            assert len(workspace["events"]) == 1;
        } finally { client.close(); }
    }
}

test "preference correction revises the same event and preserves unrelated outputs" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            pref = rpc(client,"save_preference",{"workspace_id":"review","value":"anytime","request_id":"availability"});
            assert pref["ok"], str(pref);
            data = planned(client);
            for proposal in data["proposals"] { assert review(client,proposal)["ok"]; }
            original = rpc(client,"get_workspace",{"workspace_id":"review"})["data"];
            preference = original["preferences"][0];
            corrected = rpc(client,"correct_preference",{"preference_id":preference["id"],"expected_version":preference["version"],"value":"morning"});
            assert corrected["ok"], str(corrected);
            revised = rpc(client,"replan_run",{"run_id":data["run"]["id"],"expected_version":rpc(client,"get_run",{"run_id":data["run"]["id"]})["data"]["run"]["version"]});
            assert revised["ok"], str(revised);
            update = [p for p in revised["data"]["proposals"] if p["status"] == "pending"];
            assert len(update) == 1 and update[0]["kind"] == "update_event";
            assert update[0]["payload"]["id"] == original["events"][0]["id"];
            assert review(client,update[0])["ok"];
            after = rpc(client,"get_workspace",{"workspace_id":"review"})["data"];
            assert len(after["events"]) == 1 and after["events"][0]["id"] == original["events"][0]["id"];
            assert after["events"][0]["version"] == 2;
            assert [t["id"] for t in after["tasks"]] == [t["id"] for t in original["tasks"]];
            assert [n["id"] for n in after["notes"]] == [n["id"] for n in original["notes"]];
        } finally { client.close(); }
    }
}
