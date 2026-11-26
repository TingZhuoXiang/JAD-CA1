-- Optional demo data. Run setup.sql with @jad_seed_demo = TRUE first to create demo_admin.
-- Search for "Demo Grid:" in Events to see these ten events across two pages.
-- Re-running skips existing demo titles and leaves their dates and status as saved.
USE jad_ca1;

SET @event_seed_admin_id = (
    SELECT id FROM accounts WHERE username = 'demo_admin' AND role = 'ADMIN' AND active = TRUE
);
SET @event_seed_date = DATE(UTC_TIMESTAMP() + INTERVAL 8 HOUR);

INSERT INTO events (title, location, description, starts_at, ends_at, status, created_by)
SELECT sample.title, sample.location, sample.description,
       TIMESTAMP(DATE_ADD(@event_seed_date, INTERVAL sample.days_ahead DAY), sample.start_time),
       TIMESTAMP(DATE_ADD(@event_seed_date, INTERVAL sample.days_ahead DAY), sample.end_time),
       'OPEN', @event_seed_admin_id
FROM (
    SELECT 'Demo Grid: Clementi community screening' AS title, 'Clementi Community Centre' AS location,
           'Visual acuity checks for residents.' AS description,
           2 AS days_ahead, '09:00:00' AS start_time, '12:00:00' AS end_time
    UNION ALL
    SELECT 'Demo Grid: Punggol family screening', 'Punggol Regional Library',
           'Vision checks for children and their caregivers.', 3, '14:00:00', '17:00:00'
    UNION ALL
    SELECT 'Demo Grid: Queenstown senior screening', 'Queenstown Community Centre',
           'Near-vision checks for older residents.', 5, '08:30:00', '11:30:00'
    UNION ALL
    SELECT 'Demo Grid: Serangoon evening screening', 'Serangoon Community Club',
           'After-work screening for nearby residents.', 6, '18:30:00', '20:30:00'
    UNION ALL
    SELECT 'Demo Grid: Woodlands school screening', 'Woodlands Community Club',
           'Vision screening for primary school pupils.', 8, '09:00:00', '12:00:00'
    UNION ALL
    SELECT 'Demo Grid: Ang Mo Kio outreach', 'Ang Mo Kio Community Centre',
           'Walk-in screening with a volunteer assistance desk.', 10, '10:30:00', '13:30:00'
    UNION ALL
    SELECT 'Demo Grid: Bukit Batok afternoon screening', 'Bukit Batok Community Club',
           'Distance and near-vision checks for adults.', 12, '15:00:00', '18:00:00'
    UNION ALL
    SELECT 'Demo Grid: Pasir Ris family screening', 'Pasir Ris Elias Community Club',
           'Short vision checks and eye-care information for families.', 15, '09:30:00', '12:30:00'
    UNION ALL
    SELECT 'Demo Grid: Bishan senior screening', 'Bishan Community Club',
           'Near-vision screening and booking assistance for seniors.', 18, '13:00:00', '16:00:00'
    UNION ALL
    SELECT 'Demo Grid: Yishun evening screening', 'Nee Soon Central Community Club',
           'Evening vision checks for residents and shift workers.', 21, '18:00:00', '20:30:00'
) AS sample
WHERE @event_seed_admin_id IS NOT NULL
  AND NOT EXISTS (SELECT 1 FROM events WHERE events.title = sample.title);

SELECT ROW_COUNT() AS inserted_events,
       CASE WHEN @event_seed_admin_id IS NULL
            THEN 'An active demo_admin is required. See the setup instructions above.'
            ELSE 'Search Events for Demo Grid: to find the seeded events.'
       END AS message;

SET @event_seed_admin_id = NULL;
SET @event_seed_date = NULL;
