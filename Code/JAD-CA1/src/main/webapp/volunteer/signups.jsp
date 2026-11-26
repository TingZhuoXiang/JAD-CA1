<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.time.LocalDateTime,java.util.ArrayList,java.util.Comparator,java.util.List,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "signups";
    String fromDate = Web.field(request, "fromDate");
    String toDate = Web.field(request, "toDate");
    String source = Web.field(request, "source");
    if (!"self".equals(source) && !"admin".equals(source)) {
        source = "";
    }
    String sort = Web.field(request, "sort");
    Comparator<Registrations.Signup> order = null;
    if ("earliest".equals(sort)) {
        order = Comparator.comparing(Registrations.Signup::startsAt);
    } else if ("signed-up-latest".equals(sort)) {
        order = Comparator.comparing(Registrations.Signup::registeredAt).reversed();
    } else if ("signed-up-earliest".equals(sort)) {
        order = Comparator.comparing(Registrations.Signup::registeredAt);
    }
    boolean filtered = !source.isEmpty() || !fromDate.isEmpty() || !toDate.isEmpty();
    LocalDateTime now = Events.now();
    List<Registrations.SignupSummary> upcoming = new ArrayList<>();
    List<Registrations.SignupSummary> history = new ArrayList<>();
    String error = "";
    try {
        Events.StartDateRange dates = Events.StartDateRange.parse(fromDate, toDate);
        for (Registrations.SignupSummary entry : Registrations.summarize(
                Registrations.forVolunteer(user.id()), Registrations.Signup::eventId)) {
            Registrations.Signup signup = entry.signup();
            if (!dates.includes(signup.startsAt().toLocalDate())
                    || ("self".equals(source) && !signup.selfRegistered())
                    || ("admin".equals(source) && signup.selfRegistered())) {
                continue;
            }
            if (signup.endable(now)) {
                upcoming.add(entry);
            } else {
                history.add(entry);
            }
        }
        if (order != null) {
            Comparator<Registrations.SignupSummary> bySignup = Comparator.comparing(Registrations.SignupSummary::signup, order);
            upcoming.sort(bySignup);
            history.sort(bySignup);
        }
    } catch (IllegalArgumentException e) {
        response.setStatus(400);
        error = e.getMessage();
    } catch (SQLException e) {
        application.log("Volunteer signups failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Your signups are temporarily unavailable.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>My signups | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
    <script src="../list-filters.js" defer></script>
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <div class="page-head">
        <div>
            <p class="eyebrow">Volunteer portal</p>
            <h1>My signups</h1>
            <p class="lede">Your upcoming events and history, including signups added or ended by an Admin.</p>
        </div>
        <div class="actions"><a class="button" href="events.jsp">Browse events</a></div>
    </div>
    <form class="list-filters" method="get" action="signups.jsp" aria-label="Filter my signups">
        <div class="filter-fields">
            <div>
                <label for="sort">Sort by</label>
                <select id="sort" name="sort">
                    <option value="">Event start (latest first)</option>
                    <option value="earliest" <%= "earliest".equals(sort) ? "selected" : "" %>>Event start (earliest first)</option>
                    <option value="signed-up-latest" <%= "signed-up-latest".equals(sort) ? "selected" : "" %>>Signup date (latest first)</option>
                    <option value="signed-up-earliest" <%= "signed-up-earliest".equals(sort) ? "selected" : "" %>>Signup date (earliest first)</option>
                </select>
            </div>
        </div>
        <details <%= filtered ? "open" : "" %>>
            <summary>Advanced filters</summary>
            <p class="muted">Dates refer to the event start in Singapore time.</p>
            <div class="filter-fields">
                <div>
                    <label for="source">Signup source</label>
                    <select id="source" name="source">
                        <option value="">All signups</option>
                        <option value="self" <%= "self".equals(source) ? "selected" : "" %>>Self signup</option>
                        <option value="admin" <%= "admin".equals(source) ? "selected" : "" %>>Admin signup</option>
                    </select>
                </div>
                <%@ include file="/WEB-INF/jspf/event-date-filter.jspf" %>
            </div>
        </details>
        <div class="actions">
            <a href="signups.jsp">Reset filters</a>
        </div>
    </form>
    <div id="filter-results" aria-live="polite">
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (error.isEmpty()) {
           for (boolean isUpcoming : new boolean[] {true, false}) {
               List<Registrations.SignupSummary> signups = isUpcoming ? upcoming : history; %>
    <section>
        <div class="section-head"><h2><%= isUpcoming ? "Upcoming" : "History" %></h2></div>
        <% if (signups.isEmpty()) { %>
        <p class="empty"><%= filtered ? "No signups match these filters." : isUpcoming ? "No upcoming signups." : "No signup history yet." %></p>
        <% } else { %>
        <div class="table-wrap"><table>
            <thead><tr><th>Event</th><th>Starts (Singapore time)</th><th>Status</th><th>Signed up</th><% if (isUpcoming) { %><th>Action</th><% } %></tr></thead>
            <tbody>
            <% for (Registrations.SignupSummary entry : signups) {
                Registrations.Signup signup = entry.signup(); %>
            <tr>
                <td><a href="event.jsp?id=<%= signup.eventId() %>"><%= Web.html(signup.eventTitle()) %></a></td>
                <td><%= Events.display(signup.startsAt()) %></td>
                <td><span class="badge <%= isUpcoming ? "ok" : signup.active() ? "" : "off" %>"><%= Web.html(signup.statusLabel()) %></span>
                    <% if (entry.previouslyWithdrawn()) { %><span class="badge">Previously withdrawn</span><% } %>
                    <% if (signup.endedAt() != null) { %><span class="sub"><%= Events.display(signup.endedAt()) %></span><% } %></td>
                <td><%= Events.display(signup.registeredAt()) %><span class="sub"><%= signup.selfRegistered() ? "Self signup" : "Added by Admin" %></span></td>
                <% if (isUpcoming) { %><td><a href="withdraw.jsp?id=<%= signup.id() %>" class="button small danger-outline">Withdraw</a></td><% } %>
            </tr>
            <% } %>
            </tbody>
        </table></div>
        <% } %>
    </section>
    <%     }
       } %>
    </div>
</main>
</body>
</html>
