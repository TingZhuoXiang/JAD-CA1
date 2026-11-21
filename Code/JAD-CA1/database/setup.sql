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
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_accounts_username (username),
    UNIQUE KEY uq_accounts_email (email)
) ENGINE=InnoDB;

-- Local demo only. Run SET @jad_seed_demo = TRUE; in this connection before
-- running setup.sql to opt in. The accounts use a public demo password.
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

SET @jad_seed_demo = NULL;
