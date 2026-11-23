<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.List,java.util.Map,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "dashboard";
    Map<String, Integer> counts = null;
    List<Events.Event> upcoming = List.of();
    String error = "";
    try {
        counts = Events.dashboardCounts();
        upcoming = Events.search("", Events.Filter.UPCOMING);
    } catch (SQLException e) {
        application.log("Admin dashboard failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "The dashboard is temporarily unavailable.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <h1>Admin dashboard</h1>
    <p>Signed in as <strong><%= Web.html(user.fullName()) %></strong> · Admin</p>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (counts != null) { %>
    <div class="stats">
        <a href="events.jsp"><strong><%= counts.get("upcoming") %></strong>Upcoming events</a>
        <a href="volunteers.jsp"><strong><%= counts.get("volunteers") %></strong>Active volunteers</a>
        <a href="events.jsp"><strong><%= counts.get("signups") %></strong>Signups for upcoming events</a>
    </div>
    <% } %>
    <div class="actions">
        <a class="button" href="event-form.jsp">Create event</a>
        <a class="button secondary" href="volunteer-new.jsp">Create volunteer account</a>
    </div>

    <section>
        <h2>Next events</h2>
        <% if (upcoming.isEmpty() && error.isEmpty()) { %>
        <p class="muted">No upcoming events. <a href="event-form.jsp">Create one</a>.</p>
        <% } else if (!upcoming.isEmpty()) { %>
        <div class="table-wrap"><table>
            <thead><tr><th>Event</th><th>When</th><th>Location</th><th>Signed up</th></tr></thead>
            <tbody>
            <% for (Events.Event event : upcoming.subList(0, Math.min(5, upcoming.size()))) { %>
            <tr>
                <td><a href="event.jsp?id=<%= event.id() %>"><%= Web.html(event.title()) %></a></td>
                <td><%= Web.html(event.when()) %></td>
                <td><%= Web.html(event.location()) %></td>
                <td><%= event.activeSignups() %></td>
            </tr>
            <% } %>
            </tbody>
        </table></div>
        <p><a href="events.jsp">All events</a></p>
        <% } %>
    </section>
</main>
</body>
</html>
