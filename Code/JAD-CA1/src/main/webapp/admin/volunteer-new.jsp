<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.Map,sg.edu.sp.jad.*" %>
<%!
    // Session key for the account just created. Read once after the redirect, then removed, so the
    // temporary password is shown exactly once and never appears in a URL.
    private static final String CREATED = "jad.admin.createdVolunteer";
%>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "volunteers";
    String username = "", fullName = "", contactNumber = "", email = "", error = "";
    Map<String, String> errors = Map.of();
    Volunteers.Created created = null;
    if ("POST".equals(request.getMethod())) {
        username = Web.field(request, "username").strip();
        fullName = Web.field(request, "fullName").strip();
        contactNumber = Web.field(request, "contactNumber").strip();
        email = Web.field(request, "email").strip();
        errors = Accounts.validateNewAccount(username, fullName, contactNumber, email);
        if (errors.isEmpty() && !Web.useFormToken(request)) {
            // A second click on the same form: the first click created the account. Show its one-time
            // password, instead of a "username already in use" error that would hide it for good.
            response.sendRedirect("volunteer-new.jsp?created");
            return;
        }
        if (errors.isEmpty()) {
            try {
                request.getSession(false).setAttribute(CREATED,
                        Volunteers.createWithTemporaryPassword(username, fullName, contactNumber, email));
                response.sendRedirect("volunteer-new.jsp?created");
                return;
            } catch (SQLException e) {
                if (e.getErrorCode() == 1062) {
                    response.setStatus(409);
                    error = "The username or email is already in use.";
                } else {
                    application.log("Volunteer creation failed. SQL state: " + e.getSQLState());
                    response.setStatus(503);
                    error = "Account creation is temporarily unavailable.";
                }
            }
        } else {
            response.setStatus(400);
            error = "Check the fields below and try again.";
        }
    } else if (request.getParameter("created") != null) {
        jakarta.servlet.http.HttpSession session = request.getSession(false);
        // JSPs compile at an older Java level on this server, so no pattern-matching instanceof.
        Object stored = session.getAttribute(CREATED);
        if (stored instanceof Volunteers.Created) {
            created = (Volunteers.Created) stored;
            session.removeAttribute(CREATED);
        }
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Create volunteer account | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <a class="back" href="volunteers.jsp">← All volunteers</a>
    <div class="panel">
    <% if (created != null) { %>
        <h1>Account created</h1>
        <p class="callout success" role="status">Volunteer <strong>V-<%= created.id() %></strong> was created with username
            <strong><%= Web.html(created.username()) %></strong>.</p>
        <p>Give the volunteer this temporary password. <strong>It is shown only once</strong> and is not stored anywhere
            you can view again. They must choose a new password the first time they sign in.</p>
        <p class="secret"><%= Web.html(created.temporaryPassword()) %></p>
        <div class="form-actions">
            <a class="button secondary" href="volunteer-new.jsp">Create another</a>
            <a class="button" href="volunteer.jsp?id=<%= created.id() %>">View volunteer</a>
        </div>
    <% } else { %>
        <h1>Create volunteer account</h1>
        <% if (request.getParameter("created") != null) { %>
        <p class="callout info" role="status">That temporary password has already been shown and cannot be displayed again.</p>
        <% } %>
        <p class="meta">This creates a sign-in account only. Add them to events from an event’s roster.</p>
        <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
        <form method="post" action="volunteer-new.jsp">
            <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
            <input type="hidden" name="formToken" value="<%= Web.formToken(request) %>">
            <div class="form-grid">
                <div class="field">
                    <label for="username">Username <span class="req">*</span></label>
                    <input id="username" name="username" maxlength="32" required autocomplete="off" value="<%= Web.html(username) %>" aria-describedby="username-hint">
                    <small id="username-hint" class="hint"><%= errors.getOrDefault("username", "3–32 letters, digits, dots, underscores or hyphens.") %></small>
                </div>
                <div class="field">
                    <label for="fullName">Full name <span class="req">*</span></label>
                    <input id="fullName" name="fullName" maxlength="100" required value="<%= Web.html(fullName) %>" aria-describedby="name-error">
                    <small id="name-error" class="error"><%= errors.getOrDefault("fullName", "") %></small>
                </div>
                <div class="field">
                    <label for="contactNumber">Contact number <span class="req">*</span></label>
                    <input id="contactNumber" name="contactNumber" type="tel" maxlength="20" required value="<%= Web.html(contactNumber) %>" aria-describedby="phone-error">
                    <small id="phone-error" class="error"><%= errors.getOrDefault("contactNumber", "") %></small>
                </div>
                <div class="field">
                    <label for="email">Email <span class="req">*</span></label>
                    <input id="email" name="email" type="email" maxlength="254" required value="<%= Web.html(email) %>" aria-describedby="email-error">
                    <small id="email-error" class="error"><%= errors.getOrDefault("email", "") %></small>
                </div>
            </div>
            <div class="form-actions">
                <a href="volunteers.jsp">Cancel</a>
                <button type="submit">Create account</button>
            </div>
        </form>
    <% } %>
    </div>
</main>
</body>
</html>
