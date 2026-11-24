package sg.edu.sp.jad;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HexFormat;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

public final class Web {
    static final String USER_ID = "jad.userId";
    public static final String CHANGE_PASSWORD = "/account/change-password.jsp";
    private static final String CSRF = "jad.csrf";
    private static final String FLASH = "jad.flash";
    private static final SecureRandom RANDOM = new SecureRandom();

    private Web() {}

    public static String field(HttpServletRequest request, String name) {
        String value = request.getParameter(name);
        return value == null ? "" : value;
    }

    public static String token(HttpSession session) {
        synchronized (session) {
            String token = (String) session.getAttribute(CSRF);
            if (token == null) {
                byte[] bytes = new byte[32];
                RANDOM.nextBytes(bytes);
                token = HexFormat.of().formatHex(bytes);
                session.setAttribute(CSRF, token);
            }
            return token;
        }
    }

    static boolean validToken(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null || !(session.getAttribute(CSRF) instanceof String expected)) {
            return false;
        }
        String submitted = field(request, "csrf");
        return submitted.length() == expected.length() && MessageDigest.isEqual(
                submitted.getBytes(StandardCharsets.UTF_8), expected.getBytes(StandardCharsets.UTF_8));
    }

    public static void signIn(HttpServletRequest request, Accounts.User user) {
        HttpSession previous = request.getSession(false);
        if (previous != null) {
            previous.invalidate();
        }
        request.getSession(true).setAttribute(USER_ID, user.id());
    }

    /** Reads a positive id parameter, or returns -1 if it is missing or malformed. */
    public static long id(HttpServletRequest request, String name) {
        try {
            long value = Long.parseLong(field(request, name));
            return value > 0 ? value : -1;
        } catch (NumberFormatException e) {
            return -1;
        }
    }

    /** Stores a one-time message to show after a POST-redirect-GET. */
    public static void flash(HttpServletRequest request, String message) {
        request.getSession().setAttribute(FLASH, message);
    }

    /** Returns and clears the one-time message, or "" if there is none. */
    public static String takeFlash(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        if (session == null || !(session.getAttribute(FLASH) instanceof String message)) {
            return "";
        }
        session.removeAttribute(FLASH);
        return message;
    }

    public static String home(Accounts.Role role) {
        return role == Accounts.Role.ADMIN ? "/admin/" : "/volunteer/";
    }

    public static String html(String value) {
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }
}
