<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="java.sql.SQLException,java.util.LinkedHashMap,java.util.Map,sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
    long id = Web.id(request, "id");
    // ?copy=<id> opens the create form pre-filled from another event (a repeat screening).
    long copyId = id > 0 ? -1 : Web.id(request, "copy");
    Events.Event original = null;
    Events.Event source = null;
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
        } else if (copyId > 0) {
            source = Events.find(copyId);
            if (source == null) {
                response.sendError(404, "The event to copy does not exist.");
                return;
            }
            // Copy the details but not the date: the Admin picks a new date and time.
            title = source.title();
            location = source.location();
            description = source.description();
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
    String heading = original != null ? "Edit event" : source != null ? "Copy event" : "Create event";
    String back = original != null ? "event.jsp?id=" + id : source != null ? "event.jsp?id=" + copyId : "events.jsp";
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
    <p><a href="<%= back %>">← Back</a></p>
    <h1><%= heading %></h1>
    <% if (source != null) { %>
    <p class="notice">Copied from E-<%= source.id() %> · <%= Web.html(source.title()) %>. Choose the date and time for the new event. Signups are not copied.</p>
    <% } %>
    <p class="muted">Times are Singapore time. Volunteers can sign up until the event starts.</p>
    <% if (!error.isEmpty()) { %><p class="error" role="alert"><%= Web.html(error) %></p><% } %>
    <form method="post" action="event-form.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
        <% if (original != null) { %><input type="hidden" name="id" value="<%= id %>"><% } %>
        <% if (source != null) { %><input type="hidden" name="copy" value="<%= source.id() %>"><% } %>

        <label for="title">Title</label>
        <input id="title" name="title" maxlength="120" required value="<%= Web.html(title) %>" aria-describedby="title-error">
        <small id="title-error" class="error"><%= errors.getOrDefault("title", "") %></small>

        <label for="location">Location</label>
        <input id="location" name="location" maxlength="200" required value="<%= Web.html(location) %>" aria-describedby="location-error">
        <small id="location-error" class="error"><%= errors.getOrDefault("location", "") %></small>

        <label for="startsAt">Starts</label>
        <input id="startsAt" name="startsAt" type="datetime-local" required value="<%= Web.html(startsAt) %>" aria-describedby="start-error">
        <small id="start-error" class="error"><%= errors.getOrDefault("startsAt", "") %></small>

        <label for="endsAt">Ends</label>
        <input id="endsAt" name="endsAt" type="datetime-local" required value="<%= Web.html(endsAt) %>" aria-describedby="end-error">
        <small id="end-error" class="error"><%= errors.getOrDefault("endsAt", "") %></small>

        <label for="description">Description <span class="muted">(optional)</span></label>
        <textarea id="description" name="description" maxlength="2000" aria-describedby="description-error"><%= Web.html(description) %></textarea>
        <small id="description-error" class="error"><%= errors.getOrDefault("description", "") %></small>

        <button type="submit"><%= original == null ? "Create event" : "Save changes" %></button>
    </form>
</main>
</body>
</html>
