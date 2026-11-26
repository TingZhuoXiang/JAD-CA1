<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="sg.edu.sp.jad.*" %>
<%
    Accounts.User user = (Accounts.User) request.getAttribute("currentUser");
    String navCurrent = "events";
%>
<%@ include file="/WEB-INF/jspf/event-search.jspf" %>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Events | Volunteer | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
    <script src="../list-filters.js" defer></script>
</head>
<body>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/volunteer-nav.jspf" %>
    <h1>Events</h1>

    <%@ include file="/WEB-INF/jspf/event-list.jspf" %>
</main>
</body>
</html>
