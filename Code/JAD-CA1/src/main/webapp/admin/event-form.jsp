<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.LinkedHashMap,java.util.Map,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    long id = Web.id(request, "id");
    Events.Event original = null;
    String error = "";
    Map<String, String> errors = new LinkedHashMap<>();
    String title = "", location = "", description = "", startsAt = "", endsAt = "";
    try {
        if (id > 0) {
            original = Events.find(id);
            if (original == null) {
                response.sendError(404, "That event does not exist.");
                return;
            }
            if (!original.openForSignup(Events.now())) {
                Web.flash(request, "Only upcoming events that are not cancelled can be edited.");
                response.sendRedirect("event.jsp?id=" + id);
                return;
            }
            title = original.title();
            location = original.location();
            description = original.description();
            startsAt = Events.input(original.startsAt());
            endsAt = Events.input(original.endsAt());
        }
        if ("POST".equals(request.getMethod())) {
            title = Web.field(request, "title").strip();
            location = Web.field(request, "location").strip();
            description = Web.field(request, "description").strip().replace("\r\n", "\n");
            startsAt = Web.field(request, "startsAt").strip();
            endsAt = Web.field(request, "endsAt").strip();
            Events.Form form = Events.validate(title, location, description, startsAt, endsAt, original, errors);
            if (form == null) {
                response.setStatus(400);
                error = "Check the fields below and try again.";
            } else if (original == null) {
                long created = Events.create(form, user.id());
                Web.flash(request, "Event created.");
                response.sendRedirect("event.jsp?id=" + created);
                return;
            } else if (Events.update(id, form)) {
                Web.flash(request, "Event details saved. Existing signups are unchanged.");
                response.sendRedirect("event.jsp?id=" + id);
                return;
            } else {
                response.setStatus(409);
                error = "This event was cancelled or has started, so it can no longer be edited.";
            }
        }
    } catch (SQLException e) {
        application.log("Event save failed. SQL state: " + e.getSQLState());
        response.setStatus(503);
        error = "Events are temporarily unavailable. Try again shortly.";
    }
    String heading = original == null ? "Create event" : "Edit event";
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title><%= heading %> | Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/admin-nav.jspf" %>
    <a class="back" href="<%= original == null ? "events.jsp" : "event.jsp?id=" + id %>">← Back</a>
    <div class="panel">
        <h1><%= heading %></h1>
        <p class="meta">Fields marked <span class="req">*</span> are required. Times are Singapore time. Volunteers can sign up until the event starts.</p>
        <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
        <form method="post" action="event-form.jsp">
            <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
            <% if (original != null) { %><input type="hidden" name="id" value="<%= id %>"><% } %>
            <div class="form-grid">
                <div class="field full">
                    <label for="title">Title <span class="req">*</span></label>
                    <input id="title" name="title" maxlength="120" required value="<%= Web.html(title) %>" aria-describedby="title-error">
                    <small id="title-error" class="error"><%= errors.getOrDefault("title", "") %></small>
                </div>
                <div class="field full">
                    <label for="location">Location <span class="req">*</span></label>
                    <input id="location" name="location" maxlength="200" required value="<%= Web.html(location) %>" aria-describedby="location-error">
                    <small id="location-error" class="error"><%= errors.getOrDefault("location", "") %></small>
                </div>
                <div class="field">
                    <label for="startsAt">Starts <span class="req">*</span></label>
                    <input id="startsAt" name="startsAt" type="datetime-local" required value="<%= Web.html(startsAt) %>" aria-describedby="start-error">
                    <small id="start-error" class="error"><%= errors.getOrDefault("startsAt", "") %></small>
                </div>
                <div class="field">
                    <label for="endsAt">Ends <span class="req">*</span></label>
                    <input id="endsAt" name="endsAt" type="datetime-local" required value="<%= Web.html(endsAt) %>" aria-describedby="end-error">
                    <small id="end-error" class="error"><%= errors.getOrDefault("endsAt", "") %></small>
                </div>
                <div class="field full">
                    <label for="description">Description <span class="muted">(optional)</span></label>
                    <textarea id="description" name="description" maxlength="2000" aria-describedby="description-error"><%= Web.html(description) %></textarea>
                    <small id="description-error" class="error"><%= errors.getOrDefault("description", "") %></small>
                </div>
            </div>
            <div class="form-actions">
                <a href="<%= original == null ? "events.jsp" : "event.jsp?id=" + id %>">Cancel</a>
                <button type="submit"><%= original == null ? "Create event" : "Save changes" %></button>
            </div>
        </form>
    </div>
</main>
</body>
</html>
