<!--
  Generated from docs/specs/spec-recipes.md @ d928041
  Keep in sync manually. On recipe churn, regenerate this section.
-->

# Calendar — recipes

Covers Microsoft Graph (`ms:<label>`) and Google Calendar (`google:<label>`).

Abbreviations:
- `$GRAPH` = `https://graph.microsoft.com/v1.0`
- `$CAL` = `https://www.googleapis.com/calendar/v3`

**User-visible formatting (family default):**
- Event lists: start local time + duration, subject/summary, organizer,
  Teams/Meet join URL if present.
- Single event: full time window, attendees with response status, body.
- Create actions: confirm with event id + `webUrl` / `htmlLink`.

---

## Calendar — read

### CAL-R-1: Today's events (Microsoft, calendarView)

**When to use:** "today's meetings", "what's on my calendar".

**Command (macOS/BSD date):**
```bash
apl call ms:<label> GET "$GRAPH/me/calendarView?startDateTime=$(date -u +%Y-%m-%dT00:00:00Z)&endDateTime=$(date -u -v+1d +%Y-%m-%dT00:00:00Z)&\$select=subject,start,end,organizer,isOnlineMeeting,onlineMeeting"
```

GNU Linux: `date -u -d tomorrow +%Y-%m-%dT00:00:00Z` for the upper bound.

**Expected response:** `{ value: [...] }` with recurrences expanded into instances.

**Common errors:** Using `/events` instead of `/calendarView` misses recurring instances; always use `calendarView` for "what's on my day".

**User-visible formatting:** Sorted by start time; show "HH:MM–HH:MM — subject (organizer)".

### CAL-R-2: This week's events (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/calendarView?startDateTime=<mon-iso>&endDateTime=<sun-iso>"
```

**User-visible formatting:** Group by day.

### CAL-R-3: Next 5 upcoming (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/events?\$filter=start/dateTime%20ge%20'$(date -u +%Y-%m-%dT%H:%M:%SZ)'&\$orderby=start/dateTime&\$top=5"
```

**Common errors:** Single-quote the datetime value inside `$filter`.

### CAL-R-4: Events with Teams link (Microsoft)

**When to use:** "my online meetings", "events with a join link".

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/events?\$filter=isOnlineMeeting%20eq%20true&\$orderby=start/dateTime%20desc&\$top=50&\$select=subject,start,organizer,onlineMeeting"
```

**User-visible formatting:** Show `onlineMeeting.joinUrl` as click-through.

### CAL-R-5: Single event (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/events/{id}"
```

**Expected response:** Full event incl. `attendees`, `body`, `recurrence`.

### CAL-R-6: List my calendars (Microsoft)

**Command:**
```bash
apl call ms:<label> GET "$GRAPH/me/calendars"
```

**Expected response:** `{ value: [{id, name, owner, canEdit}, ...] }`.

### CAL-R-7: Today's events (Google)

**When to use:** "what's on my calendar" (Google).

**Command:**
```bash
apl call google:<label> GET "$CAL/calendars/primary/events?timeMin=$(date -u +%Y-%m-%dT00:00:00Z)&timeMax=$(date -u -v+1d +%Y-%m-%dT00:00:00Z)&singleEvents=true&orderBy=startTime"
```

**Expected response:** `{ items: [...], nextSyncToken? }`.

**Common errors:**
- `orderBy=startTime` **only** works when `singleEvents=true`. Set both.
- Omitting `timeMin` silently defaults to "now" — past events of today disappear.

**User-visible formatting:** "HH:MM — summary (organizer)".

### CAL-R-8: Next 10 upcoming (Google)

**Command:**
```bash
apl call google:<label> GET "$CAL/calendars/primary/events?timeMin=$(date -u +%Y-%m-%dT%H:%M:%SZ)&maxResults=10&singleEvents=true&orderBy=startTime"
```

### CAL-R-9: Search by text (Google)

**Command:**
```bash
apl call google:<label> GET "$CAL/calendars/primary/events?q=retro&singleEvents=true&timeMin=2026-01-01T00:00:00Z"
```

### CAL-R-10: Single event (Google)

**Command:**
```bash
apl call google:<label> GET "$CAL/calendars/primary/events/{eventId}"
```

**Expected response:** Includes `conferenceData`, `hangoutLink`, `attendees`, `organizer`.

### CAL-R-11: List my calendars (Google)

**Command:**
```bash
apl call google:<label> GET "$CAL/users/me/calendarList"
```

**Expected response:** `{ items: [{id, summary, primary, accessRole}, ...] }`.

### CAL-R-12: Meet-enabled events (Google)

**Command:**
```bash
apl call google:<label> GET "$CAL/calendars/primary/events?timeMin=2026-01-01T00:00:00Z&maxResults=50&singleEvents=true&orderBy=startTime"
```

Then client-side filter for items where `hangoutLink` OR `conferenceData.entryPoints[].uri` exists.

**Common errors:** Older events only have `hangoutLink`; new ones populate `conferenceData.entryPoints[*].uri` with `entryPointType=="video"`. Check both.

---

## Calendar — write

### CAL-W-1: Create event (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/events" --body '{
  "subject":"Sync",
  "start":{"dateTime":"2026-05-01T09:00:00","timeZone":"UTC"},
  "end":{"dateTime":"2026-05-01T09:30:00","timeZone":"UTC"},
  "attendees":[{"emailAddress":{"address":"x@y.com"},"type":"required"}]
}'
```

**Expected response:** 201; event object with `id`.

**Common errors:** `timeZone` is required alongside `dateTime`. 403 → `apl login ms:<label> --force --scope Calendars.ReadWrite`.

**User-visible formatting:** "Created event <id>: <subject> @ <start>."

### CAL-W-2: Create event with Teams link (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/events" --body '{
  "subject":"Teams sync",
  "start":{"dateTime":"2026-05-01T09:00:00","timeZone":"UTC"},
  "end":{"dateTime":"2026-05-01T09:30:00","timeZone":"UTC"},
  "isOnlineMeeting":true,
  "onlineMeetingProvider":"teamsForBusiness"
}'
```

**Expected response:** 201 with `onlineMeeting.joinUrl`.

**Common errors:** Some tenants require `OnlineMeetings.ReadWrite` as an additional scope.

### CAL-W-3: Update event (Microsoft)

**Command:**
```bash
apl call ms:<label> PATCH "$GRAPH/me/events/{id}" --body '{"subject":"Renamed"}'
```

### CAL-W-4: Cancel event (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/events/{id}/cancel" --body '{"comment":"conflict"}'
```

**Expected response:** 202.

**Common errors:** Organizer only. Attendees should DELETE their local copy instead (CAL-W-5).

### CAL-W-5: Delete event (Microsoft)

**Command:**
```bash
apl call ms:<label> DELETE "$GRAPH/me/events/{id}"
```

**Expected response:** 204. Confirm before running.

### CAL-W-6: Accept / decline / tentative (Microsoft)

**Commands:**
```bash
apl call ms:<label> POST "$GRAPH/me/events/{id}/accept" --body '{"sendResponse":true,"comment":"joining"}'
apl call ms:<label> POST "$GRAPH/me/events/{id}/decline" --body '{"sendResponse":true}'
apl call ms:<label> POST "$GRAPH/me/events/{id}/tentativelyAccept" --body '{"sendResponse":false}'
```

**Expected response:** 202 each.

**User-visible formatting:** "RSVP: accepted/declined/tentative sent."

### CAL-W-7: Find meeting times (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/findMeetingTimes" --body '{
  "attendees":[{"emailAddress":{"address":"x@y.com"}}],
  "timeConstraint":{"timeSlots":[{"start":{"dateTime":"2026-05-01T09:00:00","timeZone":"UTC"},"end":{"dateTime":"2026-05-01T17:00:00","timeZone":"UTC"}}]},
  "meetingDuration":"PT30M"
}'
```

**Expected response:** `{ meetingTimeSuggestions: [...], emptySuggestionsReason? }`.

### CAL-W-8: Free/busy lookup (Microsoft)

**Command:**
```bash
apl call ms:<label> POST "$GRAPH/me/calendar/getSchedule" --body '{
  "schedules":["shaama@reqsume.com"],
  "startTime":{"dateTime":"2026-05-01T09:00:00","timeZone":"UTC"},
  "endTime":{"dateTime":"2026-05-01T17:00:00","timeZone":"UTC"},
  "availabilityViewInterval":30
}'
```

**Expected response:** `{ value: [{scheduleId, availabilityView, scheduleItems[]}, ...] }`.

**User-visible formatting:** Render busy/free as a visual grid per 30-min slot.

### CAL-W-9: Create event (Google)

**Command:**
```bash
apl call google:<label> POST "$CAL/calendars/primary/events" --body '{
  "summary":"Sync",
  "start":{"dateTime":"2026-05-01T10:00:00+05:30"},
  "end":{"dateTime":"2026-05-01T10:30:00+05:30"},
  "attendees":[{"email":"x@y.com"}]
}'
```

**Expected response:** 200; event object with `id`, `htmlLink`.

**Common errors:** 403 → `apl login google:<label> --force --scope calendar`.

### CAL-W-10: Create event with Meet link (Google)

**Command:**
```bash
apl call google:<label> POST "$CAL/calendars/primary/events?conferenceDataVersion=1" --body '{
  "summary":"Meet sync",
  "start":{"dateTime":"2026-05-01T10:00:00+05:30"},
  "end":{"dateTime":"2026-05-01T10:30:00+05:30"},
  "conferenceData":{"createRequest":{"requestId":"apl-'$(date +%s)'","conferenceSolutionKey":{"type":"hangoutsMeet"}}}
}'
```

**Expected response:** Event includes `hangoutLink` + `conferenceData.entryPoints[]`.

**Common errors:**
- `conferenceDataVersion=1` is **required** as a query param.
- `requestId` must be unique per request — use a timestamp or UUID.

### CAL-W-11: Update / RSVP (Google)

**Command:**
```bash
apl call google:<label> PATCH "$CAL/calendars/primary/events/{eventId}" --body '{
  "attendees":[{"email":"me@example.com","responseStatus":"accepted"}]
}'
```

Values for `responseStatus`: `accepted`, `declined`, `tentative`, `needsAction`.

**Common errors:** PATCH replaces the `attendees` array fully — include every attendee (with current `responseStatus`) or you'll drop others.

### CAL-W-12: Delete event (Google)

**Command:**
```bash
apl call google:<label> DELETE "$CAL/calendars/primary/events/{eventId}"
```

**Expected response:** 204. Confirm before running.

### CAL-W-13: quickAdd natural language (Google)

**When to use:** "schedule lunch tomorrow 12:30".

**Command:**
```bash
apl call google:<label> POST "$CAL/calendars/primary/events/quickAdd?text=Lunch%20tomorrow%2012:30"
```

**Expected response:** 200 with newly-created event.

**Common errors:** URL-encode the text. Timezone inferred from calendar default.

### CAL-W-14: Free/busy lookup (Google)

**Command:**
```bash
apl call google:<label> POST "$CAL/freeBusy" --body '{
  "timeMin":"2026-05-01T09:00:00Z",
  "timeMax":"2026-05-01T17:00:00Z",
  "items":[{"id":"muthu@example.com"},{"id":"shaama@reqsume.com"}]
}'
```

**Expected response:** `{ calendars: {email: {busy: [{start,end}, ...]}} }`.
