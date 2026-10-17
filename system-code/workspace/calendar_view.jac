import from datetime { datetime, timedelta }
import from zoneinfo { ZoneInfo }
import from contracts.models { EventRecord, APIError }
import from workspace.records { _workspace }

obj CalendarDay { has date: str, day: int, in_month: bool, events: list[EventRecord] = []; }
obj CalendarView { has month: str, label: str, previous: str, following: str, today: str, days: list[CalendarDay] = []; }

obj CalendarEnvelope { has ok: bool, data: (CalendarView | None) = None, error: (APIError | None) = None; }

def _calendar(workspace_id: str, month: str = "") -> CalendarView {
    today = datetime.now(ZoneInfo("Asia/Colombo")).date();
    first = datetime.strptime(month + "-01", "%Y-%m-%d").date() if month else today.replace(day=1);
    previous = (first.replace(day=1) - timedelta(days=1)).strftime("%Y-%m");
    following = (first.replace(day=28) + timedelta(days=4)).strftime("%Y-%m");
    events = _workspace(workspace_id).data.events;
    result = CalendarView(month=first.strftime("%Y-%m"),label=first.strftime("%B %Y"),previous=previous,following=following,today=today.isoformat());
    start = first - timedelta(days=first.weekday());
    for index in range(42) {
        day = start + timedelta(days=index);
        daily: list[EventRecord] = [];
        for event in events {
            begin = datetime.fromisoformat(event.start).astimezone(ZoneInfo("Asia/Colombo"));
            end = datetime.fromisoformat(event.end).astimezone(ZoneInfo("Asia/Colombo"));
            if begin.date() <= day and (end - timedelta(microseconds=1)).date() >= day {
                daily.append(EventRecord(id=event.id,workspace_id=event.workspace_id,title=event.title,start=begin.isoformat(),end=end.isoformat(),timezone=event.timezone,goal_id=event.goal_id,version=event.version,color=getattr(event,"color","blue")));
            }
        }
        daily.sort(key=lambda (event: EventRecord) { event.start; });
        result.days.append(CalendarDay(date=day.isoformat(),day=day.day,in_month=day.month == first.month,events=daily));
    }
    return result;
}

