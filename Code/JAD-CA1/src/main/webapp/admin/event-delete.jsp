<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    long id = Web.id(request, "id");
    Events.Event event = null;
    int records = 0;
    String error = "";
    try {
        if ("POST".equals(request.getMethod())) {
            // The typed title must match, so a stray click cannot delete an event.
            event = Events.find(id);
            if (event == null) {
                Web.flash(request, "That event no longer exists.");
                response.sendRedirect("events.jsp?show=all");
                return;
            }
            if (!event.title().equals(Web.field(request, "confirmTitle").strip())) {
                response.setStatus(400);
                error = "Type the event title exactly as shown to confirm the delete.";
                records = Events.signupRecords(id);
            } else {
                int removed = Events.delete(id);
                Web.flash(request, "Event “" + event.title() + "” deleted, with " + removed + " signup record"
                        + (removed == 1 ? "" : "s") + ".");
                response.sendRedirect("events.jsp?show=all");
                return;
            }
        } else {
            event = Events.find(id);
            if (event == null) {
                response.sendError(404, "That event does not exist.");
                return;
            }
            records = Events.signupRecords(id);
        }
    } catch (SQLException e) {
        application.log("Event delete failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Events are temporarily unavailable. Nothing was deleted.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Delete event | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <h1>Delete this event permanently?</h1>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (event != null) { %>
    <dl class="details">
        <dt>Event</dt><dd><%= Web.html(event.title()) %> <span class="muted">E-<%= event.id() %></span></dd>
        <dt>When</dt><dd><%= Web.html(event.when()) %></dd>
        <dt>Signup records</dt><dd><%= records %> (including withdrawn and cancelled)</dd>
    </dl>
    <p>Deleting removes the event <strong>and all <%= records %> signup records</strong> from the database.
        <strong>This cannot be undone.</strong>
        <% if (event.openForSignup(Events.now())) { %>To stop new signups but keep the history, <a href="event-cancel.jsp?id=<%= event.id() %>">cancel the event</a> instead.<% } %></p>
    <form method="post" action="event-delete.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
        <input type="hidden" name="id" value="<%= event.id() %>">
        <label for="confirmTitle">Type the event title to confirm</label>
        <input id="confirmTitle" name="confirmTitle" maxlength="120" required autocomplete="off"
               aria-describedby="confirm-hint">
        <small id="confirm-hint" class="muted"><%= Web.html(event.title()) %></small>
        <div class="actions">
            <button type="submit" class="danger">Delete event</button>
            <a href="event.jsp?id=<%= event.id() %>">Keep event</a>
        </div>
    </form>
    <% } %>
</main>
</body>
</html>
