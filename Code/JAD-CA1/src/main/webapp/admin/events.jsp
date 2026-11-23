<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.time.LocalDateTime,java.util.List,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    String q = Web.field(request, "q").strip();
    if (q.length() > 100) q = q.substring(0, 100);
    Events.Filter filter = Events.Filter.UPCOMING;
    for (Events.Filter option : Events.Filter.values()) {
        if (option.name().equalsIgnoreCase(Web.field(request, "show"))) filter = option;
    }
    List<Events.Event> events = List.of();
    String error = "";
    try {
        events = Events.search(q, filter);
    } catch (SQLException e) {
        application.log("Event search failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Events are temporarily unavailable.";
    }
    LocalDateTime now = Events.now();
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Events | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <h1>Events</h1>
    <div class="actions"><a class="button" href="event-form.jsp">Create event</a></div>

    <form class="row" method="get" action="events.jsp" role="search">
        <div>
            <label for="q">Search title or location</label>
            <input id="q" name="q" maxlength="100" value="<%= Web.html(q) %>">
        </div>
        <div>
            <label for="show">Show</label>
            <select id="show" name="show">
                <% for (Events.Filter option : Events.Filter.values()) { %>
                <option value="<%= option.name().toLowerCase() %>" <%= option == filter ? "selected" : "" %>>
                    <%= option.name().charAt(0) + option.name().substring(1).toLowerCase() %></option>
                <% } %>
            </select>
        </div>
        <button type="submit">Search</button>
    </form>

    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (events.isEmpty() && error.isEmpty()) { %>
    <p class="muted">No events match. <% if (!q.isEmpty() || filter != Events.Filter.ALL) { %><a href="events.jsp?show=all">Show all events</a>.<% } %></p>
    <% } else if (!events.isEmpty()) { %>
    <div class="table-wrap"><table>
        <thead><tr><th>Event</th><th>When</th><th>Location</th><th>Status</th><th>Signed up</th></tr></thead>
        <tbody>
        <% for (Events.Event event : events) {
               String state = event.state(now);
               String badge = "Cancelled".equals(state) ? "off" : "Upcoming".equals(state) ? "ok" : ""; %>
        <tr>
            <td><a href="event.jsp?id=<%= event.id() %>"><%= Web.html(event.title()) %></a></td>
            <td><%= Web.html(event.when()) %></td>
            <td><%= Web.html(event.location()) %></td>
            <td><span class="badge <%= badge %>"><%= state %></span></td>
            <td><%= event.activeSignups() %></td>
        </tr>
        <% } %>
        </tbody>
    </table></div>
    <p class="muted"><%= events.size() %> event<%= events.size() == 1 ? "" : "s" %><%= events.size() == 200 ? " (showing the first 200; refine the search)" : "" %></p>
    <% } %>
</main>
</body>
</html>
