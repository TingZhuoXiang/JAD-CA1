package sg.edu.sp.jad;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.HexFormat;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

public final class Web {
    static final String USER_ID = "jad.userId";
    private static final String CSRF = "jad.csrf";
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

    public static String home(Accounts.Role role) {
        return role == Accounts.Role.ADMIN ? "/admin/" : "/volunteer/";
    }

    public static String html(String value) {
        return value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                .replace("\"", "&quot;").replace("'", "&#39;");
    }
}
