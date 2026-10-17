# Phase 1: foundation

Branch: `codex/agent`. This phase provides the shared Jac types, boundary validators, a typed health endpoint, a minimal Jac frontend connection check, deterministic tests, and separate persistence/provider checks. It does not implement coordinator runs, workspace CRUD, approval execution, or replanning.

## Runtime requirements

- Linux x86_64 or arm64 for the official Jac 0.34.24 runtime. On Windows, use Docker Desktop with its Linux/WSL 2 backend, or a Linux WSL distribution with the official binary.
- The selected Docker image is pinned by digest in `compose.yaml`. This laptop also has an isolated `Meridian-Jac` WSL distribution containing the checksum-verified official x86_64 binary.
- System Python and Node are not needed for the bundled Jac runtime. `jac install` resolves optional Python/npm libraries required by the project.
- Internet access is needed for initial dependency installation and the optional OpenAI check. Regular tests use model mocks and require no API key.
- `OPENAI_API_KEY` must be present only in the server process environment for the live check. No `.env` file is required or read by our application code. Never paste the key into Git or a browser.
- A persistent writable `.jac` volume is required. The demonstration data is synthetic; it is not a production multi-user database.

The host has x86_64 architecture, 15.3 GiB RAM and hardware virtualization available. Docker Desktop 4.77.0 and engine 29.5.3 were verified after repairing stale runtime sockets; no data disk was removed.

## What teammates may depend on

- `contracts/models.jac`: shared DTOs, health response, planning input/output, records, dependencies, proposals and receipts.
- `contracts/validation.jac`: goal, event and review-input checks. Review-input validation is not authorization to execute.
- `app/transport.jac`: converts Jac function/walker HTTP envelopes to the application's `{ok,data,error}` envelope; rejects missing or ambiguous reports.
- `main.jac`: `POST /function/get_health` and a minimal Jac page that calls it.
- `agent/model.jac`: injectable typed goal interpretation, one malformed-output repair, semantic validation and the live model factory. It has no mutation tools and is not exposed as an HTTP endpoint.

Contract version: `1.0.0`. `system-code/` is the Jac project root. No source code is added to teammates' workspaces beyond the initial shared shell; they retain ownership of their modules.

## Verification commands

Run from the repository root. The first install may take several minutes:

```powershell
docker compose run --rm meridian --version
docker compose run --rm meridian install
docker compose run --rm meridian check main.jac
docker compose run --rm meridian test -d tests/
docker compose run --rm meridian run --entry write_probe checks/persistence_probe.jac
docker compose run --rm meridian run --entry read_probe checks/persistence_probe.jac
docker compose run --rm meridian test checks/live_model_smoke.jac
docker compose up
```

The last smoke command makes a paid API request only when explicitly invoked. `checks/` is outside normal test discovery. It uses the test runner because this Jac version can print a `jac run` error while returning exit code zero. Do not use `docker compose down -v` against data you want to keep.

Open `http://localhost:8000`. The shell must report the server connection and contract version. This page is a foundation check, not the finished dashboard. Docker publishes its port on loopback only. The default admin portal is disabled; internal framework operations endpoints still exist and must not be exposed as a public deployment.

The equivalent native Linux commands run from `system-code/` using the exact same Jac version. The separate write/read probe invocations verify process-restart durability, not just an in-memory read after write.

## Evidence

Results are recorded in `docs/VERIFICATION.md`. A CI workflow is included but remains unverified on GitHub until the branch is pushed. The current work is for local review; no merge or deployment is included.
