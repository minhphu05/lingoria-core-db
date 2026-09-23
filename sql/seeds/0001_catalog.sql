BEGIN;

INSERT INTO catalog.language (iso_639_1, iso_639_3, name, native_name)
VALUES
  ('ja', 'jpn', 'Japanese', '日本語'),
  ('ko', 'kor', 'Korean', '한국어'),
  ('zh', 'zho', 'Chinese', '中文'),
  ('vi', 'vie', 'Vietnamese', 'Tiếng Việt'),
  ('en', 'eng', 'English', 'English')
ON CONFLICT (iso_639_1) DO UPDATE SET name = EXCLUDED.name, native_name = EXCLUDED.native_name;

INSERT INTO catalog.country (iso2, iso3, name, native_name)
VALUES
  ('JP', 'JPN', 'Japan', '日本'),
  ('KR', 'KOR', 'South Korea', '대한민국'),
  ('CN', 'CHN', 'China', '中国'),
  ('VN', 'VNM', 'Vietnam', 'Việt Nam')
ON CONFLICT (iso2) DO UPDATE SET name = EXCLUDED.name, native_name = EXCLUDED.native_name;

INSERT INTO catalog.country_language (country_id, language_id, is_official, is_primary)
SELECT c.id, l.id, true, true
FROM (VALUES ('JP', 'ja'), ('KR', 'ko'), ('CN', 'zh'), ('VN', 'vi')) AS v(iso2, lang)
JOIN catalog.country c ON c.iso2 = v.iso2
JOIN catalog.language l ON l.iso_639_1 = v.lang
ON CONFLICT (country_id, language_id) DO UPDATE SET is_official = true, is_primary = true;

INSERT INTO catalog.script (iso_15924, code, name)
VALUES
  ('Hira', 'Hira', 'Hiragana'),
  ('Kana', 'Kana', 'Katakana'),
  ('Hani', 'Hani', 'Han'),
  ('Hang', 'Hang', 'Hangul'),
  ('Latn', 'Latn', 'Latin')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO catalog.locale (language_id, country_id, bcp47_code, name)
SELECT l.id, c.id, v.bcp47, v.name
FROM (VALUES
  ('ja', 'JP', 'ja-JP', 'Japanese (Japan)'),
  ('ko', 'KR', 'ko-KR', 'Korean (South Korea)'),
  ('zh', 'CN', 'zh-CN', 'Chinese (China)'),
  ('vi', 'VN', 'vi-VN', 'Vietnamese (Vietnam)')
) AS v(lang, iso2, bcp47, name)
JOIN catalog.language l ON l.iso_639_1 = v.lang
JOIN catalog.country c ON c.iso2 = v.iso2
ON CONFLICT (bcp47_code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO catalog.locale_script (locale_id, script_id, is_primary, position)
SELECT loc.id, s.id, x.is_primary, x.position
FROM (VALUES
  ('ja-JP', 'Hira', true, 1), ('ja-JP', 'Kana', false, 2), ('ja-JP', 'Hani', false, 3),
  ('ko-KR', 'Hang', true, 1), ('zh-CN', 'Hani', true, 1), ('zh-CN', 'Latn', false, 2),
  ('vi-VN', 'Latn', true, 1)
) AS x(bcp47, code, is_primary, position)
JOIN catalog.locale loc ON loc.bcp47_code = x.bcp47
JOIN catalog.script s ON s.code = x.code
ON CONFLICT (locale_id, script_id) DO UPDATE SET is_primary = EXCLUDED.is_primary, position = EXCLUDED.position;

INSERT INTO catalog.romanization_scheme (locale_id, code, name, description)
SELECT l.id, 'REVISED_ROMANIZATION', 'Revised Romanization', 'South Korean standard romanization'
FROM catalog.locale l
WHERE l.bcp47_code = 'ko-KR'
ON CONFLICT (locale_id, code) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description;

INSERT INTO catalog.proficiency_framework (code, name)
VALUES ('JLPT', 'Japanese-Language Proficiency Test'), ('TOPIK', 'Test of Proficiency in Korean'), ('NIKL_STANDARD', 'NIKL Standard Korean Curriculum'), ('HSK', 'Hanyu Shuiping Kaoshi'), ('CEFR', 'Common European Framework of Reference')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

INSERT INTO catalog.proficiency_framework_locale (framework_id, locale_id, is_default)
SELECT f.id, l.id, true
FROM (VALUES ('JLPT', 'ja-JP'), ('TOPIK', 'ko-KR'), ('HSK', 'zh-CN'), ('CEFR', 'vi-VN')) AS v(framework, bcp47)
JOIN catalog.proficiency_framework f ON f.code = v.framework
JOIN catalog.locale l ON l.bcp47_code = v.bcp47
ON CONFLICT (framework_id, locale_id) DO UPDATE SET is_default = true;

INSERT INTO catalog.proficiency_framework_locale (framework_id, locale_id, is_default)
SELECT f.id, l.id, false
FROM catalog.proficiency_framework f
JOIN catalog.locale l ON l.bcp47_code = 'ko-KR'
WHERE f.code = 'NIKL_STANDARD'
ON CONFLICT (framework_id, locale_id) DO UPDATE SET is_default = false;

INSERT INTO catalog.proficiency_level (framework_id, code, name, rank)
SELECT f.id, v.code, v.name, v.rank
FROM (VALUES
  ('JLPT', 'N5', 'JLPT N5', 1), ('JLPT', 'N4', 'JLPT N4', 2), ('JLPT', 'N3', 'JLPT N3', 3), ('JLPT', 'N2', 'JLPT N2', 4), ('JLPT', 'N1', 'JLPT N1', 5),
  ('TOPIK', '1', 'TOPIK 1', 1), ('TOPIK', '2', 'TOPIK 2', 2), ('TOPIK', '3', 'TOPIK 3', 3), ('TOPIK', '4', 'TOPIK 4', 4), ('TOPIK', '5', 'TOPIK 5', 5), ('TOPIK', '6', 'TOPIK 6', 6),
  ('NIKL_STANDARD', '1', 'NIKL Standard Level 1', 1), ('NIKL_STANDARD', '2', 'NIKL Standard Level 2', 2), ('NIKL_STANDARD', '3', 'NIKL Standard Level 3', 3), ('NIKL_STANDARD', '4', 'NIKL Standard Level 4', 4), ('NIKL_STANDARD', '5', 'NIKL Standard Level 5', 5), ('NIKL_STANDARD', '6', 'NIKL Standard Level 6', 6),
  ('HSK', '1', 'HSK 1', 1), ('HSK', '2', 'HSK 2', 2), ('HSK', '3', 'HSK 3', 3), ('HSK', '4', 'HSK 4', 4), ('HSK', '5', 'HSK 5', 5), ('HSK', '6', 'HSK 6', 6),
  ('CEFR', 'A1', 'A1', 1), ('CEFR', 'A2', 'A2', 2), ('CEFR', 'B1', 'B1', 3), ('CEFR', 'B2', 'B2', 4), ('CEFR', 'C1', 'C1', 5), ('CEFR', 'C2', 'C2', 6)
) AS v(framework, code, name, rank)
JOIN catalog.proficiency_framework f ON f.code = v.framework
ON CONFLICT (framework_id, code) DO UPDATE SET name = EXCLUDED.name, rank = EXCLUDED.rank;

INSERT INTO catalog.site (route_slug, locale_id, display_name)
SELECT v.route_slug, l.id, v.display_name
FROM (VALUES
  ('japanese', 'ja-JP', 'Japanese · Lingoria'),
  ('korea', 'ko-KR', 'Korean · Lingoria'),
  ('china', 'zh-CN', 'Chinese · Lingoria'),
  ('vietnam', 'vi-VN', 'Vietnamese · Lingoria')
) AS v(route_slug, bcp47, display_name)
JOIN catalog.locale l ON l.bcp47_code = v.bcp47
ON CONFLICT (route_slug) DO UPDATE SET locale_id = EXCLUDED.locale_id, display_name = EXCLUDED.display_name;

INSERT INTO catalog.experience_profile (locale_id, theme_key, navigation_style, motif_set, config)
SELECT l.id, v.theme_key, 'journey', v.motif_set, v.config::jsonb
FROM (VALUES
  ('ja-JP', 'japan', 'sakura_zen', '{"culture_highlight": true}'),
  ('ko-KR', 'korea', 'moonlight_hanok', '{"culture_highlight": true}'),
  ('zh-CN', 'china', 'ink_heritage', '{"culture_highlight": true}'),
  ('vi-VN', 'vietnam', 'lotus_river', '{"culture_highlight": true}')
) AS v(bcp47, theme_key, motif_set, config)
JOIN catalog.locale l ON l.bcp47_code = v.bcp47
ON CONFLICT (locale_id) DO UPDATE SET theme_key = EXCLUDED.theme_key, motif_set = EXCLUDED.motif_set, config = EXCLUDED.config;

INSERT INTO catalog.topic (code, icon)
VALUES
  ('daily-life', 'life'), ('food', 'food'), ('restaurant', 'restaurant'), ('travel', 'travel'), ('transportation', 'train'), ('hotel', 'hotel'),
  ('family', 'family'), ('work', 'work'), ('school', 'school'), ('shopping', 'shopping'), ('dating', 'heart'), ('culture', 'landmark')
ON CONFLICT (code) DO NOTHING;

INSERT INTO content.content_type (code, name)
VALUES
  ('LEXEME', 'Lexeme'), ('GRAMMAR', 'Grammar'), ('GRAPHEME', 'Grapheme'), ('SENTENCE', 'Sentence'), ('VIDEO', 'Video'), ('AUDIO', 'Audio'),
  ('ARTICLE', 'Article'), ('CULTURE_ENTITY', 'Culture entity'), ('DIALOGUE', 'Dialogue'), ('EXERCISE', 'Exercise'), ('STORY', 'Story'), ('NEWS', 'News')
ON CONFLICT (code) DO NOTHING;

INSERT INTO learning.lesson_type (code, name)
VALUES ('VOCABULARY', 'Vocabulary'), ('GRAMMAR', 'Grammar'), ('LISTENING', 'Listening'), ('READING', 'Reading'), ('SPEAKING', 'Speaking'), ('WRITING', 'Writing'), ('CULTURE', 'Culture'), ('DIALOGUE', 'Dialogue'), ('MIXED', 'Mixed'), ('VIDEO', 'Video'), ('REVIEW', 'Review')
ON CONFLICT (code) DO NOTHING;

INSERT INTO learning.block_type (code, name)
VALUES ('TEXT', 'Text'), ('HEADING', 'Heading'), ('VOCABULARY', 'Vocabulary'), ('GRAMMAR', 'Grammar'), ('CHARACTER', 'Character'), ('VIDEO', 'Video'), ('AUDIO', 'Audio'), ('IMAGE', 'Image'), ('DIALOGUE', 'Dialogue'), ('CULTURE_CARD', 'Culture card'), ('EXERCISE', 'Exercise'), ('QUIZ', 'Quiz'), ('CALLOUT', 'Callout')
ON CONFLICT (code) DO NOTHING;

INSERT INTO assessment.exercise_type (code, name)
VALUES ('MULTIPLE_CHOICE', 'Multiple choice'), ('FILL_BLANK', 'Fill blank'), ('MATCHING', 'Matching'), ('REORDER', 'Reorder'), ('DICTATION', 'Dictation'), ('LISTENING', 'Listening'), ('READING', 'Reading'), ('WRITING', 'Writing'), ('SPEAKING', 'Speaking'), ('PRONUNCIATION', 'Pronunciation'), ('TRANSLATION', 'Translation'), ('FREE_RESPONSE', 'Free response')
ON CONFLICT (code) DO NOTHING;

INSERT INTO media.media_type (code, name)
VALUES ('VIDEO', 'Video'), ('AUDIO', 'Audio'), ('PODCAST', 'Podcast'), ('SHORT', 'Short'), ('INTERVIEW', 'Interview'), ('LESSON_VIDEO', 'Lesson video'), ('CULTURE_VIDEO', 'Culture video')
ON CONFLICT (code) DO NOTHING;

INSERT INTO culture.entity_type (code, name)
VALUES ('FOOD', 'Food'), ('PLACE', 'Place'), ('CITY', 'City'), ('LANDMARK', 'Landmark'), ('TRADITION', 'Tradition'), ('FESTIVAL', 'Festival'), ('HISTORY', 'History'), ('PERSON', 'Person'), ('ART', 'Art'), ('MUSIC', 'Music'), ('FASHION', 'Fashion'), ('SPORT', 'Sport'), ('ETIQUETTE', 'Etiquette'), ('LIFESTYLE', 'Lifestyle'), ('CRAFT', 'Craft')
ON CONFLICT (code) DO NOTHING;

INSERT INTO content.relation_type (code, name, directional)
VALUES ('RELATED', 'Related', false), ('PREREQUISITE', 'Prerequisite', true), ('NEXT', 'Next', true), ('EXPLAINS', 'Explains', true), ('EXAMPLE_OF', 'Example of', true), ('CULTURE_CONTEXT', 'Culture context', true), ('RELATED_VIDEO', 'Related video', true), ('RELATED_VOCABULARY', 'Related vocabulary', true)
ON CONFLICT (code) DO NOTHING;

INSERT INTO culture.relation_type (code, name)
VALUES ('ORIGINATED_IN', 'Originated in'), ('LOCATED_IN', 'Located in'), ('PART_OF', 'Part of'), ('RELATED_TO', 'Related to'), ('COMMONLY_FOUND_IN', 'Commonly found in'), ('ASSOCIATED_WITH', 'Associated with')
ON CONFLICT (code) DO NOTHING;

INSERT INTO linguistic.sense_relation_type (code, name)
VALUES ('SYNONYM', 'Synonym'), ('ANTONYM', 'Antonym'), ('RELATED', 'Related'), ('BROADER', 'Broader'), ('NARROWER', 'Narrower')
ON CONFLICT (code) DO NOTHING;

INSERT INTO ingestion.license (code, name, commercial_use_allowed, derivatives_allowed, attribution_required, share_alike_required)
VALUES
  ('CC0', 'Creative Commons Zero', true, true, false, false),
  ('CC-BY', 'Creative Commons Attribution', true, true, true, false),
  ('CC-BY-SA', 'Creative Commons Attribution-ShareAlike', true, true, true, true),
  ('PROPRIETARY', 'Proprietary / licensed', false, false, true, false),
  ('INTERNAL', 'Lingoria internal editorial', true, true, false, false)
ON CONFLICT (code) DO NOTHING;

INSERT INTO ingestion.data_source (code, name, source_type, default_license_id)
SELECT v.code, v.name, v.source_type, l.id
FROM (VALUES
  ('JMDICT', 'JMdict', 'dictionary', 'CC-BY-SA'), ('KANJIDIC', 'KANJIDIC', 'dictionary', 'CC-BY-SA'),
  ('CC_CEDICT', 'CC-CEDICT', 'dictionary', 'CC-BY-SA'), ('TATOEBA', 'Tatoeba', 'corpus', 'CC-BY'),
  ('WIKIDATA', 'Wikidata', 'knowledge_graph', 'CC0'), ('WIKIMEDIA_COMMONS', 'Wikimedia Commons', 'media', 'PROPRIETARY'),
  ('INTERNAL_EDITORIAL', 'Lingoria internal editorial', 'editorial', 'INTERNAL')
) AS v(code, name, source_type, license_code)
JOIN ingestion.license l ON l.code = v.license_code
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, default_license_id = EXCLUDED.default_license_id;

-- Korean source registry. License is intentionally left nullable until the
-- exact release/API terms have been checked for the selected dataset version.
INSERT INTO ingestion.data_source (code, name, source_type, base_url, metadata)
VALUES
  ('KRDICT', 'Korean Basic Dictionary', 'dictionary', 'https://krdict.korean.go.kr/kor/mainAction', '{"locale":"ko-KR"}'),
  ('NIKL_STANDARD', 'NIKL Standard Korean Curriculum', 'curriculum', 'https://korean.go.kr/front/reportData/reportDataView.do?mn_id=207&report_seq=932', '{"locale":"ko-KR"}'),
  ('TEACHING_MATERIALS_KR', 'Korean Teaching Materials Dataset', 'teaching_materials', 'https://data.go.kr/data/15134722/fileData.do', '{"locale":"ko-KR"}'),
  ('MODU_CORPUS', 'NIKL Modu Corpus', 'corpus', 'https://kli.korean.go.kr/corpus', '{"locale":"ko-KR"}'),
  ('TOURAPI', 'Korea Tourism Organization TourAPI', 'culture_api', 'https://data.go.kr/data/15101578/openapi.do', '{"locale":"ko-KR"}')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name, source_type = EXCLUDED.source_type,
  base_url = EXCLUDED.base_url, metadata = EXCLUDED.metadata;

COMMIT;
