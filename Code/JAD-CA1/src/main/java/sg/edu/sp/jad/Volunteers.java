package sg.edu.sp.jad;

import java.security.SecureRandom;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Admin management of Volunteer accounts. */
public final class Volunteers {
    private static final Pattern VOLUNTEER_ID = Pattern.compile("(?i)v-?(\\d{1,18})");
    // No 0/O, 1/l/I, so a temporary password read aloud or copied by hand stays unambiguous.
    private static final String TEMP_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    public enum Filter { ACTIVE, DEACTIVATED, ALL }

    public record Volunteer(long id, String username, String fullName, String contactNumber, String email,
            boolean active, boolean mustChangePassword, LocalDateTime createdAt, LocalDateTime deactivatedAt,
            int upcomingSignups) {
        public String volunteerId() {
            return "V-" + id;
        }
    }

    /** Held in the session only until the confirmation page shows it once. */
    public record Created(long id, String username, String temporaryPassword) implements java.io.Serializable {}

    private Volunteers() {}

    private static final String SELECT = """
            SELECT a.id, a.username, a.full_name, a.contact_number, a.email, a.active, a.must_change_password,
                   a.created_at, a.deactivated_at,
                   (SELECT COUNT(*) FROM event_registrations r JOIN events e ON e.id = r.event_id
                    WHERE r.volunteer_id = a.id AND r.status = 'ACTIVE' AND e.starts_at > ?) AS upcoming
            FROM accounts a
            WHERE a.role = 'VOLUNTEER'
            """;

    /** Matches name, username, email, contact number, or a Volunteer ID such as "V-12". */
    public static List<Volunteer> search(String text, Filter filter) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT);
        List<Object> params = new ArrayList<>();
        params.add(Events.now());
        if (filter == Filter.ACTIVE) sql.append(" AND a.active = TRUE");
        if (filter == Filter.DEACTIVATED) sql.append(" AND a.active = FALSE");
        String trimmed = text.strip();
        if (!trimmed.isEmpty()) {
            sql.append(" AND (a.full_name LIKE ? ESCAPE '!' OR a.username LIKE ? ESCAPE '!'"
                    + " OR a.email LIKE ? ESCAPE '!' OR a.contact_number LIKE ? ESCAPE '!'");
            String pattern = Events.like(trimmed);
            for (int i = 0; i < 4; i++) params.add(pattern);
            Matcher id = VOLUNTEER_ID.matcher(trimmed);
            if (id.matches()) {
                sql.append(" OR a.id = ?");
                params.add(Long.parseLong(id.group(1)));
            }
            sql.append(')');
        }
        sql.append(" ORDER BY a.full_name, a.id LIMIT 200");
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                statement.setObject(i + 1, params.get(i));
            }
            List<Volunteer> volunteers = new ArrayList<>();
            try (ResultSet rows = statement.executeQuery()) {
                while (rows.next()) {
                    volunteers.add(read(rows));
                }
            }
            return volunteers;
        }
    }

    public static Volunteer find(long id) throws SQLException {
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(SELECT + " AND a.id = ?")) {
            statement.setObject(1, Events.now());
            statement.setLong(2, id);
            try (ResultSet rows = statement.executeQuery()) {
                return rows.next() ? read(rows) : null;
            }
        }
    }

    /**
     * Updates the fields an Admin may edit. The username, role and Volunteer ID stay fixed.
     * Throws SQLException with error code 1062 if the email belongs to another account.
     */
    public static boolean update(long id, String fullName, String contactNumber, String email) throws SQLException {
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement("""
                UPDATE accounts SET full_name = ?, contact_number = ?, email = ?
                WHERE id = ? AND role = 'VOLUNTEER' AND active = TRUE
                """)) {
            statement.setString(1, fullName);
            statement.setString(2, contactNumber);
            statement.setString(3, Accounts.canonical(email));
            statement.setLong(4, id);
            return statement.executeUpdate() == 1;
        }
    }

    /**
     * Deactivates a volunteer and cancels their signups for events that have not started, in one
     * transaction. Their sessions end on their next request, because AccessFilter re-checks the
     * account. Returns the number of signups cancelled, or -1 if they were not an active volunteer.
     */
    public static int deactivate(long id, long adminId) throws SQLException {
        LocalDateTime now = Events.now();
        try (Connection db = Accounts.connect()) {
            db.setAutoCommit(false);
            try {
                try (PreparedStatement account = db.prepareStatement("""
                        UPDATE accounts SET active = FALSE, deactivated_at = ?
                        WHERE id = ? AND role = 'VOLUNTEER' AND active = TRUE
                        """)) {
                    account.setObject(1, now);
                    account.setLong(2, id);
                    if (account.executeUpdate() != 1) {
                        db.rollback();
                        return -1;
                    }
                }
                int cancelled = Registrations.cancelFutureForVolunteer(db, id, adminId, now);
                db.commit();
                return cancelled;
            } catch (SQLException | RuntimeException e) {
                db.rollback();
                throw e;
            }
        }
    }

    /**
     * Creates a Volunteer account with a generated temporary password that must be changed at
     * first sign-in. The caller shows the password once and never stores it.
     */
    public static Created createWithTemporaryPassword(String username, String fullName, String contactNumber,
            String email) throws SQLException {
        String password = temporaryPassword();
        long id = Accounts.create(username, fullName, contactNumber, email, password, Accounts.Role.VOLUNTEER, true);
        return new Created(id, Accounts.canonical(username), password);
    }

    /** 12 random characters in groups of four, e.g. "Hk7q-Rm2x-Pw9d" (about 70 bits). */
    static String temporaryPassword() {
        StringBuilder password = new StringBuilder();
        for (int i = 0; i < 12; i++) {
            if (i > 0 && i % 4 == 0) password.append('-');
            password.append(TEMP_ALPHABET.charAt(RANDOM.nextInt(TEMP_ALPHABET.length())));
        }
        return password.toString();
    }

    private static Volunteer read(ResultSet rows) throws SQLException {
        return new Volunteer(rows.getLong("id"), rows.getString("username"), rows.getString("full_name"),
                rows.getString("contact_number"), rows.getString("email"), rows.getBoolean("active"),
                rows.getBoolean("must_change_password"), rows.getObject("created_at", LocalDateTime.class),
                rows.getObject("deactivated_at", LocalDateTime.class), rows.getInt("upcoming"));
    }
}
