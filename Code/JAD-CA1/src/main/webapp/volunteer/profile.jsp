<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.Map,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "profile";
    Volunteers.Volunteer profile = null;
    Map<String, String> errors = Map.of();
    String error = "";
    String fullName = "", contactNumber = "", email = "";
    try {
        profile = Volunteers.find(user.id());
        if (profile == null || !profile.active()) {
            response.sendError(403, "This account is unavailable.");
            return;
        }
        fullName = profile.fullName();
        contactNumber = profile.contactNumber();
        email = profile.email();
        if ("POST".equals(request.getMethod())) {
            fullName = Web.field(request, "fullName").strip();
            contactNumber = Web.field(request, "contactNumber").strip();
            email = Web.field(request, "email").strip();
            errors = Accounts.validateProfile(fullName, contactNumber, email);
            if (!errors.isEmpty()) {
                response.setStatus(400);
                error = "Check the fields below and try again.";
            } else if (Volunteers.update(user.id(), fullName, contactNumber, email)) {
                Web.flash(request, "Profile saved.");
                response.sendRedirect("profile.jsp");
                return;
            } else {
                response.setStatus(409);
                error = "This account is no longer active.";
            }
        }
    } catch (SQLException e) {
        if (e.getErrorCode() == 1062) {
            response.setStatus(409);
            errors = Map.of("email", "Another account already uses this email.");
            error = "Check the fields below and try again.";
        } else {
            application.log("Volunteer profile failed. SQL state: " + e.getSQLState());
            response.setStatus(503);
            error = "Your profile is temporarily unavailable.";
        }
    }
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>My profile | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <div class="page-head">
        <div>
            <p class="eyebrow">Volunteer portal</p>
            <h1>My profile</h1>
            <p class="lede">Keep your contact details up to date so the team can reach you.</p>
        </div>
    </div>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (profile != null) { %>
    <div class="grid-2">
        <div class="panel">
            <h2>Account</h2>
            <dl class="kv">
                <dt>Volunteer ID</dt><dd><%= profile.volunteerId() %></dd>
                <dt>Username</dt><dd><%= Web.html(profile.username()) %></dd>
                <dt>Role</dt><dd>Volunteer</dd>
            </dl>
        </div>
        <div class="panel">
            <h2>Contact details</h2>
            <form method="post" action="profile.jsp">
                <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
                <div class="field">
                    <label for="fullName">Full name <span class="req">*</span></label>
                    <input id="fullName" name="fullName" type="text" autocomplete="name" maxlength="100" required
                           value="<%= Web.html(fullName) %>" aria-describedby="fullName-error">
                    <small id="fullName-error" class="error"><%= Web.html(errors.getOrDefault("fullName", "")) %></small>
                </div>
                <div class="field">
                    <label for="contactNumber">Contact number <span class="req">*</span></label>
                    <input id="contactNumber" name="contactNumber" type="tel" autocomplete="tel" maxlength="20" required
                           value="<%= Web.html(contactNumber) %>" aria-describedby="contactNumber-error">
                    <small id="contactNumber-error" class="error"><%= Web.html(errors.getOrDefault("contactNumber", "")) %></small>
                </div>
                <div class="field">
                    <label for="email">Email <span class="req">*</span></label>
                    <input id="email" name="email" type="email" autocomplete="email" maxlength="254" required
                           value="<%= Web.html(email) %>" aria-describedby="email-error">
                    <small id="email-error" class="error"><%= Web.html(errors.getOrDefault("email", "")) %></small>
                </div>
                <div class="form-actions"><button type="submit">Save details</button></div>
            </form>
        </div>
    </div>

    <section class="panel full danger-zone">
        <h2>Deactivate account</h2>
        <p>Deactivating your account blocks sign-in and cancels your upcoming signups.</p>
        <div class="actions"><a class="button danger-outline" href="deactivate.jsp">Deactivate account</a></div>
    </section>
    <% } %>
</main>
</body>
</html>
