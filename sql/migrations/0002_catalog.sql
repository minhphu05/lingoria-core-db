CREATE SCHEMA IF NOT EXISTS catalog;

CREATE TABLE catalog.language (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso_639_1 varchar(2) UNIQUE,
  iso_639_3 varchar(3) UNIQUE,
  name varchar(120) NOT NULL,
  native_name varchar(120),
  text_direction varchar(10) NOT NULL DEFAULT 'ltr' CHECK (text_direction IN ('ltr', 'rtl')),
  active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT language_iso_639_1_ck CHECK (iso_639_1 IS NULL OR length(iso_639_1) = 2),
  CONSTRAINT language_iso_639_3_ck CHECK (iso_639_3 IS NULL OR length(iso_639_3) = 3)
);
CREATE TABLE catalog.country (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso2 varchar(2) NOT NULL,
  iso3 varchar(3),
  name varchar(120) NOT NULL,
  native_name varchar(120),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT country_iso2_ck CHECK (length(iso2) = 2),
  CONSTRAINT country_iso3_ck CHECK (iso3 IS NULL OR length(iso3) = 3)
);
CREATE UNIQUE INDEX country_iso2_uidx ON catalog.country (iso2);
CREATE UNIQUE INDEX country_iso3_uidx ON catalog.country (iso3) WHERE iso3 IS NOT NULL;

CREATE TABLE catalog.country_language (
  country_id uuid NOT NULL REFERENCES catalog.country(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE CASCADE,
  is_official boolean NOT NULL DEFAULT false,
  is_primary boolean NOT NULL DEFAULT false,
  PRIMARY KEY (country_id, language_id)
);

CREATE TABLE catalog.script (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  iso_15924 varchar(4),
  code varchar(50) NOT NULL,
  name varchar(120) NOT NULL,
  direction varchar(10) NOT NULL DEFAULT 'ltr' CHECK (direction IN ('ltr', 'rtl')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE UNIQUE INDEX script_code_uidx ON catalog.script (code);
CREATE UNIQUE INDEX script_iso_15924_uidx ON catalog.script (iso_15924) WHERE iso_15924 IS NOT NULL;

CREATE TABLE catalog.locale (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_id uuid NOT NULL REFERENCES catalog.language(id),
  country_id uuid REFERENCES catalog.country(id),
  bcp47_code varchar(35) NOT NULL,
  name varchar(120) NOT NULL,
  variant varchar(60),
  active boolean NOT NULL DEFAULT true,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX locale_bcp47_uidx ON catalog.locale (bcp47_code);
CREATE INDEX locale_language_idx ON catalog.locale (language_id);
CREATE INDEX locale_country_idx ON catalog.locale (country_id);

CREATE TABLE catalog.locale_script (
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE CASCADE,
  script_id uuid NOT NULL REFERENCES catalog.script(id) ON DELETE RESTRICT,
  is_primary boolean NOT NULL DEFAULT false,
  position int,
  PRIMARY KEY (locale_id, script_id)
);

CREATE TABLE catalog.romanization_scheme (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE CASCADE,
  code varchar(80) NOT NULL,
  name varchar(150) NOT NULL,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (locale_id, code)
);

CREATE TABLE catalog.proficiency_framework (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(50) NOT NULL UNIQUE,
  name varchar(150) NOT NULL,
  description text,
  organization varchar(150),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE catalog.proficiency_framework_locale (
  framework_id uuid NOT NULL REFERENCES catalog.proficiency_framework(id) ON DELETE CASCADE,
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE CASCADE,
  is_default boolean NOT NULL DEFAULT false,
  PRIMARY KEY (framework_id, locale_id)
);

CREATE TABLE catalog.proficiency_level (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  framework_id uuid NOT NULL REFERENCES catalog.proficiency_framework(id) ON DELETE CASCADE,
  code varchar(30) NOT NULL,
  name varchar(100) NOT NULL,
  rank int NOT NULL,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (framework_id, code)
);
CREATE INDEX proficiency_level_rank_idx ON catalog.proficiency_level (framework_id, rank);

CREATE TABLE catalog.topic (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id uuid REFERENCES catalog.topic(id) ON DELETE SET NULL,
  code citext NOT NULL UNIQUE,
  icon varchar(120),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT true
);

CREATE TABLE catalog.topic_text (
  topic_id uuid NOT NULL REFERENCES catalog.topic(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE CASCADE,
  name varchar(150) NOT NULL,
  description text,
  PRIMARY KEY (topic_id, language_id)
);

CREATE TABLE catalog.tag (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code citext NOT NULL UNIQUE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Public route mapping. This is the bridge between /japanese and ja-JP.
CREATE TABLE catalog.site (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  route_slug citext NOT NULL UNIQUE,
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  host citext,
  display_name varchar(160) NOT NULL,
  status varchar(30) NOT NULL DEFAULT 'active' CHECK (status IN ('draft', 'active', 'archived')),
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX site_host_uidx ON catalog.site (host) WHERE host IS NOT NULL;

CREATE TABLE catalog.experience_profile (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  locale_id uuid NOT NULL UNIQUE REFERENCES catalog.locale(id) ON DELETE CASCADE,
  theme_key varchar(100) NOT NULL,
  navigation_style varchar(100),
  motif_set varchar(100),
  hero_asset_id uuid,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX country_language_primary_idx ON catalog.country_language (country_id, is_primary);
CREATE INDEX locale_script_primary_idx ON catalog.locale_script (locale_id, is_primary);
