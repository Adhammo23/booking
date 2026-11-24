
CREATE TABLE users (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(100) NOT NULL,
  full_name     VARCHAR(120) NOT NULL,
  role          VARCHAR(10) NOT NULL CHECK (role IN ('LEARNER','INSTRUCTOR','ADMIN')),
  created_at    TIMESTAMPTZ NOT NULL,
  CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE TABLE services (
  id               BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name             VARCHAR(100) NOT NULL,
  duration_minutes INT NOT NULL,
  active           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL,
  CONSTRAINT uq_services_name UNIQUE (name),
  CONSTRAINT ck_services_duration CHECK (duration_minutes BETWEEN 30 AND 120)
);

-- المدرّسين المؤهّلين لكل خدمة (many-to-many)
CREATE TABLE instructor_services (
  instructor_id BIGINT NOT NULL,
  service_id    BIGINT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL,
  PRIMARY KEY (instructor_id, service_id),
  CONSTRAINT fk_is_instructor FOREIGN KEY (instructor_id) REFERENCES users(id),
  CONSTRAINT fk_is_service    FOREIGN KEY (service_id)    REFERENCES services(id)
);
-- ملاحظة: كون instructor_id دوره INSTRUCTOR بيتفرض في الـservice، مش في الـDB.

CREATE TABLE slots (
  id            BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  instructor_id BIGINT NOT NULL,
  service_id    BIGINT NOT NULL,
  starts_at     TIMESTAMPTZ NOT NULL,   -- UTC
  ends_at       TIMESTAMPTZ NOT NULL,   -- UTC = starts_at + مدة الخدمة وقت النشر
  cancelled_at  TIMESTAMPTZ NULL,
  created_at    TIMESTAMPTZ NOT NULL,
  CONSTRAINT fk_slots_instructor FOREIGN KEY (instructor_id) REFERENCES users(id),
  CONSTRAINT fk_slots_service    FOREIGN KEY (service_id)    REFERENCES services(id),
  CONSTRAINT ck_slots_time CHECK (ends_at > starts_at)
);
CREATE INDEX ix_slots_instructor_time ON slots (instructor_id, starts_at, ends_at);
CREATE INDEX ix_slots_service_starts ON slots (service_id, starts_at);
CREATE INDEX ix_slots_starts ON slots (starts_at);

CREATE TABLE bookings (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  slot_id        BIGINT NOT NULL,   -- ما بيتغيّرش بعد الإنشاء
  learner_id     BIGINT NOT NULL,   -- ما بيتغيّرش بعد الإنشاء
  status         VARCHAR(11) NOT NULL CHECK (status IN ('CONFIRMED','CANCELLED','RESCHEDULED')),
  cancel_reason  VARCHAR(14) NULL CHECK (cancel_reason IN ('LEARNER','INSTRUCTOR','ADMIN','SLOT_CANCELLED')),
  rescheduled_to_booking_id BIGINT NULL,
  created_at     TIMESTAMPTZ NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL,

  CONSTRAINT fk_bookings_slot    FOREIGN KEY (slot_id)    REFERENCES slots(id),
  CONSTRAINT fk_bookings_learner FOREIGN KEY (learner_id) REFERENCES users(id),
  CONSTRAINT fk_bookings_resched FOREIGN KEY (rescheduled_to_booking_id) REFERENCES bookings(id)
);
-- R1: حجز CONFIRMED واحد بس لكل slot (partial unique index، مفيش generated column)
CREATE UNIQUE INDEX uq_one_active_booking_per_slot ON bookings (slot_id) WHERE status = 'CONFIRMED';
CREATE INDEX ix_bookings_learner ON bookings (learner_id, status);
CREATE INDEX ix_bookings_learner_created ON bookings (learner_id, created_at);
CREATE INDEX ix_bookings_slot ON bookings (slot_id);

-- سجل append-only: INSERT فقط
CREATE TABLE booking_events (
  id                 BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  booking_id         BIGINT NOT NULL,
  event_type         VARCHAR(15) NOT NULL CHECK (event_type IN ('BOOKED','CANCELLED','RESCHEDULED_OUT','RESCHEDULED_IN')),
  actor_user_id      BIGINT NOT NULL,
  actor_role         VARCHAR(10) NOT NULL CHECK (actor_role IN ('LEARNER','INSTRUCTOR','ADMIN')),
  reason             VARCHAR(14) NULL CHECK (reason IN ('LEARNER','INSTRUCTOR','ADMIN','SLOT_CANCELLED')),
  related_booking_id BIGINT NULL,
  created_at         TIMESTAMPTZ NOT NULL,
  CONSTRAINT fk_be_booking FOREIGN KEY (booking_id)         REFERENCES bookings(id),
  CONSTRAINT fk_be_actor   FOREIGN KEY (actor_user_id)      REFERENCES users(id),
  CONSTRAINT fk_be_related FOREIGN KEY (related_booking_id) REFERENCES bookings(id)
);
CREATE INDEX ix_be_booking ON booking_events (booking_id, created_at, id);