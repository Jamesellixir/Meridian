sv import from app.api { get_calendar, save_event, CalendarView, CalendarDay, EventRecord }

def:pub CalendarPanel(workspace_id: str, onSaved: Callable[[],None]) -> JsxElement {
    has view: CalendarView = ({"month":"","label":"Calendar","previous":"","following":"","today":"","days":[]} as CalendarView);
    has selected: str = "", month: str = "", busy: bool = True, editing: bool = False;
    has title: str = "", start: str = "", end: str = "", color: str = "blue", event_id: str = "", version: int = 0;
    has error: str = "", notice: str = "", request_id: str = "";
    def key -> str { return str(crypto.randomUUID()); } # jac:ignore[E1032,W2001,W1051]
    async def load(target: str) -> None {
        busy = True; error = "";
        try { response = await get_calendar(workspace_id,target,key()); if not response.ok or response.data is None { error = "Couldn’t load that month. Try again."; busy = False; return; } loaded = response.data; view = loaded; month = loaded.month; if not selected or selected[:7] != loaded.month { selected = loaded.today if loaded.today[:7] == loaded.month else loaded.month + "-01"; } }
        except Exception { error = "Couldn't load the calendar. Try again."; }
        busy = False;
    }
    async can with entry { await load(""); }
    def previous(event: MouseEvent) { load(view.previous); }
    def following(event: MouseEvent) { load(view.following); }
    def today(event: MouseEvent) { selected = view.today; load(""); }
    def pick(event: MouseEvent) { selected = event.currentTarget.getAttribute("data-date") or view.today; }
    def add(event: MouseEvent) {
        event_id = ""; version = 0; title = ""; color = "blue"; request_id = "";
        start = selected + "T09:00"; end = selected + "T10:00"; editing = True; notice = "";
    }
    def close(event: MouseEvent) { editing = False; error = ""; }
    def change_title(event: ChangeEvent) { title = event.target.value; request_id = ""; }
    def change_start(event: ChangeEvent) { start = event.target.value; request_id = ""; }
    def change_end(event: ChangeEvent) { end = event.target.value; request_id = ""; }
    def choose_color(event: MouseEvent) { color = event.currentTarget.getAttribute("data-color") or "blue"; request_id = ""; }
    def edit(event: MouseEvent) {
        id = event.currentTarget.getAttribute("data-id");
        for day in view.days { for item in day.events { if item.id == id {
            event_id = item.id; version = item.version; title = item.title; color = item.color;
            start = item.start[:16]; end = item.end[:16]; editing = True; request_id = ""; notice = ""; return;
        } } }
    }
    async def save(event: FormEvent) -> None {
        event.preventDefault(); if busy { return; } busy = True; error = ""; notice = "";
        request = request_id or key(); request_id = request;
        try {
            result = await save_event(workspace_id,title,start + ":00+05:30",end + ":00+05:30",request,event_id,version,color);
            if result.ok { editing = False; selected = start[:10]; request_id = ""; await load(start[:7]); notice = "Saved to your calendar"; onSaved(); }
            else { error = result.error.message if result.error is not None else "Couldn't save. Try again."; }
        } except Exception { error = "Connection interrupted. Retry to recover the same save."; }
        busy = False;
    }
    return <section className="calendar-page">
        <div className="calendar-toolbar"><div><p className="eyebrow">A LITTLE SPACE FOR EVERYTHING</p><h1>{view.label}</h1></div><div className="button-group"><button onClick={today} disabled={busy}>Today</button><button aria-label="Previous month" onClick={previous} disabled={busy}>‹</button><button aria-label="Next month" onClick={following} disabled={busy}>›</button><button className="button-primary" onClick={add} disabled={busy}>＋ Event</button></div></div>
        <p className="calendar-caption">Asia/Colombo · Pick a day to see what's on.</p>
        {error and <p className="feedback" role="alert">{error}</p>}{notice and <p className="save-notice" role="status">✓ {notice}</p>}
        <div className="calendar-layout"><div className="calendar-grid" aria-label="Month calendar">
            {for name in ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"] { <div className="weekday" key={name}>{name}</div> }}
            {for day in view.days { <div key={day.date} className={"calendar-cell " + ("outside " if not day.in_month else "") + ("selected " if day.date == selected else "") + ("is-today" if day.date == view.today else "")}><button className="day-number" aria-label={day.date} aria-pressed={day.date == selected} data-date={day.date} onClick={pick}>{day.day}</button>{for item in day.events[:3] { <button key={item.id} className={"calendar-chip color-" + item.color} data-id={item.id} onClick={edit} title={item.title}><time>{item.start[11:16]}</time><span>{item.title}</span></button> }}{len(day.events) > 3 and <button className="more-events" data-date={day.date} onClick={pick}>{"+" + str(len(day.events)-3) + " more"}</button>}</div> }}
        </div><aside className="day-agenda"><h2>{selected}</h2><p className="muted">Your day, at a glance.</p>{for day in view.days { if day.date == selected { <div key={day.date}>{for item in day.events { <button key={item.id} className={"agenda-event color-" + item.color} data-id={item.id} onClick={edit}><strong>{item.title}</strong><span>{item.start[11:16] + " – " + item.end[11:16]}</span></button> }}{len(day.events) == 0 and <div className="day-empty"><span>☀</span><p>A little breathing room.</p><button onClick={add}>Add an event</button></div>}</div> } }}</aside></div>
        {editing and <div className="editor-backdrop"><section className="event-editor" role="dialog" aria-modal="true" aria-label="Event editor"><div className="panel-heading"><h2>{"Edit event" if event_id else "Make some time"}</h2><button aria-label="Close event editor" onClick={close} disabled={busy}>×</button></div><form className="stack-form" onSubmit={save}><label htmlFor="event-title">What’s happening?</label><input autoFocus required id="event-title" value={title} onChange={change_title} maxLength={200} disabled={busy} placeholder="Coffee with a friend"/><div className="event-times"><div><label htmlFor="event-start">Starts</label><input required type="datetime-local" id="event-start" value={start} onChange={change_start} disabled={busy}/></div><div><label htmlFor="event-end">Ends</label><input required type="datetime-local" id="event-end" value={end} onChange={change_end} disabled={busy}/></div></div><p className="muted">All times are in Asia/Colombo.</p><div className="color-picker" aria-label="Event color">{for option in ["blue","green","purple","peach","rose"] { <button key={option} type="button" className={"color-swatch color-" + option} data-color={option} onClick={choose_color} aria-label={option} aria-pressed={option == color} disabled={busy}>{"✓" if option == color else ""}</button> }}</div>{error and <p role="alert">{error}</p>}<button className="button-primary" type="submit" disabled={busy}>{"Saving…" if busy else "Save event"}</button></form></section></div>}
    </section>;
}
