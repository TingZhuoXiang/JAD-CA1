<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    long id = Web.id(request, "id");
    Events.Event event = null;
    String error = "";
    try {
        if ("POST".equals(request.getMethod())) {
            int cancelled = Events.cancel(id, user.id());
            if (cancelled >= 0) {
                Web.flash(request, "Event cancelled. " + cancelled + " active signup"
                        + (cancelled == 1 ? " was" : "s were") + " cancelled and kept in the history.");
                response.sendRedirect("event.jsp?id=" + id);
                return;
            }
            Web.flash(request, "This event was already cancelled or has started, so it was not changed.");
            response.sendRedirect("event.jsp?id=" + id);
            return;
        }
        event = Events.find(id);
        if (event == null) {
            response.sendError(404, "That event does not exist.");
            return;
        }
        if (!event.openForSignup(Events.now())) {
            Web.flash(request, "Only upcoming events that are not cancelled can be cancelled.");
            response.sendRedirect("event.jsp?id=" + id);
            return;
        }
    } catch (SQLException e) {
        application.log("Event cancellation failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Events are temporarily unavailable. Nothing was changed.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Cancel event | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <div class="panel">
        <h1>Cancel this event?</h1>
        <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
        <% if (event != null) { %>
        <dl class="kv">
            <dt>Event</dt><dd><%= Web.html(event.title()) %> <span class="muted">E-<%= event.id() %></span></dd>
            <dt>When</dt><dd><%= Web.html(event.when()) %></dd>
            <dt>Signed up</dt><dd><%= event.activeSignups() %> volunteer<%= event.activeSignups() == 1 ? "" : "s" %></dd>
        </dl>
        <p class="callout danger">Cancelling closes the event to new signups and cancels all <%= event.activeSignups() %> active signups.
            The event and its signup history are kept. <strong>This cannot be undone.</strong></p>
        <div class="form-actions">
            <form method="post" action="event-cancel.jsp">
                <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
                <input type="hidden" name="id" value="<%= event.id() %>">
                <button type="submit" class="danger">Cancel event</button>
            </form>
            <a href="event.jsp?id=<%= event.id() %>">Keep event</a>
        </div>
        <% } %>
    </div>
</main>
</body>
</html>
