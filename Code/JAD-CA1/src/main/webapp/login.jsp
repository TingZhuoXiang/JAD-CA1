<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,sg.edu.sp.jad.Accounts,sg.edu.sp.jad.Web" %>
<%
    String username = "";
    String error = "";
    if ("POST".equals(request.getMethod())) {
        username = Web.field(request, "username").strip();
        try {
            Accounts.User user = Accounts.authenticate(username, Web.field(request, "password"));
            if (user != null) {
                Web.signIn(request, user);
                response.sendRedirect(request.getContextPath()
                        + (user.mustChangePassword() ? Web.CHANGE_PASSWORD : Web.home(user.role())));
                return;
            }
            response.setStatus(400);
            error = "The username or password is incorrect.";
        } catch (SQLException e) {
            application.log("Sign in failed. SQL state: " + e.getSQLState());
            response.setStatus(503);
            error = "Sign in is temporarily unavailable.";
        }
    }
    String notice = request.getParameter("notice");
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Sign in | Vision Screening</title>
    <link rel="stylesheet" href="site.css">
</head>
<body>
<main>
    <a href="./">Vision Screening</a>
    <h1>Sign in</h1>
    <% if ("registered".equals(notice)) { %><p role="status">Account created. You can now sign in.</p><% } %>
    <% if ("signin".equals(notice)) { %><p role="status">Sign in to continue. Your previous session may have expired.</p><% } %>
    <% if ("loggedout".equals(notice)) { %><p role="status">You’ve signed out.</p><% } %>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <form method="post" action="login.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession()) %>">
        <label for="username">Username</label>
        <input id="username" name="username" autocomplete="username" maxlength="32" required
               value="<%= Web.html(username) %>">
        <label for="password">Password</label>
        <input id="password" name="password" type="password" autocomplete="current-password" maxlength="128" required>
        <button type="submit">Sign in</button>
    </form>
    <p><a href="register.jsp">Create a volunteer account</a></p>
</main>
</body>
</html>
