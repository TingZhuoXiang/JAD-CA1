<%@ page contentType="text/html; charset=UTF-8" pageEncoding="UTF-8" session="false"
    import="sg.edu.sp.jad.Accounts,sg.edu.sp.jad.Web" %>
<% Accounts.User user = (Accounts.User) request.getAttribute("currentUser"); %>
<!doctype html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Admin | Vision Screening</title>
    <link rel="stylesheet" href="../site.css">
</head>
<body>
<main>
    <a href="../">Vision Screening</a>
    <h1>Admin workspace</h1>
    <p>Signed in as <strong><%= Web.html(user.fullName()) %></strong> · Admin</p>
    <form method="post" action="../logout.jsp">
        <input type="hidden" name="csrf" value="<%= Web.token(request.getSession(false)) %>">
        <button type="submit">Sign out</button>
    </form>
</main>
</body>
</html>
