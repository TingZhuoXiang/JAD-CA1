<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.Map,sg.edu.sp.jad.Accounts,sg.edu.sp.jad.Web" %>
<%
    String username = "", fullName = "", contactNumber = "", email = "", error = "";
    Map<String, String> errors = Map.of();
    if ("POST".equals(request.getMethod())) {
        username = Web.field(request, "username").strip();
        fullName = Web.field(request, "fullName").strip();
        contactNumber = Web.field(request, "contactNumber").strip();
        email = Web.field(request, "email").strip();
        String password = Web.field(request, "password");
        errors = Accounts.validateRegistration(username, fullName, contactNumber, email, password,
                Web.field(request, "confirmation"));
        if (errors.isEmpty()) {
            try {
                Accounts.registerVolunteer(username, fullName, contactNumber, email, password);
                response.sendRedirect("login.jsp?notice=registered");
                return;
            } catch (SQLException e) {
                if (e.getErrorCode() == 1062) {
                    response.setStatus(409);
                    error = "The username or email is already in use.";
                } else {
                    application.log("Registration failed. SQL state: " + e.getSQLState());
                    response.setStatus(503);
                    error = "Registration is temporarily unavailable.";
                }
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
    <title>Create account | Vision Screening</title>
    <link rel="stylesheet" href="site.css">
</head>
<body>
<% String navCurrent = "register"; %>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/public-header.jspf" %>
    <div class="panel">
        <h1>Create a volunteer account</h1>
        <p class="meta">All fields are required. Admin accounts are set up by the team.</p>
        <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
        <form method="post" action="register.jsp">
            <input type="hidden" name="csrf" value="<%= Web.token(request.getSession()) %>">
            <div class="form-grid">
                <div class="field full">
                    <label for="username">Username</label>
                    <input id="username" name="username" autocomplete="username" maxlength="32" required
                           value="<%= Web.html(username) %>" aria-describedby="username-hint">
                    <small id="username-hint" class="hint"><%= errors.getOrDefault("username", "3–32 letters, digits, dots, underscores or hyphens.") %></small>
                </div>
                <div class="field full">
                    <label for="fullName">Full name</label>
                    <input id="fullName" name="fullName" autocomplete="name" maxlength="100" required
                           value="<%= Web.html(fullName) %>" aria-describedby="name-error">
                    <small id="name-error" class="error"><%= errors.getOrDefault("fullName", "") %></small>
                </div>
                <div class="field">
                    <label for="contactNumber">Contact number</label>
                    <input id="contactNumber" name="contactNumber" type="tel" autocomplete="tel" maxlength="20" required
                           value="<%= Web.html(contactNumber) %>" aria-describedby="phone-error">
                    <small id="phone-error" class="error"><%= errors.getOrDefault("contactNumber", "") %></small>
                </div>
                <div class="field">
                    <label for="email">Email</label>
                    <input id="email" name="email" type="email" autocomplete="email" maxlength="254" required
                           value="<%= Web.html(email) %>" aria-describedby="email-error">
                    <small id="email-error" class="error"><%= errors.getOrDefault("email", "") %></small>
                </div>
                <div class="field">
                    <label for="password">Password</label>
                    <input id="password" name="password" type="password" autocomplete="new-password"
                           minlength="<%= Accounts.MIN_PASSWORD_LENGTH %>"
                           maxlength="128" required aria-describedby="password-hint">
                    <small id="password-hint" class="hint"><%= errors.getOrDefault("password",
                            Accounts.REGISTRATION_PASSWORD_HINT) %></small>
                </div>
                <div class="field">
                    <label for="confirmation">Confirm password</label>
                    <input id="confirmation" name="confirmation" type="password" autocomplete="new-password" maxlength="128"
                           required aria-describedby="confirmation-error">
                    <small id="confirmation-error" class="error"><%= errors.getOrDefault("confirmation", "") %></small>
                </div>
            </div>
            <div class="form-actions">
                <a href="login.jsp">Back to sign in</a>
                <button type="submit">Create account</button>
            </div>
        </form>
    </div>
</main>
</body>
</html>
