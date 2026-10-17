sv import from app.api { save_soul, PreferenceRecord }

def:pub SoulEditor(workspace_id: str, preferences: list[PreferenceRecord], onSaved: Callable[[],None]) -> JsxElement {
    has text: str = "", version: int = 0, busy: bool = False, message: str = "", error: str = "";
    can with entry { for item in preferences { if item.key == "soul" { text = item.value; version = item.version; } } }
    def change(event: ChangeEvent) { text = event.target.value; message = ""; }
    async def save(event: FormEvent) -> None {
        event.preventDefault(); if busy { return; } busy = True; error = ""; message = "";
        try {
            result = await save_soul(workspace_id,text,version);
            if result.ok {
                version = 0;
                for item in result.data.preferences { if item.key == "soul" { version = item.version; } }
                message = "Remembered. I'll use this in our next conversation." if text.strip() else "Personal context forgotten.";
                onSaved();
            } else { error = result.error.message if result.error is not None else "Couldn't save memory."; }
        } except Exception { error = "Couldn't confirm the save. Reload memory before retrying."; }
        busy = False;
    }
    return <section className="soul-editor"><div className="soul-heading"><span className="soul-icon">✧</span><div><h3>A little more you.</h3><p>What would you like me to remember?</p></div><span className="file-tag">soul.md</span></div><form onSubmit={save}><label className="sr-only" htmlFor="soul-text">Personal memory</label><textarea id="soul-text" value={text} onChange={change} maxLength={4000} disabled={busy} placeholder="My name is…&#10;I’m working on…&#10;I like short, friendly replies…"/><div className="composer-footer"><span>Only what you choose to save. Clear and save to forget.</span><button className="button-primary" type="submit" disabled={busy}>{"Saving…" if busy else "Save memory"}</button></div></form><p className="muted">Personal context shapes our conversation. Set scheduling hours below.</p>{message and <p role="status" className="save-notice">{message}</p>}{error and <p role="alert">{error}</p>}</section>;
}
