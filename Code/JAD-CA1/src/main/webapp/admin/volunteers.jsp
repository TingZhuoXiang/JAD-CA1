<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.List,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "volunteers";
    String q = Web.field(request, "q").strip();
    if (q.length() > 100) q = q.substring(0, 100);
    Volunteers.Filter filter = Volunteers.Filter.ACTIVE;
    for (Volunteers.Filter option : Volunteers.Filter.values()) {
        if (option.name().equalsIgnoreCase(Web.field(request, "show"))) filter = option;
    }
    List<Volunteers.Volunteer> volunteers = List.of();
    String error = "";
    try {
        volunteers = Volunteers.search(q, filter);
    } catch (SQLException e) {
        application.log("Volunteer search failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Volunteers are temporarily unavailable.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Volunteers | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <div class="page-head">
        <div>
            <p class="eyebrow">Admin workspace</p>
            <h1>Volunteers</h1>
            <p class="lede">Manage participant accounts and see their event signups.</p>
        </div>
        <div class="actions"><a class="button" href="volunteer-new.jsp">Create volunteer account</a></div>
    </div>

    <form class="toolbar" method="get" action="volunteers.jsp" role="search">
        <div>
            <label for="q">Search name, username, email, phone or Volunteer ID</label>
            <input id="q" name="q" maxlength="100" value="<%= Web.html(q) %>" placeholder="e.g. Tan or V-12">
        </div>
        <div>
            <label for="show">Show</label>
            <select id="show" name="show">
                <% for (Volunteers.Filter option : Volunteers.Filter.values()) { %>
                <option value="<%= option.name().toLowerCase() %>" <%= option == filter ? "selected" : "" %>>
                    <%= option.name().charAt(0) + option.name().substring(1).toLowerCase() %></option>
                <% } %>
            </select>
        </div>
        <button type="submit">Search</button>
    </form>

    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (volunteers.isEmpty() && error.isEmpty()) { %>
    <p class="empty">No volunteers match.</p>
    <% } else if (!volunteers.isEmpty()) { %>
    <div class="table-wrap"><table>
        <thead><tr><th>Volunteer ID</th><th>Name</th><th>Username</th><th>Contact</th><th>Status</th><th>Upcoming signups</th></tr></thead>
        <tbody>
        <% for (Volunteers.Volunteer volunteer : volunteers) { %>
        <tr>
            <td><a href="volunteer.jsp?id=<%= volunteer.id() %>"><%= volunteer.volunteerId() %></a></td>
            <td><a href="volunteer.jsp?id=<%= volunteer.id() %>"><%= Web.html(volunteer.fullName()) %></a></td>
            <td><%= Web.html(volunteer.username()) %></td>
            <td><%= Web.html(volunteer.contactNumber()) %><span class="sub"><%= Web.html(volunteer.email()) %></span></td>
            <td><% if (!volunteer.active()) { %><span class="badge off">Deactivated</span><% } else if (volunteer.mustChangePassword()) { %><span class="badge warn">Awaiting first sign-in</span><% } else { %><span class="badge ok">Active</span><% } %></td>
            <td class="num"><%= volunteer.upcomingSignups() %></td>
        </tr>
        <% } %>
        </tbody>
    </table></div>
    <p class="table-foot"><%= volunteers.size() %> volunteer<%= volunteers.size() == 1 ? "" : "s" %><%= volunteers.size() == 200 ? " (showing the first 200; refine the search)" : "" %></p>
    <% } %>
</main>
</body>
</html>
