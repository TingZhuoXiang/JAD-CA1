<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.time.LocalDateTime,java.util.List,java.util.Map,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "volunteers";
    long id = Web.id(request, "id");
    Volunteers.Volunteer volunteer = null;
    List<Registrations.SignupSummary> signups = List.of();
    Map<String, String> errors = Map.of();
    String error = "";
    String fullName = "", contactNumber = "", email = "";
    try {
        volunteer = Volunteers.find(id);
        if (volunteer == null) {
            response.sendError(404, "That volunteer does not exist.");
            return;
        }
        fullName = volunteer.fullName();
        contactNumber = volunteer.contactNumber();
        email = volunteer.email();
        if ("POST".equals(request.getMethod())) {
            fullName = Web.field(request, "fullName").strip();
            contactNumber = Web.field(request, "contactNumber").strip();
            email = Web.field(request, "email").strip();
            errors = Accounts.validateProfile(fullName, contactNumber, email);
            if (!volunteer.active()) {
                response.setStatus(409);
                error = "Deactivated accounts cannot be edited.";
            } else if (!errors.isEmpty()) {
                response.setStatus(400);
                error = "Check the fields below and try again.";
            } else {
                try {
                    if (Volunteers.update(id, fullName, contactNumber, email)) {
                        Web.flash(request, "Volunteer details saved.");
                        response.sendRedirect("volunteer.jsp?id=" + id);
                        return;
                    }
                    response.setStatus(409);
                    error = "This account was deactivated, so it was not changed.";
                } catch (SQLException e) {
                    if (e.getErrorCode() != 1062) throw e;
                    response.setStatus(409);
                    errors = Map.of("email", "Another account already uses this email.");
                    error = "Check the fields below and try again.";
                }
            }
        }
        signups = Registrations.summarize(Registrations.forVolunteer(id), Registrations.Signup::eventId);
    } catch (SQLException e) {
        application.log("Volunteer page failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "This volunteer is temporarily unavailable. Try again shortly.";
    }
    LocalDateTime now = Events.now();
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= volunteer == null ? "Volunteer" : Web.html(volunteer.fullName()) %> | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <p><a href="volunteers.jsp">← Volunteers</a></p>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <% if (volunteer != null) { %>
    <h1><%= Web.html(volunteer.fullName()) %></h1>
    <p><% if (!volunteer.active()) { %><span class="badge off">Deactivated <%= Events.display(volunteer.deactivatedAt()) %></span><% } else if (volunteer.mustChangePassword()) { %><span class="badge warn">Awaiting first sign-in</span><% } else { %><span class="badge ok">Active</span><% } %></p>
    <dl class="details">
        <dt>Volunteer ID</dt><dd><%= volunteer.volunteerId() %></dd>
        <dt>Username</dt><dd><%= Web.html(volunteer.username()) %></dd>
        <dt>Role</dt><dd>Volunteer</dd>
        <dt>Account created</dt><dd><%= Events.display(volunteer.createdAt()) %></dd>
    </dl>

    <% if (volunteer.active()) { %>
    <section>
        <h2>Contact details</h2>
        <form method="post" action="volunteer.jsp">
            <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
            <input type="hidden" name="id" value="<%= volunteer.id() %>">
            <label for="fullName">Full name</label>
            <input id="fullName" name="fullName" maxlength="100" required value="<%= Web.html(fullName) %>" aria-describedby="name-error">
            <small id="name-error" class="error"><%= errors.getOrDefault("fullName", "") %></small>
            <label for="contactNumber">Contact number</label>
            <input id="contactNumber" name="contactNumber" type="tel" maxlength="20" required value="<%= Web.html(contactNumber) %>" aria-describedby="phone-error">
            <small id="phone-error" class="error"><%= errors.getOrDefault("contactNumber", "") %></small>
            <label for="email">Email</label>
            <input id="email" name="email" type="email" maxlength="254" required value="<%= Web.html(email) %>" aria-describedby="email-error">
            <small id="email-error" class="error"><%= errors.getOrDefault("email", "") %></small>
            <button type="submit">Save details</button>
        </form>
    </section>
    <% } else { %>
    <dl class="details">
        <dt>Contact number</dt><dd><%= Web.html(volunteer.contactNumber()) %></dd>
        <dt>Email</dt><dd><%= Web.html(volunteer.email()) %></dd>
    </dl>
    <% } %>

    <section>
        <h2>Event signups</h2>
        <% if (signups.isEmpty()) { %>
        <p class="muted">No signups yet.</p>
        <% } else { %>
        <div class="table-wrap"><table>
            <thead><tr><th>Event</th><th>When</th><th>Status</th><th>Signed up</th></tr></thead>
            <tbody>
            <% for (Registrations.SignupSummary entry : signups) {
                Registrations.Signup signup = entry.signup(); %>
            <tr>
                <td><a href="event.jsp?id=<%= signup.eventId() %>"><%= Web.html(signup.eventTitle()) %></a>
                    <% if (signup.eventStatus() == Events.Status.CANCELLED) { %><span class="badge off">Event cancelled</span><% } else if (!now.isBefore(signup.startsAt())) { %><span class="badge">Past</span><% } %></td>
                <td><%= Events.display(signup.startsAt()) %></td>
                <td><span class="badge <%= signup.active() ? "ok" : "off" %>"><%= Web.html(signup.statusLabel()) %></span>
                    <% if (entry.previouslyWithdrawn()) { %><span class="badge">Previously withdrawn</span><% } %>
                    <% if (signup.endedAt() != null) { %><br><span class="muted"><%= Events.display(signup.endedAt()) %></span><% } %></td>
                <td><%= Events.display(signup.registeredAt()) %><br><span class="muted"><%= signup.selfRegistered() ? "Self signup" : "Added by Admin" %></span></td>
            </tr>
            <% } %>
            </tbody>
        </table></div>
        <% } %>
    </section>

    <% if (volunteer.active()) { %>
    <section>
        <h2>Deactivate account</h2>
        <p>Blocks sign-in and cancels this volunteer’s <%= volunteer.upcomingSignups() %> upcoming signup<%= volunteer.upcomingSignups() == 1 ? "" : "s" %>. Their history is kept.</p>
        <a class="button secondary" href="volunteer-deactivate.jsp?id=<%= volunteer.id() %>">Deactivate…</a>
    </section>
    <% } %>
    <% } %>
</main>
</body>
</html>
