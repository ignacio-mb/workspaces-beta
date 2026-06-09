-- Dirty sample data. See 01-schema.sql for the intentional mess catalogue.

-- ========================================================================
-- EVENTS DOMAIN
-- ========================================================================

INSERT INTO events.evt_categories (code, label) VALUES
  (1, 'Meetup'),
  (2, 'Workshop'),
  (3, 'Conference'),
  (4, 'Webinar'),
  (5, 'Social');

INSERT INTO events.evt_events
  (event_id, title, category_code, venue, starts_at, capacity, is_published, host_email, _deleted) VALUES
  ('evt_8f3a', '  AI Builders Meetup ', 1, '{"name":"The Innovation Hub","city":"Austin","country":"US"}',     '2026-03-14',                 '120', 'Y',    'Hana.Park@example.com', false),
  ('evt_2b71', 'data viz WORKSHOP',     2, '{"name":"Loft 4","city":"Berlin","country":"DE"}',                  '03/22/2026',                '40',  'true', 'mateo@example.com ',    false),
  ('evt_5c09', 'Quarterly Conference 2026', 3, '{"name":"Convention Center","city":"San Francisco","country":"US"}', '2026-04-02T09:00:00Z',  '500', '1',    'events@acme.io',        false),
  ('evt_9d44', 'Intro Webinar',         4, '{"name":"Online","city":null,"country":null}',                      '14-Apr-2026',               'N/A', 'N',    'noreply@acme.io',       false),
  ('evt_1a23', 'Founders Social',       5, '{"name":"Rooftop Bar","city":"Lisbon","country":"PT"}',             '2026-04-18',                '',    'yes',  '-',                     false),
  ('evt_7e88', 'Security Deep Dive',    2, '{"name":"Room B","city":"Austin","country":"US"}',                  '2026/05/03',                '30',  '0',    'sec@acme.io',           false),
  ('evt_3f10', 'GHOST EVENT (cancelled)', 1, '{"name":"TBD","city":"-","country":"-"}',                         'NULL',                      '-5',  'N',    'NULL',                  true),
  ('evt_6b52', 'Community AMA',         4, '{"name":"Online","city":"","country":""}',                          '2026-05-20T18:30:00+02:00', '200', 'TRUE', 'ama@acme.io',           false);

INSERT INTO events.evt_people (uid, full_name, email, phone, created) VALUES
  ('p_01', '  Alice Nguyen ', 'alice.nguyen@example.com', '+1-512-555-0101',    '2025-11-02'),
  ('p_02', 'BOB smith',       'bob.smith@EXAMPLE.com',    '512.555.0102',       '2025-11-15'),
  ('p_03', 'Carla Díaz',      'carla.diaz@example.com',   'N/A',                '2025-12-01'),
  ('p_04', 'David O.',        'david@personal.io',        '+49 30 5550103',     '2026-01-09'),
  ('p_05', 'mateo rossi ',    'mateo@example.com',        '-',                  '2026-01-20'),
  ('p_06', 'Hana Park',       'hana.park@example.com',    '+1 (512) 555 0106',  '2026-02-02'),
  ('p_07', 'priya  patel',    'priya.patel@example.com',  'NULL',               '2026-02-11'),
  ('p_08', 'Tom',             'tom_h@example.com',        '',                   '2026-02-18'),
  ('p_09', 'Yuki Tanaka',     'yuki.tanaka@example.com',  '+81-3-5550-0109',    '2026-03-01'),
  ('p_10', 'Sara K',          'sara.k@example.com',       '512-555-0110',       '2026-03-05'),
  ('p_11', 'Liam',            'liam@personal.io',         '-',                  '2026-03-09'),  -- events-only
  ('p_12', 'GUEST',           'N/A',                      'N/A',                '2026-03-12');  -- anonymous junk

INSERT INTO events.evt_registrations
  (reg_id, event_id, person_ref, registered_at, status, checked_in) VALUES
  ('r001', 'evt_8f3a', 'p_01', '2026-02-20', 'going',     '1'),
  ('r002', 'evt_8f3a', 'p_02', '2026-02-21', 'GOING',     '1'),
  ('r003', 'evt_8f3a', 'p_06', '2026-02-22', 'going',     '0'),
  ('r004', 'evt_8f3a', 'p_07', '2026-02-25', 'waitlist',  ''),
  ('r005', 'evt_2b71', 'p_05', '2026-03-01', 'Going ',    '1'),
  ('r006', 'evt_2b71', 'p_03', '2026-03-02', 'going',     'Y'),
  ('r007', 'evt_2b71', 'p_10', '2026-03-04', 'cancelled', '0'),
  ('r008', 'evt_5c09', 'p_01', '2026-03-10', 'going',     '1'),
  ('r009', 'evt_5c09', 'p_04', '2026-03-11', 'going',     '0'),
  ('r010', 'evt_5c09', 'p_09', '2026-03-12', 'waitlist',  ''),
  ('r011', 'evt_5c09', 'p_06', '2026-03-12', 'Cancelled', '0'),
  ('r012', 'evt_5c09', 'p_12', '2026-03-13', 'going',     '1'),
  ('r013', 'evt_9d44', 'p_07', '2026-03-20', 'going',     '1'),
  ('r014', 'evt_9d44', 'p_08', '2026-03-21', 'going',     '0'),
  ('r015', 'evt_1a23', 'p_04', '2026-04-01', 'going',     '1'),
  ('r016', 'evt_1a23', 'p_11', '2026-04-02', 'going',     '1'),
  ('r017', 'evt_1a23', 'p_05', '2026-04-03', 'waitlist',  ''),
  ('r018', 'evt_7e88', 'p_09', '2026-04-20', 'going',     '0'),
  ('r019', 'evt_7e88', 'p_10', '2026-04-21', 'going',     '1'),
  ('r020', 'evt_6b52', 'p_01', '2026-05-10', 'going',     '1'),
  ('r021', 'evt_6b52', 'p_02', '2026-05-11', 'going',     'Y'),
  ('r022', 'evt_6b52', 'p_03', '2026-05-12', 'going',     '0'),
  ('r023', 'evt_6b52', 'p_06', '2026-05-13', 'waitlist',  ''),
  ('r024', 'evt_3f10', 'p_01', '2026-05-01', 'cancelled', ''),  -- registration on a soft-deleted event
  ('r025', 'evt_8f3a', 'p_10', '2026-02-26', 'going',     '1'),
  ('r026', 'evt_5c09', 'p_07', '2026-03-14', 'going',     '0');

INSERT INTO events.evt_custom_fields (field_key, question, field_type) VALUES
  ('cf_1021', 'Dietary restrictions',     'multi'),
  ('cf_1042', 'T-shirt size',             'single'),
  ('cf_1099', 'How did you hear about us?', 'text');

INSERT INTO events.evt_custom_responses (reg_id, field_key, answer) VALUES
  ('r001', 'cf_1021', '[{"value":"Vegan"},{"value":"Gluten-free"}]'),
  ('r001', 'cf_1042', '{"value":"M"}'),
  ('r001', 'cf_1099', '{"value":"Twitter"}'),
  ('r002', 'cf_1042', '{"value":"L"}'),
  ('r002', 'cf_1021', '[{"value":"None"}]'),
  ('r003', 'cf_1021', '[{"value":"Vegetarian"}]'),
  ('r005', 'cf_1042', '{"value":"S"}'),
  ('r005', 'cf_1099', '{"value":"A friend"}'),
  ('r006', 'cf_1021', '[{"value":"Halal"},{"value":"Nut allergy"}]'),
  ('r008', 'cf_1042', '{"value":"XL"}'),
  ('r008', 'cf_1099', 'null'),
  ('r009', 'cf_1021', '[]'),
  ('r012', 'cf_1042', '{"value":"M"}'),
  ('r013', 'cf_1099', '{"value":"LinkedIn"}'),
  ('r015', 'cf_1021', '[{"value":"Vegan"}]'),
  ('r020', 'cf_1042', '{"value":"L"}'),
  ('r021', 'cf_1099', '{"value":"Newsletter"}');

-- ========================================================================
-- CRM DOMAIN
-- ========================================================================

INSERT INTO crm.crm_lifecycle_stages (code, stage) VALUES
  (10, 'Lead'),
  (20, 'MQL'),
  (30, 'SQL'),
  (40, 'Customer'),
  (50, 'Churned');

INSERT INTO crm.crm_companies (company_id, name, domain, region, tier) VALUES
  (1, 'Acme Inc',  'acme.io',     'NA',   'Enterprise'),
  (2, 'Personal',  'personal.io', 'EU',   'Free'),
  (3, 'Globex',    'globex.com',  'NA',   'Pro'),
  (4, 'Initech',   'initech.com', 'NA',   'Pro'),
  (5, 'Umbrella',  'umbrella.co', 'APAC', 'Enterprise'),
  (6, 'Hooli',     'hooli.com',   'NA',   'Free');

-- email_address is the (dirty) bridge to events.evt_people.email. Note the
-- casing differences, the duplicate (1002/1013), and the tombstones (is_deleted=1).
INSERT INTO crm.crm_contacts
  (contact_id, first, last, email_address, mobile, company_id, lifecycle_code, lead_source, subscribed, is_deleted) VALUES
  (1001, 'Alice', 'Nguyen', 'alice.nguyen@example.com', '+15125550101', 3, 40, 'Webinar',  'Y',     0),
  (1002, 'Bob',   'Smith',  'bob.smith@example.com',    '5125550102',   1, 30, 'Referral', 'N',     0),
  (1003, 'Carla', 'Diaz',   'carla.diaz@example.com',   'NULL',         4, 20, 'Event',    'Y',     0),
  (1004, 'Mateo', 'Rossi',  'mateo@example.com',        '-',            1, 40, 'Event',    'unsub', 0),
  (1005, 'Hana',  'Park',   'HANA.PARK@example.com',    '+15125550106', 1, 40, 'Webinar',  'Y',     0),
  (1006, 'Priya', 'Patel',  'priya.patel@example.com',  '',             5, 10, 'Cold',     'Y',     0),
  (1007, 'Yuki',  'Tanaka', 'yuki.tanaka@example.com',  '+81355500109', 5, 40, 'Referral', 'Y',     0),
  (1008, 'Sara',  'Kim',    'sara.k@example.com',       '5125550110',   6, 20, 'Webinar',  'Y',     0),
  (1009, 'Tom',   'Hardy',  'tom_h@example.com',        'N/A',          6, 50, 'Cold',     'unsub', 1),  -- churned + deleted
  (1010, 'Nina',  'Lopez',  'nina.lopez@example.com',   '+15125550111', 3, 40, 'Referral', 'Y',     0),  -- crm-only
  (1011, 'Omar',  'Haddad', 'omar@globex.com',          '+15125550112', 3, 30, 'Event',    'Y',     0),  -- crm-only
  (1012, 'Eva',   'Berg',   'eva.berg@initech.com',     'N/A',          4, 10, 'Cold',     'Y',     0),  -- crm-only
  (1013, 'Bob',   'Smith',  'bob.smith@example.com',    '5125550102',   1, 30, 'Referral', 'N',     0),  -- DUPLICATE of 1002
  (1014, 'Ghost', 'User',   'NULL',                     'NULL',         2, 10, 'Cold',     'N',     1);  -- junk + deleted
