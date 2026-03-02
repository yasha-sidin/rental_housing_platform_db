-- V003: Create users and RBAC relation tables.
-- This migration wires users to roles and roles to permissions.

-- Main user account table.
CREATE TABLE users (
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(128) UNIQUE NOT NULL,
    phone_number  VARCHAR(128) UNIQUE NOT NULL,
    email         VARCHAR(128) UNIQUE,
    register_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    status        user_status NOT NULL
);

-- Many-to-many link between roles and permissions.
CREATE TABLE role_permissions (
    role_id       BIGINT NOT NULL REFERENCES roles (id),
    permission_id BIGINT NOT NULL REFERENCES permissions (id),
    PRIMARY KEY (role_id, permission_id)
);

-- Seed role-permission matrix from the technical specification.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM (
    VALUES
        -- GUEST
        ('guest', 'listing.read'),
        ('guest', 'booking.create'),
        ('guest', 'booking.read'),
        ('guest', 'booking.cancel'),
        ('guest', 'payment.create'),
        ('guest', 'payment.read'),
        ('guest', 'review.create'),
        ('guest', 'review.read'),

        -- OWNER
        ('owner', 'listing.create'),
        ('owner', 'listing.read'),
        ('owner', 'listing.update'),
        ('owner', 'listing.delete'),
        ('owner', 'availability.update'),
        ('owner', 'price_rule.create'),
        ('owner', 'price_rule.update'),
        ('owner', 'price_rule.delete'),
        ('owner', 'booking.read'),
        ('owner', 'booking.update'),
        ('owner', 'report.read'),

        -- ADMIN
        ('admin', 'user.read'),
        ('admin', 'user.update'),
        ('admin', 'listing.read'),
        ('admin', 'listing.update'),
        ('admin', 'listing.delete'),
        ('admin', 'booking.read'),
        ('admin', 'booking.update'),
        ('admin', 'booking.cancel'),
        ('admin', 'payment.read'),
        ('admin', 'review.read'),
        ('admin', 'review.moderate'),
        ('admin', 'review.delete'),
        ('admin', 'report.read')
) AS x(role_name, permission_name)
JOIN roles r ON r.name = x.role_name
JOIN permissions p ON p.name = x.permission_name
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Many-to-many link between users and roles.
CREATE TABLE user_roles (
    user_id BIGINT NOT NULL REFERENCES users (id),
    role_id BIGINT NOT NULL REFERENCES roles (id),
    PRIMARY KEY (user_id, role_id)
);