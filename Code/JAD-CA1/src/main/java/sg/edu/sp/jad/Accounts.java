package sg.edu.sp.jad;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.regex.Pattern;

public final class Accounts {
    public static final int MIN_PASSWORD_LENGTH = 8;
    public static final String REGISTRATION_PASSWORD_HINT = "Use " + MIN_PASSWORD_LENGTH
            + " to 128 characters with at least one lowercase letter, one uppercase letter, one digit and one symbol.";
    private static final Pattern USERNAME = Pattern.compile("[A-Za-z0-9_.-]{3,32}");
    private static final Pattern PASSWORD_SYMBOL = Pattern.compile("[\\p{P}\\p{S}]");

    public enum Role { ADMIN, VOLUNTEER }

    public record User(long id, String fullName, Role role, boolean mustChangePassword) {
        public String volunteerId() {
            return "V-" + id;
        }
    }

    private Accounts() {}

    public static Connection connect() throws SQLException {
        String url = System.getenv("JAD_DB_URL");
        String username = System.getenv("JAD_DB_USER");
        String password = System.getenv("JAD_DB_PASSWORD");
        if (url == null || !url.startsWith("jdbc:mysql://") || username == null
                || username.isBlank() || password == null) {
            throw new SQLException("Set JAD_DB_URL, JAD_DB_USER and JAD_DB_PASSWORD in the server environment.");
        }
        try {
            Class.forName("com.mysql.cj.jdbc.Driver");
        } catch (ClassNotFoundException e) {
            throw new SQLException("MySQL Connector/J is missing.", e);
        }
        return DriverManager.getConnection(url, username, password);
    }

    public static Map<String, String> validate(String username, String name, String phone,
            String email, String password, String confirmation) {
        Map<String, String> errors = validateNewAccount(username, name, phone, email);
        errors.putAll(validatePassword(password, confirmation));
        return errors;
    }

    public static Map<String, String> validateRegistration(String username, String name, String phone,
            String email, String password, String confirmation) {
        Map<String, String> errors = validate(username, name, phone, email, password, confirmation);
        if (!errors.containsKey("password")
                && (password.codePoints().noneMatch(Character::isLowerCase)
                        || password.codePoints().noneMatch(Character::isUpperCase)
                        || password.codePoints().noneMatch(Character::isDigit)
                        || !PASSWORD_SYMBOL.matcher(password).find())) {
            errors.put("password", REGISTRATION_PASSWORD_HINT);
        }
        return errors;
    }

    /** Checks the fields of a new account other than its password. */
    public static Map<String, String> validateNewAccount(String username, String name, String phone,
            String email) {
        Map<String, String> errors = new LinkedHashMap<>();
        if (!USERNAME.matcher(username).matches()) {
            errors.put("username", "Use 3–32 letters, digits, dots, underscores or hyphens.");
        }
        errors.putAll(validateProfile(name, phone, email));
        return errors;
    }

    /** Checks the contact fields, which an Admin may also edit on an existing volunteer. */
    public static Map<String, String> validateProfile(String name, String phone, String email) {
        Map<String, String> errors = new LinkedHashMap<>();
        if (name.isBlank() || name.length() > 100 || name.chars().anyMatch(Character::isISOControl)) {
            errors.put("fullName", "Enter your full name (up to 100 characters).");
        }
        if (phone.length() > 20 || !phone.matches("[+]?[0-9][0-9 ()-]*")
                || phone.chars().filter(Character::isDigit).count() < 8) {
            errors.put("contactNumber", "Enter a valid contact number with at least 8 digits.");
        }
        if (email.length() > 254 || !email.matches("[^\\s@]+@[^\\s@.]+(?:\\.[^\\s@.]+)+")) {
            errors.put("email", "Enter a valid email address.");
        }
        return errors;
    }

    public static Map<String, String> validatePassword(String password, String confirmation) {
        Map<String, String> errors = new LinkedHashMap<>();
        if (password.length() < MIN_PASSWORD_LENGTH || password.length() > 128 || password.isBlank()) {
            errors.put("password", "Use a password between " + MIN_PASSWORD_LENGTH + " and 128 characters.");
        } else if (!password.equals(confirmation)) {
            errors.put("confirmation", "The passwords do not match.");
        }
        return errors;
    }

    public static void registerVolunteer(String username, String name, String phone,
            String email, String password) throws SQLException {
        create(username, name, phone, email, password, Role.VOLUNTEER);
    }

    static void create(String username, String name, String phone, String email,
            String password, Role role) throws SQLException {
        create(username, name, phone, email, password, role, false);
    }

    /** Inserts an account and returns its id. */
    static long create(String username, String name, String phone, String email,
            String password, Role role, boolean mustChangePassword) throws SQLException {
        String sql = """
                INSERT INTO accounts (username, full_name, contact_number, email, password_hash, role,
                                      must_change_password)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """;
        String hash = Passwords.hash(password);
        try (Connection db = connect();
                PreparedStatement statement = db.prepareStatement(sql, Statement.RETURN_GENERATED_KEYS)) {
            statement.setString(1, canonical(username));
            statement.setString(2, name);
            statement.setString(3, phone);
            statement.setString(4, canonical(email));
            statement.setString(5, hash);
            statement.setString(6, role.name());
            statement.setBoolean(7, mustChangePassword);
            statement.executeUpdate();
            try (ResultSet keys = statement.getGeneratedKeys()) {
                keys.next();
                return keys.getLong(1);
            }
        }
    }

    public static User authenticate(String username, String password) throws SQLException {
        if (!USERNAME.matcher(username).matches() || password.length() > 128 || password.isEmpty()) {
            return null;
        }
        User user = null;
        String hash = null;
        try (Connection db = connect(); PreparedStatement statement = db.prepareStatement("""
                SELECT id, full_name, role, must_change_password, password_hash
                FROM accounts WHERE username = ? AND active = TRUE
                """)) {
            statement.setString(1, canonical(username));
            try (ResultSet rows = statement.executeQuery()) {
                if (rows.next()) {
                    user = readUser(rows);
                    hash = rows.getString("password_hash");
                }
            }
        }
        return Passwords.matches(password, hash) ? user : null;
    }

    public static User findActive(long id) throws SQLException {
        try (Connection db = connect(); PreparedStatement statement = db.prepareStatement(
                "SELECT id, full_name, role, must_change_password FROM accounts WHERE id = ? AND active = TRUE")) {
            statement.setLong(1, id);
            try (ResultSet rows = statement.executeQuery()) {
                return rows.next() ? readUser(rows) : null;
            }
        }
    }

    /**
     * Replaces the password after checking the current one, and clears the first-login flag.
     * Returns false if the current password is wrong.
     */
    public static boolean changePassword(long id, String current, String replacement) throws SQLException {
        String hash = null;
        try (Connection db = connect(); PreparedStatement statement = db.prepareStatement(
                "SELECT password_hash FROM accounts WHERE id = ? AND active = TRUE")) {
            statement.setLong(1, id);
            try (ResultSet rows = statement.executeQuery()) {
                if (rows.next()) {
                    hash = rows.getString(1);
                }
            }
        }
        if (current.length() > 128 || !Passwords.matches(current, hash)) {
            return false;
        }
        try (Connection db = connect(); PreparedStatement statement = db.prepareStatement(
                "UPDATE accounts SET password_hash = ?, must_change_password = FALSE WHERE id = ? AND active = TRUE")) {
            statement.setString(1, Passwords.hash(replacement));
            statement.setLong(2, id);
            return statement.executeUpdate() == 1;
        }
    }

    private static User readUser(ResultSet rows) throws SQLException {
        return new User(rows.getLong("id"), rows.getString("full_name"),
                Role.valueOf(rows.getString("role")), rows.getBoolean("must_change_password"));
    }

    static String canonical(String value) {
        return value.toLowerCase(Locale.ROOT);
    }
}
