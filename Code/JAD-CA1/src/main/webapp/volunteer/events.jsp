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
    String fromDate = Web.field(request, "fromDate");
    String toDate = Web.field(request, "toDate");
    String fromTime = Web.field(request, "fromTime");
    String toTime = Web.field(request, "toTime");
    boolean advanced = !fromDate.isEmpty() || !toDate.isEmpty() || !fromTime.isEmpty() || !toTime.isEmpty();
    String sort = Web.field(request, "sort");
    Events.StartOrder order = Events.StartOrder.DEFAULT;
    if ("earliest".equals(sort)) {
        order = Events.StartOrder.EARLIEST;
    } else if ("latest".equals(sort)) {
        order = Events.StartOrder.LATEST;
    }
    List<Events.Event> events = List.of();
    String error = "";
    try {
        Events.StartDateRange dates = Events.StartDateRange.parse(fromDate, toDate);
        Events.StartTimeRange times = Events.StartTimeRange.parse(fromTime, toTime);
        events = Events.search(q, filter, dates, times, order);
    } catch (IllegalArgumentException e) {
        response.setStatus(400);
        error = e.getMessage();
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
    <title>Events | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
    <script src="list-filters.js" defer></script>
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <h1>Events</h1>

    <form class="list-filters" method="get" action="events.jsp" role="search">
        <div class="filter-fields">
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
            <div>
                <label for="sort">Sort by</label>
                <select id="sort" name="sort">
                    <option value="">Default order</option>
                    <option value="earliest" <%= order == Events.StartOrder.EARLIEST ? "selected" : "" %>>Event start (earliest first)</option>
                    <option value="latest" <%= order == Events.StartOrder.LATEST ? "selected" : "" %>>Event start (latest first)</option>
                </select>
            </div>
        </div>
        <details <%= advanced ? "open" : "" %>>
            <summary>Advanced filters</summary>
            <p class="muted">Filter by event start in Singapore time. Leave either end of a range blank for an open-ended range.</p>
            <div class="filter-fields">
                <%@ include file="/WEB-INF/jspf/event-date-filter.jspf" %>
                <div>
                    <label for="fromTime">Start time (from)</label>
                    <input id="fromTime" name="fromTime" type="time" value="<%= Web.html(fromTime) %>">
                </div>
                <div>
                    <label for="toTime">Start time (to)</label>
                    <input id="toTime" name="toTime" type="time" value="<%= Web.html(toTime) %>">
                </div>
            </div>
        </details>
        <div class="actions">
            <a href="events.jsp">Reset filters</a>
        </div>
    </form>

    <div id="filter-results" aria-live="polite">
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (events.isEmpty() && error.isEmpty()) { %>
    <p class="muted">No events match. <% if (!q.isEmpty() || filter != Events.Filter.ALL || advanced) { %><a href="events.jsp?show=all">Show all events</a>.<% } %></p>
    <% } else if (!events.isEmpty()) { %>
    <div class="table-wrap"><table>
        <thead><tr><th>Event</th><th>When</th><th>Location</th><th>Status</th></tr></thead>
        <tbody>
        <% for (Events.Event event : events) {
               String state = event.state(now);
               String badge = "Cancelled".equals(state) ? "off" : "Upcoming".equals(state) ? "ok" : ""; %>
        <tr>
            <td><a href="event.jsp?id=<%= event.id() %>"><%= Web.html(event.title()) %></a></td>
            <td><%= Web.html(event.when()) %></td>
            <td><%= Web.html(event.location()) %></td>
            <td><span class="badge <%= badge %>"><%= state %></span></td>
        </tr>
        <% } %>
        </tbody>
    </table></div>
    <p class="muted"><%= events.size() %> event<%= events.size() == 1 ? "" : "s" %><%= events.size() == 200 ? " (showing the first 200; refine the search)" : "" %></p>
    <% } %>
    </div>
</main>
</body>
</html>
