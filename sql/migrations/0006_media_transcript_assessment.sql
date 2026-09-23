CREATE SCHEMA IF NOT EXISTS assessment;

CREATE TABLE media.transcript (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  media_item_id uuid NOT NULL REFERENCES media.media_item(id) ON DELETE CASCADE,
  locale_id uuid NOT NULL REFERENCES catalog.locale(id) ON DELETE RESTRICT,
  source_type varchar(50) NOT NULL CHECK (source_type IN ('HUMAN', 'AI_STT', 'EXTERNAL')),
  provider varchar(100),
  model varchar(150),
  model_version varchar(100),
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  version int NOT NULL DEFAULT 1 CHECK (version > 0),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (media_item_id, locale_id, version)
);

CREATE TABLE media.transcript_segment (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transcript_id uuid NOT NULL REFERENCES media.transcript(id) ON DELETE CASCADE,
  sequence_no int NOT NULL,
  start_ms bigint NOT NULL CHECK (start_ms >= 0),
  end_ms bigint NOT NULL CHECK (end_ms >= start_ms),
  speaker_id uuid REFERENCES media.speaker(id) ON DELETE SET NULL,
  sentence_id uuid REFERENCES linguistic.sentence(id) ON DELETE SET NULL,
  text text NOT NULL,
  confidence numeric(5, 4),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (transcript_id, sequence_no)
);
CREATE INDEX transcript_segment_time_idx ON media.transcript_segment (transcript_id, start_ms);

CREATE TABLE media.transcript_token (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  segment_id uuid NOT NULL REFERENCES media.transcript_segment(id) ON DELETE CASCADE,
  position int NOT NULL,
  surface varchar(500) NOT NULL,
  lexeme_id uuid REFERENCES linguistic.lexeme(id) ON DELETE SET NULL,
  reading varchar(500),
  romanization varchar(500),
  start_ms bigint,
  end_ms bigint,
  confidence numeric(5, 4),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (segment_id, position),
  CONSTRAINT transcript_token_time_ck CHECK (end_ms IS NULL OR start_ms IS NULL OR end_ms >= start_ms)
);
CREATE INDEX transcript_token_lexeme_idx ON media.transcript_token (lexeme_id);

CREATE TABLE assessment.exercise_type (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code varchar(100) NOT NULL UNIQUE,
  name varchar(150) NOT NULL
);

CREATE TABLE assessment.exercise (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  content_item_id uuid NOT NULL UNIQUE REFERENCES content.content_item(id) ON DELETE CASCADE,
  exercise_type_id uuid NOT NULL REFERENCES assessment.exercise_type(id) ON DELETE RESTRICT,
  grading_mode varchar(50) NOT NULL CHECK (grading_mode IN ('EXACT', 'RULE', 'MANUAL', 'AI', 'HYBRID')),
  passing_score numeric(8, 3),
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE assessment.exercise_text (
  exercise_id uuid NOT NULL REFERENCES assessment.exercise(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  title varchar(300),
  instructions text,
  PRIMARY KEY (exercise_id, language_id)
);

CREATE TABLE assessment.exercise_version (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercise_id uuid NOT NULL REFERENCES assessment.exercise(id) ON DELETE CASCADE,
  version int NOT NULL CHECK (version > 0),
  snapshot jsonb NOT NULL,
  status varchar(30) NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'reviewing', 'published', 'archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  published_at timestamptz,
  UNIQUE (exercise_id, version)
);

CREATE TABLE assessment.exercise_item (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercise_id uuid NOT NULL REFERENCES assessment.exercise(id) ON DELETE CASCADE,
  position int NOT NULL,
  prompt_sentence_id uuid REFERENCES linguistic.sentence(id) ON DELETE SET NULL,
  media_item_id uuid REFERENCES media.media_item(id) ON DELETE SET NULL,
  config jsonb NOT NULL DEFAULT '{}'::jsonb,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (exercise_id, position)
);

CREATE TABLE assessment.exercise_item_text (
  exercise_item_id uuid NOT NULL REFERENCES assessment.exercise_item(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  prompt text,
  explanation text,
  PRIMARY KEY (exercise_item_id, language_id)
);

CREATE TABLE assessment.exercise_option (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercise_item_id uuid NOT NULL REFERENCES assessment.exercise_item(id) ON DELETE CASCADE,
  position int NOT NULL,
  content_item_id uuid REFERENCES content.content_item(id) ON DELETE SET NULL,
  asset_id uuid REFERENCES media.asset(id) ON DELETE SET NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (exercise_item_id, position)
);

CREATE TABLE assessment.exercise_option_text (
  exercise_option_id uuid NOT NULL REFERENCES assessment.exercise_option(id) ON DELETE CASCADE,
  language_id uuid NOT NULL REFERENCES catalog.language(id) ON DELETE RESTRICT,
  text text,
  PRIMARY KEY (exercise_option_id, language_id)
);

CREATE TABLE assessment.answer_key (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  exercise_item_id uuid NOT NULL UNIQUE REFERENCES assessment.exercise_item(id) ON DELETE CASCADE,
  answer_type varchar(80) NOT NULL,
  answer_data jsonb NOT NULL,
  grading_config jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE assessment.attempt (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  exercise_id uuid NOT NULL REFERENCES assessment.exercise(id) ON DELETE RESTRICT,
  exercise_version_id uuid REFERENCES assessment.exercise_version(id) ON DELETE RESTRICT,
  lesson_id uuid REFERENCES learning.lesson(id) ON DELETE SET NULL,
  started_at timestamptz NOT NULL DEFAULT now(),
  submitted_at timestamptz,
  score numeric(8, 3),
  max_score numeric(8, 3),
  status varchar(30) NOT NULL DEFAULT 'started' CHECK (status IN ('started', 'submitted', 'graded', 'cancelled')),
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);
CREATE INDEX attempt_user_started_idx ON assessment.attempt (user_id, started_at DESC);
CREATE INDEX attempt_exercise_idx ON assessment.attempt (exercise_id);

CREATE TABLE assessment.attempt_answer (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_id uuid NOT NULL REFERENCES assessment.attempt(id) ON DELETE CASCADE,
  exercise_item_id uuid NOT NULL REFERENCES assessment.exercise_item(id) ON DELETE RESTRICT,
  response_data jsonb,
  is_correct boolean,
  score numeric(8, 3),
  answered_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  UNIQUE (attempt_id, exercise_item_id)
);

CREATE TABLE assessment.ai_evaluation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  attempt_answer_id uuid NOT NULL REFERENCES assessment.attempt_answer(id) ON DELETE CASCADE,
  provider varchar(100),
  model varchar(150),
  model_version varchar(100),
  overall_score numeric(8, 3),
  pronunciation_score numeric(8, 3),
  fluency_score numeric(8, 3),
  accuracy_score numeric(8, 3),
  completeness_score numeric(8, 3),
  feedback text,
  details jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX ai_evaluation_answer_idx ON assessment.ai_evaluation (attempt_answer_id, created_at DESC);

