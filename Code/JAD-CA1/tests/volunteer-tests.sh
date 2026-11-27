#!/usr/bin/env bash
# End-to-end Volunteer checks (Git Bash, curl, MySQL). Run against a seeded test database.
# Usage: CNF=path/to/mysql-option-file bash tests/volunteer-tests.sh
# Optional: B (app URL), JAD_TEST_DB (schema), MYSQL_CLIENT (path to MySQL CLI).
# The app and CLI must target the same test schema. This suite leaves its test rows there.
B=${B:-http://localhost:8080/JAD-CA1}
DB=${JAD_TEST_DB:-jad_ca1}
MYSQL_CLIENT=${MYSQL_CLIENT:-/c/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe}
: "${CNF:?Set CNF to a MySQL client option file for the test database.}"
W=$(mktemp -d) || exit 1
trap 'rm -rf -- "$W"' EXIT
PASS=0; FAIL=0
RUN=$(date +%s)_$RANDOM
USERNAME=vol_$RUN
OTHER=other_$RUN
TEST_PASSWORD='C1a!Test'

check() {
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); echo "PASS  $1"
    else FAIL=$((FAIL+1)); echo "FAIL  $1 (expected $3, got $2)"; fi
}
has() { check "$1" "$(grep -Fc -- "$2" "$W/body")" "$3"; }
sql() { "$MYSQL_CLIENT" --defaults-extra-file="$CNF" -N -B "$DB" -e "$1"; }
request() {
    local jar=$1 path=$2; shift 2
    curl -sS --max-time 15 -o "$W/body" -w "%{http_code}" -D "$W/headers" \
        -c "$W/$jar" -b "$W/$jar" "$@" "$B/$path"
}
token() {
    request "$1" "$2" >/dev/null
    sed -n 's/.*name="csrf" value="\([0-9a-f]*\)".*/\1/p' "$W/body" | head -1 > "$W/$1.tok"
    sed -n 's/.*name="formToken" value="\([0-9a-f]*\)".*/\1/p' "$W/body" | head -1 > "$W/$1.form"
}
post() {
    local jar=$1 path=$2 f; shift 2
    f=$(cat "$W/$jar.form" 2>/dev/null)
    request "$jar" "$path" --data-urlencode "csrf=$(cat "$W/$jar.tok")" ${f:+--data-urlencode "formToken=$f"} "$@"
}
redirect() { sed -n 's/^[Ll]ocation: //p' "$W/headers" | tr -d '\r'; }
login() {
    token "$1" login.jsp
    post "$1" login.jsp --data-urlencode "username=$2" --data-urlencode "password=$3"
}
register_volunteer() {
    local password=${3:-$TEST_PASSWORD}
    token public register.jsp
    post public register.jsp --data-urlencode "username=$1" --data-urlencode "fullName=$2" \
        --data-urlencode "contactNumber=91234567" --data-urlencode "email=$1@example.test" \
        --data-urlencode "password=$password" --data-urlencode "confirmation=$password"
}
create_event() {
    local title=$1 day=$2 start=$3 end=$4
    token admin admin/event-form.jsp
    check "Admin creates $title" "$(post admin admin/event-form.jsp --data-urlencode "title=$title" \
        --data-urlencode "location=Phase 3 Test Hall" --data-urlencode "description=Test description" \
        -d "startsAt=${day}T${start}" -d "endsAt=${day}T${end}")" 302
}

event_order() {
    sed -n 's/.*\(<td>\|<h2>\)<a href="event.jsp?id=\([0-9]*\)">.*/\2/p' "$W/body" | paste -sd, -
}

echo "== Test setup and access"
check "signed-out profile redirects to login" "$(request guest volunteer/profile.jsp)" 302
check "Admin login" "$(login admin demo_admin CA1-sample-demo)" 302
check "Admin denied access to Volunteer profile" "$(request admin volunteer/profile.jsp)" 403
check "registration rejects seven characters" "$(register_volunteer "$USERNAME" "Phase 3 Volunteer" 'C1a!Tes')" 400
check "registration requires lowercase" "$(register_volunteer "$USERNAME" "Phase 3 Volunteer" 'C1A!TEST')" 400
check "registration requires uppercase" "$(register_volunteer "$USERNAME" "Phase 3 Volunteer" 'c1a!test')" 400
check "registration requires a digit" "$(register_volunteer "$USERNAME" "Phase 3 Volunteer" 'Caa!Test')" 400
check "registration requires a symbol" "$(register_volunteer "$USERNAME" "Phase 3 Volunteer" 'C1a Test')" 400
check "test Volunteer registered publicly" "$(register_volunteer "$USERNAME" "Phase 3 Volunteer")" 302
check "second Volunteer registered publicly" "$(register_volunteer "$OTHER" "Phase 3 Other")" 302
check "Volunteer login" "$(login vol "$USERNAME" "$TEST_PASSWORD")" 302
check "second Volunteer login" "$(login other "$OTHER" "$TEST_PASSWORD")" 302
VID=$(sql "SELECT id FROM accounts WHERE username='$USERNAME'")
OID=$(sql "SELECT id FROM accounts WHERE username='$OTHER'")
PAST=$(sql "SELECT id FROM events WHERE title='Demo: Toa Payoh void deck screening'")
CANCELLED=$(sql "SELECT id FROM events WHERE title='Demo: Bedok senior centre screening'")
SELF_DAY=$(TZ=Asia/Singapore date -d '+7 days' +%F)
ADMIN_DAY=$(TZ=Asia/Singapore date -d '+8 days' +%F)
create_event "Self signup $RUN" "$SELF_DAY" 09:00 12:00
create_event "Admin signup $RUN" "$ADMIN_DAY" 14:00 16:00
EV=$(sql "SELECT id FROM events WHERE title='Self signup $RUN'")
ADMIN_EV=$(sql "SELECT id FROM events WHERE title='Admin signup $RUN'")
if [[ ! "$VID $OID $PAST $CANCELLED $EV $ADMIN_EV" =~ ^[0-9]+(\ [0-9]+){5}$ ]]; then
    echo "Missing fixture IDs. Check the seed data, app URL and MySQL configuration." >&2
    exit 1
fi

echo "== Profile"
check "Volunteer home renders" "$(request vol volunteer/)" 200
token vol volunteer/profile.jsp
has "profile displays own ID" "V-$VID</dd>" 1
check "invalid phone rejected" "$(post vol volunteer/profile.jsp -d fullName=Test -d contactNumber=12 -d email="$USERNAME@example.test")" 400
check "duplicate email rejected" "$(post vol volunteer/profile.jsp -d fullName=Test -d contactNumber=91234567 -d email="$OTHER@example.test")" 409
check "profile update redirects" "$(post vol volunteer/profile.jsp -d id="$OID" -d role=ADMIN -d username=changed \
    --data-urlencode "fullName=Updated Phase 3 Volunteer" -d contactNumber=92345678 -d email="$USERNAME@example.test")" 302
check "profile save only updates allowed fields of the signed-in user" "$(sql "SELECT CONCAT(full_name, '|', contact_number, '|', role) FROM accounts WHERE username='$USERNAME'")" "Updated Phase 3 Volunteer|92345678|VOLUNTEER"
check "other Volunteer profile unchanged" "$(sql "SELECT full_name FROM accounts WHERE id=$OID")" "Phase 3 Other"
check "updated profile renders" "$(request vol volunteer/profile.jsp)" 200
has "profile success feedback" "Profile saved." 1

echo "== Browse and sign up"
check "events search by location" "$(request vol "volunteer/events.jsp?q=Phase%203%20Test%20Hall")" 200
has "search includes matching event" "Self signup $RUN" 1
has "search excludes unrelated event" "Tampines community screening" 0
check "cancelled event filter renders" "$(request vol "volunteer/events.jsp?show=cancelled")" 200
has "cancelled events are visible in their filter" "Bedok senior centre screening" 1
check "past event filter renders" "$(request vol "volunteer/events.jsp?show=past")" 200
has "past events are visible in their filter" "Toa Payoh void deck screening" 1
check "event time range works without a date" "$(request vol "volunteer/events.jsp?q=$RUN&fromTime=09:00&toTime=09:00")" 200
check "time range includes only the event starting at its inclusive boundary" "$(event_order)" "$EV"
check "event date range works without a time" "$(request vol "volunteer/events.jsp?q=$RUN&fromDate=$ADMIN_DAY&toDate=$ADMIN_DAY")" 200
check "inclusive event date range includes only the event on that date" "$(event_order)" "$ADMIN_EV"
check "event date and time filters combine" "$(request vol "volunteer/events.jsp?q=$RUN&fromDate=$ADMIN_DAY&toTime=12:00")" 200
check "events must satisfy both date and time filters" "$(event_order)" ""
check "latest event start sort renders" "$(request vol "volunteer/events.jsp?q=$RUN&sort=latest")" 200
check "event start sort changes the result order" "$(event_order)" "$ADMIN_EV,$EV"
check "reversed event time range is rejected" "$(request vol "volunteer/events.jsp?fromTime=14:00&toTime=09:00")" 400
check "invalid event date is rejected" "$(request vol "volunteer/events.jsp?fromDate=2026-02-30")" 400
check "missing event returns 404" "$(request vol "volunteer/event.jsp?id=999999999")" 404
token vol "volunteer/event.jsp?id=$EV"
has "detail includes description" "Test description" 1
check "signup requires CSRF" "$(request vol volunteer/event.jsp -d id="$EV")" 403
check "signup redirects" "$(post vol volunteer/event.jsp -d id="$EV" -d volunteerId="$OID" -d actorId="$OID")" 302
check "signup is attributed to the signed-in Volunteer" "$(sql "SELECT CONCAT(volunteer_id, '/', registered_by) FROM event_registrations WHERE event_id=$EV AND status='ACTIVE'")" "$VID/$VID"
check "duplicate signup rejected" "$(post vol volunteer/event.jsp -d id="$EV")" 409
check "cancelled event signup rejected" "$(post vol volunteer/event.jsp -d id="$CANCELLED")" 409
check "started event signup rejected" "$(post vol volunteer/event.jsp -d id="$PAST")" 409
check "Admin sees the self-signup in the roster" "$(request admin "admin/event.jsp?id=$EV")" 200
has "roster includes updated Volunteer name" "Updated Phase 3 Volunteer" 1
has "first signup is shown as signed up in the roster" ">Signed up</span>" 1
token admin "admin/event.jsp?id=$ADMIN_EV"
check "Admin adds Volunteer to another event" "$(post admin admin/event.jsp -d id="$ADMIN_EV" -d action=register -d volunteerId="$VID")" 302
check "My signups loads" "$(request vol volunteer/signups.jsp)" 200
has "self-signup appears in My signups" "Self signup $RUN" 1
has "Admin signup appears in My signups" "Admin signup $RUN" 1
has "Admin signup is labelled" "Added by Admin" 1
check "self signup filter renders" "$(request vol "volunteer/signups.jsp?source=self")" 200
check "self signup filter excludes Admin signups" "$(event_order)" "$EV"
check "Admin source and event date filters combine" "$(request vol "volunteer/signups.jsp?source=admin&fromDate=$ADMIN_DAY&toDate=$ADMIN_DAY")" 200
check "Admin source and matching event date return the Admin signup" "$(event_order)" "$ADMIN_EV"
check "signup date range works without a source" "$(request vol "volunteer/signups.jsp?toDate=$SELF_DAY")" 200
check "signup date range uses the event start date" "$(event_order)" "$EV"
check "earliest event start sort renders on My signups" "$(request vol "volunteer/signups.jsp?sort=earliest")" 200
check "My signups sorts by earliest event start" "$(event_order)" "$EV,$ADMIN_EV"
check "reversed date range is rejected on My signups" "$(request vol "volunteer/signups.jsp?fromDate=$ADMIN_DAY&toDate=$SELF_DAY")" 400
check "other Volunteer signup list loads" "$(request other volunteer/signups.jsp)" 200
has "other Volunteer cannot see the signup" "Self signup $RUN" 0

echo "== Withdraw and rejoin"
REG=$(sql "SELECT id FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID AND status='ACTIVE'")
DEMO_PAST=$(sql "SELECT r.id FROM event_registrations r JOIN accounts a ON a.id=r.volunteer_id WHERE r.event_id=$PAST AND a.username='demo_volunteer'")
if [[ ! "$REG $DEMO_PAST" =~ ^[0-9]+\ [0-9]+$ ]]; then echo "Missing signup fixtures." >&2; exit 1; fi
token other volunteer/signups.jsp
check "other Volunteer cannot open event withdrawal confirmation" "$(request other "volunteer/withdraw.jsp?id=$REG&from=event")" 404
check "other Volunteer cannot withdraw this signup" "$(post other volunteer/withdraw.jsp -d id="$REG")" 404
check "withdrawal confirmation opens" "$(request vol "volunteer/withdraw.jsp?id=$REG")" 200
has "confirmation identifies the event" "Self signup $RUN" 1
has "My signups confirmation cancels back to My signups" '<a href="signups.jsp">Cancel</a>' 1
check "signed-up volunteer can open event details" "$(request vol "volunteer/event.jsp?id=$EV")" 200
has "event details link to the active signup confirmation" "withdraw.jsp?id=$REG&amp;from=event" 1
check "event withdrawal confirmation opens" "$(request vol "volunteer/withdraw.jsp?id=$REG&from=event")" 200
has "event confirmation cancels back to the event" "<a href=\"event.jsp?id=$EV\">Cancel</a>" 1
has "event confirmation preserves its origin on submit" 'name="from" value="event"' 1
check "GET confirmation leaves the signup active" "$(sql "SELECT status FROM event_registrations WHERE id=$REG")" ACTIVE
check "withdrawal requires CSRF" "$(request vol volunteer/withdraw.jsp -d id="$REG")" 403
check "withdrawal from event redirects" "$(post vol volunteer/withdraw.jsp -d id="$REG" -d from=event)" 302
TARGET=$(redirect)
check "event withdrawal redirects back to the event" "${TARGET##*/}" "event.jsp?id=$EV"
check "event details load after withdrawal" "$(request vol "volunteer/event.jsp?id=$EV")" 200
has "event details show the withdrawal confirmation message" "You withdrew from Self signup $RUN." 1
has "event details allow signing up again" '>Sign up</button>' 1
has "event details hide withdrawal after it completes" '>Withdraw</a>' 0
check "withdrawal records reason" "$(sql "SELECT end_reason FROM event_registrations WHERE id=$REG")" WITHDRAWN_BY_VOLUNTEER
check "repeated withdrawal refused" "$(post vol volunteer/withdraw.jsp -d id="$REG")" 409
# Reproduce a demo signup whose recorded signup time is later than the subsequent rejoin.
sql "UPDATE event_registrations SET registered_at = ended_at + INTERVAL 1 DAY WHERE id=$REG" || exit 1
check "My signups loads after withdrawal" "$(request vol volunteer/signups.jsp)" 200
has "current withdrawal is shown" ">Withdrawn</span>" 1
has "first withdrawal has no previous withdrawal badge" ">Previously withdrawn</span>" 0
check "rejoin succeeds" "$(post vol volunteer/event.jsp -d id="$EV")" 302
check "rejoin keeps history and only one active signup" "$(sql "SELECT CONCAT(COUNT(*), '/', SUM(status='ACTIVE')) FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID")" "2/1"
NEW_REG=$(sql "SELECT id FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID AND status='ACTIVE'")
check "My signups loads after rejoining" "$(request vol volunteer/signups.jsp)" 200
has "rejoined event appears once in the signup tables" "<td><a href=\"event.jsp?id=$EV\">" 1
has "old withdrawal is not shown as the current status" ">Withdrawn</span>" 0
has "both active signups show a signed up badge" ">Signed up</span>" 2
has "rejoined event shows a separate previous withdrawal badge" ">Previously withdrawn</span>" 1
has "withdraw link targets the new signup" "withdraw.jsp?id=$NEW_REG\"" 1
check "Admin sees the rejoin in the roster" "$(request admin "admin/event.jsp?id=$EV")" 200
has "rejoined Volunteer has one roster row" "<td><a href=\"volunteer.jsp?id=$VID\">" 1
has "roster shows a signed up badge after rejoining" ">Signed up</span>" 1
has "roster shows a separate previous withdrawal badge" ">Previously withdrawn</span>" 1
has "roster remove targets the new signup" "name=\"registrationId\" value=\"$NEW_REG\"" 1
check "Admin volunteer details load after rejoining" "$(request admin "admin/volunteer.jsp?id=$VID")" 200
has "volunteer details list the rejoined event once" "<td><a href=\"event.jsp?id=$EV\">" 1
has "volunteer details show the previous withdrawal badge" ">Previously withdrawn</span>" 1
has "volunteer details hide the old withdrawal row" ">Withdrawn</span>" 0
check "volunteer can withdraw again" "$(post vol volunteer/withdraw.jsp -d id="$NEW_REG")" 302
TARGET=$(redirect)
check "withdrawal from My signups redirects back to My signups" "${TARGET##*/}" "signups.jsp"
check "My signups loads after withdrawing again" "$(request vol volunteer/signups.jsp)" 200
has "second withdrawal is shown as the current status" ">Withdrawn</span>" 1
has "second withdrawal hides the previous withdrawal badge" ">Previously withdrawn</span>" 0
check "Admin sees the second withdrawal in the roster" "$(request admin "admin/event.jsp?id=$EV")" 200
has "withdrawn Volunteer still has one roster row" "<td><a href=\"volunteer.jsp?id=$VID\">" 1
has "roster shows the current withdrawal" ">Withdrawn</span>" 1
has "roster hides the previous withdrawal badge" ">Previously withdrawn</span>" 0
check "volunteer rejoins before admin removal" "$(post vol volunteer/event.jsp -d id="$EV")" 302

echo "== Admin removal and reinstatement"
REG=$(sql "SELECT id FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID AND status='ACTIVE'")
token admin "admin/event.jsp?id=$EV"
check "Admin removes the volunteer" "$(post admin admin/event.jsp -d id="$EV" -d action=remove -d registrationId="$REG")" 302
check "removed status renders in the roster" "$(request admin "admin/event.jsp?id=$EV")" 200
has "roster shows the admin removal" ">Removed by Admin</span>" 1
has "roster removal has no previous withdrawal badge" ">Previously withdrawn</span>" 0
check "removed status renders in My signups" "$(request vol volunteer/signups.jsp)" 200
has "My signups shows the admin removal" ">Removed by Admin</span>" 1
has "removed signup has no previous withdrawal badge" ">Previously withdrawn</span>" 0
check "Admin volunteer details load after removal" "$(request admin "admin/volunteer.jsp?id=$VID")" 200
has "volunteer details list the removed event once" "<td><a href=\"event.jsp?id=$EV\">" 1
has "volunteer details show the latest admin removal" ">Removed by Admin</span>" 1
has "volunteer details hide earlier withdrawal rows" ">Withdrawn</span>" 0
has "volunteer details hide the previous withdrawal badge after removal" ">Previously withdrawn</span>" 0
check "removed volunteer can open the event details" "$(request vol "volunteer/event.jsp?id=$EV")" 200
has "event details explain how to rejoin" "Only an admin can add you back." 1
has "event details hide the signup button" ">Sign up</button>" 0
check "removed volunteer cannot rejoin by posting directly" "$(post vol volunteer/event.jsp -d id="$EV")" 409
check "refused rejoin leaves the signup history intact" "$(sql "SELECT CONCAT(COUNT(*), '/', SUM(status='ACTIVE'), '/', SUM(end_reason='REMOVED_BY_ADMIN')) FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID")" "3/0/1"
check "Admin can add the removed volunteer back" "$(post admin admin/event.jsp -d id="$EV" -d action=register -d volunteerId="$VID")" 302
REG=$(sql "SELECT id FROM event_registrations WHERE event_id=$EV AND volunteer_id=$VID AND status='ACTIVE'")
check "reinstated volunteer can withdraw" "$(post vol volunteer/withdraw.jsp -d id="$REG")" 302
check "reinstated volunteer can rejoin after withdrawing" "$(post vol volunteer/event.jsp -d id="$EV")" 302

check "demo Volunteer login" "$(login demo demo_volunteer CA1-sample-demo)" 302
token demo volunteer/signups.jsp
check "past signup remains in history" "$(request demo volunteer/signups.jsp)" 200
has "history shows past event" "Toa Payoh void deck screening" 1
check "past signup cannot be withdrawn" "$(post demo volunteer/withdraw.jsp -d id="$DEMO_PAST")" 409
check "past event details load for a signed-up volunteer" "$(request demo "volunteer/event.jsp?id=$PAST")" 200
has "past event details hide withdrawal" '>Withdraw</a>' 0

echo "== Admin cancellation and self-service deactivation"
token admin "admin/event-cancel.jsp?id=$ADMIN_EV"
check "Admin cancels event" "$(post admin admin/event-cancel.jsp -d id="$ADMIN_EV")" 302
check "My signups reflects the cancellation" "$(request vol volunteer/signups.jsp)" 200
has "cancelled registration appears in history" "Event cancelled" 1
sql "INSERT INTO event_registrations (event_id, volunteer_id, registered_by, registered_at) VALUES ($PAST, $VID, $VID, NOW() - INTERVAL 11 DAY)" || exit 1
check "deactivation confirmation opens" "$(request vol volunteer/deactivate.jsp)" 200
has "deactivation warns about future signups" "upcoming signup" 1
check "GET confirmation leaves account active" "$(sql "SELECT active FROM accounts WHERE id=$VID")" 1
check "deactivation requires CSRF" "$(request vol volunteer/deactivate.jsp -d id="$OID")" 403
check "self-deactivation redirects" "$(post vol volunteer/deactivate.jsp -d id="$OID")" 302
check "redirect confirms deactivation" "$(redirect | sed 's|^https\{0,1\}://[^/]*||')" "/${B#*://*/}/login.jsp?notice=deactivated"
check "account is deactivated" "$(sql "SELECT active FROM accounts WHERE id=$VID")" 0
check "other Volunteer remains active" "$(sql "SELECT active FROM accounts WHERE id=$OID")" 1
check "future signup cancelled, past signup kept" "$(sql "SELECT GROUP_CONCAT(CONCAT(event_id,':',COALESCE(end_reason,status)) ORDER BY event_id) FROM event_registrations WHERE volunteer_id=$VID AND (event_id=$PAST OR (event_id=$EV AND status='CANCELLED'))")" "$PAST:ACTIVE,$EV:VOLUNTEER_DEACTIVATED"
check "deactivated session redirects to sign in" "$(request vol volunteer/profile.jsp)" 302
check "deactivated account cannot sign in again" "$(login vol "$USERNAME" "$TEST_PASSWORD")" 400

echo; echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
