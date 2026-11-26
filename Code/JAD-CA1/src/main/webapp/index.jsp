<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" %>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Vision Screening</title>
    <link rel="stylesheet" href="site.css">
</head>
<body>
<% String navCurrent = "overview"; %>
<main class="wide">
    <%@ include file="/WEB-INF/jspf/public-header.jspf" %>
    <section class="hero">
        <div>
            <p class="eyebrow">Vision Screening Station Management System</p>
            <h1>Clear sight, well organised.</h1>
            <p class="lede">Volunteers keep their details up to date and sign up for screening events. Admins run the events, look after participant records and see who is coming.</p>
            <div class="actions">
                <a class="button" href="login.jsp">Sign in &rarr;</a>
                <a class="button secondary" href="register.jsp">Create a volunteer account</a>
            </div>
        </div>
        <div class="eye-chart" aria-hidden="true"><span>E</span><span>F P</span><span>T O Z</span><span>L P E D</span><span>P E C F D</span><small>Screening events &middot; signups &middot; records</small></div>
    </section>
    <div class="cards-3">
        <div class="card"><span class="step">01</span><h2>Volunteers</h2><p>Update your own profile, browse upcoming screenings, sign up and withdraw before an event starts.</p></div>
        <div class="card"><span class="step">02</span><h2>Admins</h2><p>Create and manage events, keep participant records accurate and manage each event's roster.</p></div>
        <div class="card"><span class="step">03</span><h2>New here?</h2><p>Create a volunteer account in a minute. Admin accounts are set up by the team. <a href="register.jsp">Create account &rarr;</a></p></div>
    </div>
    <footer class="site-footer">ST0510 J2EE Application Development &middot; Assignment 1 &middot; Vision Screening Station Management System</footer>
</main>
</body>
</html>
