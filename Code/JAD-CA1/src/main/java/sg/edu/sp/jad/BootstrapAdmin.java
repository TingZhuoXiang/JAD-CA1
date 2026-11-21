package sg.edu.sp.jad;

import java.io.Console;
import java.sql.SQLException;
import java.util.Arrays;
import java.util.Map;

public final class BootstrapAdmin {
    private BootstrapAdmin() {}

    public static void main(String[] args) {
        Console console = System.console();
        if (console == null) {
            System.err.println("Run this command in an interactive terminal.");
            System.exit(1);
            return;
        }
        String username = console.readLine("Admin username: ");
        String name = console.readLine("Full name: ");
        String phone = console.readLine("Contact number: ");
        String email = console.readLine("Email: ");
        if (username == null || name == null || phone == null || email == null) {
            return;
        }
        char[] secret = console.readPassword("Password: ");
        char[] confirmation = console.readPassword("Confirm password: ");
        try {
            if (secret == null || confirmation == null) {
                return;
            }
            String password = new String(secret);
            Map<String, String> errors = Accounts.validate(username.strip(), name.strip(), phone.strip(),
                    email.strip(), password, new String(confirmation));
            if (!errors.isEmpty()) {
                errors.values().forEach(System.err::println);
                System.exit(1);
            }
            Accounts.create(username.strip(), name.strip(), phone.strip(), email.strip(), password, Accounts.Role.ADMIN);
            System.out.println("Admin account created.");
        } catch (SQLException e) {
            System.err.println("Admin account could not be created. Check database setup and whether the username or email is already in use.");
            System.exit(1);
        } finally {
            if (secret != null) Arrays.fill(secret, '\0');
            if (confirmation != null) Arrays.fill(confirmation, '\0');
        }
    }
}
