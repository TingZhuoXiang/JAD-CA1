package sg.edu.sp.jad;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeParseException;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

/** Screening events. Times are Singapore local time; see {@link #now()}. */
public final class Events {
    public static final ZoneId ZONE = ZoneId.of("Asia/Singapore");
    private static final DateTimeFormatter INPUT = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm");
    private static final DateTimeFormatter DISPLAY =
            DateTimeFormatter.ofPattern("EEE d MMM yyyy, h:mm a", Locale.ENGLISH);
    private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("h:mm a", Locale.ENGLISH);

    public enum Status { OPEN, CANCELLED }

    /** Which events a list shows. */
    public enum Filter { UPCOMING, PAST, CANCELLED, ALL }

    public enum StartOrder { DEFAULT, EARLIEST, LATEST }

    public record StartDateRange(LocalDate from, LocalDate to) {
        public static StartDateRange parse(String from, String to) {
            LocalDate first = parseDate(from);
            LocalDate last = parseDate(to);
            if (first != null && last != null && last.isBefore(first)) {
                throw new IllegalArgumentException("Event start date (to) must be on or after the from date.");
            }
            return new StartDateRange(first, last);
        }

        public boolean includes(LocalDate date) {
            return (from == null || !date.isBefore(from)) && (to == null || !date.isAfter(to));
        }

        private static LocalDate parseDate(String value) {
            if (value.isEmpty()) return null;
            if (value.matches("[1-9][0-9]{3}-[0-9]{2}-[0-9]{2}")) {
                try {
                    return LocalDate.parse(value);
                } catch (DateTimeParseException e) {
                    throw new IllegalArgumentException("Enter valid event start dates.", e);
                }
            }
            throw new IllegalArgumentException("Enter valid event start dates.");
        }
    }

    public record StartTimeRange(LocalTime from, LocalTime to) {
        public static StartTimeRange parse(String from, String to) {
            LocalTime first = parseTime(from);
            LocalTime last = parseTime(to);
            if (first != null && last != null && last.isBefore(first)) {
                throw new IllegalArgumentException("Event start time (to) must be at or after the from time.");
            }
            return new StartTimeRange(first, last);
        }

        private static LocalTime parseTime(String value) {
            if (value.isEmpty()) return null;
            if (value.matches("[0-9]{2}:[0-9]{2}")) {
                try {
                    return LocalTime.parse(value);
                } catch (DateTimeParseException e) {
                    throw new IllegalArgumentException("Enter valid event start times.", e);
                }
            }
            throw new IllegalArgumentException("Enter valid event start times.");
        }
    }

    public record Event(long id, String title, String location, String description,
            LocalDateTime startsAt, LocalDateTime endsAt, Status status, LocalDateTime cancelledAt,
            int activeSignups) {

        /** Signups, withdrawals and edits are allowed only before the event starts. */
        public boolean openForSignup(LocalDateTime now) {
            return status == Status.OPEN && now.isBefore(startsAt);
        }

        public String state(LocalDateTime now) {
            if (status == Status.CANCELLED) return "Cancelled";
            if (now.isBefore(startsAt)) return "Upcoming";
            if (now.isBefore(endsAt)) return "In progress";
            return "Completed";
        }

        public String when() {
            String end = startsAt.toLocalDate().equals(endsAt.toLocalDate())
                    ? endsAt.format(TIME) : endsAt.format(DISPLAY);
            return startsAt.format(DISPLAY) + " – " + end;
        }
    }

    /** Who created and cancelled an event, and when it was created and last changed. */
    public record Audit(String createdBy, LocalDateTime createdAt, LocalDateTime updatedAt, String cancelledBy) {

        /** True when the event changed after it was created (an edit or a cancellation). */
        public boolean changedSinceCreated() {
            return updatedAt.isAfter(createdAt);
        }
    }

    /** A validated create/edit form. */
    public record Form(String title, String location, String description, LocalDateTime startsAt,
            LocalDateTime endsAt) {}

    private Events() {}

    /** The one clock for business rules; never MySQL NOW(), whose time zone may differ. */
    public static LocalDateTime now() {
        return LocalDateTime.now(ZONE).truncatedTo(ChronoUnit.SECONDS);
    }

    public static String display(LocalDateTime time) {
        return time == null ? "" : time.format(DISPLAY);
    }

    /** Formats a time for an HTML datetime-local input. */
    public static String input(LocalDateTime time) {
        return time == null ? "" : time.format(INPUT);
    }

    /**
     * Validates raw form fields into {@code errors}; returns the form when there are none.
     * {@code original} is the event being edited, or null when creating.
     */
    public static Form validate(String title, String location, String description, String start,
            String end, Event original, Map<String, String> errors) {
        if (title.length() < 3 || title.length() > 120 || title.chars().anyMatch(Character::isISOControl)) {
            errors.put("title", "Enter a title of 3–120 characters.");
        }
        if (location.isBlank() || location.length() > 200 || location.chars().anyMatch(Character::isISOControl)) {
            errors.put("location", "Enter a location of up to 200 characters.");
        }
        if (description.length() > 2000) {
            errors.put("description", "Keep the description to 2000 characters.");
        }
        LocalDateTime startsAt = parse(start);
        LocalDateTime endsAt = parse(end);
        if (startsAt == null) {
            errors.put("startsAt", "Enter a valid start date and time.");
        } else if (!startsAt.isAfter(now()) && (original == null || !startsAt.equals(original.startsAt()))) {
            errors.put("startsAt", "The start must be in the future.");
        }
        if (endsAt == null) {
            errors.put("endsAt", "Enter a valid end date and time.");
        } else if (startsAt != null && !endsAt.isAfter(startsAt)) {
            errors.put("endsAt", "The end must be after the start.");
        }
        return errors.isEmpty() ? new Form(title, location, description, startsAt, endsAt) : null;
    }

    private static LocalDateTime parse(String value) {
        try {
            LocalDateTime time = LocalDateTime.parse(value, INPUT);
            return time.getYear() >= 2000 && time.getYear() <= 2100 ? time : null;
        } catch (DateTimeParseException e) {
            return null;
        }
    }

    public static long create(Form form, long adminId) throws SQLException {
        String sql = """
                INSERT INTO events (title, location, description, starts_at, ends_at, created_by)
                VALUES (?, ?, ?, ?, ?, ?)
                """;
        try (Connection db = Accounts.connect();
                PreparedStatement statement = db.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            bindForm(statement, form);
            statement.setLong(6, adminId);
            statement.executeUpdate();
            try (ResultSet keys = statement.getGeneratedKeys()) {
                keys.next();
                return keys.getLong(1);
            }
        }
    }

    /**
     * Saves edited details. Registrations are untouched. Returns false if the event was cancelled
     * or had started by the time of saving.
     */
    public static boolean update(long id, Form form) throws SQLException {
        String sql = """
                UPDATE events SET title = ?, location = ?, description = ?, starts_at = ?, ends_at = ?
                WHERE id = ? AND status = 'OPEN' AND starts_at > ?
                """;
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql)) {
            bindForm(statement, form);
            statement.setLong(6, id);
            statement.setObject(7, now());
            return statement.executeUpdate() == 1;
        }
    }

    private static void bindForm(PreparedStatement statement, Form form) throws SQLException {
        statement.setString(1, form.title());
        statement.setString(2, form.location());
        statement.setString(3, form.description());
        statement.setObject(4, form.startsAt());
        statement.setObject(5, form.endsAt());
    }

    /**
     * Cancels an upcoming event and every active signup for it in one transaction. Returns the
     * number of signups cancelled, or -1 if the event was not open and upcoming.
     */
    public static int cancel(long id, long adminId) throws SQLException {
        LocalDateTime now = now();
        try (Connection db = Accounts.connect()) {
            db.setAutoCommit(false);
            try {
                try (PreparedStatement lock = db.prepareStatement(
                        "SELECT id FROM events WHERE id = ? AND status = 'OPEN' AND starts_at > ? FOR UPDATE")) {
                    lock.setLong(1, id);
                    lock.setObject(2, now);
                    try (ResultSet rows = lock.executeQuery()) {
                        if (!rows.next()) {
                            db.rollback();
                            return -1;
                        }
                    }
                }
                try (PreparedStatement event = db.prepareStatement(
                        "UPDATE events SET status = 'CANCELLED', cancelled_at = ?, cancelled_by = ? WHERE id = ?")) {
                    event.setObject(1, now);
                    event.setLong(2, adminId);
                    event.setLong(3, id);
                    event.executeUpdate();
                }
                int cancelled = Registrations.cancelForEvent(db, id, adminId, now);
                db.commit();
                return cancelled;
            } catch (SQLException | RuntimeException e) {
                db.rollback();
                throw e;
            }
        }
    }

    /**
     * Permanently deletes an event and all of its signup rows in one transaction. Returns the number
     * of signup rows removed, or -1 if the event did not exist. Cancelling is the option that keeps
     * history; this is for events created by mistake or no longer needed at all.
     */
    public static int delete(long id) throws SQLException {
        try (Connection db = Accounts.connect()) {
            db.setAutoCommit(false);
            try {
                try (PreparedStatement lock = db.prepareStatement("SELECT id FROM events WHERE id = ? FOR UPDATE")) {
                    lock.setLong(1, id);
                    try (ResultSet rows = lock.executeQuery()) {
                        if (!rows.next()) {
                            db.rollback();
                            return -1;
                        }
                    }
                }
                int removed;
                try (PreparedStatement signups = db.prepareStatement("DELETE FROM event_registrations WHERE event_id = ?")) {
                    signups.setLong(1, id);
                    removed = signups.executeUpdate();
                }
                try (PreparedStatement event = db.prepareStatement("DELETE FROM events WHERE id = ?")) {
                    event.setLong(1, id);
                    event.executeUpdate();
                }
                db.commit();
                return removed;
            } catch (SQLException | RuntimeException e) {
                db.rollback();
                throw e;
            }
        }
    }

    /**
     * Returns who created and cancelled the event, or null if it does not exist. created_at and
     * updated_at are TIMESTAMP columns set by MySQL, so they are read as instants and converted to
     * Singapore time like every other time the app shows.
     */
    public static Audit audit(long id) throws SQLException {
        String sql = """
                SELECT creator.full_name AS created_by, e.created_at, e.updated_at,
                       canceller.full_name AS cancelled_by
                FROM events e
                JOIN accounts creator ON creator.id = e.created_by
                LEFT JOIN accounts canceller ON canceller.id = e.cancelled_by
                WHERE e.id = ?
                """;
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql)) {
            statement.setLong(1, id);
            try (ResultSet rows = statement.executeQuery()) {
                if (!rows.next()) return null;
                return new Audit(rows.getString("created_by"), singaporeTime(rows.getTimestamp("created_at")),
                        singaporeTime(rows.getTimestamp("updated_at")), rows.getString("cancelled_by"));
            }
        }
    }

    private static LocalDateTime singaporeTime(java.sql.Timestamp timestamp) {
        return timestamp.toInstant().atZone(ZONE).toLocalDateTime().truncatedTo(ChronoUnit.SECONDS);
    }

    /** Number of signup rows of any status for an event, shown before a delete. */
    public static int signupRecords(long id) throws SQLException {
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(
                "SELECT COUNT(*) FROM event_registrations WHERE event_id = ?")) {
            statement.setLong(1, id);
            try (ResultSet rows = statement.executeQuery()) {
                rows.next();
                return rows.getInt(1);
            }
        }
    }

    private static final String SELECT = """
            SELECT e.id, e.title, e.location, e.description, e.starts_at, e.ends_at, e.status,
                   e.cancelled_at,
                   (SELECT COUNT(*) FROM event_registrations r
                    WHERE r.event_id = e.id AND r.status = 'ACTIVE') AS active_signups
            FROM events e
            """;

    public static Event find(long id) throws SQLException {
        try (Connection db = Accounts.connect();
                PreparedStatement statement = db.prepareStatement(SELECT + " WHERE e.id = ?")) {
            statement.setLong(1, id);
            try (ResultSet rows = statement.executeQuery()) {
                return rows.next() ? read(rows) : null;
            }
        }
    }

    /** Searches title and location. Upcoming lists soonest first; the others newest first. */
    public static List<Event> search(String text, Filter filter) throws SQLException {
        return search(text, filter, new StartDateRange(null, null), new StartTimeRange(null, null),
                StartOrder.DEFAULT);
    }

    public static List<Event> search(String text, Filter filter, StartDateRange dates, StartTimeRange times,
            StartOrder order) throws SQLException {
        StringBuilder sql = new StringBuilder(SELECT).append(" WHERE 1 = 1");
        List<Object> params = new ArrayList<>();
        LocalDateTime now = now();
        switch (filter) {
            case UPCOMING -> { sql.append(" AND e.status = 'OPEN' AND e.starts_at > ?"); params.add(now); }
            case PAST -> { sql.append(" AND e.status = 'OPEN' AND e.starts_at <= ?"); params.add(now); }
            case CANCELLED -> sql.append(" AND e.status = 'CANCELLED'");
            case ALL -> { }
        }
        if (!text.isBlank()) {
            sql.append(" AND (e.title LIKE ? ESCAPE '!' OR e.location LIKE ? ESCAPE '!')");
            String pattern = like(text);
            params.add(pattern);
            params.add(pattern);
        }
        if (dates.from() != null) {
            sql.append(" AND e.starts_at >= ?");
            params.add(dates.from().atStartOfDay());
        }
        if (dates.to() != null) {
            sql.append(" AND e.starts_at <= ?");
            params.add(dates.to().atTime(23, 59, 59));
        }
        if (times.from() != null) {
            sql.append(" AND TIME(e.starts_at) >= ?");
            params.add(times.from());
        }
        if (times.to() != null) {
            sql.append(" AND TIME(e.starts_at) <= ?");
            params.add(times.to().withSecond(59));
        }
        boolean earliestFirst = order == StartOrder.EARLIEST
                || (order == StartOrder.DEFAULT && filter == Filter.UPCOMING);
        sql.append(earliestFirst ? " ORDER BY e.starts_at, e.id" : " ORDER BY e.starts_at DESC, e.id DESC");
        sql.append(" LIMIT 200");
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql.toString())) {
            for (int i = 0; i < params.size(); i++) {
                statement.setObject(i + 1, params.get(i));
            }
            List<Event> events = new ArrayList<>();
            try (ResultSet rows = statement.executeQuery()) {
                while (rows.next()) {
                    events.add(read(rows));
                }
            }
            return events;
        }
    }

    /** Counts for the Admin dashboard: upcoming events, active volunteers, upcoming signups. */
    public static Map<String, Integer> dashboardCounts() throws SQLException {
        String sql = """
                SELECT
                  (SELECT COUNT(*) FROM events WHERE status = 'OPEN' AND starts_at > ?) AS upcoming,
                  (SELECT COUNT(*) FROM accounts WHERE role = 'VOLUNTEER' AND active = TRUE) AS volunteers,
                  (SELECT COUNT(*) FROM event_registrations r JOIN events e ON e.id = r.event_id
                   WHERE r.status = 'ACTIVE' AND e.status = 'OPEN' AND e.starts_at > ?) AS signups
                """;
        LocalDateTime now = now();
        try (Connection db = Accounts.connect(); PreparedStatement statement = db.prepareStatement(sql)) {
            statement.setObject(1, now);
            statement.setObject(2, now);
            try (ResultSet rows = statement.executeQuery()) {
                rows.next();
                Map<String, Integer> counts = new LinkedHashMap<>();
                counts.put("upcoming", rows.getInt("upcoming"));
                counts.put("volunteers", rows.getInt("volunteers"));
                counts.put("signups", rows.getInt("signups"));
                return counts;
            }
        }
    }

    /** Turns search text into a LIKE pattern, escaping wildcards with '!'. */
    static String like(String text) {
        return "%" + text.strip().replace("!", "!!").replace("%", "!%").replace("_", "!_") + "%";
    }

    private static Event read(ResultSet rows) throws SQLException {
        return new Event(rows.getLong("id"), rows.getString("title"), rows.getString("location"),
                rows.getString("description"), rows.getObject("starts_at", LocalDateTime.class),
                rows.getObject("ends_at", LocalDateTime.class), Status.valueOf(rows.getString("status")),
                rows.getObject("cancelled_at", LocalDateTime.class), rows.getInt("active_signups"));
    }
}
