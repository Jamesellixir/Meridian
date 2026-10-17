# Opt-in integration check against a synthetic review workspace on the running server.
import os;
import requests;
import from concurrent.futures { ThreadPoolExecutor }

def _post(name: str, body: dict) -> dict {
    response = requests.post("http://127.0.0.1:8000/function/" + name,json=body,timeout=20);
    assert response.status_code == 200, str(response.status_code);
    return response.json()["data"]["result"];
}

def _race(body: dict) -> int {
    response = requests.post("http://127.0.0.1:8000/function/review_proposal",json=body,timeout=20);
    if response.status_code not in [200,409] {
        print("Concurrency diagnostic: " + response.text[:400]);
    }
    return response.status_code;
}

test "concurrent approval creates one task and its original receipt" {
    run_id = os.environ.get("MERIDIAN_REVIEW_RUN","");
    assert run_id, "Set MERIDIAN_REVIEW_RUN to a synthetic review run ID.";
    data = _post("get_run",{"run_id":run_id})["data"];
    workspace_id = data["run"]["workspace_id"];
    assert workspace_id.startswith("review-"), "This check only operates on synthetic review workspaces.";
    tasks = [p for p in data["proposals"] if p["kind"] == "create_task" and p["status"] == "pending"];
    assert tasks, "The test needs one pending task proposal.";
    proposal = tasks[0];
    before = _post("get_workspace",{"workspace_id":workspace_id})["data"];
    body = {"proposal_id":proposal["id"],"revision":proposal["revision"],"payload_hash":proposal["payload_hash"],"decision":"approve"};
    with ThreadPoolExecutor(max_workers=4) as executor {
        futures = [executor.submit(_race,body) for index in range(4)];
        codes = [future.result() for future in futures];
    }
    assert all(code in [200,409] for code in codes), str(codes);
    replay = _post("review_proposal",body);
    assert replay["ok"], str(replay);
    after = _post("get_workspace",{"workspace_id":workspace_id})["data"];
    assert len(after["tasks"]) == len(before["tasks"]) + 1;
    receipts = [r for r in after["receipts"] if r["proposal_id"] == proposal["id"]];
    assert len(receipts) == 1;
    again = _post("review_proposal",body);
    assert [r["id"] for r in again["data"]["receipts"] if r["proposal_id"] == proposal["id"]] == [receipts[0]["id"]];
    forbidden = requests.post("http://127.0.0.1:8000/function/_execute",json={},timeout=10);
    assert forbidden.status_code in [401,404,405];
    print("Concurrent approval verified: one record, one receipt, safe replay; private dispatcher inaccessible.");
}
