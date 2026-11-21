package sg.edu.sp.jad;

import java.io.IOException;
import java.sql.SQLException;
import jakarta.servlet.Filter;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.ServletRequest;
import jakarta.servlet.ServletResponse;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

public final class AccessFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest http = (HttpServletRequest) request;
        HttpServletResponse result = (HttpServletResponse) response;
        http.setCharacterEncoding("UTF-8");
        result.setHeader("Cache-Control", "no-store");
        result.setHeader("X-Content-Type-Options", "nosniff");
        result.setHeader("Content-Security-Policy",
                "default-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'; form-action 'self'");

        String path = http.getServletPath();
        Accounts.Role required = null;
        if (path.equals("/admin") || path.startsWith("/admin/")) {
            required = Accounts.Role.ADMIN;
        } else if (path.equals("/volunteer") || path.startsWith("/volunteer/")) {
            required = Accounts.Role.VOLUNTEER;
        }
        if (required != null && !requireUser(http, result, required)) {
            return;
        }

        if ("POST".equals(http.getMethod()) && !Web.validToken(http)) {
            result.sendError(403, "Your form has expired. Reload the page and try again.");
            return;
        }
        chain.doFilter(http, result);
    }

    private boolean requireUser(HttpServletRequest request, HttpServletResponse response, Accounts.Role role)
            throws IOException {
        HttpSession session = request.getSession(false);
        try {
            Accounts.User user = session != null && session.getAttribute(Web.USER_ID) instanceof Long id
                    ? Accounts.findActive(id) : null;
            if (user == null) {
                if (session != null) {
                    session.invalidate();
                }
                response.sendRedirect(request.getContextPath() + "/login.jsp?notice=signin");
                return false;
            }
            if (user.role() != role) {
                response.sendError(403, "You do not have access to this page.");
                return false;
            }
            request.setAttribute("currentUser", user);
            return true;
        } catch (SQLException e) {
            request.getServletContext().log("Account access check failed. SQL state: " + e.getSQLState());
            response.sendError(503, "Account access is temporarily unavailable.");
            return false;
        }
    }
}
