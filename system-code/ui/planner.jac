sv import from app.api { start_goal, get_run, advance_run, provide_input, cancel_run, review_proposal, replan_run, get_workspace, new_demo_workspace, create_task, save_event, save_preference, correct_preference, forget_preference, RunData, RunEnvelope, RunRecord, StepRecord, ProposalRecord, ActivityEntry, PreferenceDependency, APIError, WorkspaceData, WorkspaceEnvelope, EventRecord, TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, NoteRecord, PreferenceRecord, ReceiptRecord }

def:pub ProposalCard(proposal: ProposalRecord, busy: bool, before: str, onReview: Callable[[str,int,str,str],None]) -> JsxElement {
    def approve(event: MouseEvent) { onReview(proposal.id,proposal.revision,proposal.payload_hash,"approve"); }
    def reject(event: MouseEvent) { onReview(proposal.id,proposal.revision,proposal.payload_hash,"reject"); }
    return <article><h4>{proposal.kind}{": "}{proposal.status}</h4>
        {before and <p>{"Before: " + before}</p>}
        <p>{proposal.payload["title"]}</p>
        {proposal.kind == "create_note" and <p style={{"whiteSpace":"pre-wrap"}}>{proposal.payload["body"]}</p>}
        {proposal.kind in ["create_event","update_event"] and <p>{proposal.payload["start"]}{" → "}{proposal.payload["end"]}{" · "}{proposal.payload["timezone"]}</p>}
        <details><summary>Exact action data</summary><pre style={{"whiteSpace":"pre-wrap","overflowWrap":"anywhere"}}>{JSON.stringify(proposal.payload,None,2)}</pre></details>
        <button onClick={approve} disabled={busy or proposal.status != "pending"}>{"Approve " + proposal.kind}</button>
        <button onClick={reject} disabled={busy or proposal.status != "pending"}>{"Reject " + proposal.kind}</button>
    </article>;
}

def:pub PlannerPanel -> JsxElement {
    has goal: str = "Plan our two-hour AI meetup next week; create an agenda and preparation tasks, and find a free slot.";
    has answer: str = "", task_title: str = "", event_title: str = "", event_start: str = "", event_end: str = "";
    has current: RunData = ({"run":None,"proposals":[],"activity":[],"questions":[],"explanation":"","receipts":[]} as RunData), workspace: WorkspaceData = ({"workspace_id":"demo","events":[],"tasks":[],"notes":[],"preferences":[],"receipts":[]} as WorkspaceData);
    has workspace_id: str = "demo", message: str = "", busy: bool = False;
    has start_key: str = "", advance_key: str = "", manual_key: str = "", input_key: str = "";
    def key -> str { return str(crypto.randomUUID()); } # jac:ignore[E1032,W2001,W1051]
    async def load(id: str) -> None {
        response = await get_workspace(id,key());
        if response.ok { workspace = response.data; workspace_id = id; }
        else { message = "Workspace could not load. Try Reload."; }
    }
    async def accept(result: RunEnvelope) -> None {
        if result.ok {
            current = result.data;
            if result.data.run is not None {
                localStorage.setItem("meridian-demo-run",result.data.run.id);
                await load(result.data.run.workspace_id);
            }
        } else { message = result.error.message if result.error is not None else "Request failed. Reload first."; }
    }
    async can with entry {
        busy = True;
        try {
            saved = localStorage.getItem("meridian-demo-run");
            if saved { await accept(await get_run(saved,key())); }
            else { await load("demo"); }
        } except Exception { message = "Could not restore workspace. Use Reload."; }
        busy = False;
    }
    def goal_input(event: ChangeEvent) { goal = event.target.value; start_key = ""; }
    def answer_input(event: ChangeEvent) { answer = event.target.value; input_key = ""; }
    def task_input(event: ChangeEvent) { task_title = event.target.value; manual_key = ""; }
    def event_input(event: ChangeEvent) { event_title = event.target.value; manual_key = ""; }
    def start_input(event: ChangeEvent) { event_start = event.target.value; manual_key = ""; }
    def end_input(event: ChangeEvent) { event_end = event.target.value; manual_key = ""; }
    async def start(event: FormEvent) -> None {
        event.preventDefault(); if busy { return; } busy = True; message = "";
        if not start_key { start_key = key(); }
        request = start_key or key();
        start_key = request;
        try { await accept(await start_goal(goal,workspace_id,request)); advance_key = ""; }
        except Exception { message = "Connection interrupted. Retry unchanged goal to recover the same run."; }
        busy = False;
    }
    async def advance(event: MouseEvent) -> None {
        if busy or current.run is None { return; } busy = True; message = "";
        request = advance_key or key(); advance_key = request;
        try { await accept(await advance_run(current.run.id,current.run.version,request)); advance_key = ""; }
        except Exception { message = "Planning response interrupted. Reload before retrying."; }
        busy = False;
    }
    async def reload(event: MouseEvent) -> None {
        try {
            if current.run is not None { await accept(await get_run(current.run.id,key())); }
            else { await load(workspace_id); }
        } except Exception { message = "Reload failed. Check the local server."; }
    }
    async def cancel(event: MouseEvent) -> None {
        if current.run is None { return; }
        try {
            latest = await get_run(current.run.id,key());
            if latest.data.run is not None { await accept(await cancel_run(latest.data.run.id,latest.data.run.version)); }
        } except Exception { message = "Could not cancel. Reload to check status."; }
    }
    async def replan(event: MouseEvent) -> None {
        if busy or current.run is None { return; } busy = True; message = "";
        try { await accept(await replan_run(current.run.id,current.run.version)); }
        except Exception { message = "Could not replan. Reload and try again."; }
        busy = False;
    }
    async def review(id: str, revision: int, hash: str, decision: str) -> None {
        if busy { return; } busy = True; message = "";
        try { await accept(await review_proposal(id,revision,hash,decision)); }
        except Exception { message = "Review response interrupted. Reload; a retry returns the original receipt."; }
        busy = False;
    }
    async def clarify(event: FormEvent) -> None {
        event.preventDefault(); if busy or current.run is None { return; } busy = True; message = "";
        request = input_key or key(); input_key = request;
        try {
            result = await provide_input(current.run.id,current.run.version,answer,request);
            await accept(result);
            if result.ok { answer = ""; input_key = ""; advance_key = ""; }
        } except Exception { message = "Could not submit clarification. Retry unchanged text."; }
        busy = False;
    }
    async def new_demo(event: MouseEvent) -> None {
        if busy { return; } busy = True; message = "";
        try {
            result = await new_demo_workspace();
            if result.ok { workspace = result.data; workspace_id = result.data.workspace_id; current = ({"run":None,"proposals":[],"activity":[],"questions":[],"explanation":"","receipts":[]} as RunData); start_key = ""; advance_key = ""; localStorage.removeItem("meridian-demo-run"); }
        } except Exception { message = "Could not create a review workspace."; }
        busy = False;
    }
    async def preference(value: str, forget: bool = False) -> None {
        if busy { return; } busy = True; message = "";
        try {
            if len(workspace.preferences) > 0 {
                existing = workspace.preferences[0];
                result = await forget_preference(existing.id,existing.version) if forget else await correct_preference(existing.id,existing.version,value);
            } else { result = await save_preference(workspace_id,value,key()); }
            if result.ok { workspace = result.data; }
            else { message = result.error.message if result.error is not None else "Preference change failed."; }
            if current.run is not None { await accept(await get_run(current.run.id,key())); }
        } except Exception { message = "Could not change availability. Reload first."; }
        busy = False;
    }
    def morning(event: MouseEvent) { preference("morning"); }
    def anytime(event: MouseEvent) { preference("anytime"); }
    def forget(event: MouseEvent) { preference("",True); }
    async def add_task(event: FormEvent) -> None {
        event.preventDefault(); if busy { return; } busy = True; message = "";
        request = manual_key or key(); manual_key = request;
        try {
            result = await create_task(workspace_id,task_title,request);
            if result.ok { task_title = ""; manual_key = ""; await load(workspace_id); }
            else { message = "Use a task title of 1 to 200 characters."; }
        } except Exception { message = "Could not save task. Retry unchanged text."; }
        busy = False;
    }
    async def add_event(event: FormEvent) -> None {
        event.preventDefault(); if busy { return; } busy = True; message = "";
        request = manual_key or key(); manual_key = request;
        try {
            result = await save_event(workspace_id,event_title,event_start,event_end,request);
            if result.ok { workspace = result.data; event_title = ""; manual_key = ""; }
            else { message = result.error.message if result.error is not None else "Event could not be saved."; }
        } except Exception { message = "Could not save event. Retry unchanged values."; }
        busy = False;
    }
    def before(proposal: ProposalRecord) -> str {
        if proposal.kind == "update_event" and proposal.status == "pending" {
            for event in workspace.events { if event.id == proposal.payload["id"] { return event.title + ": " + event.start + " to " + event.end; } }
        }
        return "";
    }
    return <section>
        <h2>Plan a session</h2><p>Review each exact action before approving it.</p>
        <button onClick={new_demo} disabled={busy}>New review workspace</button><button onClick={reload}>Reload</button>
        <p>{"Workspace: " + workspace_id}</p><p>Next week: Monday–Friday, 09:00–17:00 Asia/Colombo. Morning: 09:00–12:00. One future YYYY-MM-DD date is also supported.</p>
        <form onSubmit={start}><label htmlFor="planning-goal">Planning goal</label><textarea id="planning-goal" style={{"display":"block","width":"100%","minHeight":"90px"}} value={goal} onChange={goal_input} disabled={busy} maxLength={4000} /><button type="submit" disabled={busy}>Start plan</button></form>
        <p role="status" aria-live="polite">{message}</p>{busy and <p>Working...</p>}
        {current.run is not None and <section>
            <h3>{"Run: " + current.run.status}</h3><p>{current.run.goal}</p>
            {current.run.error is not None and <p role="alert">{current.run.error.message}</p>}
            <ol>{for step in (current.run as RunRecord).steps { <li key={step.id}>{step.id}{": "}{step.status}</li> }}</ol>
            <button onClick={advance} disabled={busy or current.run.status not in ["queued","running"]}>Continue plan</button><button onClick={cancel} disabled={current.run.status in ["cancelled","failed","completed"]}>Cancel run</button><button onClick={replan} disabled={busy or current.run.status in ["running","failed","cancelled"]}>Replan pending actions</button>
            {current.run.status == "waiting_for_input" and <section><ul>{for question in current.questions { <li key={question}>{question}</li> }}</ul>{len(current.proposals) == 0 and <form onSubmit={clarify}><label htmlFor="clarification">Clarification</label><input id="clarification" value={answer} onChange={answer_input} maxLength={2000} disabled={busy} /><button type="submit" disabled={busy}>Submit clarification</button></form>}</section>}
            <h3>Activity</h3><ol>{for entry in current.activity { <li key={entry.sequence}>{entry.tool}{": "}{entry.outcome}</li> }}</ol>
            <h3>Proposed actions</h3><p>Agenda and tasks use supplied information; no web research was performed.</p><p>{current.explanation}</p>
            {for proposal in [p for p in current.proposals if p.status != "stale"] { <ProposalCard key={proposal.id} proposal={proposal} busy={busy} before={before(proposal)} onReview={review} /> }}
            <h3>Execution receipts</h3><ul>{for receipt in current.receipts { <li key={receipt.id}>{receipt.committed_at}{": "}{receipt.id}{" → "}{", ".join(receipt.record_ids)}</li> }}</ul>
        </section>}
        <h2>Workspace records</h2><h3>Confirmed availability</h3><p>{workspace.preferences[0].value if len(workspace.preferences) > 0 else "No confirmed availability preference"}</p>
        <button onClick={morning} disabled={busy}>Confirm morning only</button><button onClick={anytime} disabled={busy}>Confirm any time</button><button onClick={forget} disabled={busy or len(workspace.preferences) == 0}>Forget availability</button>
        <h3>Calendar</h3><ul>{for event in workspace.events { <li key={event.id}>{event.title}{": "}{event.start}{" to "}{event.end}{" (v"}{event.version}{")"}</li> }}</ul>
        <form onSubmit={add_event}><label htmlFor="event-title">Event title</label><input id="event-title" value={event_title} onChange={event_input} disabled={busy} /><label htmlFor="event-start">Start (ISO timestamp with offset)</label><input id="event-start" value={event_start} onChange={start_input} disabled={busy} /><label htmlFor="event-end">End (ISO timestamp with offset)</label><input id="event-end" value={event_end} onChange={end_input} disabled={busy} /><button type="submit" disabled={busy}>Add busy event</button></form>
        <h3>Tasks</h3><form onSubmit={add_task}><label htmlFor="task-title">Task title</label><input id="task-title" value={task_title} onChange={task_input} maxLength={200} disabled={busy} /><button type="submit" disabled={busy}>Add task</button></form><ul>{for task in workspace.tasks { <li key={task.id}>{task.title}{": "}{task.status}</li> }}</ul>
        <h3>Notes</h3>{for note in workspace.notes { <article key={note.id}><h4>{note.title}</h4><p style={{"whiteSpace":"pre-wrap"}}>{note.body}</p></article> }}
    </section>;
}
