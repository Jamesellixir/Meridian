# UI help copy only: no model, tools, persistence or workspace mutations.
obj HelpTurn { has id: str, question: str, reply: str; }

def:pub quick_help(text: str) -> str {
    clean = " ".join(text.lower().replace("?", "").replace("!", "").replace(",", "").replace(".", "").replace("'", "").split());
    if clean in ["hi", "hello", "hey", "hi there", "hello there", "good morning", "good afternoon", "good evening"] {
        return "Hi! I'm Meridian, your planning companion. I can help you plan a session, prepare an agenda and tasks, and find a free calendar slot. What would you like to put together?";
    }
    for greeting in ["hi ", "hello ", "hey ", "hi there ", "hello there "] {
        if clean.startswith(greeting) { clean = clean[len(greeting):]; break; }
    }
    if clean in ["what can you do", "what can u do", "what do you do", "what do u do", "what can you help me with", "what can u help me with", "help", "help me", "who are you", "who r u", "what is meridian", "how does this work", "how do i use this", "how do i use meridian"] {
        return "I'm Meridian, your personal planning companion. Here's how I can help:\n\n• Plan a meetup or work session and find a free slot in your calendar.\n• Prepare an agenda, notes and preparation tasks.\n• Keep your confirmed availability preferences in mind.\n• Show each proposed action for your approval before saving it.\n\nTry: Plan a two-hour AI meetup next week. You can also open Tasks, Calendar, Notes or Memory from the sidebar.";
    }
    if clean in ["how are you", "how r u", "hows it going"] {
        return "I'm here and ready to help! Tell me about a session you'd like to plan, or ask what I can do.";
    }
    if clean in ["thanks", "thank you", "thank u", "thanks a lot", "thank you so much"] {
        return "You're welcome! I'm here whenever you're ready for the next step.";
    }
    return "";
}

def:pub activity_title(tool: str, outcome: str) -> str {
    if tool == "start_goal" { return "Request received"; }
    if tool == "advance_run" { return "Preparing your plan"; }
    if tool == "read_workspace" { return "Checking your workspace"; }
    if tool == "review_proposal" { return "Review recorded"; }
    if tool == "provide_input" { return "Reply received"; }
    if tool == "planning" { return "Plan needs attention" if outcome == "failed" else "Planning update"; }
    return "Workspace update";
}

def:pub activity_copy(tool: str, outcome: str) -> str {
    if tool == "start_goal" { return "Your request is saved. No calendar or task changes have been made."; }
    if tool == "advance_run" and outcome == "Bounded planning stage started." { return "Started checking the details of your request."; }
    if tool == "planning" and outcome == "failed" { return "I couldn't finish this plan. The explanation is below."; }
    return outcome;
}

def:pub ChatBadge(kind: str = "assistant") -> JsxElement {
    path = "M12 3l2.4 6.6L21 12l-6.6 2.4L12 21l-2.4-6.6L3 12l6.6-2.4L12 3Z";
    if kind == "received" { path = "M4 5h16v12H9l-5 4V5Zm4 4h8m-8 4h5"; }
    elif kind == "working" { path = "M12 3v3m9 6h-3M12 21v-3m-9-6h3m12.4-6.4-2.1 2.1m0 8.6 2.1 2.1m-12.8 0 2.1-2.1m0-8.6L5.6 5.6"; }
    elif kind == "error" { path = "M12 8v5m0 3v.1M10.3 4.8 2.8 18a1.3 1.3 0 0 0 1.1 2h16.2a1.3 1.3 0 0 0 1.1-2L13.7 4.8a2 2 0 0 0-3.4 0Z"; }
    elif kind == "success" { path = "M5 12l4 4L19 6"; }
    elif kind == "calendar" { path = "M5 5h14v15H5V5Zm0 5h14M8 3v4m8-4v4m-8 7h3m2 0h3"; }
    return <span className={"chat-badge badge-" + kind} aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><path d={path} stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round" /></svg></span>;
}

def:pub ActivityMessage(tool: str, outcome: str) -> JsxElement {
    kind = "working";
    if tool == "start_goal" or tool == "provide_input" { kind = "received"; }
    elif tool == "review_proposal" { kind = "success" if outcome.startswith("approve ") else "received"; }
    elif tool == "read_workspace" { kind = "calendar"; }
    elif tool == "planning" and outcome == "failed" { kind = "error"; }
    return <article className="chat-message agent-message status-message"><span className="message-heading"><ChatBadge kind={kind} /><span>{activity_title(tool,outcome)}</span></span><p>{activity_copy(tool,outcome)}</p></article>;
}
