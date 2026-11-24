package sg.edu.sp.jad;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.ToLongFunction;

/**
 * Event signups. Shared by the Admin roster and Volunteer self-service: both sign up through
 * {@link #register}, which calls the sp_register_volunteer procedure holding the eligibility rules.
 */
public final class Registrations {
    private static final String RULE_VIOLATION = "45000";
    private static final int DUPLICATE_KEY = 1062;

    public record Signup(long id, long eventId, String eventTitle, LocalDateTime startsAt,
            LocalDateTime endsAt, Events.Status eventStatus, long volunteerId, String volunteerName,
            String username, String email, String contactNumber, boolean volunteerActive,
            String status, String endReason, LocalDateTime registeredAt, boolean selfRegistered,
            LocalDateTime endedAt) {

        public boolean active() {
            return "ACTIVE".equals(status);
        }

        public String statusLabel() {
            if (active()) return "Signed up";
            return switch (endReason) {
                case "WITHDRAWN_BY_VOLUNTEER" -> "Withdrawn";
                case "REMOVED_BY_ADMIN" -> "Removed by Admin";
                case "EVENT_CANCELLED" -> "Event cancelled";
                case "VOLUNTEER_DEACTIVATED" -> "Account deactivated";
                default -> status;
            };
        }

        /** An active signup can be ended only while the event is open and has not started. */
        public boolean endable(LocalDateTime now) {
            return active() && eventStatus == Events.Status.OPEN && now.isBefore(startsAt);
        }

        public String volunteerCode() {
            return "V-" + volunteerId;
        }
    }

    public record SignupSummary(Signup signup, boolean previouslyWithdrawn) {}

    /** Keeps the latest attempt for each event or volunteer in the input's group order. */
    public static List<SignupSummary> summarize(List<Signup> attempts, ToLongFunction<Signup> groupKey) {
        Map<Long, Signup> latest = new LinkedHashMap<>();
        Set<Long> withdrawals = new HashSet<>();
        for (Signup attempt : attempts) {
            long key = groupKey.applyAsLong(attempt);
            // IDs reflect insertion order even when a demo signup has a future timestamp.
            latest.merge(key, attempt, (current, candidate) -> current.id() > candidate.id() ? current : candidate);
            if ("WITHDRAWN_BY_VOLUNTEER".equals(attempt.endReason())) {
                withdrawals.add(key);
            }
        }
        List<SignupSummary> summaries = new ArrayList<>();
        latest.forEach((key, signup) -> summaries.add(new SignupSummary(signup,
                signup.active() && withdrawals.contains(key))));
        return summaries;
    }

    private Registrations() {}

    /**
     * Signs a volunteer up for an event. Returns null on success, or the reason it was refused.
     * {@code actorId} is the Admin adding them, or the volunteer themself.
     */
    public static String register(long eventId, long volunteerId, long actorId) throws SQLException {
        try (Connection db = Accounts.connect();
                PreparedStatement statement = db.prepareStatement("CALL sp_register_volunteer(?, ?, ?, ?)")) {
            statement.setLong(1, eventId);
            statement.setLong(2, volunteerId);
            statement.setLong(3, actorId);
            statement.setObject(4, Events.now());
            statement.execute();
            return null;
        } catch (SQLException e) {
            if (RULE_VIOLATION.equals(e.getSQLState())) {
                return e.getMessage();
            }
            if (e.getErrorCode() == DUPLICATE_KEY) {
                return "This volunteer is already signed up for this event.";
            }
            throw e;
        }
    }

    /** An Admin removes someone from an upcoming event's roster. Returns false if not allowed. */
    public static boolean removeByAdmin(long registrationId, long eventId, long adminId) throws SQLException {
        return end(registrationId, "r.event_id = ?", eventId, "WITHDRAWN", "REMOVED_BY_ADMIN", adminId);
    }

    /**
     * A volunteer withdraws their own signup. The ownership check is in the WHERE clause, so a
     * volunteer can never end someone else's signup. Returns false if not allowed.
     */
    public static boolean withdrawByVolunteer(long registrationId, long volunteerId) throws SQLException {
        return end(registrationId, "r.volunteer_id = ?", volunteerId, "WITHDRAWN", "WITHDRAWN_BY_VOLUNTEER",
                volunteerId);
    }

    private static boolean end(long registrationId, String scope, long scopeId, String status, String reason,
            long actorId) throws SQLException {
        String sql = """
                UPDATE event_registrations r JOIN events e ON e.id = r.event_id
                SET r.status = ?, r.end_reason = ?, r.ended_by = ?, r.ended_at = ?
                WHERE r.id = ? AND %s AND r.status = 'ACTIVE' AND e.status = 'OPEN' AND e.starts_at > ?
                """.formatted(scope);
        LocalDateTime now = Events.now();
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql)) {
            statement.setString(1, status);
            statement.setString(2, reason);
            statement.setLong(3, actorId);
            statement.setObject(4, now);
            statement.setLong(5, registrationId);
            statement.setLong(6, scopeId);
            statement.setObject(7, now);
            return statement.executeUpdate() == 1;
        }
    }

    /** Cancels every active signup for an event, inside the caller's transaction. */
    static int cancelForEvent(Connection db, long eventId, long adminId, LocalDateTime now) throws SQLException {
        try (PreparedStatement statement = db.prepareStatement("""
                UPDATE event_registrations
                SET status = 'CANCELLED', end_reason = 'EVENT_CANCELLED', ended_by = ?, ended_at = ?
                WHERE event_id = ? AND status = 'ACTIVE'
                """)) {
            statement.setLong(1, adminId);
            statement.setObject(2, now);
            statement.setLong(3, eventId);
            return statement.executeUpdate();
        }
    }

    /**
     * Cancels a volunteer's active signups for events that have not started, inside the caller's
     * transaction. Signups for past events stay as they are, as history.
     */
    static int cancelFutureForVolunteer(Connection db, long volunteerId, long adminId, LocalDateTime now)
            throws SQLException {
        try (PreparedStatement statement = db.prepareStatement("""
                UPDATE event_registrations r JOIN events e ON e.id = r.event_id
                SET r.status = 'CANCELLED', r.end_reason = 'VOLUNTEER_DEACTIVATED', r.ended_by = ?, r.ended_at = ?
                WHERE r.volunteer_id = ? AND r.status = 'ACTIVE' AND e.starts_at > ?
                """)) {
            statement.setLong(1, adminId);
            statement.setObject(2, now);
            statement.setLong(3, volunteerId);
            statement.setObject(4, now);
            return statement.executeUpdate();
        }
    }

    private static final String SELECT = """
            SELECT r.id, r.event_id, e.title, e.starts_at, e.ends_at, e.status AS event_status,
                   r.volunteer_id, a.full_name, a.username, a.email, a.contact_number, a.active,
                   r.status, r.end_reason, r.registered_at, r.registered_by = r.volunteer_id AS self_registered,
                   r.ended_at
            FROM event_registrations r
            JOIN events e ON e.id = r.event_id
            JOIN accounts a ON a.id = r.volunteer_id
            """;

    /** Everyone who has signed up for an event: active signups first, then history. */
    public static List<Signup> roster(long eventId) throws SQLException {
        return list(SELECT + " WHERE r.event_id = ? ORDER BY r.status = 'ACTIVE' DESC, a.full_name, r.registered_at DESC",
                eventId);
    }

    /** A volunteer's signups, newest event first. */
    public static List<Signup> forVolunteer(long volunteerId) throws SQLException {
        return list(SELECT + " WHERE r.volunteer_id = ? ORDER BY e.starts_at DESC, r.registered_at DESC, r.id DESC",
                volunteerId);
    }

    public static Signup findForVolunteer(long registrationId, long volunteerId) throws SQLException {
        List<Signup> matches = list(SELECT + " WHERE r.id = ? AND r.volunteer_id = ?", registrationId, volunteerId);
        return matches.isEmpty() ? null : matches.get(0);
    }

    public static Signup latestForEvent(long eventId, long volunteerId) throws SQLException {
        List<Signup> matches = list(SELECT + " WHERE r.event_id = ? AND r.volunteer_id = ? ORDER BY r.id DESC LIMIT 1",
                eventId, volunteerId);
        return matches.isEmpty() ? null : matches.get(0);
    }

    private static List<Signup> list(String sql, long... ids) throws SQLException {
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql)) {
            for (int i = 0; i < ids.length; i++) {
                statement.setLong(i + 1, ids[i]);
            }
            List<Signup> signups = new ArrayList<>();
            try (ResultSet rows = statement.executeQuery()) {
                while (rows.next()) {
                    signups.add(new Signup(rows.getLong("id"), rows.getLong("event_id"), rows.getString("title"),
                            rows.getObject("starts_at", LocalDateTime.class),
                            rows.getObject("ends_at", LocalDateTime.class),
                            Events.Status.valueOf(rows.getString("event_status")), rows.getLong("volunteer_id"),
                            rows.getString("full_name"), rows.getString("username"), rows.getString("email"),
                            rows.getString("contact_number"), rows.getBoolean("active"), rows.getString("status"),
                            rows.getString("end_reason"), rows.getObject("registered_at", LocalDateTime.class),
                            rows.getBoolean("self_registered"), rows.getObject("ended_at", LocalDateTime.class)));
                }
            }
            return signups;
        }
    }
}
