<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "signups";
    long id = Web.id(request, "id");
    Registrations.Signup signup = null;
    String error = "";
    try {
        signup = Registrations.findForVolunteer(id, user.id());
        if (signup == null) {
            response.sendError(404, "That signup does not exist.");
            return;
        }
        if ("POST".equals(request.getMethod())) {
            if (Registrations.withdrawByVolunteer(id, user.id())) {
                Web.flash(request, "You withdrew from " + signup.eventTitle() + ".");
                response.sendRedirect("signups.jsp");
                return;
            }
            response.setStatus(409);
            error = "This signup can no longer be withdrawn.";
        } else if (!signup.endable(Events.now())) {
            response.setStatus(409);
            error = "This signup can no longer be withdrawn.";
        }
    } catch (SQLException e) {
        application.log("Volunteer withdrawal failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Withdrawal is temporarily unavailable.";
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Withdraw signup | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <h1>Withdraw from this event?</h1>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (signup != null && error.isEmpty()) { %>
    <dl class="details">
        <dt>Event</dt><dd><%= Web.html(signup.eventTitle()) %></dd>
        <dt>Starts</dt><dd><%= Events.display(signup.startsAt()) %> (Singapore time)</dd>
    </dl>
    <p>You can sign up again before the event starts if it is still open.</p>
    <div class="actions">
        <form method="post" action="withdraw.jsp">
            <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
            <input type="hidden" name="id" value="<%= signup.id() %>">
            <button type="submit" class="danger">Confirm withdrawal</button>
        </form>
        <a href="signups.jsp">Cancel</a>
    </div>
    <% } else { %><p><a href="signups.jsp">Back to my signups</a></p><% } %>
</main>
</body>
</html>
