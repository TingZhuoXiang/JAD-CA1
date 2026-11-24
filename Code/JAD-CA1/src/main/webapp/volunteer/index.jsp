<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="sg.edu.sp.jad.Accounts,sg.edu.sp.jad.Web" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "home";
%>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <h1>Volunteer workspace</h1>
    <p>Signed in as <strong><%= Web.html(user.fullName()) %></strong> · Volunteer</p>
    <p>Volunteer ID: <%= user.volunteerId() %></p>
    <div class="actions">
        <a class="button" href="events.jsp">Browse events</a>
        <a class="button secondary" href="signups.jsp">My signups</a>
        <a class="button secondary" href="profile.jsp">My profile</a>
    </div>
</main>
</body>
</html>
