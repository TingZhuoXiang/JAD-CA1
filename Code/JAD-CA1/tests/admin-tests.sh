#!/usr/bin/env bash
# End-to-end checks of the Admin phase against a running local server (Git Bash).
# Usage: CNF=path/to/mysql-option-file bash tests/admin-tests.sh
#   CNF is a MySQL option file ([client] user/password/host/port) for a login that can
#   read and write jad_ca1, used to set up and check rows. Keep it outside the repo.
#   Optional: B=http://localhost:8080/JAD-CA1 (default). Needs the demo seed data.
# The script creates test events and accounts named with a run number; it does not delete them.
B=${B:-http://localhost:8080/JAD-CA1}
W=$(mktemp -d)
PASS=0; FAIL=0
RUN=$(date +%s)
ok()   { PASS=$((PASS+1)); echo "PASS  $1"; }
bad()  { FAIL=$((FAIL+1)); echo "FAIL  $1  ($2)"; }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "expected $3, got $2"; fi; }
has()  { if grep -q -- "$3" "$2"; then ok "$1"; else bad "$1" "missing: $3"; fi; }
csrf() { grep -o 'name="csrf" value="[0-9a-f]*"' "$1" | head -1 | sed 's/.*value="//;s/"//'; }
# one-time token that create forms carry, so a double-click cannot create a record twice
ftok() { grep -o 'name="formToken" value="[0-9a-f]*"' "$1" | head -1 | sed 's/.*value="//;s/"//'; }
# get JAR PATH -> body in $W/body, prints status
get()  { curl -s -o "$W/body" -w "%{http_code}" -c "$W/$1" -b "$W/$1" "$B/$2"; }
# post JAR PATH args... (adds csrf and any form token from the jar's last page) -> body in $W/body, prints status
post() { local jar=$1 path=$2; shift 2; local t f s; t=$(cat "$W/$jar.tok" 2>/dev/null); f=$(cat "$W/$jar.form" 2>/dev/null)
         s=$(curl -s -o "$W/body" -w "%{http_code}" -c "$W/$jar" -b "$W/$jar" --data-urlencode "csrf=$t" ${f:+--data-urlencode "formToken=$f"} "$@" "$B/$path")
         f=$(ftok "$W/body"); [ -n "$f" ] && echo "$f" > "$W/$jar.form"; echo "$s"; }
loc()  { curl -s -o /dev/null -w "%{redirect_url}" -c "$W/$1" -b "$W/$1" "$@"; }
token(){ get "$1" "$2" >/dev/null; csrf "$W/body" > "$W/$1.tok"; ftok "$W/body" > "$W/$1.form"; }
login(){ rm -f "$W/$1"; token "$1" login.jsp
         post "$1" login.jsp --data-urlencode "username=$2" --data-urlencode "password=$3" >/dev/null
         token "$1" "${4:-admin/}"; }
idfrom(){ sed -n 's/.*[?&]id=\([0-9]*\).*/\1/p'; }
future(){ date -d "+$1 days" +%Y-%m-%dT$2; }
past()  { date -d "-$1 days" +%Y-%m-%dT$2; }
sql()   { "/c/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" --defaults-extra-file="$CNF" -N -B jad_ca1 -e "$1"; }

echo "== Access control"
check "signed out /admin/ redirects to login" "$(curl -s -o /dev/null -w '%{http_code}' $B/admin/events.jsp)" 302
login A demo_admin CA1-sample-demo
check "admin dashboard" "$(get A admin/)" 200
has "dashboard shows counts" "$W/body" "Upcoming events"
login V demo_volunteer CA1-sample-demo volunteer/
check "volunteer denied admin events" "$(get V admin/events.jsp)" 403
check "volunteer denied admin volunteer page" "$(get V admin/volunteer.jsp?id=1)" 403
check "admin denied volunteer area" "$(get A volunteer/)" 403
check "POST without CSRF token is rejected" "$(curl -s -o /dev/null -w '%{http_code}' -b $W/A --data 'title=x' $B/admin/event-form.jsp)" 403

echo "== Event create / view / edit"
token A admin/event-form.jsp
check "create: end before start rejected" "$(post A admin/event-form.jsp --data-urlencode "title=Bad $RUN" --data-urlencode "location=X" --data-urlencode "startsAt=$(future 5 10:00)" --data-urlencode "endsAt=$(future 5 09:00)")" 400
has "create: end-before-start message" "$W/body" "The end must be after the start."
check "create: start in past rejected" "$(post A admin/event-form.jsp --data-urlencode "title=Bad $RUN" --data-urlencode "location=X" --data-urlencode "startsAt=$(past 1 10:00)" --data-urlencode "endsAt=$(past 1 12:00)")" 400
check "create: missing title rejected" "$(post A admin/event-form.jsp --data-urlencode "title=" --data-urlencode "location=X" --data-urlencode "startsAt=$(future 5 10:00)" --data-urlencode "endsAt=$(future 5 12:00)")" 400
URL=$(loc A --data-urlencode "csrf=$(cat $W/A.tok)" --data-urlencode "formToken=$(cat $W/A.form)" --data-urlencode "title=Test screening $RUN" --data-urlencode "location=Test Hall <b>" --data-urlencode "description=Line one" --data-urlencode "startsAt=$(future 9 09:00)" --data-urlencode "endsAt=$(future 9 12:00)" "$B/admin/event-form.jsp")
EV=$(echo "$URL" | idfrom)
[ -n "$EV" ] && ok "create: valid event redirects to event $EV" || bad "create: valid event" "no redirect ($URL)"
check "event page loads" "$(get A "admin/event.jsp?id=$EV")" 200
has "event page shows title" "$W/body" "Test screening $RUN"
has "user input is HTML-escaped" "$W/body" "Test Hall &lt;b&gt;"
has "flash message shown once" "$W/body" "Event created."
get A "admin/event.jsp?id=$EV" >/dev/null; if grep -q "Event created." "$W/body"; then bad "flash cleared" "still shown"; else ok "flash cleared after one view"; fi
check "unknown event is 404" "$(get A admin/event.jsp?id=999999999)" 404
check "events search finds it" "$(get A "admin/events.jsp?q=$RUN&show=all")" 200
has "events search result" "$W/body" "Test screening $RUN"

echo "== Event registration and roster"
VID=$(sql "SELECT id FROM accounts WHERE username='demo_volunteer'")
token A "admin/event.jsp?id=$EV&find=demo_volunteer"
has "roster search finds demo_volunteer" "$W/body" "Add to event"
check "register demo_volunteer" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$VID")" 302
token A "admin/event.jsp?id=$EV"
has "volunteer appears on roster" "$W/body" "Signed up"
check "duplicate registration refused" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$VID")" 409
has "duplicate message" "$W/body" "already signed up"
CANCELLED_EV=$(sql "SELECT id FROM events WHERE title='Demo: Bedok senior centre screening'")
PAST_EV=$(sql "SELECT id FROM events WHERE title='Demo: Toa Payoh void deck screening'")
check "cancelled event registration refused" "$(post A admin/event.jsp -d "id=$CANCELLED_EV" -d action=register -d "volunteerId=$VID")" 409
has "cancelled message" "$W/body" "has been cancelled"
check "started event registration refused" "$(post A admin/event.jsp -d "id=$PAST_EV" -d action=register -d "volunteerId=$VID")" 409
has "started message" "$W/body" "Signups closed"
ADMIN_ID=$(sql "SELECT id FROM accounts WHERE username='demo_admin'")
check "registering an Admin account refused" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$ADMIN_ID")" 409
REG=$(sql "SELECT id FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID AND status='ACTIVE'")
check "remove from roster" "$(post A admin/event.jsp -d "id=$EV" -d action=remove -d "registrationId=$REG")" 302
check "rejoin after removal" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$VID")" 302
check "history keeps both rows" "$(sql "SELECT CONCAT(COUNT(*), '/', SUM(status='ACTIVE')) FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID")" "2/1"
check "DB blocks a second active row" "$(sql "INSERT INTO event_registrations (event_id, volunteer_id, registered_by, registered_at) VALUES ($EV, $VID, $VID, NOW())" 2>&1 | grep -c 'Duplicate entry')" 1

echo "== Edit keeps registrations"
token A "admin/event-form.jsp?id=$EV"
check "edit event" "$(post A admin/event-form.jsp -d "id=$EV" --data-urlencode "title=Test screening $RUN (edited)" --data-urlencode "location=Test Hall" --data-urlencode "description=Changed" --data-urlencode "startsAt=$(future 10 09:00)" --data-urlencode "endsAt=$(future 10 13:00)")" 302
check "signups unchanged after edit" "$(sql "SELECT COUNT(*) FROM event_registrations WHERE event_id=$EV AND status='ACTIVE'")" 1

echo "== Admin-created account and forced password change"
token A admin/volunteer-new.jsp
check "create account: bad email rejected" "$(post A admin/volunteer-new.jsp --data-urlencode "username=new_$RUN" --data-urlencode "fullName=New Person" --data-urlencode "contactNumber=91234567" --data-urlencode "email=not-an-email")" 400
check "create account: duplicate username rejected" "$(post A admin/volunteer-new.jsp --data-urlencode "username=demo_volunteer" --data-urlencode "fullName=Dup" --data-urlencode "contactNumber=91234567" --data-urlencode "email=dup$RUN@example.test")" 409
check "create account" "$(post A admin/volunteer-new.jsp --data-urlencode "username=new_$RUN" --data-urlencode "fullName=New Person $RUN" --data-urlencode "contactNumber=91234567" --data-urlencode "email=new$RUN@example.test")" 302
check "confirmation page" "$(get A 'admin/volunteer-new.jsp?created')" 200
TEMP=$(grep -o '<p class="secret">[^<]*' "$W/body" | sed 's/.*>//')
[ ${#TEMP} -eq 14 ] && ok "temporary password shown" || bad "temporary password shown" "got '$TEMP'"
get A 'admin/volunteer-new.jsp?created' >/dev/null; if grep -q 'class="secret"' "$W/body"; then bad "temp password shown once" "shown again"; else ok "temporary password shown only once"; fi
check "temp password not stored in clear" "$(sql "SELECT password_hash LIKE 'pbkdf2-sha256:%' AND must_change_password FROM accounts WHERE username='new_$RUN'")" 1
rm -f "$W/N"; token N login.jsp
check "first sign-in redirects to change password" "$(post N login.jsp --data-urlencode "username=new_$RUN" --data-urlencode "password=$TEMP"; echo)" 302
check "volunteer area blocked until changed" "$(loc N "$B/volunteer/")" "$B/account/change-password.jsp"
token N account/change-password.jsp
has "change password page" "$W/body" "Choose a new password"
check "wrong temporary password rejected" "$(post N account/change-password.jsp --data-urlencode "current=wrong-pass" --data-urlencode "password=MyNewPass123" --data-urlencode "confirmation=MyNewPass123")" 400
check "same password rejected" "$(post N account/change-password.jsp --data-urlencode "current=$TEMP" --data-urlencode "password=$TEMP" --data-urlencode "confirmation=$TEMP")" 400
check "password changed" "$(post N account/change-password.jsp --data-urlencode "current=$TEMP" --data-urlencode "password=MyNewPass123" --data-urlencode "confirmation=MyNewPass123")" 302
check "volunteer area reachable after change" "$(get N volunteer/)" 200
login N2 "new_$RUN" MyNewPass123 volunteer/
check "new password works" "$(get N2 volunteer/)" 200

echo "== Volunteer search / edit"
NID=$(sql "SELECT id FROM accounts WHERE username='new_$RUN'")
get A "admin/volunteers.jsp?q=V-$NID" >/dev/null; has "search by Volunteer ID" "$W/body" "New Person $RUN"
get A "admin/volunteers.jsp?q=new$RUN@" >/dev/null; has "search by email" "$W/body" "New Person $RUN"
token A "admin/volunteer.jsp?id=$NID"
has "volunteer page shows ID" "$W/body" "V-$NID"
check "edit: invalid phone rejected" "$(post A admin/volunteer.jsp -d "id=$NID" --data-urlencode "fullName=New Person $RUN" --data-urlencode "contactNumber=12" --data-urlencode "email=new$RUN@example.test")" 400
check "edit: duplicate email rejected" "$(post A admin/volunteer.jsp -d "id=$NID" --data-urlencode "fullName=New Person $RUN" --data-urlencode "contactNumber=91234567" --data-urlencode "email=demo-volunteer@example.test")" 409
check "edit: valid" "$(post A admin/volunteer.jsp -d "id=$NID" --data-urlencode "fullName=Renamed $RUN" --data-urlencode "contactNumber=+65 9123 4567" --data-urlencode "email=new$RUN@example.test")" 302
check "edit saved" "$(sql "SELECT full_name FROM accounts WHERE id=$NID")" "Renamed $RUN"
check "edit cannot change admin account" "$(get A "admin/volunteer.jsp?id=$ADMIN_ID")" 404

echo "== Deactivation"
token A "admin/event.jsp?id=$EV"
check "add new volunteer to upcoming event" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$NID")" 302
sql "INSERT INTO event_registrations (event_id, volunteer_id, registered_by, registered_at) VALUES ($PAST_EV, $NID, $NID, NOW() - INTERVAL 11 DAY)"
check "deactivate confirmation page" "$(get A "admin/volunteer-deactivate.jsp?id=$NID")" 200
token A "admin/volunteer-deactivate.jsp?id=$NID"
check "deactivate" "$(post A admin/volunteer-deactivate.jsp -d "id=$NID")" 302
check "future signup cancelled, past kept" "$(sql "SELECT GROUP_CONCAT(CONCAT(e.starts_at > NOW(), ':', r.status, ':', IFNULL(r.end_reason,'-')) ORDER BY e.starts_at) FROM event_registrations r JOIN events e ON e.id=r.event_id WHERE r.volunteer_id=$NID")" "0:ACTIVE:-,1:CANCELLED:VOLUNTEER_DEACTIVATED"
check "existing session kicked out" "$(get N2 volunteer/)" 302
rm -f "$W/N3"; token N3 login.jsp
check "deactivated account cannot sign in" "$(post N3 login.jsp --data-urlencode "username=new_$RUN" --data-urlencode "password=MyNewPass123")" 400
token A "admin/event.jsp?id=$EV"
check "deactivated volunteer cannot be registered" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$NID")" 409
has "deactivated message" "$W/body" "deactivated"

echo "== Event cancellation"
check "cancel confirmation page" "$(get A "admin/event-cancel.jsp?id=$EV")" 200
has "confirmation warns" "$W/body" "cannot be undone"
token A "admin/event-cancel.jsp?id=$EV"
check "cancel event" "$(post A admin/event-cancel.jsp -d "id=$EV")" 302
check "event kept as CANCELLED" "$(sql "SELECT status FROM events WHERE id=$EV")" CANCELLED
check "active signups cancelled, history kept" "$(sql "SELECT CONCAT(SUM(status='ACTIVE'), '/', SUM(end_reason='EVENT_CANCELLED'), '/', COUNT(*)) FROM event_registrations WHERE event_id=$EV")" "0/1/3"
token A "admin/event.jsp?id=$EV"
check "registration after cancel refused" "$(post A admin/event.jsp -d "id=$EV" -d action=register -d "volunteerId=$VID")" 409
check "cancelled event cannot be edited" "$(loc A "$B/admin/event-form.jsp?id=$EV")" "$B/admin/event.jsp?id=$EV"
check "cancelling twice changes nothing" "$(post A admin/event-cancel.jsp -d "id=$EV")" 302

echo "== Event delete"
token A admin/event-form.jsp
URL=$(loc A --data-urlencode "csrf=$(cat $W/A.tok)" --data-urlencode "formToken=$(cat $W/A.form)" --data-urlencode "title=Delete me $RUN" --data-urlencode "location=Test Hall" --data-urlencode "startsAt=$(future 12 09:00)" --data-urlencode "endsAt=$(future 12 12:00)" "$B/admin/event-form.jsp")
DEL=$(echo "$URL" | idfrom)
token A "admin/event.jsp?id=$DEL"
has "event page links to delete" "$W/body" "event-delete.jsp?id=$DEL"
check "add a signup to the event being deleted" "$(post A admin/event.jsp -d "id=$DEL" -d action=register -d "volunteerId=$VID")" 302
check "delete confirmation page" "$(get A "admin/event-delete.jsp?id=$DEL")" 200
has "delete page warns" "$W/body" "cannot be undone"
has "delete page counts signups" "$W/body" "all 1 signup records"
token A "admin/event-delete.jsp?id=$DEL"
check "delete refused without the typed title" "$(post A admin/event-delete.jsp -d "id=$DEL" --data-urlencode "confirmTitle=wrong")" 400
check "event still there after refused delete" "$(sql "SELECT COUNT(*) FROM events WHERE id=$DEL")" 1
check "delete with typed title" "$(post A admin/event-delete.jsp -d "id=$DEL" --data-urlencode "confirmTitle=Delete me $RUN")" 302
check "event and its signups removed" "$(sql "SELECT CONCAT((SELECT COUNT(*) FROM events WHERE id=$DEL), '/', (SELECT COUNT(*) FROM event_registrations WHERE event_id=$DEL))")" "0/0"
check "deleted event is 404" "$(get A "admin/event.jsp?id=$DEL")" 404
check "delete page for missing event is 404" "$(get A "admin/event-delete.jsp?id=$DEL")" 404

echo "== Double submit (one-time form token)"
token A admin/event-form.jsp
has "create event form carries a one-time token" "$W/body" 'name="formToken"'
F=$(cat $W/A.form)
EVF=(--data-urlencode "csrf=$(cat $W/A.tok)" --data-urlencode "location=Test Hall"
     --data-urlencode "startsAt=$(future 14 09:00)" --data-urlencode "endsAt=$(future 14 11:00)")
dbl() { curl -s -o /dev/null -w "%{http_code}" -b "$W/A" "${EVF[@]}" --data-urlencode "formToken=$F" \
        --data-urlencode "title=Double $RUN" "$B/admin/event-form.jsp"; }
dbl > "$W/d1" & dbl > "$W/d2" & wait
check "two clicks at the same moment both get a redirect" "$(cat "$W/d1" "$W/d2" | tr -d '\r\n')" "302302"
check "two clicks at the same moment create one event" "$(sql "SELECT COUNT(*) FROM events WHERE title='Double $RUN'")" 1
check "submitting the same form again goes to the event list" "$(loc A "${EVF[@]}" --data-urlencode "formToken=$F" --data-urlencode "title=Double $RUN" "$B/admin/event-form.jsp")" "$B/admin/events.jsp?show=all"
check "still one event after the repeat" "$(sql "SELECT COUNT(*) FROM events WHERE title='Double $RUN'")" 1
get A "admin/events.jsp?show=all" >/dev/null
has "event list explains the repeat was not saved" "$W/body" "already submitted"
check "create without a form token goes to the event list" "$(loc A "${EVF[@]}" --data-urlencode "title=NoToken$RUN" "$B/admin/event-form.jsp")" "$B/admin/events.jsp?show=all"
check "no event created without a token" "$(sql "SELECT COUNT(*) FROM events WHERE title='NoToken$RUN'")" 0
for n in 1 2; do
  token A admin/event-form.jsp
  post A admin/event-form.jsp --data-urlencode "title=Twin $RUN" --data-urlencode "location=Test Hall" --data-urlencode "startsAt=$(future 15 09:00)" --data-urlencode "endsAt=$(future 15 11:00)" >/dev/null
done
check "two separate forms with the same details create two events" "$(sql "SELECT COUNT(*) FROM events WHERE title='Twin $RUN'")" 2
token A admin/volunteer-new.jsp
has "create account form carries a one-time token" "$W/body" 'name="formToken"'
F=$(cat $W/A.form)
acct() { loc A --data-urlencode "csrf=$(cat $W/A.tok)" --data-urlencode "formToken=$F" --data-urlencode "username=dbl_$RUN" \
         --data-urlencode "fullName=Double Click" --data-urlencode "contactNumber=91234567" --data-urlencode "email=dbl$RUN@example.test" "$B/admin/volunteer-new.jsp"; }
acct >/dev/null
check "second click on create account goes to the password page" "$(acct)" "$B/admin/volunteer-new.jsp?created"
get A 'admin/volunteer-new.jsp?created' >/dev/null
has "temporary password still shown after a double click" "$W/body" 'class="secret"'
check "double click creates one account" "$(sql "SELECT COUNT(*) FROM accounts WHERE username='dbl_$RUN'")" 1

echo "== Pages render"
for p in admin/ "admin/events.jsp?show=past" "admin/events.jsp?show=cancelled" "admin/volunteers.jsp?show=all" "admin/volunteer.jsp?id=$VID" "admin/event.jsp?id=$PAST_EV" "admin/event.jsp?id=$CANCELLED_EV"; do
  check "renders $p" "$(get A "$p")" 200
done

echo; echo "RESULT: $PASS passed, $FAIL failed"
rm -rf "$W"
[ $FAIL -eq 0 ]
