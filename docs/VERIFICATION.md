# Phase 1 verification — 17 October 2026

Scope: local foundation on `codex/agent`; no merge, push or deployment. Baseline commit: `c6bd8fc`. Application and test changes remain uncommitted for review.

## Verified results

| Check | Result |
|---|---|
| Compiler | Official Jac 0.34.24, Linux x86_64; standalone binary checksum and pinned Docker image digest verified |
| Type check | `jac check main.jac`: passed in native Linux and Docker |
| Deterministic suite | `jac test -d tests/`: **11 passed** in native Linux and **11 passed** in Docker |
| Real provider | `jac test checks/live_model_smoke.jac`: **1 passed**, using server environment credentials and the pinned OpenAI model |
| Persistence | Separate `write_probe` and `read_probe` processes: passed in native Linux and across fresh Docker containers; exactly one stored synthetic graph record |
| Frontend | Built successfully in native Linux and Docker; real browser displays “Server connected - contract 1.0.0” after switching to the Docker service |
| Package consistency | `pip check`: no broken requirements |
| Container configuration | `docker compose config --quiet`: passed; actual pinned container reports Jac 0.34.24 |
| Docker installation | Desktop 4.77.0; engine responds as 29.5.3 after runtime-socket repair; data disk preserved |

The core suite, compilation and persistence checks passed in both the checksum-verified native Linux binary and the pinned Docker image. The separate real-provider check passed in native Linux. The GitHub Actions workflow has not run remotely because nothing was pushed.

## Compatibility decisions

- Kept endpoint registration and frontend consumption separate: the entry module imports the endpoint and its DTOs; the client module uses `sv import`. This passed the real endpoint and browser checks.
- The live provider exercised a Jac native-schema metadata error that mocked dispatch bypassed. The adapter now calls byLLM for text and strictly decodes into the Jac GoalSpec. It rejects unknown fields, invalid types and unsupported intent values, limits response size/tokens, repairs invalid output once, and does not retry provider failures.
- Used `jac test` for the explicit live check because `jac run` may report an exception with exit status zero in this runtime.
- Added timezone data explicitly so a minimal Linux environment can validate `Asia/Colombo`.
- Disabled the default admin portal. Internal framework operations endpoints still exist; this is a local foundation and is not approved for public hosting.

The live provider test emits one upstream Pydantic warning concerning a ReadOnly type annotation. Jac may also emit an optional native-optimization fallback note for the transport helper; it executes in the server codespace and its assertions pass. These upstream diagnostics are retained rather than hidden.

## Not implemented or proven by phase 1

Actual planning runs, workspace CRUD, approval execution, atomic action/receipt commits, cancellation, memory correction and replanning. Their product acceptance checks remain pending. The persistence probe establishes storage capability only; it does not prove future business transaction behavior.

Next: after Rivith reviews this foundation, integrate one persisted manual task through the real workspace service and UI. Keep the current branch separate from main until approval.

The Docker preview is running at `http://localhost:8000`, published on laptop loopback only. Stop it with `docker compose stop`; this retains the verification volume.
