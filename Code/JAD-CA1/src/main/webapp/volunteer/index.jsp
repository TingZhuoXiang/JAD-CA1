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
    <div class="page-head">
        <div>
            <p class="eyebrow">Volunteer portal</p>
            <h1>Volunteer workspace</h1>
            <p class="lede">Signed in as <strong><%= Web.html(user.fullName()) %></strong> &middot; Volunteer ID: <%= user.volunteerId() %></p>
        </div>
        <div class="actions"><a class="button" href="events.jsp">Browse events</a></div>
    </div>
    <div class="cards-3">
        <div class="card"><span class="step">01</span><h2><a href="events.jsp">Browse events</a></h2><p>Find an upcoming screening and sign up. You can withdraw any time before it starts.</p></div>
        <div class="card"><span class="step">02</span><h2><a href="signups.jsp">My signups</a></h2><p>See your upcoming events and your history, including signups added by an Admin.</p></div>
        <div class="card"><span class="step">03</span><h2><a href="profile.jsp">My profile</a></h2><p>Keep your name, contact number and email up to date.</p></div>
    </div>
</main>
</body>
</html>
