CREATE SCHEMA IF NOT EXISTS linguistic;

CREATE TABLE linguistic.grapheme (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  script_id uuid NOT NULL REFERENCES catalog.script(id) ON DELETE RESTRICT,
  symbol varchar(30) NOT NULL,
  normalized_symbol varchar(30),
  unicode_sequence varchar(200),
  category varchar(100),
  stroke_count int CHECK (stroke_count IS NULL OR stroke_count >= 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX grapheme_script_symbol_idx ON linguistic.grapheme (script_id, symbol);

CREATE TABLE linguistic.grapheme_reading (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grapheme_id uuid NOT NULL REFERENCES linguistic.grapheme(id) ON DELETE CASCADE,
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  reading varchar(300) NOT NULL,
  reading_type varchar(100),
  romanization_scheme_id uuid REFERENCES catalog.romanization_scheme(id) ON DELETE RESTRICT,
  romanized varchar(300),
  position int,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (grapheme_id, locale_id, reading)
);

CREATE TABLE linguistic.grapheme_component (
  parent_grapheme_id uuid NOT NULL REFERENCES linguistic.grapheme(id) ON DELETE CASCADE,
  component_grapheme_id uuid NOT NULL REFERENCES linguistic.grapheme(id) ON DELETE RESTRICT,
  relation_type varchar(80),
  position int,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  PRIMARY KEY (parent_grapheme_id, component_grapheme_id, relation_type)
);

CREATE TABLE linguistic.grapheme_stroke (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  grapheme_id uuid NOT NULL REFERENCES linguistic.grapheme(id) ON DELETE CASCADE,
  stroke_number int NOT NULL CHECK (stroke_number > 0),
  path_data text,
  asset_id uuid REFERENCES media.asset(id) ON DELETE RESTRICT,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (grapheme_id, stroke_number),
  CONSTRAINT grapheme_stroke_data_ck CHECK (path_data IS NOT NULL OR asset_id IS NOT NULL)
);

CREATE TABLE linguistic.part_of_speech (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE CASCADE,
  code varchar(100) NOT NULL,
  name varchar(150) NOT NULL,
  parent_id uuid REFERENCES linguistic.part_of_speech(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (locale_id, code)
);

CREATE TABLE linguistic.lexeme (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  lemma varchar(500) NOT NULL,
  normalized_lemma varchar(500) NOT NULL,
  primary_part_of_speech_id uuid REFERENCES linguistic.part_of_speech(id) ON DELETE RESTRICT,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX lexeme_normalized_lemma_idx ON linguistic.lexeme (normalized_lemma);
CREATE INDEX lexeme_normalized_lemma_trgm_idx ON linguistic.lexeme USING gin (normalized_lemma gin_trgm_ops);

CREATE TABLE linguistic.lexeme_form (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_id uuid NOT NULL REFERENCES linguistic.lexeme(id) ON DELETE CASCADE,
  script_id uuid REFERENCES catalog.script(id) ON DELETE RESTRICT,
  written_form varchar(500) NOT NULL,
  reading varchar(500),
  form_type varchar(100),
  orthography_tag varchar(100),
  romanization_scheme_id uuid REFERENCES catalog.romanization_scheme(id) ON DELETE RESTRICT,
  romanization varchar(500),
  is_primary boolean NOT NULL DEFAULT false,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX lexeme_form_lexeme_idx ON linguistic.lexeme_form (lexeme_id);
CREATE INDEX lexeme_form_written_idx ON linguistic.lexeme_form (written_form);
CREATE UNIQUE INDEX lexeme_form_primary_uidx ON linguistic.lexeme_form (lexeme_id) WHERE is_primary;

CREATE TABLE linguistic.lexical_sense (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_id uuid NOT NULL REFERENCES linguistic.lexeme(id) ON DELETE CASCADE,
  part_of_speech_id uuid REFERENCES linguistic.part_of_speech(id) ON DELETE RESTRICT,
  position int NOT NULL,
  register varchar(100),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (lexeme_id, position)
);

CREATE TABLE linguistic.sense_text (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sense_id uuid NOT NULL REFERENCES linguistic.lexical_sense(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  definition text NOT NULL,
  short_gloss varchar(500),
  usage_note text,
  UNIQUE (sense_id, language_id)
);

CREATE TABLE linguistic.sense_relation_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(80) NOT NULL UNIQUE,
  name varchar(120) NOT NULL
);

CREATE TABLE linguistic.sense_relation (
  source_sense_id uuid NOT NULL REFERENCES linguistic.lexical_sense(id) ON DELETE CASCADE,
  target_sense_id uuid NOT NULL REFERENCES linguistic.lexical_sense(id) ON DELETE CASCADE,
  relation_type_id uuid NOT NULL REFERENCES linguistic.sense_relation_type(id) ON DELETE RESTRICT,
  PRIMARY KEY (source_sense_id, target_sense_id, relation_type_id),
  CONSTRAINT sense_relation_not_self_ck CHECK (source_sense_id <> target_sense_id)
);

CREATE TABLE linguistic.pronunciation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_form_id uuid NOT NULL REFERENCES linguistic.lexeme_form(id) ON DELETE CASCADE,
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  ipa varchar(500),
  audio_asset_id uuid REFERENCES media.asset(id) ON DELETE RESTRICT,
  speaker_id uuid REFERENCES media.speaker(id) ON DELETE SET NULL,
  pronunciation_data jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX pronunciation_form_idx ON linguistic.pronunciation (lexeme_form_id, locale_id);

CREATE TABLE linguistic.grammatical_category (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE CASCADE,
  code varchar(100) NOT NULL,
  name varchar(150) NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (locale_id, code)
);

CREATE TABLE linguistic.grammatical_value (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  category_id uuid NOT NULL REFERENCES linguistic.grammatical_category(id) ON DELETE CASCADE,
  code varchar(100) NOT NULL,
  name varchar(150) NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (category_id, code)
);

CREATE TABLE linguistic.lexeme_grammatical_value (
  lexeme_id uuid NOT NULL REFERENCES linguistic.lexeme(id) ON DELETE CASCADE,
  grammatical_value_id uuid NOT NULL REFERENCES linguistic.grammatical_value(id) ON DELETE CASCADE,
  PRIMARY KEY (lexeme_id, grammatical_value_id)
);

CREATE TABLE linguistic.inflected_form (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_id uuid NOT NULL REFERENCES linguistic.lexeme(id) ON DELETE CASCADE,
  written_form varchar(500) NOT NULL,
  reading varchar(500),
  romanization varchar(500),
  form_type varchar(100),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX inflected_form_lexeme_idx ON linguistic.inflected_form (lexeme_id);

CREATE TABLE linguistic.inflected_form_value (
  inflected_form_id uuid NOT NULL REFERENCES linguistic.inflected_form(id) ON DELETE CASCADE,
  grammatical_value_id uuid NOT NULL REFERENCES linguistic.grammatical_value(id) ON DELETE CASCADE,
  PRIMARY KEY (inflected_form_id, grammatical_value_id)
);

CREATE TABLE linguistic.lexeme_frequency (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  lexeme_id uuid NOT NULL REFERENCES linguistic.lexeme(id) ON DELETE CASCADE,
  corpus_name varchar(200) NOT NULL,
  rank int,
  frequency_per_million numeric,
  source_item_id uuid REFERENCES ingestion.source_item(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (lexeme_id, corpus_name)
);
CREATE INDEX lexeme_frequency_rank_idx ON linguistic.lexeme_frequency (corpus_name, rank);

CREATE TABLE linguistic.grammar_point (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  pattern varchar(1000),
  code varchar(150),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX grammar_point_code_idx ON linguistic.grammar_point (code);

CREATE TABLE linguistic.grammar_text (
  grammar_point_id uuid NOT NULL REFERENCES linguistic.grammar_point(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  name varchar(300) NOT NULL,
  explanation text,
  formation text,
  usage_notes text,
  PRIMARY KEY (grammar_point_id, language_id)
);

CREATE TABLE linguistic.sentence (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  locale_id uuid REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  text text NOT NULL,
  normalized_text text,
  source_item_id uuid REFERENCES ingestion.source_item(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX sentence_locale_idx ON linguistic.sentence (locale_id);

CREATE TABLE linguistic.sentence_translation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sentence_id uuid NOT NULL REFERENCES linguistic.sentence(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  translation text NOT NULL,
  translation_type varchar(50) NOT NULL DEFAULT 'human',
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (sentence_id, language_id, translation_type)
);

CREATE TABLE linguistic.sentence_token (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sentence_id uuid NOT NULL REFERENCES linguistic.sentence(id) ON DELETE CASCADE,
  position int NOT NULL,
  surface varchar(500) NOT NULL,
  normalized_surface varchar(500),
  lexeme_id uuid REFERENCES linguistic.lexeme(id) ON DELETE SET NULL,
  part_of_speech_id uuid REFERENCES linguistic.part_of_speech(id) ON DELETE SET NULL,
  reading varchar(500),
  romanization varchar(500),
  start_offset int,
  end_offset int,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (sentence_id, position)
);
CREATE INDEX sentence_token_lexeme_idx ON linguistic.sentence_token (lexeme_id);

CREATE TABLE linguistic.grammar_example (
  grammar_point_id uuid NOT NULL REFERENCES linguistic.grammar_point(id) ON DELETE CASCADE,
  sentence_id uuid NOT NULL REFERENCES linguistic.sentence(id) ON DELETE CASCADE,
  position int,
  note text,
  PRIMARY KEY (grammar_point_id, sentence_id)
);

CREATE TABLE linguistic.dialogue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE linguistic.dialogue_line (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  dialogue_id uuid NOT NULL REFERENCES linguistic.dialogue(id) ON DELETE CASCADE,
  position int NOT NULL,
  speaker_id uuid REFERENCES media.speaker(id) ON DELETE SET NULL,
  sentence_id uuid NOT NULL REFERENCES linguistic.sentence(id) ON DELETE RESTRICT,
  audio_asset_id uuid REFERENCES media.asset(id) ON DELETE RESTRICT,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (dialogue_id, position)
);

