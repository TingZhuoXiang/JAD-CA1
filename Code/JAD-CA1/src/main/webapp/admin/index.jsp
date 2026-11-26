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
    <div class="page-head">
        <div>
            <p class="eyebrow">Admin workspace</p>
            <h1>Admin dashboard</h1>
            <p class="lede">Welcome back, <%= Web.html(user.fullName()) %>. Here is what is coming up.</p>
        </div>
        <div class="actions">
            <a class="button secondary" href="volunteer-new.jsp">Create volunteer account</a>
            <a class="button" href="event-form.jsp">Create event</a>
        </div>
    </div>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (counts != null) { %>
    <div class="stats">
        <a class="stat" href="events.jsp"><span class="num"><%= counts.get("upcoming") %></span><span class="label">Upcoming events</span></a>
        <a class="stat" href="volunteers.jsp"><span class="num"><%= counts.get("volunteers") %></span><span class="label">Active volunteers</span></a>
        <a class="stat" href="events.jsp"><span class="num"><%= counts.get("signups") %></span><span class="label">Signups for upcoming events</span></a>
    </div>
    <% } %>

    <section>
        <div class="section-head"><h2>Next events</h2><% if (!upcoming.isEmpty()) { %><a href="events.jsp">All events &rarr;</a><% } %></div>
        <% if (upcoming.isEmpty() && error.isEmpty()) { %>
        <p class="empty">No upcoming events. <a href="event-form.jsp">Create one</a>.</p>
        <% } else if (!upcoming.isEmpty()) { %>
        <div class="table-wrap"><table>
            <thead><tr><th>Event</th><th>When</th><th>Location</th><th>Signed up</th></tr></thead>
            <tbody>
            <% for (Events.Event event : upcoming.subList(0, Math.min(5, upcoming.size()))) { %>
            <tr>
                <td><div class="event-cell"><span class="date-tile" aria-hidden="true"><b><%= event.startsAt().getDayOfMonth() %></b><small><%= java.time.format.DateTimeFormatter.ofPattern("MMM", java.util.Locale.ENGLISH).format(event.startsAt()) %></small></span>
                    <a href="event.jsp?id=<%= event.id() %>"><%= Web.html(event.title()) %></a></div></td>
                <td><%= Web.html(event.when()) %></td>
                <td><%= Web.html(event.location()) %></td>
                <td class="num"><%= event.activeSignups() %></td>
            </tr>
            <% } %>
            </tbody>
        </table></div>
        <% } %>
    </section>
</main>
</body>
</html>
