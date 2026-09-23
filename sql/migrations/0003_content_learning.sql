CREATE SCHEMA IF NOT EXISTS content;
CREATE SCHEMA IF NOT EXISTS learning;

CREATE TABLE content.content_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(80) NOT NULL UNIQUE,
  name varchar(120) NOT NULL,
  description text
);

CREATE TABLE content.content_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_type_id uuid NOT NULL REFERENCES content.content_type(id) ON DELETE RESTRICT,
  primary_locale_id uuid REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  internal_key varchar(160),
  slug varchar(250),
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  difficulty_score numeric(8, 3),
  version int NOT NULL DEFAULT 1 CHECK (version > 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  published_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);
CREATE INDEX content_item_type_idx ON content.content_item (content_type_id);
CREATE INDEX content_item_locale_idx ON content.content_item (primary_locale_id);
CREATE INDEX content_item_status_idx ON content.content_item (status);
CREATE UNIQUE INDEX content_item_internal_key_uidx ON content.content_item (internal_key) WHERE internal_key IS NOT NULL;
CREATE UNIQUE INDEX content_item_locale_slug_uidx ON content.content_item (primary_locale_id, slug) WHERE slug IS NOT NULL;

-- A shared culture or media item may be visible from more than one locale.
CREATE TABLE content.content_item_locale (
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE CASCADE,
  is_primary boolean NOT NULL DEFAULT false,
  PRIMARY KEY (content_item_id, locale_id)
);
CREATE INDEX content_item_locale_locale_idx ON content.content_item_locale (locale_id, content_item_id);

CREATE TABLE content.content_text (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(500),
  short_description text,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (content_item_id, language_id)
);

CREATE TABLE content.content_level (
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  proficiency_level_id uuid NOT NULL REFERENCES catalog.proficiency_level(id) ON DELETE RESTRICT,
  confidence numeric(5, 4),
  PRIMARY KEY (content_item_id, proficiency_level_id)
);

CREATE TABLE content.content_topic (
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  topic_id uuid NOT NULL REFERENCES catalog.topic(id) ON DELETE RESTRICT,
  weight numeric(8, 4),
  PRIMARY KEY (content_item_id, topic_id)
);
CREATE INDEX content_topic_topic_idx ON content.content_topic (topic_id);

CREATE TABLE content.content_tag (
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  tag_id uuid NOT NULL REFERENCES catalog.tag(id) ON DELETE RESTRICT,
  PRIMARY KEY (content_item_id, tag_id)
);
CREATE INDEX content_tag_tag_idx ON content.content_tag (tag_id);

CREATE TABLE content.relation_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(150) NOT NULL,
  directional boolean NOT NULL DEFAULT true
);

CREATE TABLE content.content_relation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_content_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  target_content_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  relation_type_id uuid NOT NULL REFERENCES content.relation_type(id) ON DELETE RESTRICT,
  weight numeric(8, 4),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  CONSTRAINT content_relation_not_self_ck CHECK (source_content_id <> target_content_id),
  UNIQUE (source_content_id, target_content_id, relation_type_id)
);
CREATE INDEX content_relation_target_idx ON content.content_relation (target_content_id);

CREATE TABLE content.content_revision (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL REFERENCES content.content_item(id) ON DELETE CASCADE,
  revision int NOT NULL CHECK (revision > 0),
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  snapshot jsonb NOT NULL,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  UNIQUE (content_item_id, revision)
);
CREATE INDEX content_revision_status_idx ON content.content_revision (content_item_id, status);

CREATE TABLE learning.course (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  target_locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  instruction_language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  code varchar(120) NOT NULL,
  slug varchar(250) NOT NULL,
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  version int NOT NULL DEFAULT 1 CHECK (version > 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (target_locale_id, instruction_language_id, slug)
);
CREATE INDEX course_target_locale_idx ON learning.course (target_locale_id);

CREATE TABLE learning.course_text (
  course_id uuid NOT NULL REFERENCES learning.course(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(300) NOT NULL,
  description text,
  PRIMARY KEY (course_id, language_id)
);

CREATE TABLE learning.course_level (
  course_id uuid NOT NULL REFERENCES learning.course(id) ON DELETE CASCADE,
  proficiency_level_id uuid NOT NULL REFERENCES catalog.proficiency_level(id) ON DELETE RESTRICT,
  position int,
  PRIMARY KEY (course_id, proficiency_level_id)
);

CREATE TABLE learning.unit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL REFERENCES learning.course(id) ON DELETE CASCADE,
  proficiency_level_id uuid REFERENCES catalog.proficiency_level(id) ON DELETE RESTRICT,
  primary_topic_id uuid REFERENCES catalog.topic(id) ON DELETE SET NULL,
  code varchar(120),
  position int NOT NULL,
  estimated_minutes int CHECK (estimated_minutes IS NULL OR estimated_minutes >= 0),
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (course_id, position)
);

CREATE TABLE learning.unit_text (
  unit_id uuid NOT NULL REFERENCES learning.unit(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(300) NOT NULL,
  description text,
  PRIMARY KEY (unit_id, language_id)
);

CREATE TABLE learning.lesson_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(150) NOT NULL
);

CREATE TABLE learning.lesson (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  unit_id uuid NOT NULL REFERENCES learning.unit(id) ON DELETE CASCADE,
  lesson_type_id uuid REFERENCES learning.lesson_type(id) ON DELETE RESTRICT,
  position int NOT NULL,
  estimated_minutes int CHECK (estimated_minutes IS NULL OR estimated_minutes >= 0),
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (unit_id, position)
);

CREATE TABLE learning.lesson_text (
  lesson_id uuid NOT NULL REFERENCES learning.lesson(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(300) NOT NULL,
  description text,
  PRIMARY KEY (lesson_id, language_id)
);

CREATE TABLE learning.block_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(150) NOT NULL
);

CREATE TABLE learning.lesson_block (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id uuid NOT NULL REFERENCES learning.lesson(id) ON DELETE CASCADE,
  block_type_id uuid NOT NULL REFERENCES learning.block_type(id) ON DELETE RESTRICT,
  content_item_id uuid REFERENCES content.content_item(id) ON DELETE RESTRICT,
  position int NOT NULL,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (lesson_id, position)
);
CREATE INDEX lesson_block_content_idx ON learning.lesson_block (content_item_id);

CREATE TABLE learning.lesson_block_text (
  lesson_block_id uuid NOT NULL REFERENCES learning.lesson_block(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(500),
  body text,
  PRIMARY KEY (lesson_block_id, language_id)
);

