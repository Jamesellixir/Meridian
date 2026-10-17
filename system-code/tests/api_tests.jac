import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.testing { JacTestClient }
import from app.transport { unwrap_response }

test "real health endpoint uses the application envelope" {
    with tempfile.TemporaryDirectory() as directory {
        client = JacTestClient.from_file(str(Path("main.jac").resolve()), base_path=directory);
        try {
            response = client.post("/function/get_health", json={});
            assert response.ok, response.text;
            data = unwrap_response(response.json());
            assert data["ok"], str(response.json());
            assert data["data"]["contract_version"] == "1.0.0";
            assert data["data"]["phase"] == "foundation";
        } finally {
            client.close();
        }
    }
}
