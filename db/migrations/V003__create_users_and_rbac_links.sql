-- V003: пользователи и связующие таблицы RBAC.

-- Основная таблица учетных записей пользователей.
CREATE TABLE users
(
    id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    username      VARCHAR(128) UNIQUE NOT NULL,
    phone_number  VARCHAR(128) UNIQUE NOT NULL,
    email         VARCHAR(128) UNIQUE,
    register_date TIMESTAMPTZ         NOT NULL DEFAULT now(),
    status        user_status         NOT NULL,
    -- Проверка запрещает пустой логин (включая строку из пробелов).
    CONSTRAINT chk_users_username_not_blank CHECK (btrim(username) <> ''),
    -- Проверка запрещает пустой номер телефона.
    CONSTRAINT chk_users_phone_not_blank CHECK (btrim(phone_number) <> ''),
    -- Проверка запрещает пустой email, если значение передано.
    CONSTRAINT chk_users_email_not_blank CHECK (email IS NULL OR btrim(email) <> '')
);

-- Связь many-to-many между ролями и разрешениями.
CREATE TABLE role_permissions
(
    role_id       BIGINT NOT NULL REFERENCES roles (id),
    permission_id BIGINT NOT NULL REFERENCES permissions (id),
    PRIMARY KEY (role_id, permission_id)
);

-- Заполнение матрицы role -> permission по ТЗ.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM (VALUES
          -- Роль GUEST
          ('guest', 'listing.read'),
          ('guest', 'booking.create'),
          ('guest', 'booking.read'),
          ('guest', 'booking.cancel'),
          ('guest', 'payment.create'),
          ('guest', 'payment.read'),
          ('guest', 'review.create'),
          ('guest', 'review.read'),

          -- Роль OWNER
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

          -- Роль ADMIN
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
          ('admin', 'report.read')) AS x(role_name, permission_name)
         JOIN roles r ON r.name = x.role_name
         JOIN permissions p ON p.name = x.permission_name
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Связь many-to-many между пользователями и ролями.
CREATE TABLE user_roles
(
    user_id BIGINT NOT NULL REFERENCES users (id),
    role_id BIGINT NOT NULL REFERENCES roles (id),
    PRIMARY KEY (user_id, role_id)
);
