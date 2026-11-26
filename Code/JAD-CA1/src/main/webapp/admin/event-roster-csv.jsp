<%@ page contentType="text/csv; charset=UTF-8" pageEncoding="UTF-8" session="false" trimDirectiveWhitespaces="true"
    import="java.sql.SQLException,java.util.List,sg.edu.sp.jad.*" %>
<%!
    // One CSV cell: always quoted, with inner quotes doubled. A value starting with = + - or @ could
    // run as a formula when opened in Excel, so it gets a leading apostrophe. Phone numbers such as
    // +65 9123 4567 contain only digits and phone symbols, which cannot form a harmful formula, so
    // they are left as they are.
    private static String cell(String value) {
        String text = value == null ? "" : value;
        if (!text.isEmpty() && "=+-@\t\r".indexOf(text.charAt(0)) >= 0 && !text.matches("[0-9 ()+-]*")) {
            text = "'" + text;
        }
        return "\"" + text.replace("\"", "\"\"") + "\"";
    }
%>
<%
    // Downloads an event's roster as a spreadsheet file: the same rows as the roster on event.jsp.
    // AccessFilter already limits /admin/* to Admins.
    long id = Web.id(request, "id");
    try {
        Events.Event event = Events.find(id);
        if (event == null) {
            response.sendError(404, "That event does not exist.");
            return;
        }
        List<Registrations.SignupSummary> roster =
                Registrations.summarize(Registrations.roster(id), Registrations.Signup::volunteerId);
        response.setHeader("Content-Disposition", "attachment; filename=\"roster-E-" + id + ".csv\"");
        out.write('﻿'); // byte order mark, so Excel reads the file as UTF-8
        out.write("Volunteer ID,Full name,Username,Contact number,Email,Status,Signed up at,Added by\r\n");
        for (Registrations.SignupSummary entry : roster) {
            Registrations.Signup signup = entry.signup();
            out.write(String.join(",",
                    cell(signup.volunteerCode()),
                    cell(signup.volunteerName()),
                    cell(signup.username()),
                    cell(signup.contactNumber()),
                    cell(signup.email()),
                    cell(signup.statusLabel()),
                    cell(Events.input(signup.registeredAt()).replace('T', ' ')),
                    cell(signup.selfRegistered() ? "Self signup" : "Admin")) + "\r\n");
        }
    } catch (SQLException e) {
        application.log("Roster export failed. SQL state: " + e.getSQLState());
        response.sendError(503, "The roster is temporarily unavailable.");
    }
%>
