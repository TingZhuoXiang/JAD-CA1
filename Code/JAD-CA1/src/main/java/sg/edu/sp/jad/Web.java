package sg.edu.sp.jad;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Collections;
import java.util.HexFormat;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.Set;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpSession;

public final class Web {
    static final String USER_ID = "jad.userId";
    public static final String CHANGE_PASSWORD = "/account/change-password.jsp";
    private static final String CSRF = "jad.csrf";
    private static final String FLASH = "jad.flash";
    private static final String FORM_TOKENS = "jad.formTokens";
    private static final int MAX_FORM_TOKENS = 20;
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

    /**
     * Issues a one-time token for a form that creates a record. The page puts it in a hidden
     * "formToken" field, and {@link #useFormToken} accepts it only once, so a double-click or a
     * repeated submit of the same form cannot create the record twice. Each time a create form is
     * shown it gets a new token, so separate forms with identical details still work.
     */
    public static String formToken(HttpServletRequest request) {
        byte[] bytes = new byte[16];
        RANDOM.nextBytes(bytes);
        String token = HexFormat.of().formatHex(bytes);
        Set<String> tokens = formTokens(request.getSession(false));
        synchronized (tokens) {
            tokens.add(token);
            // Keep only the newest few, so forms that are opened and never submitted do not pile up.
            Iterator<String> oldest = tokens.iterator();
            while (tokens.size() > MAX_FORM_TOKENS) {
                oldest.next();
                oldest.remove();
            }
        }
        return token;
    }

    /**
     * Uses up the request's form token. Returns true only the first time; a repeat, unknown or
     * missing token returns false. The check and removal are one atomic step, so two requests that
     * arrive at the same moment cannot both pass.
     */
    public static boolean useFormToken(HttpServletRequest request) {
        String token = field(request, "formToken");
        return !token.isEmpty() && formTokens(request.getSession(false)).remove(token);
    }

    @SuppressWarnings("unchecked")
    private static Set<String> formTokens(HttpSession session) {
        synchronized (session) {
            Set<String> tokens = (Set<String>) session.getAttribute(FORM_TOKENS);
            if (tokens == null) {
                tokens = Collections.synchronizedSet(new LinkedHashSet<>());
                session.setAttribute(FORM_TOKENS, tokens);
            }
            return tokens;
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
