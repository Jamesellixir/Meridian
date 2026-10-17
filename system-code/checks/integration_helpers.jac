import from unittest.mock { patch }
import from jaclang.runtimelib.testing { JacTestClient }
import from jaclang.byllm.lib { MockLLM, MockRawResponse }
import from app.transport { unwrap_response }

def model_patch(client: JacTestClient, model: MockLLM) -> any {
    rpc(client,"get_health",{});
    server = client._server;
    assert server is not None;
    endpoint = server.introspector.get_functions()["advance_run"];
    namespace = endpoint.__globals__["_advance"].__globals__;
    return patch.dict(namespace,{"create_live_model":lambda { model; }});
}

def rpc(client: JacTestClient, name: str, body: dict) -> dict {
    response = client.post("/function/" + name, json=body);
    assert response.ok, response.text;
    return unwrap_response(response.json());
}

def fake_model -> MockLLM {
    return MockLLM(model_name="mockllm", config={"outputs": [
        MockRawResponse(content='{"title":"AI meetup","duration_minutes":120,"missing_information":[],"constraints":[],"intent":"plan_session"}'),
        MockRawResponse(content='{"note_title":"Meetup agenda","note_body":"Introductions, demonstrations, discussion.","tasks":[{"title":"Prepare demonstration","due_at":null}],"selected_slot_index":0,"explanation":"First available slot; agenda based on user information."}')
    ]});
}
