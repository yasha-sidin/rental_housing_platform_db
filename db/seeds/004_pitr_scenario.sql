SET search_path = application, public;

INSERT INTO users (username, phone_number, email, status)
VALUES ('pitr_guard_user', '+10000000999', 'pitr_guard_user@example.com', 'active')
ON CONFLICT (username) DO UPDATE
    SET status = 'active',
        email = EXCLUDED.email;

SELECT 'PITR marker user is present before logical error' AS check_name,
       id,
       username,
       status
FROM users
WHERE username = 'pitr_guard_user';
