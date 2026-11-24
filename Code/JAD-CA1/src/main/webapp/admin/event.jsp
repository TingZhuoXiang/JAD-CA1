<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.time.LocalDateTime,java.util.HashSet,java.util.List,java.util.Set,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    long id = Web.id(request, "id");
    String find = Web.field(request, "find").strip();
    if (find.length() > 100) find = find.substring(0, 100);
    String error = "";
    Events.Event event = null;
    List<Registrations.SignupSummary> roster = List.of();
    List<Volunteers.Volunteer> matches = List.of();
    try {
        if ("POST".equals(request.getMethod())) {
            String action = Web.field(request, "action");
            if ("register".equals(action)) {
                long volunteerId = Web.id(request, "volunteerId");
                String refusal = volunteerId < 0 ? "Choose a volunteer to add."
                        : Registrations.register(id, volunteerId, user.id());
                if (refusal == null) {
                    Web.flash(request, "Volunteer V-" + volunteerId + " added to the roster.");
                    response.sendRedirect("event.jsp?id=" + id);
                    return;
                }
                response.setStatus(409);
                error = refusal;
            } else if ("remove".equals(action)) {
                if (Registrations.removeByAdmin(Web.id(request, "registrationId"), id, user.id())) {
                    Web.flash(request, "Volunteer removed from the roster. Only an admin can add them back.");
                    response.sendRedirect("event.jsp?id=" + id);
                    return;
                }
                response.setStatus(409);
                error = "That signup could not be removed. It may already have ended, or the event has started or been cancelled.";
            } else {
                response.sendError(400);
                return;
            }
        }
        event = Events.find(id);
        if (event == null) {
            response.sendError(404, "That event does not exist.");
            return;
        }
        roster = Registrations.summarize(Registrations.roster(id), Registrations.Signup::volunteerId);
        if (!find.isEmpty()) {
            matches = Volunteers.search(find, Volunteers.Filter.ACTIVE);
        }
    } catch (SQLException e) {
        application.log("Event page failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "This event is temporarily unavailable. Try again shortly.";
    }
    LocalDateTime now = Events.now();
    String csrf = Web.token(request.getSession(false));
    Set<Long> onRoster = new HashSet<>();
    int activeCount = 0;
    for (Registrations.SignupSummary entry : roster) {
        Registrations.Signup signup = entry.signup();
        if (signup.active()) { onRoster.add(signup.volunteerId()); activeCount++; }
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= event == null ? "Event" : Web.html(event.title()) %> | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <p><a href="events.jsp">← Events</a></p>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (event != null) {
           boolean open = event.openForSignup(now);
           String state = event.state(now); %>
    <h1><%= Web.html(event.title()) %></h1>
    <p><span class="badge <%= "Cancelled".equals(state) ? "off" : open ? "ok" : "" %>"><%= state %></span>
        <% if (open) { %><span class="muted"> · Signups open until the event starts</span><% } %></p>
    <dl class="details">
        <dt>Event ID</dt><dd>E-<%= event.id() %></dd>
        <dt>When</dt><dd><%= Web.html(event.when()) %></dd>
        <dt>Location</dt><dd><%= Web.html(event.location()) %></dd>
        <dt>Description</dt><dd><%= event.description().isEmpty() ? "<span class=\"muted\">None</span>" : Web.html(event.description()) %></dd>
        <% if (event.status() == Events.Status.CANCELLED) { %>
        <dt>Cancelled</dt><dd><%= Events.display(event.cancelledAt()) %></dd>
        <% } %>
    </dl>
    <div class="actions">
        <% if (open) { %>
        <a class="button secondary" href="event-form.jsp?id=<%= event.id() %>">Edit details</a>
        <a class="button secondary" href="event-cancel.jsp?id=<%= event.id() %>">Cancel event</a>
        <% } %>
        <a href="event-delete.jsp?id=<%= event.id() %>">Delete event…</a>
    </div>

    <section>
        <h2>Roster <span class="muted">(<%= activeCount %> signed up)</span></h2>
        <% if (open) { %>
        <form class="row" method="get" action="event.jsp" role="search">
            <input type="hidden" name="id" value="<%= event.id() %>">
            <div>
                <label for="find">Add a volunteer: search name, username, email or Volunteer ID</label>
                <input id="find" name="find" maxlength="100" value="<%= Web.html(find) %>">
            </div>
            <button type="submit" class="secondary">Find</button>
        </form>
        <% if (!find.isEmpty()) { %>
            <% if (matches.isEmpty()) { %>
            <p class="muted">No active volunteers match “<%= Web.html(find) %>”.</p>
            <% } else { %>
            <div class="table-wrap"><table>
                <thead><tr><th>Volunteer</th><th>Username</th><th>Email</th><th></th></tr></thead>
                <tbody>
                <% for (Volunteers.Volunteer match : matches) { %>
                <tr>
                    <td><%= Web.html(match.fullName()) %> <span class="muted"><%= match.volunteerId() %></span></td>
                    <td><%= Web.html(match.username()) %></td>
                    <td><%= Web.html(match.email()) %></td>
                    <td><% if (onRoster.contains(match.id())) { %><span class="badge">Already signed up</span><% } else { %>
                        <form class="inline" method="post" action="event.jsp">
                            <input type="hidden" name="csrf" value="<%= csrf %>">
                            <input type="hidden" name="id" value="<%= event.id() %>">
                            <input type="hidden" name="action" value="register">
                            <input type="hidden" name="volunteerId" value="<%= match.id() %>">
                            <button type="submit" class="small">Add to event</button>
                        </form><% } %></td>
                </tr>
                <% } %>
                </tbody>
            </table></div>
            <% } %>
        <% } %>
        <% } else { %>
        <p class="muted">This event is <%= state.toLowerCase() %>, so the roster can no longer change.</p>
        <% } %>

        <% if (roster.isEmpty()) { %>
        <p class="muted">No one has signed up yet.</p>
        <% } else { %>
        <div class="table-wrap"><table>
            <thead><tr><th>Volunteer</th><th>Contact</th><th>Status</th><th>Signed up</th><th></th></tr></thead>
            <tbody>
            <% for (Registrations.SignupSummary entry : roster) {
                Registrations.Signup signup = entry.signup(); %>
            <tr>
                <td><a href="volunteer.jsp?id=<%= signup.volunteerId() %>"><%= Web.html(signup.volunteerName()) %></a>
                    <span class="muted"><%= signup.volunteerCode() %></span>
                    <% if (!signup.volunteerActive()) { %><span class="badge off">Deactivated</span><% } %></td>
                <td><%= Web.html(signup.contactNumber()) %><br><span class="muted"><%= Web.html(signup.email()) %></span></td>
                <td><span class="badge <%= signup.active() ? "ok" : "off" %>"><%= Web.html(signup.statusLabel()) %></span>
                    <% if (entry.previouslyWithdrawn()) { %><span class="badge">Previously withdrawn</span><% } %>
                    <% if (signup.endedAt() != null) { %><br><span class="muted"><%= Events.display(signup.endedAt()) %></span><% } %></td>
                <td><%= Events.display(signup.registeredAt()) %><br><span class="muted"><%= signup.selfRegistered() ? "Self signup" : "Added by Admin" %></span></td>
                <td><% if (signup.endable(now)) { %>
                    <form class="inline" method="post" action="event.jsp">
                        <input type="hidden" name="csrf" value="<%= csrf %>">
                        <input type="hidden" name="id" value="<%= event.id() %>">
                        <input type="hidden" name="action" value="remove">
                        <input type="hidden" name="registrationId" value="<%= signup.id() %>">
                        <button type="submit" class="small secondary">Remove</button>
                    </form><% } %></td>
            </tr>
            <% } %>
            </tbody>
        </table></div>
        <% } %>
    </section>
    <% } %>
</main>
</body>
</html>
