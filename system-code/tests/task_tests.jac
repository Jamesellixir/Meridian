import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.testing { JacTestClient }
import from app.transport { unwrap_response }

def call(client: JacTestClient, operation: str, payload: dict) -> dict {
    response = client.post("/function/" + operation, json=payload);
    assert response.ok, response.text;
    return unwrap_response(response.json());
}

test "manual task is trimmed and visible only in its workspace" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            created = call(client, "create_task", {"workspace_id": "demo", "title": "  Prepare meetup  ", "request_id": "first"});
            assert created["ok"], str(created);
            task = created["data"]["task"];
            assert task["title"] == "Prepare meetup" and task["status"] == "todo" and task["version"] == 1;
            listed = call(client, "list_tasks", {"workspace_id": "demo"});
            assert len(listed["data"]["tasks"]) == 1, str(listed);
            assert listed["data"]["tasks"][0]["id"] == task["id"];
            assert call(client, "list_tasks", {"workspace_id": "other"})["data"]["tasks"] == [];
        } finally { client.close(); }
    }
}

test "retry returns original task and different content conflicts" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            payload = {"workspace_id": "demo", "title": "Prepare meetup", "request_id": "retry"};
            first = call(client, "create_task", payload);
            assert first["ok"], str(first);
            retried = call(client, "create_task", payload);
            assert retried["ok"] and retried["data"]["task"]["id"] == first["data"]["task"]["id"], str(retried);
            payload["title"] = "Changed task";
            conflict = call(client, "create_task", payload);
            assert not conflict["ok"] and conflict["error"]["code"] == "IDEMPOTENCY_CONFLICT";
            assert len(call(client, "list_tasks", {"workspace_id": "demo"})["data"]["tasks"]) == 1;
        } finally { client.close(); }
    }
}

test "invalid manual input creates no task" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            for title in ["", "   ", "x" * 201] {
                result = call(client, "create_task", {"workspace_id": "demo", "title": title, "request_id": "invalid"});
                assert not result["ok"] and result["error"]["code"] == "VALIDATION_ERROR";
            }
            assert not call(client, "list_tasks", {"workspace_id": "../bad"})["ok"];
            assert not call(client, "create_task", {"workspace_id": "demo", "title": "Task", "request_id": "../bad"})["ok"];
            assert call(client, "list_tasks", {"workspace_id": "demo"})["data"]["tasks"] == [];
        } finally { client.close(); }
    }
}
