<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "profile";
    Volunteers.Volunteer profile = null;
    String error = "";
    try {
        if ("POST".equals(request.getMethod())) {
            Volunteers.deactivate(user.id(), user.id());
            request.getSession(false).invalidate();
            response.sendRedirect(request.getContextPath() + "/login.jsp?notice=deactivated");
            return;
        }
        profile = Volunteers.find(user.id());
        if (profile == null || !profile.active()) {
            response.sendError(403, "This account is unavailable.");
            return;
        }
    } catch (SQLException e) {
        application.log("Self-service deactivation failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Account deactivation is temporarily unavailable.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Deactivate account | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <h1>Deactivate your account?</h1>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (profile != null) { %>
    <p>You'll be signed out and unable to sign in. This cancels your <%= profile.upcomingSignups() %>
        upcoming signup<%= profile.upcomingSignups() == 1 ? "" : "s" %> and keeps your past signup history.
        <strong>Reactivation is unavailable.</strong></p>
    <div class="actions">
        <form method="post" action="deactivate.jsp">
            <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
            <button type="submit" class="danger">Deactivate my account</button>
        </form>
        <a href="profile.jsp">Keep my account active</a>
    </div>
    <% } else { %><p><a href="profile.jsp">Back to my profile</a></p><% } %>
</main>
</body>
</html>
