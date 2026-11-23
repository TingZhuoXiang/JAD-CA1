-- JAD CA1 database setup. Safe to re-run: it creates what is missing and upgrades older copies.
-- To add the demo accounts, events and signups, run SET @jad_seed_demo = TRUE; in the same
-- connection first. Run as a MySQL account that can create tables and procedures in jad_ca1.
CREATE DATABASE IF NOT EXISTS jad_ca1 CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE jad_ca1;

CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(32) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    contact_number VARCHAR(20) NOT NULL,
    email VARCHAR(254) NOT NULL,
    password_hash VARCHAR(150) NOT NULL,
    role ENUM('ADMIN', 'VOLUNTEER') NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    must_change_password BOOLEAN NOT NULL DEFAULT FALSE,
    deactivated_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_accounts_username (username),
    UNIQUE KEY uq_accounts_email (email)
) ENGINE=InnoDB;

-- Upgrade databases created by the phase 1 script (MySQL 8.0 has no ADD COLUMN IF NOT EXISTS).
SET @jad_sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE()
        AND table_name = 'accounts' AND column_name = 'must_change_password') = 0,
    'ALTER TABLE accounts ADD COLUMN must_change_password BOOLEAN NOT NULL DEFAULT FALSE AFTER active',
    'DO 0');
PREPARE jad_stmt FROM @jad_sql; EXECUTE jad_stmt; DEALLOCATE PREPARE jad_stmt;
SET @jad_sql = IF((SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE()
        AND table_name = 'accounts' AND column_name = 'deactivated_at') = 0,
    'ALTER TABLE accounts ADD COLUMN deactivated_at DATETIME NULL AFTER must_change_password',
    'DO 0');
PREPARE jad_stmt FROM @jad_sql; EXECUTE jad_stmt; DEALLOCATE PREPARE jad_stmt;
SET @jad_sql = NULL;

-- Event times are Singapore local time. The application passes "now" in as a parameter so the
-- signup cutoff never depends on the MySQL server's time zone.
CREATE TABLE IF NOT EXISTS events (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(120) NOT NULL,
    location VARCHAR(200) NOT NULL,
    description VARCHAR(2000) NOT NULL DEFAULT '',
    starts_at DATETIME NOT NULL,
    ends_at DATETIME NOT NULL,
    status ENUM('OPEN', 'CANCELLED') NOT NULL DEFAULT 'OPEN',
    cancelled_at DATETIME NULL,
    cancelled_by BIGINT NULL,
    created_by BIGINT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_events_created_by FOREIGN KEY (created_by) REFERENCES accounts (id),
    CONSTRAINT fk_events_cancelled_by FOREIGN KEY (cancelled_by) REFERENCES accounts (id),
    CONSTRAINT chk_events_time CHECK (ends_at > starts_at),
    KEY ix_events_status_start (status, starts_at)
) ENGINE=InnoDB;

-- One row per signup. Withdrawing or cancelling ends the row; rejoining inserts a new row, so the
-- rows for a volunteer and event are the full history. active_flag is 1 only for ACTIVE rows and
-- NULL otherwise; MySQL allows repeated NULLs in a unique key, so the key below permits at most
-- one ACTIVE signup per volunteer per event while keeping any number of ended rows.
CREATE TABLE IF NOT EXISTS event_registrations (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    event_id BIGINT NOT NULL,
    volunteer_id BIGINT NOT NULL,
    status ENUM('ACTIVE', 'WITHDRAWN', 'CANCELLED') NOT NULL DEFAULT 'ACTIVE',
    end_reason ENUM('WITHDRAWN_BY_VOLUNTEER', 'REMOVED_BY_ADMIN', 'EVENT_CANCELLED',
        'VOLUNTEER_DEACTIVATED') NULL,
    registered_by BIGINT NOT NULL,
    registered_at DATETIME NOT NULL,
    ended_by BIGINT NULL,
    ended_at DATETIME NULL,
    active_flag TINYINT AS (IF(status = 'ACTIVE', 1, NULL)) STORED,
    CONSTRAINT fk_reg_event FOREIGN KEY (event_id) REFERENCES events (id),
    CONSTRAINT fk_reg_volunteer FOREIGN KEY (volunteer_id) REFERENCES accounts (id),
    CONSTRAINT fk_reg_registered_by FOREIGN KEY (registered_by) REFERENCES accounts (id),
    CONSTRAINT fk_reg_ended_by FOREIGN KEY (ended_by) REFERENCES accounts (id),
    CONSTRAINT chk_reg_end CHECK ((status = 'ACTIVE') = (end_reason IS NULL)),
    UNIQUE KEY uq_reg_one_active (event_id, volunteer_id, active_flag),
    KEY ix_reg_volunteer (volunteer_id, status)
) ENGINE=InnoDB;

-- The one signup rule for both roles. Admin "add to roster" and Volunteer self-signup both call
-- this, so eligibility can't drift between the two screens. Rejections raise SQLSTATE 45000 with
-- a message the page shows as is. Locking the event and account rows serialises a signup with a
-- concurrent event cancellation or volunteer deactivation.
DROP PROCEDURE IF EXISTS sp_register_volunteer;
DELIMITER $$
CREATE PROCEDURE sp_register_volunteer(IN p_event_id BIGINT, IN p_volunteer_id BIGINT,
                                       IN p_actor_id BIGINT, IN p_now DATETIME)
BEGIN
    DECLARE v_event_status VARCHAR(16);
    DECLARE v_starts_at DATETIME;
    DECLARE v_role VARCHAR(16);
    DECLARE v_active BOOLEAN;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT status, starts_at INTO v_event_status, v_starts_at
        FROM events WHERE id = p_event_id FOR UPDATE;
    IF v_event_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'That event does not exist.';
    END IF;
    IF v_event_status <> 'OPEN' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This event has been cancelled.';
    END IF;
    IF p_now >= v_starts_at THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Signups closed when this event started.';
    END IF;

    SELECT role, active INTO v_role, v_active
        FROM accounts WHERE id = p_volunteer_id FOR UPDATE;
    IF v_role IS NULL OR v_role <> 'VOLUNTEER' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'That volunteer does not exist.';
    END IF;
    IF NOT v_active THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'That volunteer account is deactivated.';
    END IF;

    IF EXISTS (SELECT 1 FROM event_registrations WHERE event_id = p_event_id
               AND volunteer_id = p_volunteer_id AND status = 'ACTIVE') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This volunteer is already signed up for this event.';
    END IF;

    INSERT INTO event_registrations (event_id, volunteer_id, registered_by, registered_at)
    VALUES (p_event_id, p_volunteer_id, p_actor_id, p_now);
    COMMIT;
END$$
DELIMITER ;

-- Local demo only. The accounts use a public demo password.
INSERT INTO accounts (username, full_name, contact_number, email, password_hash, role)
SELECT sample.username, sample.full_name, sample.contact_number, sample.email,
       sample.password_hash, sample.role
FROM (
    SELECT 'demo_admin' AS username, 'Demo Admin' AS full_name, '80000001' AS contact_number,
           'demo-admin@example.test' AS email,
           'pbkdf2-sha256:600000:1Km9nhMLHriBIrmsp428og==:+rzafFS0r+LZWZUEPhVZIKQuV6CQ0ZeiVLiKaiB7H/w=' AS password_hash,
           'ADMIN' AS role
    UNION ALL
    SELECT 'demo_volunteer', 'Demo Volunteer', '80000002', 'demo-volunteer@example.test',
           'pbkdf2-sha256:600000:gb53GoIrk5opTs6XjV/2Dw==:vQK+ApBVqWlTENIqxgWatGD6L3mpRYU8MB+SKejvBkY=',
           'VOLUNTEER'
) AS sample
WHERE COALESCE(@jad_seed_demo, FALSE) = TRUE
ON DUPLICATE KEY UPDATE id = accounts.id;

-- Demo events relative to the day the script runs: two upcoming, one cancelled, one past.
INSERT INTO events (title, location, description, starts_at, ends_at, status, cancelled_at,
                    cancelled_by, created_by)
SELECT sample.title, sample.location, sample.description, sample.starts_at, sample.ends_at,
       sample.status, IF(sample.status = 'CANCELLED', NOW(), NULL),
       IF(sample.status = 'CANCELLED', admin.id, NULL), admin.id
FROM (
    SELECT 'Demo: Tampines community screening' AS title, 'Tampines Hub, Level 2 Hall' AS location,
           'Basic visual acuity and near-vision checks for residents aged 40 and above.' AS description,
           TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '09:00') AS starts_at,
           TIMESTAMP(CURDATE() + INTERVAL 14 DAY, '13:00') AS ends_at, 'OPEN' AS status
    UNION ALL
    SELECT 'Demo: Jurong West school screening', 'Jurong West Primary School',
           'Vision screening for Primary 1 and 2 pupils.',
           TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '08:30'),
           TIMESTAMP(CURDATE() + INTERVAL 30 DAY, '12:30'), 'OPEN'
    UNION ALL
    SELECT 'Demo: Bedok senior centre screening', 'Bedok Senior Activity Centre',
           'Cancelled because the venue became unavailable.',
           TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '10:00'),
           TIMESTAMP(CURDATE() + INTERVAL 21 DAY, '14:00'), 'CANCELLED'
    UNION ALL
    SELECT 'Demo: Toa Payoh void deck screening', 'Blk 177 Toa Payoh Central',
           'Past event kept for history.',
           TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '09:00'),
           TIMESTAMP(CURDATE() - INTERVAL 10 DAY, '12:00'), 'OPEN'
) AS sample
JOIN accounts AS admin ON admin.username = 'demo_admin'
WHERE COALESCE(@jad_seed_demo, FALSE) = TRUE
  AND NOT EXISTS (SELECT 1 FROM events WHERE events.title = sample.title);

-- Demo signups for demo_volunteer: one upcoming and one past.
INSERT INTO event_registrations (event_id, volunteer_id, registered_by, registered_at)
SELECT e.id, v.id, v.id, e.starts_at - INTERVAL 7 DAY
FROM events AS e
JOIN accounts AS v ON v.username = 'demo_volunteer'
WHERE COALESCE(@jad_seed_demo, FALSE) = TRUE
  AND e.title IN ('Demo: Tampines community screening', 'Demo: Toa Payoh void deck screening')
  AND NOT EXISTS (SELECT 1 FROM event_registrations AS r WHERE r.event_id = e.id AND r.volunteer_id = v.id);

SET @jad_seed_demo = NULL;
