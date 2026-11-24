<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.Map,sg.edu.sp.jad.Accounts,sg.edu.sp.jad.Web" %>
<%
    // Reached by any signed-in account. AccessFilter sends accounts created with a temporary
    // password here until they replace it.
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    Map<String, String> errors = Map.of();
    String error = "";
    if ("POST".equals(request.getMethod())) {
        String current = Web.field(request, "current");
        String password = Web.field(request, "password");
        errors = Accounts.validatePassword(password, Web.field(request, "confirmation"));
        if (errors.isEmpty() && password.equals(current)) {
            errors = Map.of("password", "Choose a password different from your current one.");
        }
        if (errors.isEmpty()) {
            try {
                if (Accounts.changePassword(user.id(), current, password)) {
                    // A new session id after a credential change; the account now has full access.
                    Accounts.User refreshed = Accounts.findActive(user.id());
                    if (refreshed == null) {
                        response.sendRedirect(request.getContextPath() + "/login.jsp?notice=signin");
                        return;
                    }
                    Web.signIn(request, refreshed);
                    response.sendRedirect(request.getContextPath() + Web.home(refreshed.role()));
                    return;
                }
                response.setStatus(400);
                errors = Map.of("current", "Your current password is incorrect.");
                error = "Check the fields below and try again.";
            } catch (SQLException e) {
                application.log("Password change failed. SQL state: " + e.getSQLState());
                response.setStatus(503);
                error = "Password changes are temporarily unavailable.";
            }
        } else {
            response.setStatus(400);
            error = "Check the fields below and try again.";
        }
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Change password | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main>
    <a href="../">Vision Screening</a>
    <h1><%= user.mustChangePassword() ? "Choose a new password" : "Change password" %></h1>
    <% if (user.mustChangePassword()) { %>
    <p role="status">Signed in as <strong><%= Web.html(user.fullName()) %></strong>. Your account was set up with a
        temporary password. Choose your own password to continue.</p>
    <% } %>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <form method="post" action="change-password.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
        <label for="current"><%= user.mustChangePassword() ? "Temporary password" : "Current password" %></label>
        <input id="current" name="current" type="password" autocomplete="current-password" maxlength="128" required aria-describedby="current-error">
        <small id="current-error" class="error"><%= errors.getOrDefault("current", "") %></small>
        <label for="password">New password</label>
        <input id="password" name="password" type="password" autocomplete="new-password"
               minlength="<%= Accounts.MIN_PASSWORD_LENGTH %>" maxlength="128" required aria-describedby="password-hint">
        <small id="password-hint"><%= errors.getOrDefault("password", "Use at least " + Accounts.MIN_PASSWORD_LENGTH + " characters.") %></small>
        <label for="confirmation">Confirm new password</label>
        <input id="confirmation" name="confirmation" type="password" autocomplete="new-password" maxlength="128" required aria-describedby="confirmation-error">
        <small id="confirmation-error" class="error"><%= errors.getOrDefault("confirmation", "") %></small>
        <button type="submit">Save password</button>
    </form>
    <form method="post" action="../logout.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
        <button type="submit" class="link">Sign out instead</button>
    </form>
</main>
</body>
</html>
