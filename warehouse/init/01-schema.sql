-- Sample "dirty" warehouse: raw, un-modeled data straight off two SaaS exports.
--
-- The same real-world humans show up in BOTH domains, with totally different
-- table shapes, id schemes and column names:
--
--   events.*  -- export from a community-events platform (Luma-style)
--   crm.*     -- export from a marketing / CRM tool
--
-- Deliberately messy, the way connector output usually is:
--   * coded columns that only make sense via a lookup/decode table
--   * JSON blobs stuffed into text columns
--   * mixed date formats, mixed boolean spellings
--   * junk null placeholders ('N/A', 'NULL', '-', '')
--   * inconsistent casing / stray whitespace
--   * soft-deleted "tombstone" rows that should be filtered out
--   * a duplicate contact under the same email
--   * NO declared foreign keys -- the relationships have to be inferred
--
-- Nothing here is constrained beyond a primary key, on purpose.

CREATE SCHEMA IF NOT EXISTS events;
CREATE SCHEMA IF NOT EXISTS crm;

-- ========================================================================
-- EVENTS DOMAIN
-- ========================================================================

-- Decode table: events.evt_events.category_code -> label
CREATE TABLE events.evt_categories (
  code  integer PRIMARY KEY,
  label text NOT NULL
);

CREATE TABLE events.evt_events (
  event_id      text PRIMARY KEY,
  title         text,     -- inconsistent casing / whitespace
  category_code integer,  -- -> events.evt_categories.code
  venue         text,     -- JSON object as text: {"name":..,"city":..,"country":..}
  starts_at     text,     -- mixed formats: ISO, US, "14-Apr-2026", junk
  capacity      text,     -- mostly numbers, but also '', 'N/A', '-5'
  is_published  text,     -- Y / N / true / 1 / 0 / yes / TRUE
  host_email    text,
  _deleted      boolean DEFAULT false  -- soft delete
);

-- Events-domain view of a person.
CREATE TABLE events.evt_people (
  uid       text PRIMARY KEY,
  full_name text,  -- single column, messy casing/whitespace
  email     text,  -- some 'N/A'
  phone     text,  -- wildly varied formats + null placeholders
  created   text
);

CREATE TABLE events.evt_registrations (
  reg_id        text PRIMARY KEY,
  event_id      text,  -- -> events.evt_events.event_id
  person_ref    text,  -- -> events.evt_people.uid
  registered_at text,
  status        text,  -- going / waitlist / cancelled  (+ dirty variants)
  checked_in    text   -- 1 / 0 / '' / Y
);

-- Decode table for the coded custom-field answers below.
CREATE TABLE events.evt_custom_fields (
  field_key  text PRIMARY KEY,  -- e.g. 'cf_1021'
  question   text,              -- e.g. 'Dietary restrictions'
  field_type text               -- single / multi / text
);

-- Coded answers, one row per (registration, field). Answers are JSON text:
--   single -> {"value":"L"}
--   multi  -> [{"value":"Vegan"},{"value":"Gluten-free"}]
CREATE TABLE events.evt_custom_responses (
  reg_id    text,  -- -> events.evt_registrations.reg_id
  field_key text,  -- -> events.evt_custom_fields.field_key
  answer    text
);

-- ========================================================================
-- CRM DOMAIN  (same humans, different shape and id scheme)
-- ========================================================================

-- Decode table: crm.crm_contacts.lifecycle_code -> stage
CREATE TABLE crm.crm_lifecycle_stages (
  code  integer PRIMARY KEY,
  stage text NOT NULL
);

CREATE TABLE crm.crm_companies (
  company_id integer PRIMARY KEY,
  name       text,
  domain     text,
  region     text,
  tier       text
);

CREATE TABLE crm.crm_contacts (
  contact_id     integer PRIMARY KEY,
  first          text,     -- name split into first/last here, unlike events
  last           text,
  email_address  text,     -- the only (dirty) bridge back to events.evt_people
  mobile         text,
  company_id     integer,  -- -> crm.crm_companies.company_id
  lifecycle_code integer,  -- -> crm.crm_lifecycle_stages.code
  lead_source    text,
  subscribed     text,     -- Y / N / unsub
  is_deleted     smallint DEFAULT 0  -- soft delete (1 = gone)
);
