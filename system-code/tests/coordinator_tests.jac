import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.runtimelib.testing { JacTestClient }
import from jaclang.byllm.lib { MockLLM, MockRawResponse, MockError }
import from app.transport { unwrap_response }
import from workspace.runs { StoredRun, _claim, _finish }

import from checks.integration_helpers { rpc, fake_model, model_patch }

test "durable coordinator stages propose without executing workspace writes" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            with model_patch(client,fake_model()) {
                started = rpc(client, "start_goal", {"text":"Plan our two-hour AI meetup next week", "workspace_id":"demo", "request_id":"start"});
                assert started["ok"], str(started);
                run = started["data"]["run"];
                same = rpc(client, "start_goal", {"text":run["goal"], "workspace_id":"demo", "request_id":"start"});
                assert same["data"]["run"]["id"] == run["id"];
                first = rpc(client, "advance_run", {"run_id":run["id"], "expected_version":run["version"], "request_id":"interpret"});
                assert first["ok"] and first["data"]["run"]["status"] == "queued", str(first);
                assert first["data"]["run"]["steps"][0]["status"] == "completed";
                second = rpc(client, "advance_run", {"run_id":run["id"], "expected_version":first["data"]["run"]["version"], "request_id":"draft"});
                assert second["ok"] and second["data"]["run"]["status"] == "waiting_for_approval", str(second);
                proposals = second["data"]["proposals"];
                assert len(proposals) == 3;
                assert {p["kind"] for p in proposals} == {"create_note", "create_task", "create_event"};
                assert all(p["status"] == "pending" and len(p["payload_hash"]) == 64 for p in proposals);
                assert second["data"]["run"]["output_ids"] == [];
                retry = rpc(client, "advance_run", {"run_id":run["id"], "expected_version":1, "request_id":"draft"});
                assert [p["id"] for p in retry["data"]["proposals"]] == [p["id"] for p in proposals];
                old_retry = rpc(client,"advance_run",{"run_id":run["id"],"expected_version":second["data"]["run"]["version"],"request_id":"interpret"});
                assert old_retry["data"]["run"]["version"] == second["data"]["run"]["version"];
                assert rpc(client, "list_tasks", {"workspace_id":"demo"})["data"]["tasks"] == [];
                loaded = rpc(client, "get_run", {"run_id":run["id"]});
                assert loaded["data"]["run"]["version"] == second["data"]["run"]["version"];
                client.close();
                client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
                restored = rpc(client,"get_run",{"run_id":run["id"]});
                assert [p["id"] for p in restored["data"]["proposals"]] == [p["id"] for p in proposals];
                cancelled = rpc(client,"cancel_run",{"run_id":run["id"],"expected_version":restored["data"]["run"]["version"]});
                assert all(p["status"] == "stale" for p in cancelled["data"]["proposals"]);
            }
        } finally { client.close(); }
    }
}

test "clarification cancellation and stale versions are explicit" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            model = MockLLM(model_name="mockllm", config={"outputs":[MockRawResponse(content='{"title":"Meetup","duration_minutes":0,"missing_information":["How long?"],"constraints":[],"intent":"clarify"}')]});
            with model_patch(client,model) {
                started = rpc(client,"start_goal",{"text":"Plan a meetup","workspace_id":"demo","request_id":"clarify"});
                run = started["data"]["run"];
                waiting = rpc(client,"advance_run",{"run_id":run["id"],"expected_version":1,"request_id":"clarify-stage"});
                assert waiting["data"]["run"]["status"] == "waiting_for_input", str(waiting);
                assert waiting["data"]["questions"] == ["How long?"];
                conflict = rpc(client,"provide_input",{"run_id":run["id"],"expected_version":1,"text":"Two hours next week","request_id":"answer"});
                assert conflict["error"]["code"] == "VERSION_CONFLICT";
                answer = rpc(client,"provide_input",{"run_id":run["id"],"expected_version":waiting["data"]["run"]["version"],"text":"Two hours next week","request_id":"answer"});
                assert answer["data"]["run"]["status"] == "queued";
                cancelled = rpc(client,"cancel_run",{"run_id":run["id"],"expected_version":answer["data"]["run"]["version"]});
                assert cancelled["data"]["run"]["status"] == "cancelled";
                again = rpc(client,"advance_run",{"run_id":run["id"],"expected_version":cancelled["data"]["run"]["version"],"request_id":"after-cancel"});
                assert again["data"]["run"]["status"] == "cancelled";
                assert len(model.seen_prompts) == 1;
            }
        } finally { client.close(); }
    }
}

test "provider errors persist sanitized failure and cannot retry paid work" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            model = MockLLM(model_name="mockllm", config={"outputs":[MockError(error=TimeoutError("sensitive-provider-detail"))]});
            with model_patch(client,model) {
                started = rpc(client,"start_goal",{"text":"Plan two hours next week","workspace_id":"demo","request_id":"error"});
                run = started["data"]["run"];
                failed = rpc(client,"advance_run",{"run_id":run["id"],"expected_version":1,"request_id":"error-stage"});
                assert failed["data"]["run"]["status"] == "failed", str(failed);
                assert failed["data"]["run"]["error"]["code"] == "PROVIDER_ERROR";
                assert "sensitive-provider-detail" not in str(failed);
                rpc(client,"advance_run",{"run_id":run["id"],"expected_version":failed["data"]["run"]["version"],"request_id":"error-again"});
                assert len(model.seen_prompts) == 1;
            }
        } finally { client.close(); }
    }
}

test "interrupted lease expires and cancelled attempt cannot finish" {
    stored = StoredRun(id="interrupted",workspace_id="demo",goal="Plan",request_id="start",
        status="running",attempt_id="old-attempt",lease_expires_at="2000-01-01T00:00:00+05:30");
    with patch.dict(_claim.__globals__,{"_find":lambda (run_id: str) { stored; }}) {
        result = _claim("interrupted",1,"recover");
        assert result.data.run is not None;
        assert result.data.run.status == "failed";
        assert result.data.run.error is not None and result.data.run.error.code == "TOOL_ERROR";
        stored.status = "cancelled";
        rejected = _finish("interrupted","old-attempt","waiting_for_approval",3);
        assert not rejected.ok and rejected.error is not None and rejected.error.code == "VERSION_CONFLICT";
    }
}

test "goal validation identity conflicts and unknown runs fail without model work" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            for text in ["", " ", "x" * 4001] {
                assert not rpc(client,"start_goal",{"text":text,"workspace_id":"demo","request_id":"invalid"})["ok"];
            }
            first = rpc(client,"start_goal",{"text":"Original","workspace_id":"demo","request_id":"identity"});
            assert first["ok"];
            conflict = rpc(client,"start_goal",{"text":"Different","workspace_id":"demo","request_id":"identity"});
            assert conflict["error"]["code"] == "IDEMPOTENCY_CONFLICT";
            assert rpc(client,"get_run",{"run_id":"missing"})["error"]["code"] == "NOT_FOUND";
        } finally { client.close(); }
    }
}
