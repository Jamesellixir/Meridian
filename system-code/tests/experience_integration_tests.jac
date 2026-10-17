import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.testing { JacTestClient }
import from checks.integration_helpers { rpc, model_patch }
import from jaclang.byllm.lib { MockLLM, MockRawResponse }
import from agent.model { decode_goal }

test "chat persists context without creating proposals and rejects cross-workspace parents" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            model = MockLLM(model_name="mockllm",config={"outputs":[MockRawResponse(content='{"title":"Hello","duration_minutes":0,"missing_information":[],"constraints":[],"intent":"chat","reply":"Hi Alex! What is on your mind?"}')]});
            with model_patch(client,model) {
                run = rpc(client,"start_goal",{"text":"Hi","workspace_id":"experience","request_id":"hello"})["data"]["run"];
                result = rpc(client,"advance_run",{"run_id":run["id"],"expected_version":run["version"],"request_id":"reply"});
                assert result["data"]["run"]["status"] == "completed";
                assert result["data"]["proposals"] == [] and result["data"]["receipts"] == [];
                next_turn = rpc(client,"start_goal",{"text":"Help me focus","workspace_id":"experience","request_id":"next","parent_run_id":run["id"]});
                assert next_turn["data"]["conversation"][0]["user"] == "Hi";
                assert not rpc(client,"start_goal",{"text":"Hi","workspace_id":"other","request_id":"cross","parent_run_id":run["id"]})["ok"];
            }
        } finally { client.close(); }
    }
}

test "conversation output remains bounded and cannot carry an approval" {
    result = decode_goal('{"title":"Hello","duration_minutes":0,"missing_information":[],"constraints":[],"intent":"chat","reply":"Hi, Alex!"}');
    assert result.intent == "chat" and result.reply == "Hi, Alex!";
    failed = False;
    try { decode_goal('{"title":"Hello","duration_minutes":0,"missing_information":[],"constraints":[],"intent":"chat","reply":"Hi","approved":true}'); }
    except ValueError { failed = True; }
    assert failed;
}

test "calendar color retries and stale edits preserve the original record" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            args = {"workspace_id":"experience","title":"Coffee","start":"2026-10-22T14:00:00+05:30","end":"2026-10-22T14:30:00+05:30","request_id":"coffee","color":"purple"};
            first = rpc(client,"save_event",args);
            assert first["ok"];
            assert rpc(client,"save_event",args)["ok"];
            args["color"] = "rose";
            assert not rpc(client,"save_event",args)["ok"];
            saved = rpc(client,"get_workspace",{"workspace_id":"experience"})["data"]["events"];
            assert len(saved) == 1 and saved[0]["color"] == "purple";
            args["request_id"] = "edit"; args["event_id"] = saved[0]["id"]; args["expected_version"] = 99;
            assert not rpc(client,"save_event",args)["ok"];
            month = rpc(client,"get_calendar",{"workspace_id":"experience","month":"2026-10"});
            assert len(month["data"]["days"]) == 42;
        } finally { client.close(); }
    }
}

test "personal memory supports version checks forget and resave independently of availability" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()),base_path=directory);
        try {
            assert rpc(client,"save_soul",{"workspace_id":"experience","value":"Call me Alex","expected_version":0})["ok"];
            assert not rpc(client,"save_soul",{"workspace_id":"experience","value":"Stale overwrite","expected_version":0})["ok"];
            assert rpc(client,"save_preference",{"workspace_id":"experience","value":"morning","request_id":"morning"})["ok"];
            assert rpc(client,"save_soul",{"workspace_id":"experience","value":"","expected_version":1})["ok"];
            prefs = rpc(client,"get_workspace",{"workspace_id":"experience"})["data"]["preferences"];
            assert len(prefs) == 1 and prefs[0]["key"] == "availability";
            assert rpc(client,"save_soul",{"workspace_id":"experience","value":"Keep it brief","expected_version":0})["ok"];
        } finally { client.close(); }
    }
}
