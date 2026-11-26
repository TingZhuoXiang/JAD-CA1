<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "volunteers";
    long id = Web.id(request, "id");
    Volunteers.Volunteer volunteer = null;
    String error = "";
    try {
        if ("POST".equals(request.getMethod())) {
            int cancelled = Volunteers.deactivate(id, user.id());
            Web.flash(request, cancelled < 0 ? "This account was already deactivated, so nothing changed."
                    : "Account deactivated. They can no longer sign in, and " + cancelled + " upcoming signup"
                      + (cancelled == 1 ? " was" : "s were") + " cancelled.");
            response.sendRedirect("volunteer.jsp?id=" + id);
            return;
        }
        volunteer = Volunteers.find(id);
        if (volunteer == null) {
            response.sendError(404, "That volunteer does not exist.");
            return;
        }
        if (!volunteer.active()) {
            Web.flash(request, "This account is already deactivated.");
            response.sendRedirect("volunteer.jsp?id=" + id);
            return;
        }
    } catch (SQLException e) {
        application.log("Volunteer deactivation failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Volunteers are temporarily unavailable. Nothing was changed.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Deactivate volunteer | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <div class="panel">
        <h1>Deactivate this volunteer?</h1>
        <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
        <% if (volunteer != null) { %>
        <dl class="kv">
            <dt>Volunteer</dt><dd><%= Web.html(volunteer.fullName()) %> <span class="muted"><%= volunteer.volunteerId() %></span></dd>
            <dt>Username</dt><dd><%= Web.html(volunteer.username()) %></dd>
            <dt>Upcoming signups</dt><dd><%= volunteer.upcomingSignups() %></dd>
        </dl>
        <p class="callout danger">They will be signed out and unable to sign in. Their <%= volunteer.upcomingSignups() %> upcoming signups will be
            cancelled. Past signups and their details are kept. <strong>Reactivation is not available.</strong></p>
        <div class="form-actions">
            <form method="post" action="volunteer-deactivate.jsp">
                <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
                <input type="hidden" name="id" value="<%= volunteer.id() %>">
                <button type="submit" class="danger">Deactivate account</button>
            </form>
            <a href="volunteer.jsp?id=<%= volunteer.id() %>">Keep active</a>
        </div>
        <% } %>
    </div>
</main>
</body>
</html>
