-- ============================================================
-- ENGLISH_LEARNING SYSTEM - Advanced Database Objects
-- Target: MySQL 8.0 / InnoDB / database db_LexiLoop
-- Prerequisite: import data/db_LexiLoop.sql first.
-- Run this script once after a backup. PHP application accounts should be
-- granted EXECUTE and SELECT on views, not direct DML on base tables.
-- ============================================================

USE `db_LexiLoop`;

-- Đồng nhất mã ký tự và quy tắc so sánh cho phiên import.
SET NAMES utf8mb4 COLLATE utf8mb4_0900_ai_ci;
-- user_vocab_progress(user_id, vocabulary_id) is already UNIQUE in init data.
-- Do not recreate the same index here; schema changes belong in migrations.

DROP VIEW IF EXISTS `vw_user_daily_learning_summary`;
DROP VIEW IF EXISTS `vw_user_daily_unique_words`;
DROP VIEW IF EXISTS `vw_quiz_incorrect_answers`;
DROP VIEW IF EXISTS `vw_personal_vocabulary`;
DROP VIEW IF EXISTS `vw_system_recent_activity`;
DROP VIEW IF EXISTS `vw_user_recent_activity`;
DROP VIEW IF EXISTS `vw_system_settings`;
DROP VIEW IF EXISTS `vw_vocabulary_sets`;
DROP VIEW IF EXISTS `vw_learning_sessions`;
DROP VIEW IF EXISTS `vw_quiz_results`;
DROP VIEW IF EXISTS `vw_vocabulary_catalog`;
DROP VIEW IF EXISTS `vw_topic_catalog`;
DROP VIEW IF EXISTS `vw_users`;
DROP VIEW IF EXISTS `vw_quiz_result_summary`;
DROP VIEW IF EXISTS `vw_learning_attempt_status`;
DROP VIEW IF EXISTS `vw_learning_items`;
DROP VIEW IF EXISTS `vw_learning_sources`;
DROP VIEW IF EXISTS `vw_user_progress`;
DROP VIEW IF EXISTS `vw_srs_due_topics`;
DROP FUNCTION IF EXISTS `fn_get_current_streak`;
DROP PROCEDURE IF EXISTS `sp_set_vocabulary_statuses`;
DROP PROCEDURE IF EXISTS `sp_delete_personal_vocabularies`;
DROP PROCEDURE IF EXISTS `sp_save_personal_vocabulary`;
DROP PROCEDURE IF EXISTS `sp_save_flashcard_session`;
DROP PROCEDURE IF EXISTS `sp_submit_quiz`;
DROP PROCEDURE IF EXISTS `sp_manage_learning_attempt`;
DROP PROCEDURE IF EXISTS `sp_auth_update_account_settings`;
DROP PROCEDURE IF EXISTS `sp_auth_register_user`;
DROP PROCEDURE IF EXISTS `sp_auth_get_account_by_id`;
DROP PROCEDURE IF EXISTS `sp_auth_get_account_by_email`;
DROP PROCEDURE IF EXISTS `sp_auth_get_active_admin_by_email`;
DROP PROCEDURE IF EXISTS `sp_save_system_setting`;
DROP PROCEDURE IF EXISTS `sp_admin_delete_topic`;
DROP PROCEDURE IF EXISTS `sp_admin_save_topic`;
DROP PROCEDURE IF EXISTS `sp_admin_change_user_status`;
DROP PROCEDURE IF EXISTS `sp_admin_account_capabilities`;
DROP PROCEDURE IF EXISTS `sp_admin_create_account`;
DROP PROCEDURE IF EXISTS `sp_admin_change_user_role`;
DROP PROCEDURE IF EXISTS `sp_admin_delete_account`;
DROP PROCEDURE IF EXISTS `sp_admin_lock_account_pair`;
DROP PROCEDURE IF EXISTS `sp_admin_delete_vocabulary`;
DROP PROCEDURE IF EXISTS `sp_admin_save_vocabulary`;
DROP PROCEDURE IF EXISTS `sp_admin_delete_vocabulary_set`;
DROP PROCEDURE IF EXISTS `sp_delete_vocabulary_set`;
DROP PROCEDURE IF EXISTS `sp_save_vocabulary_set`;
DROP PROCEDURE IF EXISTS `sp_update_user_profile`;
DROP TRIGGER IF EXISTS `trg_validate_review_log`;
DROP TRIGGER IF EXISTS `trg_update_last_studied_date`;

DELIMITER $$

-- One row per user-vocabulary progress record, suitable for dashboards/history.
CREATE VIEW `vw_user_progress` AS
SELECT
    u.`userID` AS `user_id`,
    u.`full_name`,
    p.`id` AS `progress_id`,
    v.`id` AS `vocabulary_id`,
    v.`word`,
    v.`meaning`,
    t.`topicID` AS `topic_id`,
    t.`topicName` AS `topic_name`,
    p.`status`,
    p.`repetitions`,
    p.`ease_factor`,
    p.`interval_days`,
    p.`next_review_date`,
    p.`last_reviewed_at`,
    p.`last_quality_rating`,
    CASE
        WHEN p.`next_review_date` IS NULL THEN 'new'
        WHEN p.`next_review_date` <= CURRENT_DATE THEN 'due'
        ELSE 'scheduled'
    END AS `review_state`
FROM `user_vocab_progress` p
JOIN `Users` u ON u.`userID` = p.`user_id`
JOIN `vocabulary` v ON v.`id` = p.`vocabulary_id`
LEFT JOIN `Topics` t ON t.`topicID` = v.`topic_id`$$

-- Aggregates due vocabulary for SRS review by topic.
CREATE VIEW `vw_srs_due_topics` AS
SELECT 
    up.`user_id`,
    up.`topic_id`,
    up.`topic_name`,
    tc.`category`,
    COUNT(up.`vocabulary_id`) AS `due_word_count`,
    MIN(up.`next_review_date`) AS `oldest_due_date`,
    DATEDIFF(CURRENT_DATE, MIN(up.`next_review_date`)) AS `overdue_days`
FROM `vw_user_progress` up
JOIN `Topics` tc ON up.`topic_id` = tc.`topicID`
WHERE up.`next_review_date` <= CURRENT_DATE
GROUP BY up.`user_id`, up.`topic_id`, up.`topic_name`, tc.`category`$$

-- Stable read contracts used while legacy pages are migrated away from tables.
CREATE VIEW `vw_users` AS
SELECT `userID`, `email`, `password_hash`, `full_name`, `avatar_url`, `role`, `status`,
       `created_at`, `update_at`, `daily_reminder_enabled`, `reminder_time`, `daily_target_words`,
       `date_of_birth`, `target_level`
FROM `Users`$$

CREATE VIEW `vw_topic_catalog` AS
SELECT t.`topicID`, t.`topicName`, t.`topicDescription`, t.`category`, t.`created_by`,
       u.`full_name` AS `creator_name`, u.`email` AS `creator_email`, u.`role` AS `creator_role`,
       t.`topicCreated_at`, COUNT(DISTINCT v.`id`) AS `word_count`
FROM `Topics` t
LEFT JOIN `Users` u ON u.`userID` = t.`created_by`
LEFT JOIN `vocabulary` v ON v.`topic_id` = t.`topicID`
GROUP BY t.`topicID`, t.`topicName`, t.`topicDescription`, t.`category`, t.`created_by`,
         u.`full_name`, u.`email`, u.`role`, t.`topicCreated_at`$$

CREATE VIEW `vw_vocabulary_catalog` AS
SELECT
    v.`id`,
    v.`topic_id`,
    v.`word`,
    v.`pronunciation`,
    v.`part_of_speech`,
    v.`meaning`,
    v.`example_sentence`,
    v.`created_by`,
    v.`created_at`,
    v.`audio_url`,
    t.`topicName`,
    t.`category` AS `topic_category`,
    u.`full_name` AS `creator_name`,
    u.`email` AS `creator_email`,
    u.`role` AS `creator_role`,
    CASE
        WHEN v.`topic_id` IS NOT NULL THEN 'system'
        ELSE 'personal'
    END AS `source_type`,
    GROUP_CONCAT(DISTINCT vs.`id` ORDER BY vs.`id`) AS `set_ids`,
    GROUP_CONCAT(DISTINCT vs.`name` ORDER BY vs.`name` SEPARATOR ', ') AS `set_names`,
    CASE
        WHEN t.`topicName` IS NOT NULL THEN t.`topicName`
        WHEN GROUP_CONCAT(DISTINCT vs.`name` SEPARATOR ', ') IS NOT NULL THEN GROUP_CONCAT(DISTINCT vs.`name` SEPARATOR ', ')
        ELSE 'Cá nhân (Chưa gán bộ từ)'
    END AS `display_topic`
FROM `vocabulary` v
LEFT JOIN `Topics` t ON t.`topicID` = v.`topic_id`
LEFT JOIN `Users` u ON u.`userID` = v.`created_by`
LEFT JOIN `vocabulary_set_items` vsi ON vsi.`vocabulary_id` = v.`id`
LEFT JOIN `vocabulary_sets` vs ON vs.`id` = vsi.`vocabulary_set_id`
GROUP BY v.`id`, v.`topic_id`, v.`word`, v.`pronunciation`, v.`part_of_speech`,
         v.`meaning`, v.`example_sentence`, v.`created_by`, v.`created_at`,
         v.`audio_url`, t.`topicName`, t.`category`, u.`full_name`, u.`email`, u.`role`$$

CREATE VIEW `vw_quiz_results` AS SELECT * FROM `quiz_results`$$
CREATE VIEW `vw_learning_sessions` AS SELECT * FROM `learning_sessions`$$
CREATE VIEW `vw_vocabulary_sets` AS
SELECT vs.*, u.`full_name` AS `owner_name`, u.`email` AS `owner_email`, COUNT(DISTINCT vsi.`id`) AS `word_count`
FROM `vocabulary_sets` vs
LEFT JOIN `Users` u ON u.`userID` = vs.`user_id`
LEFT JOIN `vocabulary_set_items` vsi ON vsi.`vocabulary_set_id` = vs.`id`
GROUP BY vs.`id`, vs.`user_id`, vs.`name`, vs.`description`, vs.`created_at`, vs.`updated_at`,
         u.`full_name`, u.`email`$$
CREATE VIEW `vw_system_settings` AS SELECT * FROM `system_settings`$$

-- A stable database-facing contract for topic and owned personal-set labels.
CREATE VIEW `vw_learning_sources` AS
SELECT
    'topic' AS `source_type`,
    t.`topicID` AS `source_id`,
    NULL AS `owner_user_id`,
    t.`topicName` AS `source_name`,
    t.`topicDescription` AS `source_description`,
    COUNT(v.`id`) AS `word_count`
FROM `Topics` t
LEFT JOIN `vocabulary` v ON v.`topic_id` = t.`topicID`
GROUP BY t.`topicID`, t.`topicName`, t.`topicDescription`
UNION ALL
SELECT
    'set' AS `source_type`,
    vs.`id` AS `source_id`,
    vs.`user_id` AS `owner_user_id`,
    vs.`name` AS `source_name`,
    vs.`description` AS `source_description`,
    COUNT(vsi.`id`) AS `word_count`
FROM `vocabulary_sets` vs
LEFT JOIN `vocabulary_set_items` vsi ON vsi.`vocabulary_set_id` = vs.`id`
GROUP BY vs.`id`, vs.`user_id`, vs.`name`, vs.`description`$$

-- One view serves all three learning sources. For topic rows owner_user_id is
-- NULL; for set/review rows PHP must filter it with the authenticated user ID.
CREATE VIEW `vw_learning_items` AS
SELECT
    'topic' AS `source_type`, v.`topic_id` AS `source_id`, NULL AS `owner_user_id`,
    v.`id` AS `vocabulary_id`, v.`word`, v.`pronunciation`, v.`part_of_speech`,
    v.`meaning`, v.`example_sentence`, v.`audio_url`, NULL AS `next_review_date`,
    v.`id` AS `display_order`
FROM `vocabulary` v
UNION ALL
SELECT
    'set', vsi.`vocabulary_set_id`, vs.`user_id`,
    v.`id`, v.`word`, v.`pronunciation`, v.`part_of_speech`,
    v.`meaning`, v.`example_sentence`, v.`audio_url`, p.`next_review_date`,
    vsi.`display_order`
FROM `vocabulary_set_items` vsi
JOIN `vocabulary_sets` vs ON vs.`id` = vsi.`vocabulary_set_id`
JOIN `vocabulary` v ON v.`id` = vsi.`vocabulary_id`
LEFT JOIN `user_vocab_progress` p
       ON p.`vocabulary_id` = v.`id` AND p.`user_id` = vs.`user_id`
UNION ALL
SELECT
    'review', NULL, p.`user_id`,
    v.`id`, v.`word`, v.`pronunciation`, v.`part_of_speech`,
    v.`meaning`, v.`example_sentence`, v.`audio_url`, p.`next_review_date`,
    DATEDIFF(p.`next_review_date`, '1970-01-01')
FROM `user_vocab_progress` p
JOIN `vocabulary` v ON v.`id` = p.`vocabulary_id`
WHERE p.`next_review_date` <= CURRENT_DATE OR DATE(p.`last_reviewed_at`) = CURRENT_DATE$$

CREATE VIEW `vw_quiz_result_summary` AS
SELECT
    qr.`id` AS `quiz_result_id`, qr.`user_id`, qr.`topic_id`, qr.`vocabulary_set_id`,
    qr.`total_questions`, qr.`correct_answers`, qr.`score`, qr.`started_at`, qr.`finished_at`,
    GREATEST(0, TIMESTAMPDIFF(SECOND, qr.`started_at`, qr.`finished_at`)) AS `duration_seconds`
FROM `quiz_results` qr$$

CREATE VIEW `vw_learning_attempt_status` AS
SELECT `id`, `user_id`, `activity_type`, `source_type`, `source_id`, `item_limit`,
       `state_json`, `status`, `started_at`, `updated_at`, `completed_at`
FROM `learning_attempts`$$

CREATE VIEW `vw_quiz_incorrect_answers` AS
SELECT
    qr.`user_id`, qad.`quiz_result_id`, qad.`question_order`, qad.`vocabulary_id`,
    v.`word`, qad.`selected_answer`, qad.`correct_answer`, qad.`response_time_ms`
FROM `quiz_answer_details` qad
JOIN `quiz_results` qr ON qr.`id` = qad.`quiz_result_id`
JOIN `vocabulary` v ON v.`id` = qad.`vocabulary_id`
WHERE qad.`is_correct` = 0$$

-- Personal vocabulary read model. PHP filters by the authenticated user ID;
-- ownership checks for writes remain inside Stored Procedures.
CREATE VIEW `vw_personal_vocabulary` AS
SELECT
    vs.`user_id`, v.`id`, v.`word`, v.`pronunciation`, v.`part_of_speech`,
    v.`meaning`, v.`example_sentence`, v.`topic_id`, v.`created_by`,
    GROUP_CONCAT(vsi.`vocabulary_set_id` ORDER BY vsi.`vocabulary_set_id`) AS `set_ids`,
    GROUP_CONCAT(vs.`name` ORDER BY vs.`name` SEPARATOR ' • ') AS `set_names`,
    COALESCE(p.`status`, 'new') AS `progress_status`, p.`next_review_date`
FROM `vocabulary_set_items` vsi
JOIN `vocabulary_sets` vs ON vs.`id` = vsi.`vocabulary_set_id`
JOIN `vocabulary` v ON v.`id` = vsi.`vocabulary_id`
LEFT JOIN `user_vocab_progress` p
       ON p.`user_id` = vs.`user_id` AND p.`vocabulary_id` = v.`id`
GROUP BY vs.`user_id`, v.`id`, v.`word`, v.`pronunciation`, v.`part_of_speech`,
         v.`meaning`, v.`example_sentence`, v.`topic_id`, v.`created_by`,
         p.`status`, p.`next_review_date`$$

CREATE VIEW `vw_user_recent_activity` AS
SELECT qr.`id`, qr.`user_id`, 'quiz' AS `activity_type`,
       COALESCE(t.`topicName`, vs.`name`, 'Ôn tập tổng hợp') AS `source_name`,
       qr.`correct_answers`, qr.`total_questions`, NULL AS `words_studied`,
       COALESCE(qr.`finished_at`, qr.`started_at`) AS `activity_time`,
       GREATEST(0, TIMESTAMPDIFF(SECOND, qr.`started_at`, qr.`finished_at`)) AS `duration_seconds`, 1 AS `has_exact_time`
FROM `quiz_results` qr
LEFT JOIN `Topics` t ON t.`topicID` = qr.`topic_id`
LEFT JOIN `vocabulary_sets` vs ON vs.`id` = qr.`vocabulary_set_id`
UNION ALL
SELECT ls.`id`, ls.`user_id`, 'flashcard',
       COALESCE(t.`topicName`, vs.`name`, 'Ôn tập tổng hợp'),
       NULL, NULL, ls.`words_studied`,
       COALESCE(ls.`finished_at`, ls.`started_at`, CAST(CONCAT(ls.`session_date`, ' 00:00:00') AS DATETIME)),
       COALESCE(ls.`duration_seconds`, 0), IF(ls.`finished_at` IS NULL AND ls.`started_at` IS NULL, 0, 1)
FROM `learning_sessions` ls
LEFT JOIN `Topics` t ON t.`topicID` = ls.`topic_id`
LEFT JOIN `vocabulary_sets` vs ON vs.`id` = ls.`vocabulary_set_id`
WHERE ls.`words_studied` > 0$$

-- Mỗi dòng là một từ duy nhất mà user đã luyện trong một ngày.
-- UNION (không phải UNION ALL) loại trùng khi cùng từ được học nhiều lần,
-- học bằng Flashcard rồi Quiz, hoặc xuất hiện ở cả chủ đề và bộ từ cá nhân.
CREATE VIEW `vw_user_daily_unique_words` AS
SELECT p.`user_id`, rl.`review_date` AS `activity_date`, p.`vocabulary_id`
FROM `review_logs` rl
JOIN `user_vocab_progress` p ON p.`id` = rl.`progress_id`
UNION
SELECT qr.`user_id`, DATE(qr.`finished_at`) AS `activity_date`, qad.`vocabulary_id`
FROM `quiz_results` qr
JOIN `quiz_answer_details` qad ON qad.`quiz_result_id` = qr.`id`
WHERE qr.`finished_at` IS NOT NULL$$

-- View tổng hợp dùng chung cho Dashboard, streak và biểu đồ lịch sử.
-- Việc tính một lần tại DB giúp các trang không tự cộng theo quy tắc khác nhau.
CREATE VIEW `vw_user_daily_learning_summary` AS
SELECT `user_id`, `activity_date`, COUNT(*) AS `unique_words_count`
FROM `vw_user_daily_unique_words`
GROUP BY `user_id`, `activity_date`$$

CREATE VIEW `vw_system_recent_activity` AS
SELECT 
    'user' AS `loai`,
    `userID` AS `activity_id`,
    `full_name` AS `tieuDe`,
    `email` AS `chiTiet`,
    `created_at` AS `thoiGian`,
    `full_name` AS `actor_name`,
    `email` AS `target_name`,
    NULL AS `score_text`
FROM `Users`
UNION ALL
SELECT 
    'topic' AS `loai`,
    `topicID` AS `activity_id`,
    `topicName` AS `tieuDe`,
    `topicDescription` AS `chiTiet`,
    `topicCreated_at` AS `thoiGian`,
    NULL AS `actor_name`,
    `topicName` AS `target_name`,
    NULL AS `score_text`
FROM `Topics`
UNION ALL
SELECT 
    'set' AS `loai`,
    vs.`id` AS `activity_id`,
    vs.`name` AS `tieuDe`,
    u.`full_name` AS `chiTiet`,
    vs.`created_at` AS `thoiGian`,
    u.`full_name` AS `actor_name`,
    vs.`name` AS `target_name`,
    NULL AS `score_text`
FROM `vocabulary_sets` vs
LEFT JOIN `Users` u ON u.`userID` = vs.`user_id`
UNION ALL
SELECT 
    'quiz' AS `loai`,
    qr.`id` AS `activity_id`,
    COALESCE(t.`topicName`, vs.`name`, 'Ôn tập tổng hợp') AS `tieuDe`,
    CONCAT(qr.`correct_answers`, '/', qr.`total_questions`) AS `chiTiet`,
    COALESCE(qr.`finished_at`, qr.`started_at`) AS `thoiGian`,
    u.`full_name` AS `actor_name`,
    COALESCE(t.`topicName`, vs.`name`, 'Ôn tập') AS `target_name`,
    CONCAT(qr.`correct_answers`, '/', qr.`total_questions`) AS `score_text`
FROM `quiz_results` qr
LEFT JOIN `Users` u ON u.`userID` = qr.`user_id`
LEFT JOIN `Topics` t ON t.`topicID` = qr.`topic_id`
LEFT JOIN `vocabulary_sets` vs ON vs.`id` = qr.`vocabulary_set_id`
WHERE qr.`finished_at` IS NOT NULL
UNION ALL
SELECT 
    'flashcard' AS `loai`,
    ls.`id` AS `activity_id`,
    COALESCE(t.`topicName`, vs.`name`, 'Ôn tập tổng hợp') AS `tieuDe`,
    CAST(ls.`words_studied` AS CHAR) AS `chiTiet`,
    COALESCE(ls.`finished_at`, ls.`started_at`, CAST(CONCAT(ls.`session_date`, ' 00:00:00') AS DATETIME)) AS `thoiGian`,
    u.`full_name` AS `actor_name`,
    COALESCE(t.`topicName`, vs.`name`, 'Ôn tập') AS `target_name`,
    CAST(ls.`words_studied` AS CHAR) AS `score_text`
FROM `learning_sessions` ls
LEFT JOIN `Users` u ON u.`userID` = ls.`user_id`
LEFT JOIN `Topics` t ON t.`topicID` = ls.`topic_id`
LEFT JOIN `vocabulary_sets` vs ON vs.`id` = ls.`vocabulary_set_id`
WHERE ls.`words_studied` > 0$$

-- Đếm chuỗi ngày có ít nhất một từ duy nhất được luyện bằng Flashcard hoặc Quiz.
-- Nếu hôm nay chưa học nhưng hôm qua có học, chuỗi vẫn được giữ đến hết hôm nay;
-- chỉ khi bỏ trọn một ngày thì chuỗi mới trở về 0.
CREATE FUNCTION `fn_get_current_streak`(p_user_id INT)
RETURNS INT
READS SQL DATA
BEGIN
    DECLARE v_day DATE DEFAULT NULL;
    DECLARE v_streak INT DEFAULT 0;
    DECLARE v_has_activity BOOLEAN DEFAULT FALSE;

    SELECT MAX(`activity_date`) INTO v_day
      FROM `vw_user_daily_learning_summary`
     WHERE `user_id` = p_user_id
       AND `activity_date` BETWEEN CURRENT_DATE - INTERVAL 1 DAY AND CURRENT_DATE;

    IF v_day IS NULL THEN
        RETURN 0;
    END IF;

    streak_loop: LOOP
        SELECT EXISTS(
            SELECT 1
              FROM `vw_user_daily_learning_summary` d
             WHERE d.`user_id` = p_user_id AND d.`activity_date` = v_day
        ) INTO v_has_activity;

        IF NOT v_has_activity THEN
            LEAVE streak_loop;
        END IF;
        SET v_streak = v_streak + 1;
        SET v_day = DATE_SUB(v_day, INTERVAL 1 DAY);
    END LOOP;

    RETURN v_streak;
END$$

-- Authentication reads stay behind procedures so PHP never selects Users directly.
CREATE PROCEDURE `sp_auth_get_account_by_email`(IN p_email VARCHAR(50))
READS SQL DATA
BEGIN
    SELECT `userID`, `email`, `password_hash`, `full_name`, `avatar_url`, `role`, `status`,
           `date_of_birth`, `target_level`
      FROM `Users`
     WHERE `email` = LOWER(TRIM(p_email))
     LIMIT 1;
END$$

-- This is intentionally separate from user login: it never exposes a normal
-- user account to the administration login flow.
CREATE PROCEDURE `sp_auth_get_active_admin_by_email`(IN p_email VARCHAR(50))
READS SQL DATA
BEGIN
    SELECT `userID`, `email`, `password_hash`, `full_name`, `role`, `status`
      FROM `Users`
     WHERE `email` = LOWER(TRIM(p_email))
       AND `role` = 'admin'
       AND `status` = 'active'
     LIMIT 1;
END$$

CREATE PROCEDURE `sp_auth_get_account_by_id`(IN p_user_id INT)
READS SQL DATA
BEGIN
    SELECT `userID`, `email`, `password_hash`, `full_name`, `avatar_url`, `role`, `status`,
           `daily_reminder_enabled`, `reminder_time`, `daily_target_words`,
           `date_of_birth`, `target_level`
      FROM `Users`
     WHERE `userID` = p_user_id
     LIMIT 1;
END$$

-- TS Đăng ký tài khoản
CREATE PROCEDURE `sp_auth_register_user`(
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(50),
    IN p_password_hash VARCHAR(300)
)
MODIFIES SQL DATA
BEGIN
    IF CHAR_LENGTH(TRIM(p_full_name)) < 2 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'full_name is invalid';
    END IF;
    IF CHAR_LENGTH(TRIM(p_email)) < 3 OR LOCATE('@', p_email) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'email is invalid';
    END IF;
    IF CHAR_LENGTH(p_password_hash) < 20 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'password hash is invalid';
    END IF;

    INSERT INTO `Users` (`full_name`, `email`, `password_hash`, `role`, `status`)
    VALUES (TRIM(p_full_name), LOWER(TRIM(p_email)), p_password_hash, 'user', 'active');

    SELECT LAST_INSERT_ID() AS `user_id`;
    -- 
END$$

CREATE PROCEDURE `sp_auth_update_account_settings`(
    IN p_user_id INT,
    IN p_new_password_hash VARCHAR(300),
    IN p_daily_reminder_enabled BOOLEAN,
    IN p_reminder_time TIME,
    IN p_daily_target_words INT
)
MODIFIES SQL DATA
BEGIN
    IF p_daily_target_words NOT BETWEEN 1 AND 200 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'daily target must be between 1 and 200';
    END IF;
    IF p_new_password_hash IS NOT NULL AND CHAR_LENGTH(p_new_password_hash) < 20 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'password hash is invalid';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `Users` WHERE `userID` = p_user_id AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found';
    END IF;

    UPDATE `Users`
       SET `password_hash` = COALESCE(p_new_password_hash, `password_hash`),
           `daily_reminder_enabled` = IF(p_daily_reminder_enabled, 1, 0),
           `reminder_time` = p_reminder_time,
           `daily_target_words` = p_daily_target_words
     WHERE `userID` = p_user_id AND `status` = 'active';
END$$

-- Integrity guard: the quality scale is 0..5 and response time cannot be negative.
CREATE TRIGGER `trg_validate_review_log`
BEFORE INSERT ON `review_logs`
FOR EACH ROW
BEGIN
    IF NEW.`quality_rating` NOT BETWEEN 0 AND 5 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'quality_rating must be between 0 and 5';
    END IF;
    IF NEW.`response_time_ms` IS NOT NULL AND NEW.`response_time_ms` < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'response_time_ms must not be negative';
    END IF;
END$$

-- Centralizes the denormalized “last studied” values when a review is logged.
CREATE TRIGGER `trg_update_last_studied_date`
AFTER INSERT ON `review_logs`
FOR EACH ROW
BEGIN
    UPDATE `user_vocab_progress`
       SET `last_reviewed_at` = NOW(),
           `last_quality_rating` = NEW.`quality_rating`
     WHERE `id` = NEW.`progress_id`;
END$$

-- Saves an entire Flashcard screen as one atomic session. p_statuses_json is
-- an object such as {"12":"da_nho","15":"chua_nho"}.
CREATE PROCEDURE `sp_save_flashcard_session`(
    IN p_user_id INT,
    IN p_source_type VARCHAR(10),
    IN p_source_id INT,
    IN p_statuses_json JSON,
    IN p_duration_seconds INT,
    IN p_is_final BOOLEAN
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_user_exists BOOLEAN DEFAULT FALSE;
    DECLARE v_locked_user_id INT;
    DECLARE v_vocabulary_id INT;
    DECLARE v_answer VARCHAR(20);
    DECLARE v_is_member BOOLEAN DEFAULT FALSE;
    DECLARE v_progress_id INT;
    DECLARE v_status VARCHAR(10);
    DECLARE v_interval INT;
    DECLARE v_quality INT;
    DECLARE v_word_count INT DEFAULT 0;
    DECLARE v_topic_id INT DEFAULT NULL;
    DECLARE v_set_id INT DEFAULT NULL;
    DECLARE v_session_type VARCHAR(20);
    DECLARE v_streak INT DEFAULT 0;
    DECLARE v_session_id INT DEFAULT NULL;
    DECLARE v_base_ease FLOAT DEFAULT 2.5;
    DECLARE v_min_interval INT DEFAULT 1;
    DECLARE v_old_interval INT DEFAULT 0;
    DECLARE v_old_ease FLOAT DEFAULT 2.5;
    DECLARE v_old_repetitions INT DEFAULT 0;
    DECLARE v_repetitions INT DEFAULT 0;
    DECLARE v_new_ease FLOAT;

    DECLARE status_cursor CURSOR FOR
        SELECT CAST(j.`vocabulary_key` AS UNSIGNED),
               JSON_UNQUOTE(JSON_EXTRACT(p_statuses_json, CONCAT('$."', j.`vocabulary_key`, '"')))
          FROM JSON_TABLE(
              JSON_KEYS(p_statuses_json),
              '$[*]' COLUMNS (`vocabulary_key` VARCHAR(20) PATH '$')
          ) j;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_source_type NOT IN ('topic', 'set', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid learning source';
    END IF;
    IF p_source_type <> 'review' AND (p_source_id IS NULL OR p_source_id <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source ID is required';
    END IF;
    IF p_statuses_json IS NULL OR JSON_TYPE(p_statuses_json) <> 'OBJECT' OR JSON_LENGTH(p_statuses_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'statuses must be a non-empty JSON object';
    END IF;
    IF p_duration_seconds NOT BETWEEN 0 AND 86400 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid duration';
    END IF;

    -- TS Flashcard/SRS
    START TRANSACTION;
    SELECT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_user_id AND `status` = 'active')
      INTO v_user_exists;
    IF NOT v_user_exists THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found';
    END IF;
    
    SELECT `userID`, COALESCE(`srs_base_ease`, 2.5), COALESCE(`srs_min_interval`, 1) 
      INTO v_locked_user_id, v_base_ease, v_min_interval 
      FROM `Users` WHERE `userID` = p_user_id FOR UPDATE;
    -- 

    IF p_source_type = 'topic' THEN
        IF NOT EXISTS(SELECT 1 FROM `Topics` WHERE `topicID` = p_source_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic not found';
        END IF;
        SET v_topic_id = p_source_id;
        SET v_session_type = 'new_learning';
    ELSEIF p_source_type = 'set' THEN
        IF NOT EXISTS(SELECT 1 FROM `vocabulary_sets` WHERE `id` = p_source_id AND `user_id` = p_user_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary set is not owned by user';
        END IF;
        SET v_set_id = p_source_id;
        SET v_session_type = 'new_learning';
    ELSE
        SET v_session_type = 'review';
    END IF;

    OPEN status_cursor;
    status_loop: LOOP
        FETCH status_cursor INTO v_vocabulary_id, v_answer;
        IF v_done THEN LEAVE status_loop; END IF;
        IF v_vocabulary_id <= 0 OR v_answer NOT IN ('da_nho', 'chua_nho') THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid Flashcard answer';
        END IF;

        IF p_source_type = 'topic' THEN
            SELECT EXISTS(SELECT 1 FROM `vocabulary` WHERE `id` = v_vocabulary_id AND `topic_id` = p_source_id)
              INTO v_is_member;
        ELSEIF p_source_type = 'set' THEN
            SELECT EXISTS(
                SELECT 1 FROM `vocabulary_set_items` vsi
                JOIN `vocabulary_sets` vs ON vs.`id` = vsi.`vocabulary_set_id`
                WHERE vsi.`vocabulary_id` = v_vocabulary_id
                  AND vsi.`vocabulary_set_id` = p_source_id AND vs.`user_id` = p_user_id
            ) INTO v_is_member;
        ELSE
            SELECT EXISTS(
                SELECT 1 FROM `user_vocab_progress`
                WHERE `user_id` = p_user_id AND `vocabulary_id` = v_vocabulary_id
                  AND (`next_review_date` <= CURRENT_DATE OR DATE(`last_reviewed_at`) = CURRENT_DATE)
            ) INTO v_is_member;
        END IF;
        IF NOT v_is_member THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary is not in the authorized source';
        END IF;

        -- Một từ chỉ được thay đổi lịch SRS một lần trong ngày. Checkpoint,
        -- tab thứ hai hoặc Quiz sau Flashcard không được tăng/lùi lịch lần nữa.
        IF p_source_type = 'review' AND EXISTS(
            SELECT 1 FROM `user_vocab_progress`
             WHERE `user_id` = p_user_id AND `vocabulary_id` = v_vocabulary_id
               AND DATE(`last_reviewed_at`) = CURRENT_DATE
        ) THEN
            SET v_word_count = v_word_count + 1;
            ITERATE status_loop;
        END IF;

        -- SM-2 Algorithm Integration
        -- Dùng aggregate COALESCE(MAX(...)) để luôn trả về đúng 1 dòng (kể cả khi từ chưa có trong user_vocab_progress),
        -- tránh kích hoạt CONTINUE HANDLER FOR NOT FOUND làm cursor bị ngắt vòng lặp sớm.
        SET v_old_interval = 0;
        SET v_old_ease = v_base_ease;
        SET v_old_repetitions = 0;

        SELECT COALESCE(MAX(`interval_days`), 0),
               COALESCE(MAX(`ease_factor`), v_base_ease),
               COALESCE(MAX(`repetitions`), 0)
          INTO v_old_interval, v_old_ease, v_old_repetitions
          FROM `user_vocab_progress`
         WHERE `user_id` = p_user_id AND `vocabulary_id` = v_vocabulary_id;

        SET v_quality = IF(v_answer = 'da_nho', 5, 2);
        SET v_new_ease = GREATEST(1.30, v_old_ease + (0.10 - (5 - v_quality) * (0.08 + (5 - v_quality) * 0.02)));

        IF v_answer = 'chua_nho' THEN
            SET v_repetitions = 0;
            SET v_interval = v_min_interval;
        ELSE
            SET v_repetitions = v_old_repetitions + IF(p_is_final, 1, 0);
            SET v_interval = CASE
                WHEN v_repetitions = 0 THEN v_min_interval
                WHEN v_repetitions = 1 THEN GREATEST(v_min_interval, 1)
                WHEN v_repetitions = 2 THEN GREATEST(v_min_interval, 6)
                ELSE GREATEST(v_min_interval, ROUND(GREATEST(v_old_interval, 1) * v_new_ease))
            END;
        END IF;

        SET v_status = CASE
            WHEN v_answer = 'chua_nho' THEN 'learning'
            WHEN v_repetitions >= 5 THEN 'mastered'
            ELSE 'learning'
        END;

        INSERT INTO `user_vocab_progress`
            (`user_id`, `vocabulary_id`, `status`, `ease_factor`, `interval_days`, `repetitions`,
             `next_review_date`, `last_reviewed_at`, `last_quality_rating`)
        VALUES
            (p_user_id, v_vocabulary_id, v_status, v_new_ease, v_interval, v_repetitions,
             DATE_ADD(CURRENT_DATE, INTERVAL v_interval DAY), NOW(), v_quality)
        ON DUPLICATE KEY UPDATE
            `id` = LAST_INSERT_ID(`id`),
            `ease_factor` = VALUES(`ease_factor`),
            `interval_days` = VALUES(`interval_days`),
            `repetitions` = VALUES(`repetitions`),
            `status` = CASE
                WHEN `status` = 'mastered' AND VALUES(`status`) = 'learning' THEN 'learning'
                WHEN `status` = 'mastered' THEN 'mastered'
                ELSE VALUES(`status`)
            END,
            `next_review_date` = VALUES(`next_review_date`),
            `last_reviewed_at` = NOW(), `last_quality_rating` = VALUES(`last_quality_rating`);
        SET v_progress_id = LAST_INSERT_ID();

        -- Ghi nhận cả những thẻ đã đánh giá trong phiên kết thúc sớm. View
        -- thống kê theo ngày sẽ loại trùng, nên lưu lại nhiều lần vẫn chỉ tính
        -- một vocabulary_id cho KPI và streak của ngày đó.
        INSERT INTO `review_logs` (`progress_id`, `review_date`, `quality_rating`, `response_time_ms`)
        VALUES (v_progress_id, CURRENT_DATE, v_quality, NULL);
        SET v_word_count = v_word_count + 1;
        SET v_done = FALSE;
    END LOOP;
    CLOSE status_cursor;

    IF v_word_count <> JSON_LENGTH(p_statuses_json) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'one or more Flashcard answers are invalid';
    END IF;

    IF p_is_final THEN
        SET v_streak = fn_get_current_streak(p_user_id);
        INSERT INTO `learning_sessions`
            (`user_id`, `topic_id`, `vocabulary_set_id`, `session_type`, `session_date`,
             `words_studied`, `duration_seconds`, `streak_count`, `started_at`, `finished_at`)
        VALUES
            (p_user_id, v_topic_id, v_set_id, v_session_type, CURRENT_DATE,
             v_word_count, p_duration_seconds, v_streak,
             DATE_SUB(NOW(), INTERVAL p_duration_seconds SECOND), NOW());
        SET v_session_id = LAST_INSERT_ID();
    END IF;

    COMMIT;
    SELECT v_session_id AS `learning_session_id`, v_word_count AS `word_count`;
END$$

-- Validates answers against the authorized source, scores them in MySQL and
-- writes result + details + attempt completion in one transaction.
CREATE PROCEDURE `sp_submit_quiz`(
    IN p_user_id INT,
    IN p_source_type VARCHAR(10),
    IN p_source_id INT,
    IN p_mode VARCHAR(10),
    IN p_item_limit VARCHAR(10),
    IN p_answers_json JSON,
    IN p_duration_seconds INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_input_count INT DEFAULT 0;
    DECLARE v_locked_user_id INT;
    DECLARE v_valid_count INT DEFAULT 0;
    DECLARE v_correct_count INT DEFAULT 0;
    DECLARE v_quiz_result_id INT;
    DECLARE v_topic_id INT DEFAULT NULL;
    DECLARE v_set_id INT DEFAULT NULL;
    DECLARE v_source_id_db INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS `tmp_quiz_answers`;
        RESIGNAL;
    END;

    IF p_source_type NOT IN ('topic', 'set', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid learning source';
    END IF;
    IF p_mode NOT IN ('practice', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid quiz mode';
    END IF;
    IF p_mode = 'review' AND p_source_type NOT IN ('topic', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid SRS review source';
    END IF;
    IF p_source_type <> 'review' AND (p_source_id IS NULL OR p_source_id <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source ID is required';
    END IF;
    IF p_item_limit NOT IN ('5', '10', '20', 'all') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid item limit';
    END IF;
    IF p_answers_json IS NULL OR JSON_TYPE(p_answers_json) <> 'ARRAY' OR JSON_LENGTH(p_answers_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'answers must be a non-empty JSON array';
    END IF;
    IF p_duration_seconds NOT BETWEEN 0 AND 86400 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid duration';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS `tmp_quiz_answers`;
    CREATE TEMPORARY TABLE `tmp_quiz_answers` (
        `question_order` INT NOT NULL,
        `vocabulary_id` INT NOT NULL,
        `selected_answer` TEXT NULL,
        `correct_answer` TEXT NOT NULL,
        `is_correct` BOOLEAN NOT NULL,
        `response_time_ms` INT NULL,
        PRIMARY KEY (`vocabulary_id`)
    ) ENGINE=InnoDB;

    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_user_id AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found';
    END IF;
    SELECT `userID` INTO v_locked_user_id FROM `Users` WHERE `userID` = p_user_id FOR UPDATE;

    SET v_input_count = JSON_LENGTH(p_answers_json);
    IF p_source_type = 'topic' THEN
        IF NOT EXISTS(SELECT 1 FROM `Topics` WHERE `topicID` = p_source_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic not found';
        END IF;
        SET v_topic_id = p_source_id;
        SET v_source_id_db = p_source_id;
        IF p_mode = 'review' THEN
            INSERT INTO `tmp_quiz_answers`
            SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
                   v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
              FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
                  `question_order` FOR ORDINALITY,
                  `vocabulary_id` INT PATH '$.vocabularyId',
                  `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
                  `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
              )) j
              JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id` AND v.`topic_id` = p_source_id
              JOIN `user_vocab_progress` p
                ON p.`vocabulary_id` = v.`id` AND p.`user_id` = p_user_id
               AND p.`next_review_date` <= CURRENT_DATE;
        ELSE
            INSERT INTO `tmp_quiz_answers`
            SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
                   v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
              FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
                  `question_order` FOR ORDINALITY,
                  `vocabulary_id` INT PATH '$.vocabularyId',
                  `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
                  `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
              )) j
              JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id` AND v.`topic_id` = p_source_id;
        END IF;
    ELSEIF p_source_type = 'set' THEN
        IF NOT EXISTS(SELECT 1 FROM `vocabulary_sets` WHERE `id` = p_source_id AND `user_id` = p_user_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary set is not owned by user';
        END IF;
        SET v_set_id = p_source_id;
        SET v_source_id_db = p_source_id;
        INSERT INTO `tmp_quiz_answers`
        SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
               v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
          FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
              `question_order` FOR ORDINALITY,
              `vocabulary_id` INT PATH '$.vocabularyId',
              `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
              `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
          )) j
          JOIN `vocabulary_set_items` vsi
            ON vsi.`vocabulary_id` = j.`vocabulary_id` AND vsi.`vocabulary_set_id` = p_source_id
          JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id`;
    ELSE
        INSERT INTO `tmp_quiz_answers`
        SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
               v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
          FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
              `question_order` FOR ORDINALITY,
              `vocabulary_id` INT PATH '$.vocabularyId',
              `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
              `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
          )) j
          JOIN `user_vocab_progress` p
            ON p.`vocabulary_id` = j.`vocabulary_id` AND p.`user_id` = p_user_id
           AND (p.`next_review_date` <= CURRENT_DATE OR DATE(p.`last_reviewed_at`) = CURRENT_DATE)
          JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id`;
    END IF;

    SELECT COUNT(*), COALESCE(SUM(`is_correct`), 0)
      INTO v_valid_count, v_correct_count FROM `tmp_quiz_answers`;
    IF v_valid_count = 0 OR v_valid_count <> v_input_count THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'one or more Quiz answers are invalid or duplicated';
    END IF;

    INSERT INTO `quiz_results`
        (`user_id`, `topic_id`, `vocabulary_set_id`, `total_questions`, `correct_answers`, `started_at`, `finished_at`)
    VALUES
        (p_user_id, v_topic_id, v_set_id, v_valid_count, v_correct_count,
         DATE_SUB(NOW(), INTERVAL p_duration_seconds SECOND), NOW());
    SET v_quiz_result_id = LAST_INSERT_ID();

    INSERT INTO `quiz_answer_details`
        (`quiz_result_id`, `vocabulary_id`, `question_order`, `selected_answer`,
         `correct_answer`, `is_correct`, `response_time_ms`)
    SELECT v_quiz_result_id, `vocabulary_id`, `question_order`, `selected_answer`,
           `correct_answer`, `is_correct`, `response_time_ms`
      FROM `tmp_quiz_answers` ORDER BY `question_order`;

    IF p_mode = 'practice' THEN
        UPDATE `learning_attempts`
           SET `status` = 'completed', `completed_at` = NOW(), `updated_at` = NOW()
         WHERE `user_id` = p_user_id AND `activity_type` = 'quiz'
           AND `source_type` = p_source_type AND `source_id` <=> v_source_id_db
           AND `item_limit` = p_item_limit AND `status` = 'in_progress';
    END IF;

    COMMIT;
    DROP TEMPORARY TABLE `tmp_quiz_answers`;
    SELECT v_quiz_result_id AS `quiz_result_id`, v_correct_count AS `correct_count`,
           v_valid_count AS `total_questions`;
END$$

-- Single transaction boundary for resumable Flashcard/Quiz attempts.
CREATE PROCEDURE `sp_manage_learning_attempt`(
    IN p_user_id INT,
    IN p_action VARCHAR(10),
    IN p_activity_type VARCHAR(10),
    IN p_source_type VARCHAR(10),
    IN p_source_id INT,
    IN p_item_limit VARCHAR(10),
    IN p_state_json JSON
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_attempt_id INT DEFAULT NULL;
    DECLARE v_source_id_db INT DEFAULT NULL;
    DECLARE v_locked_user_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    IF p_action NOT IN ('load', 'save', 'complete', 'restart')
       OR p_activity_type NOT IN ('flashcard', 'quiz')
       OR p_source_type NOT IN ('topic', 'set', 'review')
       OR p_item_limit NOT IN ('5', '10', '20', 'all') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid learning attempt request';
    END IF;
    IF p_source_type <> 'review' AND (p_source_id IS NULL OR p_source_id <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source ID is required';
    END IF;
    IF p_action = 'save' AND p_state_json IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'state JSON is required';
    END IF;

    SET v_source_id_db = IF(p_source_type = 'review', NULL, p_source_id);
    --  Quản lý phiên học dở
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_user_id AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found';
    END IF;
    SELECT `userID` INTO v_locked_user_id FROM `Users` WHERE `userID` = p_user_id FOR UPDATE;
    IF p_source_type = 'topic' AND NOT EXISTS(SELECT 1 FROM `Topics` WHERE `topicID` = p_source_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic not found';
    END IF;
    IF p_source_type = 'set' AND NOT EXISTS(
        SELECT 1 FROM `vocabulary_sets` WHERE `id` = p_source_id AND `user_id` = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary set is not owned by user';
    END IF;

    SELECT MAX(`id`) INTO v_attempt_id
      FROM `learning_attempts`
     WHERE `user_id` = p_user_id AND `activity_type` = p_activity_type
       AND `source_type` = p_source_type AND `source_id` <=> v_source_id_db
       AND `item_limit` = p_item_limit AND `status` = 'in_progress';
    -- 

    IF p_action = 'save' THEN
        IF v_attempt_id IS NULL THEN
            INSERT INTO `learning_attempts`
                (`user_id`, `activity_type`, `source_type`, `source_id`, `item_limit`, `state_json`)
            VALUES (p_user_id, p_activity_type, p_source_type, v_source_id_db, p_item_limit, p_state_json);
            SET v_attempt_id = LAST_INSERT_ID();
        ELSE
            UPDATE `learning_attempts` SET `state_json` = p_state_json, `updated_at` = NOW()
             WHERE `id` = v_attempt_id AND `user_id` = p_user_id;
        END IF;
    ELSEIF p_action = 'complete' AND v_attempt_id IS NOT NULL THEN
        UPDATE `learning_attempts` SET `status` = 'completed', `completed_at` = NOW()
         WHERE `id` = v_attempt_id AND `user_id` = p_user_id;
    ELSEIF p_action = 'restart' AND v_attempt_id IS NOT NULL THEN
        UPDATE `learning_attempts` SET `status` = 'abandoned'
         WHERE `id` = v_attempt_id AND `user_id` = p_user_id;
    END IF;

    COMMIT;
    IF p_action = 'load' AND v_attempt_id IS NOT NULL THEN
        SELECT `id`, `state_json`, `started_at`, `updated_at`
          FROM `learning_attempts` WHERE `id` = v_attempt_id AND `user_id` = p_user_id;
    ELSE
        SELECT v_attempt_id AS `attempt_id`;
    END IF;
END$$

CREATE PROCEDURE `sp_update_user_profile`(
    IN p_user_id INT,
    IN p_full_name VARCHAR(100),
    IN p_email VARCHAR(50),
    IN p_avatar_url VARCHAR(250),
    IN p_date_of_birth DATE,
    IN p_target_level VARCHAR(50)
)
MODIFIES SQL DATA
BEGIN
    IF CHAR_LENGTH(TRIM(p_full_name)) < 2 OR LOCATE('@', p_email) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid profile data';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM `Users` WHERE `userID` = p_user_id AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found';
    END IF;

    IF EXISTS (SELECT 1 FROM `Users` WHERE `email` = LOWER(TRIM(p_email)) AND `userID` <> p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'email already exists';
    END IF;

    UPDATE `Users`
       SET `full_name` = TRIM(p_full_name),
           `email` = LOWER(TRIM(p_email)),
           `avatar_url` = COALESCE(p_avatar_url, `avatar_url`),
           `date_of_birth` = COALESCE(p_date_of_birth, `date_of_birth`),
           `target_level` = COALESCE(p_target_level, `target_level`)
     WHERE `userID` = p_user_id AND `status` = 'active';
END$$

CREATE PROCEDURE `sp_save_vocabulary_set`(
    IN p_user_id INT, IN p_set_id INT, IN p_name VARCHAR(100), IN p_description VARCHAR(255)
)
MODIFIES SQL DATA
BEGIN
    IF CHAR_LENGTH(TRIM(p_name)) = 0 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'set name is required'; END IF;
    IF EXISTS(SELECT 1 FROM `vocabulary_sets` WHERE `user_id` = p_user_id
              AND LOWER(`name`) = LOWER(TRIM(p_name)) AND `id` <> COALESCE(p_set_id, 0)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'set name already exists';
    END IF;
    IF p_set_id IS NULL OR p_set_id = 0 THEN
        INSERT INTO `vocabulary_sets` (`user_id`, `name`, `description`)
        VALUES (p_user_id, TRIM(p_name), NULLIF(TRIM(p_description), ''));
        SELECT LAST_INSERT_ID() AS `set_id`;
    ELSE
        UPDATE `vocabulary_sets` SET `name` = TRIM(p_name), `description` = NULLIF(TRIM(p_description), '')
        WHERE `id` = p_set_id AND `user_id` = p_user_id;
        IF ROW_COUNT() <> 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'owned set not found'; END IF;
        SELECT p_set_id AS `set_id`;
    END IF;
END$$

CREATE PROCEDURE `sp_delete_vocabulary_set`(IN p_user_id INT, IN p_set_id INT)
MODIFIES SQL DATA
BEGIN
    DELETE FROM `vocabulary_sets` WHERE `id` = p_set_id AND `user_id` = p_user_id;
    IF ROW_COUNT() <> 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'owned set not found'; END IF;
END$$

-- Insert/update a personal word and its set membership as one atomic unit.
CREATE PROCEDURE `sp_save_personal_vocabulary`(
    IN p_user_id INT, IN p_vocabulary_id INT, IN p_set_id INT,
    IN p_word VARCHAR(100), IN p_pronunciation VARCHAR(100),
    IN p_part_of_speech VARCHAR(30), IN p_meaning TEXT, IN p_example_sentence TEXT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_user_lock INT DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    IF CHAR_LENGTH(TRIM(p_word)) = 0 OR CHAR_LENGTH(TRIM(p_meaning)) = 0
       OR p_part_of_speech NOT IN ('noun','verb','adjective','adverb','pronoun','preposition','conjunction','phrase','other') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid personal vocabulary data';
    END IF; 
    -- Từ vựng cá nhân
    START TRANSACTION;
    SELECT `userID` INTO v_user_lock FROM `Users`
     WHERE `userID` = p_user_id AND `status` = 'active' FOR UPDATE;
    IF v_user_lock IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found'; END IF;
    IF NOT EXISTS (SELECT 1 FROM `vocabulary_sets` WHERE `id` = p_set_id AND `user_id` = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'owned set not found';
    END IF;
    IF EXISTS (SELECT 1 FROM `vocabulary` WHERE `created_by` = p_user_id
               AND LOWER(`word`) = LOWER(TRIM(p_word)) AND `id` <> COALESCE(p_vocabulary_id, 0)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'personal word already exists';
    END IF;
    IF p_vocabulary_id IS NULL OR p_vocabulary_id = 0 THEN
        INSERT INTO `vocabulary`
            (`topic_id`, `word`, `pronunciation`, `part_of_speech`, `meaning`, `example_sentence`, `created_by`)
        VALUES
            (NULL, TRIM(p_word), NULLIF(TRIM(p_pronunciation), ''), p_part_of_speech,
             TRIM(p_meaning), NULLIF(TRIM(p_example_sentence), ''), p_user_id);
        SET v_id = LAST_INSERT_ID();
        INSERT INTO `user_vocab_progress` (`user_id`, `vocabulary_id`, `status`, `next_review_date`)
        VALUES (p_user_id, v_id, 'new', CURRENT_DATE);
    -- 
    ELSE
        SELECT `id` INTO v_id FROM `vocabulary`
         WHERE `id` = p_vocabulary_id AND `created_by` = p_user_id FOR UPDATE;
        IF v_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'owned vocabulary not found'; END IF;
        UPDATE `vocabulary`
           SET `topic_id` = NULL, `word` = TRIM(p_word),
               `pronunciation` = NULLIF(TRIM(p_pronunciation), ''),
               `part_of_speech` = p_part_of_speech, `meaning` = TRIM(p_meaning),
               `example_sentence` = NULLIF(TRIM(p_example_sentence), '')
         WHERE `id` = v_id;
        DELETE vsi FROM `vocabulary_set_items` vsi
        JOIN `vocabulary_sets` vs ON vs.`id` = vsi.`vocabulary_set_id`
        WHERE vsi.`vocabulary_id` = v_id AND vs.`user_id` = p_user_id;
    END IF;
    INSERT INTO `vocabulary_set_items` (`vocabulary_set_id`, `vocabulary_id`)
    VALUES (p_set_id, v_id);
    COMMIT;
    SELECT v_id AS `vocabulary_id`;
END$$

CREATE PROCEDURE `sp_delete_personal_vocabularies`(IN p_user_id INT, IN p_ids JSON)
MODIFIES SQL DATA
BEGIN
    DECLARE v_deleted INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    IF p_ids IS NULL OR JSON_TYPE(p_ids) <> 'ARRAY' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary ids must be a JSON array';
    END IF;
    START TRANSACTION;
    DELETE v FROM `vocabulary` v
    JOIN JSON_TABLE(p_ids, '$[*]' COLUMNS (`id` INT PATH '$')) ids ON ids.`id` = v.`id`
    WHERE v.`created_by` = p_user_id;
    SET v_deleted = ROW_COUNT();
    COMMIT;
    SELECT v_deleted AS `deleted_count`;
END$$

CREATE PROCEDURE `sp_set_vocabulary_statuses`(
    IN p_user_id INT, IN p_ids JSON, IN p_status VARCHAR(20)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_updated INT DEFAULT 0;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    IF p_ids IS NULL OR JSON_TYPE(p_ids) <> 'ARRAY' OR p_status NOT IN ('learning', 'mastered') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid vocabulary status request';
    END IF;
    START TRANSACTION;
    SELECT COUNT(DISTINCT v.`id`) INTO v_updated
      FROM JSON_TABLE(p_ids, '$[*]' COLUMNS (`id` INT PATH '$')) ids
      JOIN `vocabulary` v ON v.`id` = ids.`id`;
    INSERT INTO `user_vocab_progress` (`user_id`, `vocabulary_id`, `status`, `next_review_date`)
    SELECT p_user_id, v.`id`, p_status,
           CASE WHEN p_status = 'mastered' THEN CURRENT_DATE + INTERVAL 30 DAY ELSE CURRENT_DATE END
      FROM JSON_TABLE(p_ids, '$[*]' COLUMNS (`id` INT PATH '$')) ids
      JOIN `vocabulary` v ON v.`id` = ids.`id`
    ON DUPLICATE KEY UPDATE
        `status` = VALUES(`status`), `next_review_date` = VALUES(`next_review_date`);
    COMMIT;
    SELECT v_updated AS `updated_count`;
END$$

-- Quản trị học liệu
CREATE PROCEDURE `sp_admin_save_vocabulary`(
    IN p_actor_id INT, IN p_vocabulary_id INT, IN p_topic_id INT,
    IN p_word VARCHAR(100), IN p_pronunciation VARCHAR(100),
    IN p_part_of_speech VARCHAR(30), IN p_meaning TEXT, IN p_example_sentence TEXT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_valid_topic INT DEFAULT NULL;
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_actor_id AND `role` = 'admin' AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    IF CHAR_LENGTH(TRIM(p_word)) = 0 OR CHAR_LENGTH(TRIM(p_meaning)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid vocabulary data';
    END IF;
    IF p_topic_id IS NOT NULL AND p_topic_id > 0 THEN
        IF NOT EXISTS(SELECT 1 FROM `Topics` WHERE `topicID` = p_topic_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic not found';
        END IF;
        SET v_valid_topic = p_topic_id;
    ELSE
        SET v_valid_topic = NULL;
    END IF;

    IF v_valid_topic IS NOT NULL AND EXISTS(
        SELECT 1 FROM `vocabulary` WHERE LOWER(`word`) = LOWER(TRIM(p_word))
        AND `topic_id` = v_valid_topic AND `id` <> COALESCE(p_vocabulary_id, 0)
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'word already exists in topic';
    END IF;

    IF p_vocabulary_id IS NULL OR p_vocabulary_id = 0 THEN
        INSERT INTO `vocabulary` (`topic_id`, `word`, `pronunciation`, `part_of_speech`, `meaning`, `example_sentence`, `created_by`)
        VALUES (v_valid_topic, TRIM(p_word), NULLIF(TRIM(p_pronunciation), ''), NULLIF(TRIM(p_part_of_speech), ''),
                TRIM(p_meaning), NULLIF(TRIM(p_example_sentence), ''), p_actor_id);
    --  
    ELSE
        IF NOT EXISTS(SELECT 1 FROM `vocabulary` WHERE `id` = p_vocabulary_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary not found';
        END IF;
        UPDATE `vocabulary`
           SET `topic_id` = IF(p_topic_id IS NOT NULL AND p_topic_id > 0, v_valid_topic, `topic_id`),
               `word` = TRIM(p_word),
               `pronunciation` = NULLIF(TRIM(p_pronunciation), ''),
               `part_of_speech` = NULLIF(TRIM(p_part_of_speech), ''),
               `meaning` = TRIM(p_meaning),
               `example_sentence` = NULLIF(TRIM(p_example_sentence), '')
         WHERE `id` = p_vocabulary_id;
    END IF;
END$$

CREATE PROCEDURE `sp_admin_delete_vocabulary`(IN p_actor_id INT, IN p_vocabulary_id INT)
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_actor_id AND `role` = 'admin' AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    DELETE FROM `vocabulary` WHERE `id` = p_vocabulary_id;
    IF ROW_COUNT() <> 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary not found'; END IF;
END$$

CREATE PROCEDURE `sp_admin_delete_vocabulary_set`(IN p_actor_id INT, IN p_set_id INT)
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_actor_id AND `role` = 'admin' AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    DELETE FROM `vocabulary_sets` WHERE `id` = p_set_id;
    IF ROW_COUNT() <> 1 THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary set not found'; END IF;
END$$

CREATE PROCEDURE `sp_admin_save_topic`(
    IN p_actor_id INT, IN p_topic_id INT, IN p_name VARCHAR(100), IN p_description TEXT
)
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_actor_id AND `role` = 'admin' AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    IF CHAR_LENGTH(TRIM(p_name)) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic name is required';
    END IF;
    IF EXISTS(SELECT 1 FROM `Topics` WHERE LOWER(`topicName`) = LOWER(TRIM(p_name)) AND `topicID` <> COALESCE(p_topic_id, 0)) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic name already exists';
    END IF;
    IF p_topic_id IS NULL OR p_topic_id = 0 THEN
        INSERT INTO `Topics` (`topicName`, `topicDescription`, `category`, `created_by`)
        VALUES (TRIM(p_name), NULLIF(TRIM(p_description), ''), 'common', p_actor_id);
    ELSE
        UPDATE `Topics` SET `topicName` = TRIM(p_name), `topicDescription` = NULLIF(TRIM(p_description), '')
        WHERE `topicID` = p_topic_id;
    END IF;
END$$

CREATE PROCEDURE `sp_admin_delete_topic`(IN p_actor_id INT, IN p_topic_id INT)
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_actor_id AND `role` = 'admin' AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    DELETE FROM `Topics` WHERE `topicID` = p_topic_id;
END$$

CREATE PROCEDURE `sp_save_system_setting`(IN p_actor_id INT, IN p_key VARCHAR(100), IN p_value TEXT)
MODIFIES SQL DATA
BEGIN
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_actor_id AND `role` = 'admin' AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    
    -- Lưu biến session để Trigger có thể đọc được ID của Admin đang thao tác
    SET @current_admin_id = p_actor_id;
    
    INSERT INTO `system_settings` (`setting_key`, `setting_value`) VALUES (p_key, p_value)
    ON DUPLICATE KEY UPDATE `setting_value` = VALUES(`setting_value`);
END$$

-- Helper chạy bên trong transaction của procedure gọi nó.
-- Khóa hai dòng Users theo userID tăng dần để tránh vòng chờ A->B, B->A.
-- Sau khi có khóa, đọc lại quyền hiện tại; không tin role lưu trong session PHP.
CREATE PROCEDURE sp_admin_lock_account_pair(IN p_actor_id INT, IN p_target_id INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_id INT DEFAULT NULL;
    DECLARE v_role VARCHAR(10) DEFAULT NULL;
    DECLARE v_status VARCHAR(10) DEFAULT NULL;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_id = NULL;
    IF p_actor_id IS NULL OR p_target_id IS NULL OR p_actor_id <= 0 OR p_target_id <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'account not found';
    END IF;
    SELECT userID INTO v_id FROM Users WHERE userID = LEAST(p_actor_id, p_target_id) FOR UPDATE;
    IF v_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'account not found'; END IF;
    SELECT userID INTO v_id FROM Users WHERE userID = GREATEST(p_actor_id, p_target_id) FOR UPDATE;
    IF v_id IS NULL THEN SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'account not found'; END IF;
    SELECT role, status INTO v_role, v_status FROM Users WHERE userID = p_actor_id FOR UPDATE;
    IF v_role IS NULL OR v_role <> 'admin' OR v_status IS NULL OR v_status <> 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    IF p_actor_id = p_target_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'self account change denied';
    END IF;
    -- Actor active/admin vẫn giữ khóa đến COMMIT và không được sửa chính mình.
    -- Vì vậy luôn còn ít nhất một admin active sau thay đổi, kể cả khi hai admin
    -- đồng thời yêu cầu hạ quyền/khóa nhau: người chạy sau phải kiểm tra lại quyền.
END$$

CREATE PROCEDURE sp_admin_create_account(
    IN p_actor_id INT, IN p_full_name VARCHAR(100), IN p_email VARCHAR(50),
    IN p_password_hash VARCHAR(300), IN p_role VARCHAR(10)
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_actor_role VARCHAR(10) DEFAULT NULL;
    DECLARE v_actor_status VARCHAR(10) DEFAULT NULL;
    DECLARE v_user_id INT;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_actor_role = NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    SELECT role, status INTO v_actor_role, v_actor_status FROM Users WHERE userID = p_actor_id FOR UPDATE;
    IF v_actor_role IS NULL OR v_actor_role <> 'admin' OR v_actor_status <> 'active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'admin required';
    END IF;
    IF p_full_name IS NULL OR CHAR_LENGTH(TRIM(p_full_name)) < 2
       OR p_email IS NULL OR CHAR_LENGTH(TRIM(p_email)) < 3 OR LOCATE('@', p_email) = 0
       OR p_password_hash IS NULL OR CHAR_LENGTH(p_password_hash) < 20
       OR p_role IS NULL OR p_role NOT IN ('user', 'admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid account data';
    END IF;
    -- UNIQUE(email) là lớp bảo vệ cuối cùng khi hai request cùng tạo một email.
    INSERT INTO Users(full_name, email, password_hash, role, status)
    VALUES(TRIM(p_full_name), LOWER(TRIM(p_email)), p_password_hash, p_role, 'active');
    SET v_user_id = LAST_INSERT_ID();
    COMMIT;
    SELECT v_user_id AS user_id;
END$$

CREATE PROCEDURE sp_admin_change_user_role(IN p_actor_id INT, IN p_user_id INT, IN p_role VARCHAR(10))
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_admin_lock_account_pair(p_actor_id, p_user_id);
    IF p_role IS NULL OR p_role NOT IN ('user', 'admin') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid role';
    END IF;
    UPDATE Users SET role = p_role WHERE userID = p_user_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_admin_change_user_status(IN p_actor_id INT, IN p_user_id INT, IN p_status VARCHAR(10))
MODIFIES SQL DATA
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_admin_lock_account_pair(p_actor_id, p_user_id);
    IF p_status IS NULL OR p_status NOT IN ('active', 'locked') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid status';
    END IF;
    UPDATE Users SET status = p_status WHERE userID = p_user_id;
    COMMIT;
END$$

CREATE PROCEDURE sp_admin_delete_account(IN p_actor_id INT, IN p_user_id INT)
MODIFIES SQL DATA
BEGIN
    DECLARE v_status VARCHAR(10);
    DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END;
    START TRANSACTION;
    CALL sp_admin_lock_account_pair(p_actor_id, p_user_id);
    SELECT status INTO v_status FROM Users WHERE userID = p_user_id FOR UPDATE;
    IF v_status <> 'locked' OR v_status IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'account must be locked';
    END IF;
    -- Không xóa tài khoản có lịch sử hoặc tài nguyên cá nhân để tránh CASCADE
    -- làm mất dữ liệu học/orphan từ cá nhân. Tài khoản này nên giữ trạng thái locked.
    IF EXISTS(SELECT 1 FROM learning_sessions WHERE user_id = p_user_id)
       OR EXISTS(SELECT 1 FROM quiz_results WHERE user_id = p_user_id)
       OR EXISTS(SELECT 1 FROM user_vocab_progress WHERE user_id = p_user_id)
       OR EXISTS(SELECT 1 FROM learning_attempts WHERE user_id = p_user_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'account has learning data';
    END IF;
    IF EXISTS(SELECT 1 FROM vocabulary_sets WHERE user_id = p_user_id)
       OR EXISTS(SELECT 1 FROM vocabulary WHERE created_by = p_user_id AND topic_id IS NULL) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'account has personal data';
    END IF;
    DELETE FROM Users WHERE userID = p_user_id;
    COMMIT;
END$$

-- PHP chỉ CALL để kiểm tra tính sẵn sàng, không truy vấn metadata trực tiếp.
CREATE PROCEDURE sp_admin_account_capabilities()
READS SQL DATA
BEGIN
    SELECT (COUNT(*) = 5) AS ready FROM information_schema.ROUTINES
    WHERE ROUTINE_SCHEMA = DATABASE() AND ROUTINE_TYPE = 'PROCEDURE'
      AND ROUTINE_NAME IN ('sp_admin_lock_account_pair', 'sp_admin_create_account',
        'sp_admin_change_user_role', 'sp_admin_change_user_status', 'sp_admin_delete_account');
END$$
DELIMITER ;

-- Recommended least-privilege pattern (replace app_user with the actual account):
-- REVOKE INSERT, UPDATE, DELETE ON `db_LexiLoop`.* FROM 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_user_progress` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_learning_sources` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_learning_items` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_learning_attempt_status` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_quiz_result_summary` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_quiz_incorrect_answers` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_personal_vocabulary` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_user_recent_activity` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_user_daily_unique_words` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_user_daily_learning_summary` TO 'app_user'@'%';
-- GRANT SELECT ON `db_LexiLoop`.`vw_system_recent_activity` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_save_flashcard_session` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_submit_quiz` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_manage_learning_attempt` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_auth_get_account_by_email` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_auth_get_active_admin_by_email` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_auth_get_account_by_id` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_auth_register_user` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_auth_update_account_settings` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_save_personal_vocabulary` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_delete_personal_vocabularies` TO 'app_user'@'%';
-- GRANT EXECUTE ON PROCEDURE `db_LexiLoop`.`sp_set_vocabulary_statuses` TO 'app_user'@'%';

-- ==============================================================================
-- KỊCH BẢN TẠO CÁC ĐỐI TƯỢNG CSDL CHO MODULE CÀI ĐẶT (ĐỒ ÁN MÔN HQTCSDL)
-- Chứa: Table, View, Trigger, Function
-- ==============================================================================

DELIMITER //
-- 3. TRIGGER: Tự động ghi log khi có thay đổi cấu hình (Audit Trail)
-- Trigger này thỏa mãn tiêu chí thiết kế an toàn CSDL của môn học
DROP TRIGGER IF EXISTS trg_audit_system_settings//
CREATE TRIGGER trg_audit_system_settings
AFTER UPDATE ON system_settings
FOR EACH ROW
BEGIN
    -- Chỉ ghi log nếu giá trị thực sự bị thay đổi
    IF OLD.setting_value != NEW.setting_value THEN
        INSERT INTO system_settings_logs (setting_key, old_value, new_value, changed_by, created_at)
        VALUES (
            NEW.setting_key,
            OLD.setting_value,
            NEW.setting_value,
            @current_admin_id, -- Biến session được thiết lập trong Procedure sp_save_system_setting
            NOW()
        );
    END IF;
END//

DELIMITER ;

DROP PROCEDURE IF EXISTS `sp_submit_quiz`;
DELIMITER $$
CREATE PROCEDURE `sp_submit_quiz`(
    IN p_user_id INT,
    IN p_source_type VARCHAR(10),
    IN p_source_id INT,
    IN p_mode VARCHAR(10),
    IN p_item_limit VARCHAR(10),
    IN p_answers_json JSON,
    IN p_duration_seconds INT
)
MODIFIES SQL DATA
BEGIN
    DECLARE v_input_count INT DEFAULT 0;
    DECLARE v_locked_user_id INT;
    DECLARE v_valid_count INT DEFAULT 0;
    DECLARE v_correct_count INT DEFAULT 0;
    DECLARE v_quiz_result_id INT;
    DECLARE v_topic_id INT DEFAULT NULL;
    DECLARE v_set_id INT DEFAULT NULL;
    DECLARE v_source_id_db INT DEFAULT NULL;

    -- SRS Variables
    DECLARE v_vocabulary_id INT;
    DECLARE v_is_correct BOOLEAN;
    DECLARE v_progress_id INT;
    DECLARE v_status VARCHAR(10);
    DECLARE v_interval INT;
    DECLARE v_quality INT;
    DECLARE v_base_ease FLOAT DEFAULT 2.5;
    DECLARE v_min_interval INT DEFAULT 1;
    DECLARE v_old_interval INT DEFAULT 0;
    DECLARE v_old_ease FLOAT DEFAULT 2.5;
    DECLARE v_old_repetitions INT DEFAULT 0;
    DECLARE v_repetitions INT DEFAULT 0;
    DECLARE v_new_ease FLOAT;
    DECLARE v_done BOOLEAN DEFAULT FALSE;

    DECLARE answer_cursor CURSOR FOR
        SELECT `vocabulary_id`, `is_correct` FROM `tmp_quiz_answers`;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        DROP TEMPORARY TABLE IF EXISTS `tmp_quiz_answers`;
        RESIGNAL;
    END;
    
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;

    IF p_source_type NOT IN ('topic', 'set', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid learning source';
    END IF;
    IF p_mode NOT IN ('practice', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid quiz mode';
    END IF;
    IF p_mode = 'review' AND p_source_type NOT IN ('topic', 'review') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid SRS review source';
    END IF;
    IF p_source_type <> 'review' AND (p_source_id IS NULL OR p_source_id <= 0) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'source ID is required';
    END IF;
    IF p_item_limit NOT IN ('5', '10', '20', 'all') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid item limit';
    END IF;
    IF p_answers_json IS NULL OR JSON_TYPE(p_answers_json) <> 'ARRAY' OR JSON_LENGTH(p_answers_json) = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'answers must be a non-empty JSON array';
    END IF;
    IF p_duration_seconds NOT BETWEEN 0 AND 86400 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'invalid duration';
    END IF;

    DROP TEMPORARY TABLE IF EXISTS `tmp_quiz_answers`;
    CREATE TEMPORARY TABLE `tmp_quiz_answers` (
        `question_order` INT NOT NULL,
        `vocabulary_id` INT NOT NULL,
        `selected_answer` TEXT NULL,
        `correct_answer` TEXT NOT NULL,
        `is_correct` BOOLEAN NOT NULL,
        `response_time_ms` INT NULL,
        PRIMARY KEY (`vocabulary_id`)
    ) ENGINE=InnoDB;

    -- TS Quiz
    START TRANSACTION;
    IF NOT EXISTS(SELECT 1 FROM `Users` WHERE `userID` = p_user_id AND `status` = 'active') THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'active user not found';
    END IF;
    SELECT `userID`, COALESCE(`srs_base_ease`, 2.5), COALESCE(`srs_min_interval`, 1) 
      INTO v_locked_user_id, v_base_ease, v_min_interval 
      FROM `Users` WHERE `userID` = p_user_id FOR UPDATE;
    -- 

    SET v_input_count = JSON_LENGTH(p_answers_json);
    IF p_source_type = 'topic' THEN
        IF NOT EXISTS(SELECT 1 FROM `Topics` WHERE `topicID` = p_source_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'topic not found';
        END IF;
        SET v_topic_id = p_source_id;
        SET v_source_id_db = p_source_id;
        IF p_mode = 'review' THEN
            INSERT INTO `tmp_quiz_answers`
            SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
                   v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
              FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
                  `question_order` FOR ORDINALITY,
                  `vocabulary_id` INT PATH '$.vocabularyId',
                  `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
                  `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
              )) j
              JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id` AND v.`topic_id` = p_source_id
              JOIN `user_vocab_progress` p
                ON p.`vocabulary_id` = v.`id` AND p.`user_id` = p_user_id
               AND p.`next_review_date` <= CURRENT_DATE;
        ELSE
            INSERT INTO `tmp_quiz_answers`
            SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
                   v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
              FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
                  `question_order` FOR ORDINALITY,
                  `vocabulary_id` INT PATH '$.vocabularyId',
                  `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
                  `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
              )) j
              JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id` AND v.`topic_id` = p_source_id;
        END IF;
    ELSEIF p_source_type = 'set' THEN
        IF NOT EXISTS(SELECT 1 FROM `vocabulary_sets` WHERE `id` = p_source_id AND `user_id` = p_user_id) THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'vocabulary set is not owned by user';
        END IF;
        SET v_set_id = p_source_id;
        SET v_source_id_db = p_source_id;
        INSERT INTO `tmp_quiz_answers`
        SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
               v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
          FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
              `question_order` FOR ORDINALITY,
              `vocabulary_id` INT PATH '$.vocabularyId',
              `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
              `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
          )) j
          JOIN `vocabulary_set_items` vsi
            ON vsi.`vocabulary_id` = j.`vocabulary_id` AND vsi.`vocabulary_set_id` = p_source_id
          JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id`;
    ELSE
        INSERT INTO `tmp_quiz_answers`
        SELECT j.`question_order`, j.`vocabulary_id`, NULLIF(TRIM(j.`selected_answer`), ''),
               v.`meaning`, COALESCE(LOWER(TRIM(j.`selected_answer`)) = LOWER(TRIM(v.`meaning`)), 0), j.`response_time_ms`
          FROM JSON_TABLE(p_answers_json, '$[*]' COLUMNS (
              `question_order` FOR ORDINALITY,
              `vocabulary_id` INT PATH '$.vocabularyId',
              `selected_answer` TEXT PATH '$.selectedAnswer' NULL ON EMPTY,
              `response_time_ms` INT PATH '$.responseTimeMs' NULL ON EMPTY
          )) j
          JOIN `user_vocab_progress` p
            ON p.`vocabulary_id` = j.`vocabulary_id` AND p.`user_id` = p_user_id
           AND (p.`next_review_date` <= CURRENT_DATE OR DATE(p.`last_reviewed_at`) = CURRENT_DATE)
          JOIN `vocabulary` v ON v.`id` = j.`vocabulary_id`;
    END IF;

    SELECT COUNT(*), COALESCE(SUM(`is_correct`), 0)
      INTO v_valid_count, v_correct_count FROM `tmp_quiz_answers`;
    IF v_valid_count = 0 OR v_valid_count <> v_input_count THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'one or more Quiz answers are invalid or duplicated';
    END IF;

    INSERT INTO `quiz_results`
        (`user_id`, `topic_id`, `vocabulary_set_id`, `total_questions`, `correct_answers`, `started_at`, `finished_at`)
    VALUES
        (p_user_id, v_topic_id, v_set_id, v_valid_count, v_correct_count,
         DATE_SUB(NOW(), INTERVAL p_duration_seconds SECOND), NOW());
    SET v_quiz_result_id = LAST_INSERT_ID();

    INSERT INTO `quiz_answer_details`
        (`quiz_result_id`, `vocabulary_id`, `question_order`, `selected_answer`,
         `correct_answer`, `is_correct`, `response_time_ms`)
    SELECT v_quiz_result_id, `vocabulary_id`, `question_order`, `selected_answer`,
           `correct_answer`, `is_correct`, `response_time_ms`
      FROM `tmp_quiz_answers` ORDER BY `question_order`;

    IF p_mode = 'practice' THEN
        UPDATE `learning_attempts`
           SET `status` = 'completed', `completed_at` = NOW(), `updated_at` = NOW()
         WHERE `user_id` = p_user_id AND `activity_type` = 'quiz'
           AND `source_type` = p_source_type AND `source_id` <=> v_source_id_db
           AND `item_limit` = p_item_limit AND `status` = 'in_progress';
    END IF;

    -- SRS Update Loop (SM-2 equivalent logic for Quiz)
    IF p_mode = 'review' THEN
        SET v_done = FALSE;
        OPEN answer_cursor;
        answer_loop: LOOP
        FETCH answer_cursor INTO v_vocabulary_id, v_is_correct;
        IF v_done THEN
            LEAVE answer_loop;
        END IF;

        -- Quiz vẫn được lưu kết quả, nhưng không thay đổi SRS lần thứ hai nếu
        -- từ này đã được Flashcard/Quiz ôn chính thức trong cùng ngày.
        IF EXISTS(
            SELECT 1 FROM `user_vocab_progress`
             WHERE `user_id` = p_user_id AND `vocabulary_id` = v_vocabulary_id
               AND DATE(`last_reviewed_at`) = CURRENT_DATE
        ) THEN
            ITERATE answer_loop;
        END IF;

        IF v_is_correct = 1 THEN
            SET v_quality = 4;
        ELSE
            SET v_quality = 1;
        END IF;

        SET v_progress_id = NULL;
        SELECT `id`, `interval_days`, `ease_factor`, `repetitions`
          INTO v_progress_id, v_old_interval, v_old_ease, v_old_repetitions
          FROM `user_vocab_progress`
         WHERE `user_id` = p_user_id AND `vocabulary_id` = v_vocabulary_id
         LIMIT 1;

        IF v_progress_id IS NULL THEN
            SET v_old_interval = 0;
            SET v_old_ease = v_base_ease;
            SET v_old_repetitions = 0;
        END IF;

        IF v_quality < 3 THEN
            SET v_repetitions = 0;
            SET v_interval = v_min_interval;
        ELSE
            SET v_repetitions = v_old_repetitions + 1;
            IF v_repetitions = 1 THEN
                SET v_interval = v_min_interval;
            ELSEIF v_repetitions = 2 THEN
                SET v_interval = 6;
            ELSE
                SET v_interval = ROUND(v_old_interval * v_old_ease);
            END IF;
        END IF;

        SET v_new_ease = v_old_ease + (0.1 - (5 - v_quality) * (0.08 + (5 - v_quality) * 0.02));
        IF v_new_ease < 1.3 THEN
            SET v_new_ease = 1.3;
        END IF;
        
        SET v_status = CASE
            WHEN v_quality < 3 THEN 'learning'
            WHEN v_repetitions >= 5 THEN 'mastered'
            ELSE 'learning'
        END;

        IF v_progress_id IS NULL THEN
            INSERT INTO `user_vocab_progress`
                (`user_id`, `vocabulary_id`, `status`, `interval_days`, `ease_factor`, `repetitions`, `next_review_date`, `last_reviewed_at`)
            VALUES
                (p_user_id, v_vocabulary_id, v_status, v_interval, v_new_ease, v_repetitions, DATE_ADD(CURRENT_DATE, INTERVAL v_interval DAY), NOW());
            SET v_progress_id = LAST_INSERT_ID();
        ELSE
            UPDATE `user_vocab_progress`
               SET `status` = v_status,
                   `interval_days` = v_interval,
                   `ease_factor` = v_new_ease,
                   `repetitions` = v_repetitions,
                   `next_review_date` = DATE_ADD(CURRENT_DATE, INTERVAL v_interval DAY),
                   `last_reviewed_at` = NOW(),
                   `last_quality_rating` = v_quality
             WHERE `id` = v_progress_id;
        END IF;

        INSERT INTO `review_logs`
            (`progress_id`, `review_date`, `quality_rating`, `response_time_ms`)
        VALUES
            (v_progress_id, CURRENT_DATE, v_quality, NULL);
            
        END LOOP;
        CLOSE answer_cursor;
    END IF;

    COMMIT;
    DROP TEMPORARY TABLE `tmp_quiz_answers`;
    SELECT v_quiz_result_id AS `quiz_result_id`, v_correct_count AS `correct_count`,
           v_valid_count AS `total_questions`;
END$$
DELIMITER ;

