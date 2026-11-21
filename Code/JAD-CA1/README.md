# JAD-CA1 setup and Admin handoff

Hi Aarya. Phase 1 provides Volunteer registration, login and logout, and separate protected landing pages for Admin and Volunteer. Your phase is the Admin side, including event CRUD, volunteer management and adding a volunteer to an event.

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

## Build the Admin pages

Put Admin pages and form handlers under `src/main/webapp/admin/`. That path is already protected. Use the `currentUser` request attribute for the signed-in account, `Accounts.connect()` for JDBC, and `Web.token(request.getSession(false))` in the hidden `csrf` field on POST forms. Use `accounts.id` as the foreign key for volunteer event registrations. Coordinate shared schema changes by adding them to `database/setup.sql`.

Keep your MySQL credentials in the local Eclipse launch and use your own Git author identity for commits. Run normal Git commands from the clone root.
