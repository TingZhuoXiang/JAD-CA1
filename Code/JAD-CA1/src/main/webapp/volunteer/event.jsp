<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.time.LocalDateTime,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    long id = Web.id(request, "id");
    Events.Event event = null;
    Registrations.Signup latestSignup = null;
    String error = "";
    try {
        event = Events.find(id);
        if (event == null) {
            response.sendError(404, "That event does not exist.");
            return;
        }
        if ("POST".equals(request.getMethod())) {
            String refusal = Registrations.register(id, user.id(), user.id());
            if (refusal == null) {
                Web.flash(request, "You signed up for " + event.title() + ".");
                response.sendRedirect("signups.jsp");
                return;
            }
            response.setStatus(409);
            error = refusal;
            event = Events.find(id);
        }
        latestSignup = Registrations.latestForEvent(id, user.id());
    } catch (SQLException e) {
        application.log("Volunteer event page failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "This event is temporarily unavailable.";
    }
    LocalDateTime now = Events.now();
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Event details | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <p><a href="events.jsp">Back to events</a></p>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (event != null) { %>
    <h1><%= Web.html(event.title()) %></h1>
    <p><span class="badge <%= event.openForSignup(now) ? "ok" : event.status() == Events.Status.CANCELLED ? "off" : "" %>"><%= event.state(now) %></span></p>
    <dl class="details">
        <dt>When</dt><dd><%= Web.html(event.when()) %> (Singapore time)</dd>
        <dt>Location</dt><dd><%= Web.html(event.location()) %></dd>
    </dl>
    <% if (!event.description().isBlank()) { %><p><%= Web.html(event.description()).replace("\n", "<br>") %></p><% } %>
    <% if (latestSignup != null && latestSignup.active()) { %>
    <p>You are signed up. <a href="signups.jsp">View my signups</a>.</p>
    <% if (latestSignup.endable(now)) { %>
    <p><a class="button secondary" href="withdraw.jsp?id=<%= latestSignup.id() %>&amp;from=event">Withdraw</a></p>
    <% } %>
    <% } else if (latestSignup != null && "REMOVED_BY_ADMIN".equals(latestSignup.endReason())) { %>
    <% if (error.isEmpty()) { %><p>An admin removed you from this event. Only an admin can add you back.</p><% } %>
    <% } else if (event.openForSignup(now) && response.getStatus() != 503) { %>
    <form method="post" action="event.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
        <input type="hidden" name="id" value="<%= event.id() %>">
        <button type="submit">Sign up</button>
    </form>
    <% } else if (!event.openForSignup(now)) { %><p>Signups are closed for this event.</p><% } %>
    <% } %>
</main>
</body>
</html>
