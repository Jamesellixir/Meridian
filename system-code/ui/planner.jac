sv import from app.api { start_goal, get_run, advance_run, provide_input, cancel_run, RunData, RunEnvelope, RunRecord, StepRecord, ProposalRecord, ActivityEntry, PreferenceDependency, APIError }

def:pub PlannerPanel -> JsxElement {
    has goal: str = "Plan our two-hour AI meetup next week; create an agenda and preparation tasks, and find a free slot.";
    has answer: str = "";
    has current: RunData = RunData();
    has busy: bool = False;
    has message: str = "";
    has start_key: str = "";
    has advance_key: str = "";
    has input_key: str = "";

    async def fresh(run_id: str) -> RunEnvelope {
        nonce = str(crypto.randomUUID()); # jac:ignore[E1032,W2001,W1051]
        return await get_run(run_id,nonce);
    }

    def accept(result: RunEnvelope) -> None {
        if result.ok {
            current = result.data;
            if result.data.run is not None {
                localStorage.setItem("meridian-demo-run",result.data.run.id);
            }
        } else {
            message = result.error.message if result.error is not None else "Request failed. Reload the run to retry.";
        }
    }

    async can with entry {
        saved = localStorage.getItem("meridian-demo-run");
        if saved {
            busy = True;
            try { accept(await fresh(saved)); }
            except Exception { message = "Could not restore the last run. Try reload."; }
            busy = False;
        }
    }

    def change_goal(event: ChangeEvent) { goal = event.target.value; start_key = ""; }
    def change_answer(event: ChangeEvent) { answer = event.target.value; input_key = ""; }

    async def start(event: FormEvent) -> None {
        event.preventDefault();
        if busy { return; }
        busy = True; message = "";
        key = start_key;
        if not key {
            key = str(crypto.randomUUID()); # jac:ignore[E1032,W2001,W1051]
            start_key = key;
        }
        try { accept(await start_goal(goal,"demo",key)); advance_key = ""; }
        except Exception { message = "Connection interrupted. Retry unchanged text to recover the same run."; }
        busy = False;
    }

    async def advance(event: MouseEvent) -> None {
        if busy or current.run is None { return; }
        busy = True; message = "";
        key = advance_key;
        if not key {
            key = str(crypto.randomUUID()); # jac:ignore[E1032,W2001,W1051]
            advance_key = key;
        }
        try { accept(await advance_run(current.run.id,current.run.version,key)); advance_key = ""; }
        except Exception { message = "Planning response interrupted. Reload the run before retrying."; }
        busy = False;
    }

    async def reload_run(event: MouseEvent) -> None {
        if current.run is None { return; }
        message = "";
        try { accept(await fresh(current.run.id)); }
        except Exception { message = "Could not reload this run."; }
    }

    async def cancel(event: MouseEvent) -> None {
        if current.run is None { return; }
        try {
            latest = await fresh(current.run.id);
            if latest.ok and latest.data.run is not None {
                accept(await cancel_run(latest.data.run.id,latest.data.run.version));
            } else { accept(latest); }
        } except Exception { message = "Could not cancel. Reload to check the current status."; }
    }

    async def clarify(event: FormEvent) -> None {
        event.preventDefault();
        if busy or current.run is None { return; }
        busy = True; message = "";
        key = input_key;
        if not key {
            key = str(crypto.randomUUID()); # jac:ignore[E1032,W2001,W1051]
            input_key = key;
        }
        try {
            result = await provide_input(current.run.id,current.run.version,answer,key);
            accept(result);
            if result.ok { answer = ""; input_key = ""; advance_key = ""; }
        } except Exception { message = "Could not submit clarification. Retry unchanged text."; }
        busy = False;
    }

    return <section>
        <h2>Plan a session</h2>
        <p>Preview an agenda, preparation tasks and a calendar slot. Nothing is created until a later approval step.</p>
        <p>Demo scheduling: next week is Monday to Friday, 09:00–17:00 Asia/Colombo; morning means 09:00–12:00. You can also give one future YYYY-MM-DD date.</p>
        <form onSubmit={start}>
            <label htmlFor="planning-goal">Planning goal</label>
            <textarea id="planning-goal" value={goal} onChange={change_goal} maxLength={4000} disabled={busy} />
            <button type="submit" disabled={busy}>Start plan</button>
        </form>
        <p role="status" aria-live="polite">{message}</p>
        {busy and <p>Planning stage in progress...</p>}
        {current.run is not None and <section>
            <h3>{"Run: " + current.run.status}</h3>
            <p>{current.run.goal}</p>
            {current.run.error is not None and <p role="alert">{current.run.error.message}</p>}
            <ol>{for step in (current.run as RunRecord).steps { <li key={step.id}>{step.id}{": "}{step.status}</li> }}</ol>
            <button onClick={advance} disabled={busy or current.run.status not in ["queued","running"]}>Continue plan</button>
            <button onClick={reload_run}>Reload run</button>
            <button onClick={cancel} disabled={current.run.status in ["cancelled","completed","failed"]}>Cancel run</button>
            {current.run.status == "waiting_for_input" and <section>
                <ul>{for question in current.questions { <li key={question}>{question}</li> }}</ul>
                <form onSubmit={clarify}>
                    <label htmlFor="clarification">Clarification</label>
                    <input id="clarification" value={answer} onChange={change_answer} disabled={busy} maxLength={2000} />
                    <button type="submit" disabled={busy}>Submit clarification</button>
                </form>
            </section>}
            <h3>Activity</h3>
            <ol>{for entry in current.activity { <li key={entry.sequence}>{entry.tool}{": "}{entry.outcome}</li> }}</ol>
            {len(current.proposals) > 0 and <section>
                <h3>Proposed actions</h3>
                <p>Review previews only. Approval and execution are phase 4.</p>
                <p>Agenda and tasks use your supplied information; no web research was performed.</p>
                <p>{current.explanation}</p>
                {for proposal in current.proposals { <article key={proposal.id}>
                    <h4>{proposal.kind}{": "}{proposal.status}</h4>
                    <pre style={{"whiteSpace":"pre-wrap","overflowWrap":"anywhere"}}>{JSON.stringify(proposal.payload,None,2)}</pre>
                </article> }}
            </section>}
        </section>}
    </section>;
}
