import from .calendar { CalendarPanel }
import from .memory { SoulEditor }
import from .chat_presenter { quick_help, HelpTurn, ChatBadge, ActivityMessage, activity_title }
import from react { useEffect }
import from .mascot.AgentMascot { AgentMascot }
sv import from app.api { start_goal, get_run, advance_run, provide_input, cancel_run, review_proposal, replan_run, get_workspace, new_demo_workspace, create_task, update_task_status, save_event, save_preference, correct_preference, forget_preference, RunData, RunEnvelope, RunRecord, StepRecord, ProposalRecord, ActivityEntry, PreferenceDependency, APIError, WorkspaceData, WorkspaceEnvelope, EventRecord, TaskRecord, TaskData, TasksData, TaskEnvelope, TasksEnvelope, NoteRecord, PreferenceRecord, ReceiptRecord }

def:pub ProposalCard(proposal: ProposalRecord, busy: bool, before: str, onReview: Callable[[str,int,str,str],None]) -> JsxElement {
    def approve(event: MouseEvent) { onReview(proposal.id,proposal.revision,proposal.payload_hash,"approve"); }
    def reject(event: MouseEvent) { onReview(proposal.id,proposal.revision,proposal.payload_hash,"reject"); }
    return <article className="proposal-card"><h4>{proposal.kind}{": "}{proposal.status}</h4>
        {before and <p>{"Before: " + before}</p>}
        <p>{proposal.payload["title"]}</p>
        {proposal.kind == "create_note" and <p style={{"whiteSpace":"pre-wrap"}}>{proposal.payload["body"]}</p>}
        {proposal.kind in ["create_event","update_event"] and <p>{proposal.payload["start"]}{" → "}{proposal.payload["end"]}{" · "}{proposal.payload["timezone"]}</p>}
        <details><summary>Exact action data</summary><pre style={{"whiteSpace":"pre-wrap","overflowWrap":"anywhere"}}>{JSON.stringify(proposal.payload,None,2)}</pre></details>
        <button onClick={approve} disabled={busy or proposal.status != "pending"}>{"Approve " + proposal.kind}</button>
        <button onClick={reject} disabled={busy or proposal.status != "pending"}>{"Reject " + proposal.kind}</button>
    </article>;
}

def:pub PlannerPanel(connection_status: str) -> JsxElement {
    has goal: str = "", help_turns: list[HelpTurn] = [];
    has answer: str = "", task_title: str = "", event_title: str = "", event_start: str = "", event_end: str = "";
    has current: RunData = ({"run":None,"proposals":[],"activity":[],"questions":[],"explanation":"","receipts":[]} as RunData), workspace: WorkspaceData = ({"workspace_id":"demo","events":[],"tasks":[],"notes":[],"preferences":[],"receipts":[]} as WorkspaceData);
    has workspace_id: str = "demo", message: str = "", busy: bool = False;
    has start_key: str = "", advance_key: str = "", manual_key: str = "", input_key: str = "";
    has operation: str = "working", outcome: str = "";
    has page: str = "home", history: list[RunRecord] = [], history_error: str = "";
    def sync_route -> None {
        route = window.location.hash[1:];
        page = route if route in ["tasks","calendar","notes","memory","activity","history"] else "home";
    }
    def unwatch_route -> None { window.removeEventListener("hashchange",sync_route); }
    def watch_route -> Callable[[],None] {
        sync_route();
        window.addEventListener("hashchange",sync_route);
        return unwatch_route;
    }
    useEffect(watch_route,[]);
    def reveal_latest -> None {
        if page == "home" and not busy and (current.run is not None or len(help_turns) > 0) {
            tail = document.getElementById("chat-tail");
            if tail is not None {
                # The DOM lookup is typed as object in Jac 0.34.24.
                tail.scrollIntoView({"block":"nearest","behavior":"smooth"}); # jac:ignore[E1030]
            }
        }
    }
    useEffect(reveal_latest,[current,busy,page,help_turns]);
    def error_text(error: APIError) -> str {
        if error.code == "VALIDATION_ERROR" {
            return "I couldn't turn that message into a valid session plan. Try including the session topic, duration and a date or next week. For example: Plan a two-hour AI meetup next week. Your existing records haven't been changed.";
        }
        if error.code == "PROVIDER_ERROR" and "not configured" in error.message {
            return "Planning is unavailable because the server provider is not configured. The server API key may be missing. Configure OPENAI_API_KEY on the server and recreate the app container, then start a new plan. No actions were executed.";
        }
        if error.code == "PROVIDER_ERROR" {
            return error.message + " This may be an API-key, provider, quota or connection issue. Check the server provider configuration before retrying.";
        }
        return error.message;
    }
    def remember(run: RunRecord) -> None {
        history = [run] + [item for item in history if item.id != run.id];
        # Navigation index only. Content always comes from the server's get_run.
        try {
            ids = JSON.parse(localStorage.getItem("meridian-run-index") or "[]") as list[str];
            localStorage.setItem("meridian-run-index",JSON.stringify([run.id] + [id for id in ids if id != run.id]));
        } except Exception { history_error = "This browser could not update its history index. The plan is still saved on the server."; }
    }
    async def open_history(event: MouseEvent) -> None {
        if busy { return; }
        id = event.currentTarget.getAttribute("data-run-id");
        help_turns = [];
        if id is None { return; }
        busy = True; message = ""; outcome = ""; operation = "working";
        try { await accept(await get_run(id,key())); window.location.hash = "home"; }
        except Exception { message = "Could not open this conversation. Your saved run remains on the server; try again."; }
        busy = False;
    }
    def new_chat(event: MouseEvent) -> None {
        if busy { return; }
        current = ({"run":None,"proposals":[],"activity":[],"questions":[],"explanation":"","receipts":[]} as RunData);
        help_turns = [];
        goal = ""; answer = ""; start_key = ""; advance_key = ""; input_key = ""; message = ""; outcome = "";
        localStorage.removeItem("meridian-demo-run");
        window.location.hash = "home";
    }
    async def drive(snapshot: RunData) -> None {
        # The supported coordinator has two bounded stages. Stop at input/review/failure.
        for stage in range(2) {
            if snapshot.run is None or snapshot.run.status != "queued" { return; }
            operation = "thinking" if stage == 0 else "working";
            request = advance_key or key(); advance_key = request;
            response = await advance_run(snapshot.run.id,snapshot.run.version,request);
            await accept(response);
            if not response.ok { return; }
            snapshot = response.data; advance_key = "";
        }
    }
    def mascot_state -> str {
        if busy { return operation; }
        if message { return "error"; }
        if outcome { return outcome; }
        if current.run is not None and current.run.status == "completed" and len(current.proposals) == 0 { return "idle"; }
        return current.run.status if current.run is not None else "idle";
    }
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
                remember(result.data.run);
                await load(result.data.run.workspace_id);
            }
        } else { message = error_text(result.error) if result.error is not None else "Request failed. Reload first."; }
    }
    async can with entry {
        busy = True;
        try {
            restored: list[RunRecord] = [];
            index = localStorage.getItem("meridian-run-index");
            if index {
                ids = JSON.parse(index) as list[str];
                for id in ids {
                    try {
                        fetched = await get_run(id,key());
                        if fetched.ok and fetched.data.run is not None { restored.append(fetched.data.run); }
                    } except Exception { history_error = "Some conversations could not load. Reload to try again."; }
                }
            }
            saved = localStorage.getItem("meridian-demo-run");
            if saved {
                snapshot = await get_run(saved,key());
                await accept(snapshot);
                if snapshot.ok and snapshot.data.run is not None {
                    restored = [snapshot.data.run] + [item for item in restored if item.id != saved];
                }
            } else { await load(localStorage.getItem("meridian-workspace") or "demo"); }
            history = restored;
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
        event.preventDefault(); if busy { return; }
        help_turns = []; busy = True; message = ""; outcome = ""; operation = "working";
        if not start_key { start_key = key(); }
        request = start_key or key();
        start_key = request;
        try {
            result = await start_goal(goal,workspace_id,request,current.run.id if current.run is not None else "");
            await accept(result); advance_key = "";
            if result.ok { goal = ""; await drive(result.data); start_key = ""; }
        }
        except Exception { message = "Connection interrupted. If a run is shown, reload its status. Otherwise resend the unchanged message to recover the same request."; }
        busy = False;
    }
    async def advance(event: MouseEvent) -> None {
        if busy or current.run is None { return; } busy = True; message = ""; outcome = ""; operation = "working";
        operation = "thinking";
        request = advance_key or key(); advance_key = request;
        try { await drive(current); }
        except Exception { message = "Planning response interrupted. Reload before retrying."; }
        busy = False;
    }
    async def reload(event: MouseEvent) -> None {
        if busy { return; } busy = True; message = ""; outcome = ""; operation = "working";
        try {
            if current.run is not None { await accept(await get_run(current.run.id,key())); }
            else { await load(workspace_id); }
        } except Exception { message = "Reload failed. Check the local server."; }
        busy = False;
    }
    async def cancel(event: MouseEvent) -> None {
        if busy or current.run is None { return; } busy = True; message = ""; outcome = ""; operation = "working";
        try {
            latest = await get_run(current.run.id,key());
            if latest.data.run is not None { await accept(await cancel_run(latest.data.run.id,latest.data.run.version)); }
        } except Exception { message = "Could not cancel. Reload to check status."; }
        busy = False;
    }
    async def replan(event: MouseEvent) -> None {
        if busy or current.run is None { return; } busy = True; message = ""; outcome = ""; operation = "working";
        try { await accept(await replan_run(current.run.id,current.run.version)); }
        except Exception { message = "Could not replan. Reload and try again."; }
        busy = False;
    }
    async def review(id: str, revision: int, hash: str, decision: str) -> None {
        if busy { return; } busy = True; message = ""; outcome = ""; operation = "working";
        try {
            result = await review_proposal(id,revision,hash,decision);
            await accept(result);
            if result.ok and decision == "approve" and not message {
                for receipt in result.data.receipts {
                    if receipt.proposal_id == id and receipt.idempotency_key == id + ":" + str(revision) {
                        outcome = "approved_completed" if result.data.run is not None and result.data.run.status == "completed" else "approved";
                    }
                }
            }
        }
        except Exception { message = "Review response interrupted. Reload; a retry returns the original receipt."; }
        busy = False;
    }
    async def clarify(event: FormEvent) -> None {
        event.preventDefault(); if busy or current.run is None { return; } busy = True; message = ""; outcome = ""; operation = "working";
        request = input_key or key(); input_key = request;
        try {
            result = await provide_input(current.run.id,current.run.version,answer,request);
            await accept(result);
            if result.ok { answer = ""; input_key = ""; advance_key = ""; await drive(result.data); }
        } except Exception { message = "Could not submit clarification. Retry unchanged text."; }
        busy = False;
    }
    async def new_demo(event: MouseEvent) -> None {
        if busy { return; } busy = True; message = ""; outcome = ""; operation = "working";
        try {
            result = await new_demo_workspace();
            if result.ok { workspace = result.data; workspace_id = result.data.workspace_id; current = ({"run":None,"proposals":[],"activity":[],"questions":[],"explanation":"","receipts":[]} as RunData); start_key = ""; advance_key = ""; localStorage.removeItem("meridian-demo-run"); localStorage.setItem("meridian-workspace",result.data.workspace_id); }
            else { message = "Could not create a review workspace."; }
        } except Exception { message = "Could not create a review workspace."; }
        busy = False;
    }
    async def preference(value: str, forget: bool = False) -> None {
        if busy { return; } busy = True; message = ""; outcome = ""; operation = "working";
        try {
            if len([p for p in workspace.preferences if p.key == "availability"]) > 0 {
                existing = [p for p in workspace.preferences if p.key == "availability"][0];
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
        event.preventDefault(); if busy { return; } busy = True; message = ""; outcome = ""; operation = "working";
        request = manual_key or key(); manual_key = request;
        try {
            result = await create_task(workspace_id,task_title,request);
            if result.ok { outcome = "success"; task_title = ""; manual_key = ""; await load(workspace_id); }
            else { message = "Use a task title of 1 to 200 characters."; }
        } except Exception { message = "Could not save task. Retry unchanged text."; }
        busy = False;
    }
    async def add_event(event: FormEvent) -> None {
        event.preventDefault(); if busy { return; } busy = True; message = ""; outcome = ""; operation = "working";
        request = manual_key or key(); manual_key = request;
        try {
            result = await save_event(workspace_id,event_title,event_start,event_end,request);
            if result.ok { outcome = "success"; workspace = result.data; event_title = ""; manual_key = ""; }
            else { message = result.error.message if result.error is not None else "Event could not be saved."; }
        } except Exception { message = "Could not save event. Retry unchanged values."; }
        busy = False;
    }
    async def refresh_workspace -> None { await load(workspace_id); }
    async def toggle_task(event: MouseEvent) -> None {
        if busy { return; }
        id = event.currentTarget.getAttribute("data-id");
        for task in workspace.tasks { if task.id == id {
            busy = True; message = "";
            try {
                result = await update_task_status(workspace_id,task.id,task.version,"todo" if task.status == "done" else "done");
                if result.ok { workspace = result.data; }
                else { message = result.error.message if result.error is not None else "Couldn't update task."; }
            } except Exception { message = "Couldn't confirm the update. Reload before retrying."; }
            busy = False; return;
        } }
    }
    def suggest(event: MouseEvent) { goal = event.currentTarget.getAttribute("data-prompt") or ""; }
    def event_order(event: EventRecord) -> str { return event.start; }
    def before(proposal: ProposalRecord) -> str {
        if proposal.kind == "update_event" and proposal.status == "pending" {
            for event in workspace.events { if event.id == proposal.payload["id"] { return event.title + ": " + event.start + " to " + event.end; } }
        }
        return "";
    }
    return <div className="app-frame">
        <a className="skip-link" href="#page-content">Skip to content</a>
        <aside className="sidebar"><a className="brand" href="#home"><span className="brand-mark">m</span>meridian<span className="brand-dot">.</span></a><button className="new-chat-button" onClick={new_chat} disabled={busy}>New chat <span>＋</span></button>
            <p className="nav-label">WORKSPACE</p><nav aria-label="Workspace navigation">
                <a className={"is-active" if page == "home" else ""} href="#home"><span aria-hidden="true">◫</span>Home</a>
                <a className={"is-active" if page == "tasks" else ""} href="#tasks"><span aria-hidden="true">✓</span>Tasks</a>
                <a className={"is-active" if page == "calendar" else ""} href="#calendar"><span aria-hidden="true">▦</span>Calendar</a>
                <a className={"is-active" if page == "notes" else ""} href="#notes"><span aria-hidden="true">▤</span>Notes</a>
                <a className={"is-active" if page == "memory" else ""} href="#memory"><span aria-hidden="true">◇</span>Memory</a>
                <a className={"is-active" if page == "activity" else ""} href="#activity"><span aria-hidden="true">↗</span>Activity & reviews</a>
                <a className={"is-active" if page == "history" else ""} href="#history"><span aria-hidden="true">◷</span>Chat history</a>
            </nav>
            <div className="recent-chats"><p className="nav-label">RECENT CHATS · THIS BROWSER</p>{for item in history[:8] { <button key={item.id} data-run-id={item.id} onClick={open_history} disabled={busy}>{item.goal}</button> }}{len(history) == 0 and <p className="history-empty">Your conversations will appear here.</p>}</div>
            <div className="sidebar-footer"><span className="mini-mark">m</span><p>Less juggling.<br/>More living.</p><small>Made with Jac</small></div>
        </aside>
        <main className="main-content" id="page-content"><header className="topbar"><div className="breadcrumb">Workspace <span>/</span><strong>{page.replace("activity","Activity & reviews").replace("history","Chat history")}</strong></div><div className="connection" role="status">{connection_status}</div></header>
        {message and <div className="feedback persistent-error" role="alert">{message}</div>}
        {page != "home" and busy and <p className="working-label" role="status">Working on your request…</p>}
        {page == "home" and <section className={"chat-home " + ("has-conversation" if current.run is not None or len(help_turns) > 0 else "")} aria-label="Planning conversation">
            <div className="chat-welcome"><AgentMascot status={mascot_state()} /><h1>{"Meridian" if current.run is not None else "A lighter day starts here."}</h1><p>Hi, I’m Meridian. What shall we make time for?</p></div>
            {current.run is None and <div className="idea-chips"><button onClick={suggest} data-prompt="Plan a two-hour AI meetup next week">▦ Plan my week</button><button onClick={suggest} data-prompt="Help me break a big project into smaller steps">✧ Untangle an idea</button><a href="#calendar">☀ Make some time</a></div>}
            {len(help_turns) > 0 and <div className="chat-transcript help-transcript" aria-label="Quick help conversation">{for turn in help_turns { <div key={turn.id}><article className="chat-message user-message"><span>You</span><p>{turn.question}</p></article><article className="chat-message agent-message help-message"><span className="message-heading"><ChatBadge /><span>Meridian</span><small>Quick help</small></span><p>{turn.reply}</p><a className="chat-review-link" href="#calendar">Open your calendar →</a></article></div> }}</div>}
            {current.run is not None and <div className="chat-transcript" aria-label="Current conversation">
                {for turn in current.conversation { <div key={turn.user + turn.assistant}><article className="chat-message user-message"><p>{turn.user}</p></article>{turn.assistant and <article className="chat-message agent-message"><p>{turn.assistant}</p></article>}</div> }}<article className="chat-message user-message"><p>{current.run.goal}</p></article>
                {len(current.proposals) > 0 and <a className="activity-pill" href="#activity">✧ View activity & action reviews</a>}
                {current.run.status == "waiting_for_input" and <article className="chat-message agent-message"><span className="message-heading"><ChatBadge kind="received"/><span>A little more detail</span></span>{for question in current.questions { <p key={question}>{question}</p> }}</article>}
                {current.explanation and <article className="chat-message agent-message"><span className="message-heading"><ChatBadge/><span>Meridian</span></span><p>{current.explanation}</p></article>}
                {current.run.error is not None and <article className="chat-message error-message" role="alert"><span className="message-heading"><ChatBadge kind="error"/><span>Let's try another way</span></span><p>{error_text(current.run.error)}</p><p>Your request is saved in history. You can adjust your message and send a new plan, or ask what I can do.</p></article>}
                {current.run.status == "waiting_for_approval" and <article className="chat-message agent-message"><span className="message-heading"><ChatBadge kind="received"/><span>Ready for your review</span></span><p>{str(len([item for item in current.proposals if item.status == "pending"])) + " actions are waiting. Nothing pending has been executed."}</p><a className="chat-review-link" href="#activity">Review exact actions →</a></article>}
                {current.run.status == "completed" and len(current.receipts) > 0 and <article className="chat-message agent-message"><span className="message-heading"><ChatBadge kind="success"/><span>Completed</span></span><p>{str(len(current.receipts)) + " committed receipts are available."}</p><a className="chat-review-link" href="#activity">View results & receipts →</a></article>}
                {current.run.status == "cancelled" and <article className="chat-message agent-message"><span>Cancelled</span><p>This plan was cancelled. Any previously committed results are retained.</p></article>}
                {current.run.status in ["queued","running"] and <div className="button-group"><button onClick={advance} disabled={busy or current.run.status == "running"}>Continue plan</button><button onClick={cancel} disabled={busy}>Cancel run</button><button onClick={reload} disabled={busy}>Reload status</button></div>}
                <div id="chat-tail" />
            </div>}
            {busy and <div className="typing-indicator" role="status"><ChatBadge kind="working"/><span>Meridian is working on your request</span><span className="typing-dots" aria-hidden="true"><i/><i/><i/></span></div>}
            <div className="chat-composer-wrap">
                {current.run is not None and current.run.status == "waiting_for_input" and len(current.proposals) == 0 and <form className="goal-composer chat-composer" onSubmit={clarify}><label className="sr-only" htmlFor="clarification">Clarification</label><input id="clarification" value={answer} onChange={answer_input} maxLength={2000} disabled={busy} placeholder="Tell Meridian a little more…"/><div className="composer-footer"><span>Reply to this plan</span><button className="button-primary" type="submit" disabled={busy or not answer.strip()}>Send reply ↗</button></div></form>}
                <form className="goal-composer chat-composer" onSubmit={start}><label className="sr-only" htmlFor="planning-goal">Planning goal</label><textarea id="planning-goal" value={goal} onChange={goal_input} disabled={busy} maxLength={4000} placeholder="Message Meridian…"/><div className="composer-footer"><span>{"Planning…" if busy else "Just ask. You’re in charge of every action."}</span><button className="button-primary" type="submit" disabled={busy or not goal.strip()}>{"Planning…" if busy else "Send"}<span aria-hidden="true">↗</span></button></div></form>
                <p className="chat-footnote">A little help, a little headspace.</p>
    
            </div>
        </section>}
        {page == "history" and <section className="history-page"><div className="page-heading"><div><p className="eyebrow">PICK UP WHERE YOU LEFT OFF</p><h1>Conversation history</h1><p>Plans opened on this browser. Content is loaded from the server.</p></div><button onClick={new_chat} disabled={busy}>New chat ＋</button></div>{history_error and <p role="alert">{history_error}</p>}{len(history) == 0 and <div className="empty-state"><h3>Your first conversation starts here.</h3><a href="#home">Go to Home →</a></div>}<div className="history-list">{for item in history { <button key={item.id} data-run-id={item.id} onClick={open_history} disabled={busy}><strong>{item.goal}</strong><span>{item.status.replace("_"," ")}</span><small>{item.id}</small></button> }}</div></section>}
        <div className="routed-workspace">
            {page == "tasks" and <section className="panel tasks-panel" id="tasks"><div className="panel-heading"><div><p className="eyebrow">ONE THING AT A TIME</p><h2>Tasks</h2></div><span className="count-tag">{len(workspace.tasks)}</span></div>
                <form className="inline-form" onSubmit={add_task}><label className="sr-only" htmlFor="task-title">Task title</label><input id="task-title" value={task_title} onChange={task_input} maxLength={200} disabled={busy} placeholder="Add a little to-do…" /><button type="submit" disabled={busy or not task_title.strip()}>Add task</button></form>
                <ul className="record-list task-list">{for task in workspace.tasks { <li key={task.id}><button className={"task-check " + task.status} data-id={task.id} aria-label={"Reopen " + task.title if task.status == "done" else "Complete " + task.title} aria-pressed={task.status == "done"} onClick={toggle_task} disabled={busy}>{"✓" if task.status == "done" else ""}</button><div><strong>{task.title}</strong></div><span className="status-tag">{task.status.replace("_"," ")}</span></li> }}</ul>
                {len(workspace.tasks) == 0 and <div className="empty-state"><span aria-hidden="true">✓</span><h3>A fresh start.</h3><p>Add your first task. One small step is enough.</p></div>}
            </section>}
            {page == "calendar" and <CalendarPanel key={workspace_id} workspace_id={workspace_id} onSaved={refresh_workspace} />}
            {page == "memory" and <section className="panel memory-panel" id="memory"><div className="panel-heading"><div><p className="eyebrow">THE LITTLE THINGS THAT MATTER</p><h2>Memory</h2></div><span className="memory-symbol" aria-hidden="true">◇</span></div><p className="panel-description">Your preferences. Remembered with your say-so.</p>
                <SoulEditor key={workspace_id + str([p.version for p in workspace.preferences if p.key == "soul"])} workspace_id={workspace_id} preferences={workspace.preferences} onSaved={refresh_workspace}/><div className="preference-value"><span>CONFIRMED AVAILABILITY</span><strong>{[p for p in workspace.preferences if p.key == "availability"][0].value if len([p for p in workspace.preferences if p.key == "availability"]) > 0 else "Not set yet"}</strong>{len([p for p in workspace.preferences if p.key == "availability"]) > 0 and <small>{"Version " + str([p for p in workspace.preferences if p.key == "availability"][0].version) + " · " + [p for p in workspace.preferences if p.key == "availability"][0].source}</small>}</div>
                <div className="button-group"><button onClick={morning} disabled={busy}>Confirm morning only</button><button onClick={anytime} disabled={busy}>Confirm any time</button></div><button className="text-button" onClick={forget} disabled={busy or len([p for p in workspace.preferences if p.key == "availability"]) == 0}>Forget availability</button>
            </section>}
            {page == "notes" and <section className="panel notes-panel" id="notes"><div className="panel-heading"><div><p className="eyebrow">THOUGHTS WORTH KEEPING</p><h2>Notes</h2></div><span className="count-tag">{len(workspace.notes)}</span></div>
                {for note in workspace.notes { <article className="note-card" key={note.id}><h3>{note.title}</h3><p>{note.body}</p></article> }}
                {len(workspace.notes) == 0 and <div className="empty-state"><span aria-hidden="true">▤</span><h3>Good ideas belong here.</h3><p>Agenda notes from approved plans will appear here.</p></div>}
            </section>}

        </div>
        {page == "activity" and <section className="panel activity-panel" id="activity"><div className="panel-heading"><div><p className="eyebrow">EVERY STEP, IN THE OPEN</p><h2>Activity & action reviews</h2></div><span className="status-tag">{current.run.status.replace("_"," ") if current.run is not None else "No active plan"}</span></div>
            {current.run is None and <div className="empty-state activity-empty"><span aria-hidden="true">↗</span><div><h3>It starts with an idea.</h3><p>Start a conversation on Home to see real activity, review actions, and keep the receipts.</p></div></div>}
            {current.run is not None and <div className="run-content"><p className="run-goal">{current.run.goal}</p><p className="run-id">{"Run " + current.run.id}</p>{current.run.error is not None and <p className="error-message" role="alert">{error_text(current.run.error)}</p>}
                <ol className="step-list">{for step in (current.run as RunRecord).steps { <li key={step.id}><span>{step.id}</span><span className="status-tag">{step.status.replace("_"," ")}</span></li> }}</ol>
                <div className="button-group"><button className="button-primary" onClick={advance} disabled={busy or current.run.status not in ["queued","running"]}>Continue plan</button><button onClick={replan} disabled={busy or current.run.status in ["running","failed","cancelled"]}>Replan pending actions</button><button className="text-button" onClick={cancel} disabled={busy or current.run.status in ["cancelled","failed","completed"]}>Cancel run</button></div>
                {current.run.status == "waiting_for_input" and <section className="clarification"><ul>{for question in current.questions { <li key={question}>{question}</li> }}</ul>{len(current.proposals) == 0 and <form className="stack-form" onSubmit={clarify}><label htmlFor="clarification">Clarification</label><input id="clarification" value={answer} onChange={answer_input} maxLength={2000} disabled={busy} /><button type="submit" disabled={busy}>Submit clarification</button></form>}</section>}
                <div className="run-columns"><section><h3>Public activity</h3><ol className="timeline">{for entry in current.activity { <li key={entry.sequence}><strong>{activity_title(entry.tool,entry.outcome)}</strong><p>{entry.outcome}</p><details><summary>Technical details</summary><code>{entry.tool}</code></details></li> }}</ol>{len(current.activity) == 0 and <p className="muted">No tool activity yet.</p>}</section><section><h3>Proposed actions</h3><p className="muted">Review each exact action. Each approval commits one write.</p><p>{current.explanation}</p>{for proposal in [p for p in current.proposals if p.status != "stale"] { <ProposalCard key={proposal.id} proposal={proposal} busy={busy} before={before(proposal)} onReview={review} /> }}{len(current.proposals) == 0 and <p className="muted">No actions proposed yet.</p>}</section></div>
                <details className="receipt-details"><summary>{"Execution receipts · " + str(len(current.receipts))}</summary><ul className="record-list">{for receipt in current.receipts { <li key={receipt.id}><div><strong>{receipt.committed_at}</strong><small>{receipt.id}{" → "}{", ".join(receipt.record_ids)}</small></div></li> }}</ul>{len(current.receipts) == 0 and <p>No committed actions yet.</p>}</details>
            </div>}
        </section>}
        {page == "activity" and <details className="workspace-details"><summary>Workspace details & demo tools</summary><p>{"Workspace: " + workspace_id}</p><p>Next week: Monday–Friday, 09:00–17:00 Asia/Colombo. Morning: 09:00–12:00. Agenda and tasks use supplied information; no web research is performed.</p><button onClick={new_demo} disabled={busy}>New review workspace</button></details>}
        {page not in ["home","history"] and <footer className="page-footer"><span>meridian. <span>A calmer way to get there.</span></span><span>Asia/Colombo · Personal workspace</span></footer>}
        </main>
    </div>;
}
