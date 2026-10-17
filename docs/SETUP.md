# Setup

Read [phase 1](PHASE-1.md) for the pinned Jac runtime, requirements and commands, and [verification evidence](VERIFICATION.md) for actual results.

The Jac project root is `system-code/`. All authored application and test code is Jac. Optional runtime dependencies come from Jac's dependency resolver; do not install the older standalone `byllm` or `jac-scale` PyPI plugins into this runtime.

On Linux with the verified official Jac 0.34.24 binary:

```sh
cd system-code
jac install
jac check main.jac
jac test -d tests/
jac start main.jac --port 8000
```

On Windows, the equivalent Docker Compose commands are in PHASE-1.md. The Docker engine was repaired without removing its data disk. The official standalone Linux binary was also installed in an isolated `Meridian-Jac` WSL distribution for verification.

`OPENAI_API_KEY` is needed only for the separately invoked live check. Normal tests use mocks. No API key is committed or requested through the UI.

No deployment or merge to main is included. The next implementation phase wires a real persisted task through the workspace facade and UI; it must not bypass the shared contracts.
