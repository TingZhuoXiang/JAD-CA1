# JAD-CA1 setup and team handoff

Phase 1 provides Volunteer registration, login and logout. Phase 2 adds Admin event management, Volunteer administration and rosters. Phase 3 adds Volunteer profile editing, event browsing and signup, My signups, confirmed withdrawal and account deactivation.

## Run locally

1. Accept the GitHub collaborator invitation, then clone the repository.

   ```sh
   git clone https://github.com/TingZhuoXiang/JAD-CA1.git
   cd JAD-CA1
   ```

2. In Eclipse IDE for Enterprise Java and Web Developers, open the clone's `Code/` folder as your workspace. Create a **Dynamic Web Project** named **JAD-CA1** at the existing `Code/JAD-CA1/` location. Use **Java 25**, **Dynamic Web Module 6.0**, and the **Apache Tomcat v10.1** runtime. Set the source folder to `src/main/java`, the output folder to `build/classes`, the content directory to `src/main/webapp`, and the context root to `JAD-CA1`. Leave **Generate web.xml** unchecked so Eclipse keeps the shared file.
3. Put your local **MySQL Connector/J** JAR in `src/main/webapp/WEB-INF/lib/` inside the project and refresh it in Eclipse. In MySQL Workbench, connect to your local MySQL 8 server. To create demo accounts, execute `SET @jad_seed_demo = TRUE;` in that connection and then run [setup.sql](database/setup.sql) in the same connection.
4. In Eclipse's **Servers** view, create an **Apache Tomcat v10.1 Server**, choose your installation folder, and add **JAD-CA1**. Start it once to generate the launch configuration. If using the Lectures TomEE installation and Eclipse cannot find `org.apache.catalina.startup.Bootstrap`, add `bin/bootstrap.jar` and `bin/tomcat-juli.jar` to **Run Configurations > Apache Tomcat > Classpath > User Entries**.
5. Open **Run Configurations > Apache Tomcat > Environment** and add these values using your own local MySQL settings. Apply and restart the server.

   | Setting | Example |
   | --- | --- |
   | `JAD_DB_URL` | `jdbc:mysql://localhost:52836/jad_ca1` if your MySQL port is 52836 |
   | `JAD_DB_USER` | Your local MySQL username |
   | `JAD_DB_PASSWORD` | Your local MySQL password |

6. Open [the local app](http://localhost:8080/JAD-CA1/). Sign in as `demo_admin` to reach the Admin landing page or `demo_volunteer` to reach the Volunteer page. Both use the public local demo password `CA1-sample-demo` if you enabled seed accounts.

## Updating your database

`setup.sql` can be run again at any time. It creates missing tables, adds new columns to a database made by an older version, and replaces the `sp_register_volunteer` procedure, without touching existing data. Run it as a MySQL account that can create tables and procedures (for example root in MySQL Workbench). The app's own login only needs `SELECT, INSERT, UPDATE, DELETE, EXECUTE` on `jad_ca1`.

## Where things are

- **Admin pages** (`src/main/webapp/admin/`): dashboard, events (list, create/edit, details and roster, cancel, delete) and volunteers (search, details/edit, deactivate, create account). The access filter allows only Admins here.
- **Volunteer pages** (`src/main/webapp/volunteer/`): Browse and search events, view event details and sign up, review upcoming signups and history, withdraw before the event starts, edit contact details, and deactivate your account.
- **`/account/change-password.jsp`**: any signed-in user. Accounts created by an Admin are sent here until they replace their temporary password.
- **Java** (`src/main/java/sg/edu/sp/jad/`): `Accounts`, `Events`, `Registrations` and `Volunteers` hold the SQL. Pages use `currentUser`, `Accounts.connect()` and `Web.token(...)` in each POST form's hidden `csrf` field.
- **Signup rules** live in the `sp_register_volunteer` stored procedure. Call `Registrations.register(eventId, volunteerId, actorId)` from any page that signs someone up.
- **JSP syntax:** this TomEE compiles JSPs at Java 11 level, so JSP scriptlets cannot use switch expressions, `instanceof` patterns, text blocks or records. Plain `.java` classes can.

See [docs/technical-document.md](docs/technical-document.md) for the architecture, database design, requirement mapping, setup and test evidence.

## End-to-end tests

Start the app against a seeded test database. In Git Bash, run these commands from the repository root using a MySQL client option file outside the repository:

```sh
CNF=/path/to/mysql-client.ini bash Code/JAD-CA1/tests/admin-tests.sh
CNF=/path/to/mysql-client.ini bash Code/JAD-CA1/tests/volunteer-tests.sh
```

Both suites create test accounts and events and leave test rows in the database. The Volunteer suite also accepts `JAD_TEST_DB` and `MYSQL_CLIENT` overrides. Its CLI and the running app must target the same schema.

Keep your MySQL credentials in the local Eclipse launch and use your own Git author identity for commits. Run normal Git commands from the clone root.
