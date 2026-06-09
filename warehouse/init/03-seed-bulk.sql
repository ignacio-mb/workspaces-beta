-- ~10x more (dirty) data, generated procedurally so the mess and the
-- cross-domain coherence both survive at scale:
--   * crm_contacts reuse evt_people emails (with case/whitespace mismatches)
--     so reconciling "the same person across both domains" stays a real task
--   * generated registrations reference generated events + people (with a few
--     deliberate orphans), custom responses reference generated registrations
--   * every original dirtiness pattern is reproduced: coded fields, JSON blobs,
--     mixed date/boolean formats, junk null placeholders, soft-delete tombstones,
--     duplicate contacts.
--
-- Decode/lookup tables are reference data, so we widen them a little rather than
-- 10x them (a closed enum like lifecycle stages stays as-is).
--
-- Disjoint key ranges from 02-seed.sql: people p_1xxx, events evt_bxxxx,
-- registrations rbxxxxx, companies 1xx, contacts 2xxx.

-- ---- widen decode tables ---------------------------------------------------
INSERT INTO events.evt_categories (code, label) VALUES
  (6, 'Hackathon'), (7, 'Panel'), (8, 'Training'), (9, 'Networking'), (10, 'AMA')
ON CONFLICT (code) DO NOTHING;

INSERT INTO events.evt_custom_fields (field_key, question, field_type) VALUES
  ('cf_1150', 'Accessibility needs',  'multi'),
  ('cf_1175', 'Years of experience',  'single'),
  ('cf_1190', 'Company size',         'single'),
  ('cf_1200', 'LinkedIn profile',     'text')
ON CONFLICT (field_key) DO NOTHING;

-- ---- generated people (TEMP: reused to build the overlapping crm contacts) --
CREATE TEMP TABLE g_people AS
WITH pools AS (
  SELECT
    ARRAY['Alice','Bob','Carla','David','Mateo','Hana','Priya','Tom','Yuki','Sara',
          'Liam','Nina','Omar','Eva','Noah','Mia','Raj','Lena','Sam','Ivy',
          'Leo','Zoe','Kai','Ana']::text[] AS firsts,
    ARRAY['Nguyen','Smith','Diaz','Owens','Rossi','Park','Patel','Hardy','Tanaka','Kim',
          'Walsh','Lopez','Haddad','Berg','Cole','Frost','Singh','Vance','Reed','Webb',
          'Lund','Mora','Shaw','Ito']::text[] AS lasts,
    ARRAY['example.com','example.com','example.com','personal.io','acme.io','globex.com']::text[] AS domains
),
base AS (
  SELECT
    i AS idx,
    firsts[1 + (i % 24)]                                  AS first,
    lasts[1 + ((i * 7) % 24)]                             AS last,
    lower(firsts[1 + (i % 24)]) || '.' || lower(lasts[1 + ((i * 7) % 24)])
      || '@' || domains[1 + ((i * 3) % 6)]                AS email_base,
    (DATE '2025-09-01' + i)                               AS d
  FROM pools, generate_series(1, 120) AS i
)
SELECT
  idx, first, last, email_base,
  CASE idx % 6
    WHEN 0 THEN '  ' || first || ' ' || last || ' '
    WHEN 1 THEN upper(first) || ' ' || lower(last)
    WHEN 2 THEN lower(first || ' ' || last)
    WHEN 3 THEN first || ' ' || left(last, 1) || '.'
    WHEN 4 THEN upper(first || ' ' || last)
    ELSE first || ' ' || last
  END AS full_name,
  CASE
    WHEN idx % 17 = 0 THEN 'N/A'
    WHEN idx % 5 = 0  THEN upper(left(email_base, 1)) || substr(email_base, 2)
    ELSE email_base
  END AS email,
  CASE idx % 7
    WHEN 0 THEN '+1-512-555-' || lpad(idx::text, 4, '0')
    WHEN 1 THEN '512.555.' || lpad(idx::text, 4, '0')
    WHEN 2 THEN '+1 (512) 555 ' || lpad(idx::text, 4, '0')
    WHEN 3 THEN 'N/A'
    WHEN 4 THEN ''
    WHEN 5 THEN '-'
    ELSE 'NULL'
  END AS phone,
  CASE idx % 4
    WHEN 0 THEN to_char(d, 'YYYY-MM-DD')
    WHEN 1 THEN to_char(d, 'MM/DD/YYYY')
    WHEN 2 THEN to_char(d, 'DD-Mon-YYYY')
    ELSE to_char(d, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  END AS created
FROM base;

INSERT INTO events.evt_people (uid, full_name, email, phone, created)
SELECT 'p_1' || lpad(idx::text, 3, '0'), full_name, email, phone, created
FROM g_people;

-- ---- generated events ------------------------------------------------------
INSERT INTO events.evt_events
  (event_id, title, category_code, venue, starts_at, capacity, is_published, host_email, _deleted)
SELECT
  'evt_b' || lpad(e::text, 4, '0'),
  CASE e % 5
    WHEN 0 THEN '  ' || topic || ' Meetup '
    WHEN 1 THEN lower(topic || ' workshop')
    WHEN 2 THEN upper(topic)
    WHEN 3 THEN topic || ' 2026'
    ELSE topic || ' Session'
  END,
  1 + (e % 10),
  format(
    '{"name":"%s","city":%s,"country":"%s"}',
    venue_name,
    CASE WHEN e % 9 = 0 THEN 'null' WHEN e % 11 = 0 THEN '""' ELSE '"' || city || '"' END,
    country
  ),
  CASE e % 4
    WHEN 0 THEN to_char(DATE '2026-03-01' + e, 'YYYY-MM-DD')
    WHEN 1 THEN to_char(DATE '2026-03-01' + e, 'MM/DD/YYYY')
    WHEN 2 THEN to_char(DATE '2026-03-01' + e, 'DD-Mon-YYYY')
    ELSE to_char(DATE '2026-03-01' + e, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
  END,
  CASE e % 7
    WHEN 4 THEN 'N/A'
    WHEN 5 THEN ''
    WHEN 6 THEN '-5'
    ELSE ((e * 13) % 480 + 20)::text
  END,
  (ARRAY['Y','N','true','1','0','yes','TRUE'])[1 + (e % 7)],
  (ARRAY['events@acme.io','noreply@acme.io','sec@acme.io','ama@acme.io','hello@globex.com'])[1 + (e % 5)],
  (e % 12 = 0)
FROM generate_series(1, 80) AS e
CROSS JOIN LATERAL (
  SELECT
    (ARRAY['AI Builders','Data Viz','Quarterly Sync','Intro Webinar','Founders Social',
           'Security Deep Dive','Community AMA','Growth Clinic','Design Jam',
           'Open Source Night','Product Demo','Leadership Roundtable'])[1 + (e % 12)] AS topic,
    (ARRAY['The Innovation Hub','Loft 4','Convention Center','Online','Rooftop Bar','Room B',
           'Hall A','Garden Pavilion','Studio 9','Tech Campus','Coworking Space','Grand Hotel'])[1 + (e % 12)] AS venue_name,
    (ARRAY['Austin','Berlin','San Francisco','Lisbon','London','Tokyo',
           'Toronto','Madrid','Amsterdam','Singapore','Denver','Paris'])[1 + (e % 12)] AS city,
    (ARRAY['US','DE','US','PT','GB','JP','CA','ES','NL','SG','US','FR'])[1 + (e % 12)] AS country
) v;

-- ---- generated registrations (a few orphan person_refs on purpose) ---------
INSERT INTO events.evt_registrations
  (reg_id, event_id, person_ref, registered_at, status, checked_in)
SELECT
  'rb' || lpad(r::text, 5, '0'),
  'evt_b' || lpad((1 + ((r - 1) % 80))::text, 4, '0'),
  CASE WHEN r % 53 = 0 THEN 'p_ghost'
       ELSE 'p_1' || lpad((1 + ((r - 1) % 120))::text, 3, '0') END,
  CASE r % 3
    WHEN 0 THEN to_char(DATE '2026-02-15' + r, 'YYYY-MM-DD')
    WHEN 1 THEN to_char(DATE '2026-02-15' + r, 'MM/DD/YYYY')
    ELSE to_char(DATE '2026-02-15' + r, 'DD-Mon-YYYY')
  END,
  (ARRAY['going','GOING','Going ','waitlist','cancelled','Cancelled'])[1 + (r % 6)],
  (ARRAY['1','0','','Y'])[1 + (r % 4)]
FROM generate_series(1, 260) AS r;

-- ---- generated custom responses (coded JSON answers, some junk) -------------
INSERT INTO events.evt_custom_responses (reg_id, field_key, answer)
SELECT
  'rb' || lpad((1 + ((c - 1) % 260))::text, 5, '0'),
  field_key,
  CASE WHEN c % 13 = 0 THEN 'null' ELSE answer END
FROM generate_series(1, 170) AS c
CROSS JOIN LATERAL (
  SELECT
    (ARRAY['cf_1021','cf_1042','cf_1099','cf_1150','cf_1175','cf_1190','cf_1200'])[1 + (c % 7)] AS field_key,
    (ARRAY[
      '[{"value":"Vegan"},{"value":"Gluten-free"}]',
      '{"value":"' || (ARRAY['S','M','L','XL'])[1 + (c % 4)] || '"}',
      '{"value":"' || (ARRAY['Twitter','LinkedIn','A friend','Newsletter','Google'])[1 + (c % 5)] || '"}',
      '[{"value":"Wheelchair access"},{"value":"Captioning"}]',
      '{"value":"' || (ARRAY['0-2','3-5','6-10','10+'])[1 + (c % 4)] || '"}',
      '{"value":"' || (ARRAY['1-10','11-50','51-200','200+'])[1 + (c % 4)] || '"}',
      '{"value":"https://linkedin.com/in/user' || c || '"}'
    ])[1 + (c % 7)] AS answer
) a;

-- ---- generated companies ---------------------------------------------------
INSERT INTO crm.crm_companies (company_id, name, domain, region, tier)
SELECT
  100 + m,
  (ARRAY['Acme Inc','Globex','Initech','Umbrella','Hooli','Soylent','Stark Industries',
         'Wayne Enterprises','Wonka','Cyberdyne','Tyrell','Massive Dynamic','Vandelay',
         'Gekko & Co','Pied Piper'])[1 + (m % 15)],
  (ARRAY['acme.io','globex.com','initech.com','umbrella.co','hooli.com','soylent.com',
         'stark.com','wayne.com','wonka.com','cyberdyne.com','tyrell.com','massive.com',
         'vandelay.com','gekko.com','piedpiper.com'])[1 + (m % 15)],
  (ARRAY['NA','EU','APAC','NA','N/A','','LATAM'])[1 + (m % 7)],
  (ARRAY['Free','Pro','Enterprise','',' Pro '])[1 + (m % 5)]
FROM generate_series(1, 60) AS m;

-- ---- generated contacts ----------------------------------------------------
-- Part A (2001..2100): the SAME humans as evt_people, different shape + id +
-- a dirtier rendering of the same email (the reconciliation bridge).
INSERT INTO crm.crm_contacts
  (contact_id, first, last, email_address, mobile, company_id, lifecycle_code, lead_source, subscribed, is_deleted)
SELECT
  2000 + idx,
  first,
  last,
  CASE WHEN idx % 4 = 0 THEN upper(email_base)
       WHEN idx % 6 = 0 THEN ' ' || email_base || ' '
       ELSE email_base END,
  CASE idx % 6
    WHEN 0 THEN '+1' || lpad(idx::text, 9, '0')
    WHEN 3 THEN 'N/A'
    WHEN 4 THEN ''
    WHEN 5 THEN 'NULL'
    ELSE '512555' || lpad(idx::text, 4, '0')
  END,
  100 + (1 + ((idx - 1) % 60)),
  (ARRAY[10, 20, 30, 40, 50])[1 + (idx % 5)],
  (ARRAY['Webinar','Referral','Event','Cold','Newsletter','Ad'])[1 + (idx % 6)],
  CASE WHEN idx % 9 = 0 THEN 'unsub' WHEN idx % 4 = 0 THEN 'N' ELSE 'Y' END,
  CASE WHEN idx % 15 = 0 THEN 1 ELSE 0 END
FROM g_people
WHERE idx <= 100;

-- Part B (2101..2140): crm-only people (unique domain so they never match events).
INSERT INTO crm.crm_contacts
  (contact_id, first, last, email_address, mobile, company_id, lifecycle_code, lead_source, subscribed, is_deleted)
SELECT
  2100 + j,
  first,
  last,
  lower(first) || '.' || lower(last) || j || '@' ||
    (ARRAY['leadgen.io','outbound.co','crmonly.com'])[1 + (j % 3)],
  CASE j % 5 WHEN 2 THEN 'N/A' WHEN 4 THEN 'NULL' ELSE '+1' || lpad((900 + j)::text, 9, '0') END,
  100 + (1 + (j % 60)),
  (ARRAY[10, 20, 30, 40, 50])[1 + (j % 5)],
  (ARRAY['Cold','Ad','Referral','List import'])[1 + (j % 4)],
  CASE WHEN j % 7 = 0 THEN 'unsub' ELSE 'Y' END,
  CASE WHEN j % 11 = 0 THEN 1 ELSE 0 END
FROM generate_series(1, 40) AS j
CROSS JOIN LATERAL (
  SELECT
    (ARRAY['Grace','Henry','Iris','Jack','Kara','Luis','Mona','Nate','Opal','Pete',
           'Quinn','Rosa','Stan','Tara','Uma','Vince','Wendy','Xavi','Yara','Zane'])[1 + (j % 20)] AS first,
    (ARRAY['Adler','Bauer','Costa','Dunn','Engel','Fuchs','Gomez','Holt','Imai','Jonas',
           'Klein','Leroy','Marsh','Novak','Ortiz','Pruitt','Quill','Rossi','Stein','Tobin'])[1 + ((j * 3) % 20)] AS last
) b;

-- Part C (2141..2150): duplicate CRM records for people 1..10 (same email twice).
INSERT INTO crm.crm_contacts
  (contact_id, first, last, email_address, mobile, company_id, lifecycle_code, lead_source, subscribed, is_deleted)
SELECT
  2140 + idx,
  first,
  last,
  email_base,
  '512555' || lpad(idx::text, 4, '0'),
  100 + idx,
  (ARRAY[10, 20, 30, 40, 50])[1 + (idx % 5)],
  'Referral',
  'N',
  0
FROM g_people
WHERE idx <= 10;
