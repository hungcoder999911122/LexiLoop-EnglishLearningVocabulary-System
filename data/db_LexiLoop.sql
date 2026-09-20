-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: db
-- Generation Time: Sep 09, 2026 at 04:36 PM
-- Server version: 8.0.46
-- PHP Version: 8.3.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `db_LexLoop  `
--
CREATE DATABASE IF NOT EXISTS `db_LexiLoop` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE `db_LexiLoop`;

-- --------------------------------------------------------

--
-- Table structure for table `favorites`
--

CREATE TABLE `favorites` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `vocabulary_id` int NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `favorites`
--

INSERT INTO `favorites` (`id`, `user_id`, `vocabulary_id`, `created_at`) VALUES
(1, 2, 1, '2026-08-28 16:40:44'),
(2, 2, 2, '2026-08-28 16:40:44');

-- --------------------------------------------------------

--
-- Table structure for table `learning_sessions`
--

CREATE TABLE `learning_sessions` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `topic_id` int DEFAULT NULL,
  `vocabulary_set_id` int DEFAULT NULL,
  `session_type` enum('new_learning','review') NOT NULL DEFAULT 'new_learning',
  `session_date` date NOT NULL,
  `words_studied` int DEFAULT '0',
  `duration_seconds` int DEFAULT '0',
  `streak_count` int DEFAULT '0',
  `started_at` datetime DEFAULT NULL,
  `finished_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `learning_sessions`
--

INSERT INTO `learning_sessions` (`id`, `user_id`, `topic_id`, `session_type`, `session_date`, `words_studied`, `duration_seconds`, `streak_count`, `started_at`, `finished_at`) VALUES
(1, 2, NULL, 'new_learning', '2026-08-28', 15, 900, 3, NULL, NULL);

-- --------------------------------------------------------

--
-- Table structure for table `learning_attempts`
--

CREATE TABLE `learning_attempts` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `activity_type` enum('flashcard','quiz') NOT NULL,
  `source_type` enum('topic','set','review') NOT NULL,
  `source_id` int DEFAULT NULL,
  `item_limit` varchar(10) NOT NULL DEFAULT '10',
  `state_json` json NOT NULL,
  `status` enum('in_progress','completed','abandoned') NOT NULL DEFAULT 'in_progress',
  `started_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `completed_at` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_attempt_resume` (`user_id`,`activity_type`,`source_type`,`source_id`,`status`,`updated_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int NOT NULL,
  `email` varchar(100) NOT NULL,
  `otp_code` varchar(6) NOT NULL,
  `expires_at` datetime NOT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `password_resets`
--

INSERT INTO `password_resets` (`id`, `email`, `otp_code`, `expires_at`, `created_at`) VALUES
(1, 'quan@gmail.com', '123456', '2026-08-28 16:55:44', '2026-08-28 16:40:44');

-- --------------------------------------------------------

--
-- Table structure for table `quiz_answer_details`
--

CREATE TABLE `quiz_answer_details` (
  `id` int NOT NULL,
  `quiz_result_id` int NOT NULL,
  `vocabulary_id` int NOT NULL,
  `question_order` int NOT NULL,
  `selected_answer` text,
  `correct_answer` text NOT NULL,
  `is_correct` tinyint(1) NOT NULL DEFAULT '0',
  `response_time_ms` int DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `quiz_results`
--

CREATE TABLE `quiz_results` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `topic_id` int DEFAULT NULL,
  `vocabulary_set_id` int DEFAULT NULL,
  `total_questions` int NOT NULL,
  `correct_answers` int NOT NULL,
  `score` float GENERATED ALWAYS AS (((`correct_answers` / `total_questions`) * 100)) STORED,
  `started_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `finished_at` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `quiz_results`
--

INSERT INTO `quiz_results` (`id`, `user_id`, `topic_id`, `total_questions`, `correct_answers`, `started_at`, `finished_at`) VALUES
(1, 2, 1, 10, 10, '2026-08-28 16:30:44', '2026-08-28 16:40:44');

-- --------------------------------------------------------

--
-- Table structure for table `review_logs`
--

CREATE TABLE `review_logs` (
  `id` int NOT NULL,
  `progress_id` int NOT NULL,
  `review_date` date NOT NULL,
  `quality_rating` tinyint NOT NULL,
  `response_time_ms` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `review_logs`
--

INSERT INTO `review_logs` (`id`, `progress_id`, `review_date`, `quality_rating`, `response_time_ms`) VALUES
(1, 1, '2026-08-23', 4, 2500),
(2, 1, '2026-08-28', 5, 1800),
(3, 2, '2026-08-28', 4, 3200);

-- --------------------------------------------------------

--
-- Table structure for table `system_settings`
--

CREATE TABLE `system_settings` (
  `setting_key` varchar(50) NOT NULL,
  `setting_value` text,
  `updated_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping default data for table `system_settings`
--
INSERT IGNORE INTO `system_settings` (`setting_key`, `setting_value`) VALUES 
('quiz_default_questions', '15'),
('daily_word_limit', '30'),
('spaced_repetition_intervals', '1,3,7,21');

-- --------------------------------------------------------

--
-- Table structure for table `system_settings_logs` (AUDIT LOG)
--

CREATE TABLE `system_settings_logs` (
  `log_id` int NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `setting_key` varchar(100) NOT NULL,
  `old_value` text,
  `new_value` text,
  `changed_by` int DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `Topics`
--

CREATE TABLE `Topics` (
  `topicID` int NOT NULL,
  `topicName` varchar(100) NOT NULL,
  `topicDescription` text,
  `category` varchar(20) NOT NULL DEFAULT 'common',
  `created_by` int DEFAULT NULL,
  `topicCreated_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `Topics`
--

INSERT INTO `Topics` (`topicID`, `topicName`, `topicDescription`, `category`, `created_by`, `topicCreated_at`) VALUES
(1, 'Animals', 'Từ vựng về các loài động vật', 'common', 1, '2026-08-28 16:40:44'),
(2, 'Technology', 'Từ vựng về công nghệ và kỹ thuật số', 'common', 1, '2026-08-28 16:40:44'),
(3, 'Food & Drink', 'Từ vựng về ẩm thực và đồ uống', 'common', 2, '2026-08-28 16:40:44'),
(4, 'Travel', 'Từ vựng liên quan đến du lịch và di chuyển', 'common', 2, '2026-08-28 16:40:44'),
(5, 'Business', 'Từ vựng trong môi trường kinh doanh', 'common', 1, '2026-08-28 16:40:44'),
(6, 'Health & Medical', 'Từ vựng về sức khỏe, y tế và chăm sóc cơ thể', 'common', 1, '2026-08-28 16:40:44'),
(7, 'Education', 'Từ vựng về giáo dục và học thuật', 'common', 1, '2026-08-28 16:40:44'),
(8, 'Environment', 'Từ vựng về môi trường và thiên nhiên', 'common', 2, '2026-08-28 16:40:44'),
(9, 'Entertainment', 'Từ vựng về giải trí, nghệ thuật và sở thích', 'common', 2, '2026-08-28 16:40:44'),
(10, 'Shopping', 'Từ vựng về mua sắm và giao dịch', 'common', 1, '2026-08-28 16:40:44'),
(11, 'Sports', 'Từ vựng về các thể loại thể thao và vận động', 'common', 1, '2026-08-28 16:40:44'),
(12, 'Music', 'Từ vựng về âm nhạc và dụng cụ âm nhạc', 'common', 1, '2026-08-28 16:40:44'),
(13, 'Weather', 'Từ vựng về thời tiết và khí hậu', 'common', 2, '2026-08-28 16:40:44'),
(14, 'Fashion', 'Từ vựng về thời trang và trang phục', 'common', 2, '2026-08-28 16:40:44'),
(15, 'Workplace', 'Từ vựng về văn phòng và công việc hàng ngày', 'common', 1, '2026-08-28 16:40:44'),
(16, 'Finance', 'Từ vựng về tài chính và ngân hàng', 'common', 1, '2026-08-28 16:40:44'),
(17, 'Transportation', 'Từ vựng về phương tiện giao thông', 'common', 1, '2026-08-28 16:40:44'),
(18, 'Science', 'Từ vựng về khoa học và nghiên cứu', 'common', 2, '2026-08-28 16:40:44'),
(19, 'Architecture', 'Từ vựng về kiến trúc và xây dựng', 'common', 2, '2026-08-28 16:40:44'),
(20, 'Emotions', 'Từ vựng mô tả cảm xúc và tâm lý', 'common', 1, '2026-08-28 16:40:44');

-- --------------------------------------------------------

--
-- Stand-in structure for view `tu_vung`
-- (See below for the actual view)
--
CREATE TABLE `tu_vung` (
`id` int
,`topic_id` int
,`word` varchar(100)
,`pronunciation` varchar(100)
,`part_of_speech` varchar(30)
,`meaning` text
,`example_sentence` text
,`created_by` int
,`created_at` datetime
,`audio_url` varchar(255)
);

-- --------------------------------------------------------

--
-- Table structure for table `Users`
--

CREATE TABLE `Users` (
  `userID` int NOT NULL,
  `email` varchar(50) NOT NULL,
  `password_hash` varchar(300) CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `full_name` varchar(100) DEFAULT NULL,
  `avatar_url` varchar(250) DEFAULT NULL,
  `role` enum('user','admin') DEFAULT 'user',
  `status` enum('active','locked') DEFAULT 'active',
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `update_at` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `daily_reminder_enabled` tinyint DEFAULT '1',
  `reminder_time` time DEFAULT '20:00:00',
  `daily_target_words` int DEFAULT '20',
  `date_of_birth` date DEFAULT '2002-05-15',
  `target_level` varchar(50) DEFAULT 'Trung cấp (B1)',
  `srs_base_ease` float DEFAULT '2.5',
  `srs_min_interval` int DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `Users`
--

INSERT INTO `Users` (`userID`, `email`, `password_hash`, `full_name`, `avatar_url`, `role`, `status`, `created_at`, `update_at`, `daily_reminder_enabled`, `reminder_time`, `daily_target_words`, `srs_base_ease`, `srs_min_interval`) VALUES
(1, 'admin@example.com', '$2y$10$SmbIcPwTzdkFP.Dx5H2tg.H6.6ouLNaAYrn2fyE7tdDiXeSBG95ge', 'Quản Trị Viên', NULL, 'admin', 'active', '2026-08-28 16:40:44', '2026-08-28 16:40:44', 1, '20:00:00', 20, 2.5, 1),
(2, 'quan@gmail.com', '$2y$12$Ej6xJqyHLOL79SXI8aRdvuLOS42nASiV6Yse5YmZsctsx.qF.KD/q', 'Lê Quân', NULL, 'user', 'active', '2026-08-28 16:40:44', '2026-08-28 16:40:44', 1, '21:00:00', 15, 2.5, 1),
(3, 'hungkill146@gmail.com', '$2y$10$Z2/VG5nprFQcK/p6Gdaj0eYcCOx/q48FpHzysLHp04mFLgsJntsyC', 'Nguyễn Tuấn Hùng', NULL, 'user', 'active', '2026-09-06 00:49:49', '2026-09-08 14:21:59', 1, '20:00:00', 20, 2.5, 1);
-- Tuấn Hùng: Tuanhung@123
-- Lê Quân: 12345678
-- admin: 123456
-- --------------------------------------------------------

--
-- Table structure for table `user_login_sessions`
--

CREATE TABLE `user_login_sessions` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `session_token` varchar(255) NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` varchar(255) DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `expires_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `user_vocab_progress`
--

CREATE TABLE `user_vocab_progress` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `vocabulary_id` int NOT NULL,
  `status` enum('new','learning','mastered') DEFAULT 'new',
  `ease_factor` float DEFAULT '2.5',
  `interval_days` int DEFAULT '0',
  `repetitions` int DEFAULT '0',
  `next_review_date` date DEFAULT NULL,
  `last_reviewed_at` datetime DEFAULT NULL,
  `last_quality_rating` tinyint DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `user_vocab_progress`
--

INSERT INTO `user_vocab_progress` (`id`, `user_id`, `vocabulary_id`, `status`, `ease_factor`, `interval_days`, `repetitions`, `next_review_date`, `last_reviewed_at`, `last_quality_rating`) VALUES
(1, 2, 1, 'mastered', 2.5, 21, 5, '2026-09-18', '2026-08-28 16:40:44', 5),
(2, 2, 2, 'learning', 2.4, 6, 2, '2026-09-03', '2026-08-28 16:40:44', 4);

-- --------------------------------------------------------

--
-- Table structure for table `vocabulary`
--

CREATE TABLE `vocabulary` (
  `id` int NOT NULL,
  `topic_id` int DEFAULT NULL,
  `word` varchar(100) NOT NULL,
  `pronunciation` varchar(100) DEFAULT NULL,
  `part_of_speech` varchar(30) DEFAULT NULL,
  `meaning` text NOT NULL,
  `example_sentence` text,
  `created_by` int DEFAULT NULL,
  `created_at` datetime DEFAULT CURRENT_TIMESTAMP,
  `audio_url` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `vocabulary`
--

INSERT INTO `vocabulary` (`id`, `topic_id`, `word`, `pronunciation`, `part_of_speech`, `meaning`, `example_sentence`, `created_by`, `created_at`, `audio_url`) VALUES
(1, 1, 'elephant', '/ˈɛlɪfənt/', 'noun', 'con voi', 'The elephant is the largest land animal.', 1, '2026-08-28 16:40:44', NULL),
(2, 2, 'algorithm', '/ˈælɡərɪðəm/', 'noun', 'thuật toán', 'The search algorithm finds results quickly.', 1, '2026-08-28 16:40:44', NULL),
(3, 3, 'cuisine', '/kwɪˈziːn/', 'noun', 'ẩm thực', 'Vietnamese cuisine is famous worldwide.', 2, '2026-08-28 16:40:44', NULL),
(4, 4, 'itinerary', '/aɪˈtɪnərəri/', 'noun', 'lịch trình', 'We planned our itinerary in advance.', 2, '2026-08-28 16:40:44', NULL),
(5, 5, 'revenue', '/ˈrɛvənjuː/', 'noun', 'doanh thu', 'Company revenue grew significantly this year.', 1, '2026-08-28 16:40:44', NULL),
(6, 6, 'symptom', '/ˈsɪmptəm/', 'noun', 'triệu chứng', 'Fever is a common symptom of flu.', 1, '2026-08-28 16:40:44', NULL),
(7, 7, 'curriculum', '/kəˈrɪkjələm/', 'noun', 'chương trình học', 'The school updated its computer science curriculum.', 1, '2026-08-28 16:40:44', NULL),
(8, 8, 'ecosystem', '/ˈiːkəʊsɪstəm/', 'noun', 'hệ sinh thái', 'Forests play a crucial role in maintaining the ecosystem.', 2, '2026-08-28 16:40:44', NULL),
(9, 9, 'exhibition', '/ˌɛksɪˈbɪʃn/', 'noun', 'cuộc triển lãm', 'They visited an modern art exhibition.', 2, '2026-08-28 16:40:44', NULL),
(10, 10, 'discount', '/ˈdɪskaʊnt/', 'noun', 'giảm giá', 'The store offers a 20% discount today.', 1, '2026-08-28 16:40:44', NULL),
(11, 11, 'tournament', '/ˈtʊənəmənt/', 'noun', 'giải đấu', 'He played well in the tennis tournament.', 1, '2026-08-28 16:40:44', NULL),
(12, 12, 'melody', '/ˈmɛlədi/', 'noun', 'giai điệu', 'That song has a catchy melody.', 1, '2026-08-28 16:40:44', NULL),
(13, 13, 'humidity', '/hjuːˈmɪdɪti/', 'noun', 'độ ẩm', 'The high humidity makes it feel warmer.', 2, '2026-08-28 16:40:44', NULL),
(14, 14, 'accessory', '/əkˈsɛsəri/', 'noun', 'phụ kiện', 'A leather belt is a good accessory.', 2, '2026-08-28 16:40:44', NULL),
(15, 15, 'colleague', '/ˈkɒliːɡ/', 'noun', 'đồng nghiệp', 'She works closely with her colleague.', 1, '2026-08-28 16:40:44', NULL),
(16, 16, 'investment', '/ɪnˈvɛstmənt/', 'noun', 'khoản đầu tư', 'Real estate is a long-term investment.', 1, '2026-08-28 16:40:44', NULL),
(17, 17, 'vehicle', '/ˈviːək(əl)/', 'noun', 'phương tiện', 'Electric vehicles are getting popular.', 1, '2026-08-28 16:40:44', NULL),
(18, 18, 'hypothesis', '/haɪˈpɒθɪsɪs/', 'noun', 'giả thuyết', 'The experiment proved the hypothesis right.', 2, '2026-08-28 16:40:44', NULL),
(19, 19, 'blueprint', '/ˈbluːprɪnt/', 'noun', 'bản thiết kế', 'The architect showed us the house blueprint.', 2, '2026-08-28 16:40:44', NULL),
(20, 20, 'empathy', '/ˈɛmpəθi/', 'noun', 'sự đồng cảm', 'Great leaders show empathy towards others.', 1, '2026-08-28 16:40:44', NULL),
(21, 1, 'lion', '/ˈlaɪən/', 'noun', 'sư tử', 'The lion is known as the king of the jungle.', 1, '2026-08-28 16:40:44', NULL),
(22, 1, 'tiger', '/ˈtaɪɡər/', 'noun', 'hổ', 'The tiger lives mainly in forests and grasslands.', 1, '2026-08-28 16:40:44', NULL),
(23, 1, 'giraffe', '/dʒəˈræf/', 'noun', 'hươu cao cổ', 'The giraffe has a very long neck.', 1, '2026-08-28 16:40:44', NULL),
(24, 1, 'monkey', '/ˈmʌŋki/', 'noun', 'khỉ', 'The monkey climbed the tree quickly.', 1, '2026-08-28 16:40:44', NULL),
(25, 1, 'dolphin', '/ˈdɒlfɪn/', 'noun', 'cá heo', 'The dolphin swam beside the boat.', 1, '2026-08-28 16:40:44', NULL),
(26, 1, 'rabbit', '/ˈræbɪt/', 'noun', 'con thỏ', 'The rabbit is eating a carrot.', 1, '2026-08-28 16:40:44', NULL),
(27, 1, 'eagle', '/ˈiːɡəl/', 'noun', 'đại bàng', 'The eagle flew high above the mountains.', 1, '2026-08-28 16:40:44', NULL),
(28, 1, 'whale', '/weɪl/', 'noun', 'cá voi', 'The whale is one of the largest animals in the ocean.', 1, '2026-08-28 16:40:44', NULL),
(29, 1, 'penguin', '/ˈpeŋɡwɪn/', 'noun', 'chim cánh cụt', 'The penguin cannot fly but it can swim very well.', 1, '2026-08-28 16:40:44', NULL),
(30, 2, 'software', '/ˈsɒftweər/', 'noun', 'phần mềm', 'The company develops software for small businesses.', 1, '2026-08-28 16:40:44', NULL),
(31, 2, 'hardware', '/ˈhɑːrdweər/', 'noun', 'phần cứng', 'The computer hardware needs to be upgraded.', 1, '2026-08-28 16:40:44', NULL),
(32, 2, 'database', '/ˈdeɪtəbeɪs/', 'noun', 'cơ sở dữ liệu', 'The application stores user information in a database.', 1, '2026-08-28 16:40:44', NULL),
(33, 2, 'network', '/ˈnetwɜːrk/', 'noun', 'mạng', 'The computers are connected to the same network.', 1, '2026-08-28 16:40:44', NULL),
(34, 2, 'browser', '/ˈbraʊzər/', 'noun', 'trình duyệt', 'You can open the website in any modern browser.', 1, '2026-08-28 16:40:44', NULL),
(35, 2, 'server', '/ˈsɜːrvər/', 'noun', 'máy chủ', 'The web server processes the request quickly.', 1, '2026-08-28 16:40:44', NULL),
(36, 2, 'encryption', '/ɪnˈkrɪpʃən/', 'noun', 'mã hóa', 'Encryption helps protect sensitive information.', 1, '2026-08-28 16:40:44', NULL),
(37, 2, 'interface', '/ˈɪntərfeɪs/', 'noun', 'giao diện', 'The application has a simple user interface.', 1, '2026-08-28 16:40:44', NULL),
(38, 2, 'device', '/dɪˈvaɪs/', 'noun', 'thiết bị', 'This device can connect to the internet.', 1, '2026-08-28 16:40:44', NULL),
(39, 3, 'ingredient', '/ɪnˈɡriːdiənt/', 'noun', 'nguyên liệu', 'Fresh ingredients make the dish taste better.', 2, '2026-08-28 16:40:44', NULL),
(40, 3, 'recipe', '/ˈresəpi/', 'noun', 'công thức nấu ăn', 'My mother gave me a recipe for vegetable soup.', 2, '2026-08-28 16:40:44', NULL),
(41, 3, 'flavor', '/ˈfleɪvər/', 'noun', 'hương vị', 'The sauce has a strong garlic flavor.', 2, '2026-08-28 16:40:44', NULL),
(42, 3, 'spicy', '/ˈspaɪsi/', 'adjective', 'cay', 'This soup is too spicy for me.', 2, '2026-08-28 16:40:44', NULL),
(43, 3, 'delicious', '/dɪˈlɪʃəs/', 'adjective', 'ngon', 'The food at this restaurant is delicious.', 2, '2026-08-28 16:40:44', NULL),
(44, 3, 'beverage', '/ˈbevərɪdʒ/', 'noun', 'đồ uống', 'The restaurant offers a wide range of beverages.', 2, '2026-08-28 16:40:44', NULL),
(45, 3, 'dessert', '/dɪˈzɜːrt/', 'noun', 'món tráng miệng', 'We ordered ice cream for dessert.', 2, '2026-08-28 16:40:44', NULL),
(46, 3, 'portion', '/ˈpɔːrʃən/', 'noun', 'khẩu phần', 'The restaurant serves large portions.', 2, '2026-08-28 16:40:44', NULL),
(47, 3, 'appetizer', '/ˈæpɪtaɪzər/', 'noun', 'món khai vị', 'We ordered an appetizer before the main course.', 2, '2026-08-28 16:40:44', NULL),
(48, 4, 'destination', '/ˌdestɪˈneɪʃən/', 'noun', 'điểm đến', 'Paris is a popular tourist destination.', 2, '2026-08-28 16:40:44', NULL),
(49, 4, 'journey', '/ˈdʒɜːrni/', 'noun', 'hành trình', 'The journey took more than five hours.', 2, '2026-08-28 16:40:44', NULL),
(50, 4, 'passport', '/ˈpɑːspɔːrt/', 'noun', 'hộ chiếu', 'Make sure you have your passport before leaving.', 2, '2026-08-28 16:40:44', NULL),
(51, 4, 'luggage', '/ˈlʌɡɪdʒ/', 'noun', 'hành lý', 'My luggage was too heavy to carry.', 2, '2026-08-28 16:40:44', NULL),
(52, 4, 'departure', '/dɪˈpɑːrtʃər/', 'noun', 'sự khởi hành', 'The departure time is six in the morning.', 2, '2026-08-28 16:40:44', NULL),
(53, 4, 'arrival', '/əˈraɪvəl/', 'noun', 'sự đến nơi', 'The train arrival time has changed.', 2, '2026-08-28 16:40:44', NULL),
(54, 4, 'accommodation', '/əˌkɒməˈdeɪʃən/', 'noun', 'chỗ ở', 'We booked our accommodation two months in advance.', 2, '2026-08-28 16:40:44', NULL),
(55, 4, 'tourist', '/ˈtʊərɪst/', 'noun', 'khách du lịch', 'The city attracts millions of tourists every year.', 2, '2026-08-28 16:40:44', NULL),
(56, 4, 'souvenir', '/ˌsuːvəˈnɪər/', 'noun', 'quà lưu niệm', 'She bought a souvenir for her family.', 2, '2026-08-28 16:40:44', NULL),
(57, 5, 'profit', '/ˈprɒfɪt/', 'noun', 'lợi nhuận', 'The company made a large profit this year.', 1, '2026-08-28 16:40:44', NULL),
(58, 5, 'customer', '/ˈkʌstəmər/', 'noun', 'khách hàng', 'The company always listens to its customers.', 1, '2026-08-28 16:40:44', NULL),
(59, 5, 'market', '/ˈmɑːrkɪt/', 'noun', 'thị trường', 'The company wants to enter the international market.', 1, '2026-08-28 16:40:44', NULL),
(60, 5, 'strategy', '/ˈstrætədʒi/', 'noun', 'chiến lược', 'The manager developed a new marketing strategy.', 1, '2026-08-28 16:40:44', NULL),
(61, 5, 'contract', '/ˈkɒntrækt/', 'noun', 'hợp đồng', 'They signed a contract with a new partner.', 1, '2026-08-28 16:40:44', NULL),
(62, 5, 'manager', '/ˈmænɪdʒər/', 'noun', 'quản lý', 'The manager organized a meeting for the team.', 1, '2026-08-28 16:40:44', NULL),
(63, 5, 'employee', '/ɪmˈplɔɪiː/', 'noun', 'nhân viên', 'Every employee must follow company policies.', 1, '2026-08-28 16:40:44', NULL),
(64, 5, 'meeting', '/ˈmiːtɪŋ/', 'noun', 'cuộc họp', 'The meeting starts at nine o’clock.', 1, '2026-08-28 16:40:44', NULL),
(65, 5, 'deadline', '/ˈdedlaɪn/', 'noun', 'hạn chót', 'We must finish the project before the deadline.', 1, '2026-08-28 16:40:44', NULL),
(66, 6, 'patient', '/ˈpeɪʃənt/', 'noun', 'bệnh nhân', 'The doctor examined the patient carefully.', 1, '2026-08-28 16:40:44', NULL),
(67, 6, 'treatment', '/ˈtriːtmənt/', 'noun', 'điều trị', 'The patient received treatment at the hospital.', 1, '2026-08-28 16:40:44', NULL),
(68, 6, 'medicine', '/ˈmedɪsɪn/', 'noun', 'thuốc', 'The doctor prescribed some medicine.', 1, '2026-08-28 16:40:44', NULL),
(69, 6, 'disease', '/dɪˈziːz/', 'noun', 'bệnh', 'Scientists are studying the disease.', 1, '2026-08-28 16:40:44', NULL),
(70, 6, 'hospital', '/ˈhɒspɪtəl/', 'noun', 'bệnh viện', 'The hospital is near the city center.', 1, '2026-08-28 16:40:44', NULL),
(71, 6, 'doctor', '/ˈdɒktər/', 'noun', 'bác sĩ', 'The doctor gave him some useful advice.', 1, '2026-08-28 16:40:44', NULL),
(72, 6, 'healthy', '/ˈhelθi/', 'adjective', 'khỏe mạnh', 'Regular exercise helps people stay healthy.', 1, '2026-08-28 16:40:44', NULL),
(73, 6, 'recovery', '/rɪˈkʌvəri/', 'noun', 'sự hồi phục', 'She made a quick recovery after the operation.', 1, '2026-08-28 16:40:44', NULL),
(74, 6, 'exercise', '/ˈeksərsaɪz/', 'noun', 'tập thể dục', 'Daily exercise is good for your health.', 1, '2026-08-28 16:40:44', NULL),
(75, 7, 'student', '/ˈstjuːdənt/', 'noun', 'học sinh, sinh viên', 'Every student has access to the online library.', 1, '2026-08-28 16:40:44', NULL),
(76, 7, 'teacher', '/ˈtiːtʃər/', 'noun', 'giáo viên', 'The teacher explained the lesson clearly.', 1, '2026-08-28 16:40:44', NULL),
(77, 7, 'assignment', '/əˈsaɪnmənt/', 'noun', 'bài tập', 'The students completed their assignment on time.', 1, '2026-08-28 16:40:44', NULL),
(78, 7, 'lecture', '/ˈlektʃər/', 'noun', 'bài giảng', 'The professor gave a lecture about modern science.', 1, '2026-08-28 16:40:44', NULL),
(79, 7, 'exam', '/ɪɡˈzæm/', 'noun', 'kỳ thi', 'The students are preparing for their final exam.', 1, '2026-08-28 16:40:44', NULL),
(80, 7, 'knowledge', '/ˈnɒlɪdʒ/', 'noun', 'kiến thức', 'Reading helps students gain knowledge.', 1, '2026-08-28 16:40:44', NULL),
(81, 7, 'academic', '/ˌækəˈdemɪk/', 'adjective', 'học thuật', 'She has a strong academic background.', 1, '2026-08-28 16:40:44', NULL),
(82, 7, 'scholarship', '/ˈskɒlərʃɪp/', 'noun', 'học bổng', 'He received a scholarship to study abroad.', 1, '2026-08-28 16:40:44', NULL),
(83, 7, 'research', '/rɪˈsɜːrtʃ/', 'noun', 'nghiên cứu', 'The students conducted research on climate change.', 1, '2026-08-28 16:40:44', NULL),
(84, 8, 'pollution', '/pəˈluːʃən/', 'noun', 'ô nhiễm', 'Air pollution is a serious problem in large cities.', 2, '2026-08-28 16:40:44', NULL),
(85, 8, 'climate', '/ˈklaɪmət/', 'noun', 'khí hậu', 'The climate is changing rapidly around the world.', 2, '2026-08-28 16:40:44', NULL),
(86, 8, 'forest', '/ˈfɒrɪst/', 'noun', 'rừng', 'Many animals live in the forest.', 2, '2026-08-28 16:40:44', NULL),
(87, 8, 'recycle', '/ˌriːˈsaɪkəl/', 'verb', 'tái chế', 'We should recycle plastic bottles whenever possible.', 2, '2026-08-28 16:40:44', NULL),
(88, 8, 'waste', '/weɪst/', 'noun', 'rác thải', 'The city is trying to reduce household waste.', 2, '2026-08-28 16:40:44', NULL),
(89, 8, 'natural', '/ˈnætʃərəl/', 'adjective', 'tự nhiên', 'The park protects many natural habitats.', 2, '2026-08-28 16:40:44', NULL),
(90, 8, 'conservation', '/ˌkɒnsərˈveɪʃən/', 'noun', 'bảo tồn', 'Wildlife conservation is important for future generations.', 2, '2026-08-28 16:40:44', NULL),
(91, 8, 'habitat', '/ˈhæbɪtæt/', 'noun', 'môi trường sống', 'The forest is an important habitat for many species.', 2, '2026-08-28 16:40:44', NULL),
(92, 8, 'sustainable', '/səˈsteɪnəbəl/', 'adjective', 'bền vững', 'We need more sustainable sources of energy.', 2, '2026-08-28 16:40:44', NULL),
(93, 9, 'movie', '/ˈmuːvi/', 'noun', 'bộ phim', 'We watched a movie at the cinema last night.', 2, '2026-08-28 16:40:44', NULL),
(94, 9, 'actor', '/ˈæktər/', 'noun', 'diễn viên nam', 'The actor played the main character.', 2, '2026-08-28 16:40:44', NULL),
(95, 9, 'artist', '/ˈɑːrtɪst/', 'noun', 'nghệ sĩ', 'The artist displayed her paintings at the gallery.', 2, '2026-08-28 16:40:44', NULL),
(96, 9, 'performance', '/pərˈfɔːrməns/', 'noun', 'màn trình diễn', 'The performance received a lot of applause.', 2, '2026-08-28 16:40:44', NULL),
(97, 9, 'concert', '/ˈkɒnsərt/', 'noun', 'buổi hòa nhạc', 'Thousands of people attended the concert.', 2, '2026-08-28 16:40:44', NULL),
(98, 9, 'audience', '/ˈɔːdiəns/', 'noun', 'khán giả', 'The audience enjoyed the show.', 2, '2026-08-28 16:40:44', NULL),
(99, 9, 'gallery', '/ˈɡæləri/', 'noun', 'phòng trưng bày', 'The gallery displays modern artwork.', 2, '2026-08-28 16:40:44', NULL),
(100, 9, 'festival', '/ˈfestɪvəl/', 'noun', 'lễ hội', 'The city holds a music festival every summer.', 2, '2026-08-28 16:40:44', NULL),
(101, 9, 'creative', '/kriˈeɪtɪv/', 'adjective', 'sáng tạo', 'She has a very creative approach to painting.', 2, '2026-08-28 16:40:44', NULL),
(102, 10, 'price', '/praɪs/', 'noun', 'giá', 'The price of this product is reasonable.', 1, '2026-08-28 16:40:44', NULL),
(103, 10, 'customer', '/ˈkʌstəmər/', 'noun', 'khách hàng', 'The customer asked for a different size.', 1, '2026-08-28 16:40:44', NULL),
(104, 10, 'purchase', '/ˈpɜːrtʃəs/', 'noun', 'việc mua hàng', 'The purchase was completed online.', 1, '2026-08-28 16:40:44', NULL),
(105, 10, 'receipt', '/rɪˈsiːt/', 'noun', 'hóa đơn', 'Please keep your receipt after the purchase.', 1, '2026-08-28 16:40:44', NULL),
(106, 10, 'brand', '/brænd/', 'noun', 'thương hiệu', 'This is a popular clothing brand.', 1, '2026-08-28 16:40:44', NULL),
(107, 10, 'product', '/ˈprɒdʌkt/', 'noun', 'sản phẩm', 'The company launched a new product.', 1, '2026-08-28 16:40:44', NULL),
(108, 10, 'sale', '/seɪl/', 'noun', 'đợt giảm giá', 'The store has a big sale this weekend.', 1, '2026-08-28 16:40:44', NULL),
(109, 10, 'refund', '/ˈriːfʌnd/', 'noun', 'khoản hoàn tiền', 'The customer requested a refund.', 1, '2026-08-28 16:40:44', NULL),
(110, 10, 'cashier', '/kæˈʃɪər/', 'noun', 'nhân viên thu ngân', 'The cashier gave me my receipt.', 1, '2026-08-28 16:40:44', NULL),
(111, 11, 'player', '/ˈpleɪər/', 'noun', 'vận động viên, người chơi', 'The player scored the winning goal.', 1, '2026-08-28 16:40:44', NULL),
(112, 11, 'team', '/tiːm/', 'noun', 'đội', 'Our team won the final match.', 1, '2026-08-28 16:40:44', NULL),
(113, 11, 'match', '/mætʃ/', 'noun', 'trận đấu', 'The football match starts at seven.', 1, '2026-08-28 16:40:44', NULL),
(114, 11, 'coach', '/koʊtʃ/', 'noun', 'huấn luyện viên', 'The coach gave the players useful advice.', 1, '2026-08-28 16:40:44', NULL),
(115, 11, 'competition', '/ˌkɒmpəˈtɪʃən/', 'noun', 'cuộc thi đấu', 'She won first place in the competition.', 1, '2026-08-28 16:40:44', NULL),
(116, 11, 'athlete', '/ˈæθliːt/', 'noun', 'vận động viên', 'The athlete trains every morning.', 1, '2026-08-28 16:40:44', NULL),
(117, 11, 'score', '/skɔːr/', 'noun', 'tỉ số', 'The final score was three to two.', 1, '2026-08-28 16:40:44', NULL),
(118, 11, 'victory', '/ˈvɪktəri/', 'noun', 'chiến thắng', 'The team celebrated its victory.', 1, '2026-08-28 16:40:44', NULL),
(119, 11, 'training', '/ˈtreɪnɪŋ/', 'noun', 'luyện tập', 'The players have training every afternoon.', 1, '2026-08-28 16:40:44', NULL),
(120, 12, 'rhythm', '/ˈrɪðəm/', 'noun', 'nhịp điệu', 'The song has a strong rhythm.', 1, '2026-08-28 16:40:44', NULL),
(121, 12, 'instrument', '/ˈɪnstrəmənt/', 'noun', 'nhạc cụ', 'She plays a musical instrument.', 1, '2026-08-28 16:40:44', NULL),
(122, 12, 'guitar', '/ɡɪˈtɑːr/', 'noun', 'đàn ghi-ta', 'He plays the guitar very well.', 1, '2026-08-28 16:40:44', NULL),
(123, 12, 'piano', '/piˈænoʊ/', 'noun', 'đàn piano', 'My sister is learning to play the piano.', 1, '2026-08-28 16:40:44', NULL),
(124, 12, 'singer', '/ˈsɪŋər/', 'noun', 'ca sĩ', 'The singer performed three songs.', 1, '2026-08-28 16:40:44', NULL),
(125, 12, 'lyrics', '/ˈlɪrɪks/', 'noun', 'lời bài hát', 'I like the lyrics of this song.', 1, '2026-08-28 16:40:44', NULL),
(126, 12, 'composer', '/kəmˈpoʊzər/', 'noun', 'nhà soạn nhạc', 'The composer created several famous pieces.', 1, '2026-08-28 16:40:44', NULL),
(127, 12, 'genre', '/ˈʒɒnrə/', 'noun', 'thể loại', 'Jazz is my favorite music genre.', 1, '2026-08-28 16:40:44', NULL),
(128, 12, 'instrumental', '/ˌɪnstrəˈmentəl/', 'adjective', 'thuộc về nhạc cụ', 'The album contains several instrumental tracks.', 1, '2026-08-28 16:40:44', NULL),
(129, 13, 'temperature', '/ˈtemprətʃər/', 'noun', 'nhiệt độ', 'The temperature reached thirty degrees today.', 2, '2026-08-28 16:40:44', NULL),
(130, 13, 'forecast', '/ˈfɔːrkæst/', 'noun', 'dự báo', 'The weather forecast says it will rain tomorrow.', 2, '2026-08-28 16:40:44', NULL),
(131, 13, 'rainfall', '/ˈreɪnfɔːl/', 'noun', 'lượng mưa', 'The region receives heavy rainfall during summer.', 2, '2026-08-28 16:40:44', NULL),
(132, 13, 'storm', '/stɔːrm/', 'noun', 'bão', 'The storm damaged several buildings.', 2, '2026-08-28 16:40:44', NULL),
(133, 13, 'thunder', '/ˈθʌndər/', 'noun', 'sấm', 'We heard loud thunder during the storm.', 2, '2026-08-28 16:40:44', NULL),
(134, 13, 'lightning', '/ˈlaɪtnɪŋ/', 'noun', 'tia chớp', 'The lightning lit up the sky.', 2, '2026-08-28 16:40:44', NULL),
(135, 13, 'sunny', '/ˈsʌni/', 'adjective', 'có nắng', 'It will be sunny this afternoon.', 2, '2026-08-28 16:40:44', NULL),
(136, 13, 'cloudy', '/ˈklaʊdi/', 'adjective', 'nhiều mây', 'The sky is cloudy today.', 2, '2026-08-28 16:40:44', NULL),
(137, 13, 'windy', '/ˈwɪndi/', 'adjective', 'nhiều gió', 'It is too windy to go sailing today.', 2, '2026-08-28 16:40:44', NULL),
(138, 14, 'clothing', '/ˈkloʊðɪŋ/', 'noun', 'quần áo', 'The store sells fashionable clothing.', 2, '2026-08-28 16:40:44', NULL),
(139, 14, 'outfit', '/ˈaʊtfɪt/', 'noun', 'bộ trang phục', 'She chose a simple outfit for the party.', 2, '2026-08-28 16:40:44', NULL),
(140, 14, 'fashionable', '/ˈfæʃənəbəl/', 'adjective', 'thời trang', 'These shoes are very fashionable this year.', 2, '2026-08-28 16:40:44', NULL),
(141, 14, 'designer', '/dɪˈzaɪnər/', 'noun', 'nhà thiết kế', 'The designer created a new collection.', 2, '2026-08-28 16:40:44', NULL),
(142, 14, 'fabric', '/ˈfæbrɪk/', 'noun', 'vải', 'This shirt is made from soft fabric.', 2, '2026-08-28 16:40:44', NULL),
(143, 14, 'sleeve', '/sliːv/', 'noun', 'tay áo', 'The shirt has long sleeves.', 2, '2026-08-28 16:40:44', NULL),
(144, 14, 'jacket', '/ˈdʒækɪt/', 'noun', 'áo khoác', 'He wore a black jacket to work.', 2, '2026-08-28 16:40:44', NULL),
(145, 14, 'pattern', '/ˈpætərn/', 'noun', 'hoa văn', 'The dress has a beautiful floral pattern.', 2, '2026-08-28 16:40:44', NULL),
(146, 14, 'trend', '/trend/', 'noun', 'xu hướng', 'This style is becoming a popular fashion trend.', 2, '2026-08-28 16:40:44', NULL),
(147, 15, 'office', '/ˈɒfɪs/', 'noun', 'văn phòng', 'Our office is located in the city center.', 1, '2026-08-28 16:40:44', NULL),
(148, 15, 'project', '/ˈprɒdʒekt/', 'noun', 'dự án', 'The team is working on an important project.', 1, '2026-08-28 16:40:44', NULL),
(149, 15, 'schedule', '/ˈskedʒuːl/', 'noun', 'lịch trình', 'I checked my schedule before the meeting.', 1, '2026-08-28 16:40:44', NULL),
(150, 15, 'manager', '/ˈmænɪdʒər/', 'noun', 'quản lý', 'The manager approved the new plan.', 1, '2026-08-28 16:40:44', NULL),
(151, 15, 'department', '/dɪˈpɑːrtmənt/', 'noun', 'phòng ban', 'She works in the marketing department.', 1, '2026-08-28 16:40:44', NULL),
(152, 15, 'employee', '/ɪmˈplɔɪiː/', 'noun', 'nhân viên', 'The company has more than one hundred employees.', 1, '2026-08-28 16:40:44', NULL),
(153, 15, 'task', '/tɑːsk/', 'noun', 'nhiệm vụ', 'I finished the task before lunch.', 1, '2026-08-28 16:40:44', NULL),
(154, 15, 'workload', '/ˈwɜːrkloʊd/', 'noun', 'khối lượng công việc', 'Her workload increased during the busy season.', 1, '2026-08-28 16:40:44', NULL),
(155, 15, 'presentation', '/ˌprezənˈteɪʃən/', 'noun', 'bài thuyết trình', 'He prepared a presentation for the meeting.', 1, '2026-08-28 16:40:44', NULL),
(156, 16, 'bank', '/bæŋk/', 'noun', 'ngân hàng', 'I opened a new account at the bank.', 1, '2026-08-28 16:40:44', NULL),
(157, 16, 'account', '/əˈkaʊnt/', 'noun', 'tài khoản', 'She transferred money to her bank account.', 1, '2026-08-28 16:40:44', NULL),
(158, 16, 'budget', '/ˈbʌdʒɪt/', 'noun', 'ngân sách', 'We need to create a budget for the project.', 1, '2026-08-28 16:40:44', NULL),
(159, 16, 'income', '/ˈɪnkʌm/', 'noun', 'thu nhập', 'His monthly income is enough to cover his expenses.', 1, '2026-08-28 16:40:44', NULL),
(160, 16, 'expense', '/ɪkˈspens/', 'noun', 'chi phí', 'Travel expenses were higher than expected.', 1, '2026-08-28 16:40:44', NULL),
(161, 16, 'loan', '/loʊn/', 'noun', 'khoản vay', 'The company applied for a business loan.', 1, '2026-08-28 16:40:44', NULL),
(162, 16, 'interest', '/ˈɪntrəst/', 'noun', 'lãi suất', 'The bank offers a low interest rate.', 1, '2026-08-28 16:40:44', NULL),
(163, 16, 'capital', '/ˈkæpɪtəl/', 'noun', 'vốn', 'The company needs more capital to expand.', 1, '2026-08-28 16:40:44', NULL),
(164, 16, 'financial', '/faɪˈnænʃəl/', 'adjective', 'thuộc về tài chính', 'The company is facing financial difficulties.', 1, '2026-08-28 16:40:44', NULL),
(165, 17, 'bus', '/bʌs/', 'noun', 'xe buýt', 'I take the bus to school every day.', 1, '2026-08-28 16:40:44', NULL),
(166, 17, 'train', '/treɪn/', 'noun', 'tàu hỏa', 'The train leaves at eight o’clock.', 1, '2026-08-28 16:40:44', NULL),
(167, 17, 'airport', '/ˈeərpɔːrt/', 'noun', 'sân bay', 'We arrived at the airport two hours early.', 1, '2026-08-28 16:40:44', NULL),
(168, 17, 'traffic', '/ˈtræfɪk/', 'noun', 'giao thông', 'There was heavy traffic this morning.', 1, '2026-08-28 16:40:44', NULL),
(169, 17, 'subway', '/ˈsʌbweɪ/', 'noun', 'tàu điện ngầm', 'The subway is the fastest way to travel across the city.', 1, '2026-08-28 16:40:44', NULL),
(170, 17, 'bicycle', '/ˈbaɪsɪkəl/', 'noun', 'xe đạp', 'He rides his bicycle to work.', 1, '2026-08-28 16:40:44', NULL),
(171, 17, 'passenger', '/ˈpæsɪndʒər/', 'noun', 'hành khách', 'All passengers must wear a seat belt.', 1, '2026-08-28 16:40:44', NULL),
(172, 17, 'route', '/ruːt/', 'noun', 'tuyến đường', 'This bus route passes through the city center.', 1, '2026-08-28 16:40:44', NULL),
(173, 17, 'station', '/ˈsteɪʃən/', 'noun', 'nhà ga', 'The train station is close to the hotel.', 1, '2026-08-28 16:40:44', NULL),
(174, 18, 'experiment', '/ɪkˈsperɪmənt/', 'noun', 'thí nghiệm', 'The students conducted a science experiment.', 2, '2026-08-28 16:40:44', NULL),
(175, 18, 'theory', '/ˈθɪəri/', 'noun', 'lý thuyết', 'The theory has been tested by many scientists.', 2, '2026-08-28 16:40:44', NULL),
(176, 18, 'laboratory', '/ləˈbɒrətɔːri/', 'noun', 'phòng thí nghiệm', 'The researchers work in a modern laboratory.', 2, '2026-08-28 16:40:44', NULL),
(177, 18, 'researcher', '/rɪˈsɜːrtʃər/', 'noun', 'nhà nghiên cứu', 'The researcher collected data from the experiment.', 2, '2026-08-28 16:40:44', NULL),
(178, 18, 'evidence', '/ˈevɪdəns/', 'noun', 'bằng chứng', 'The researchers found strong evidence to support the theory.', 2, '2026-08-28 16:40:44', NULL),
(179, 18, 'discovery', '/dɪˈskʌvəri/', 'noun', 'phát hiện', 'The discovery changed our understanding of the disease.', 2, '2026-08-28 16:40:44', NULL),
(180, 18, 'scientist', '/ˈsaɪəntɪst/', 'noun', 'nhà khoa học', 'The scientist published the results of the study.', 2, '2026-08-28 16:40:44', NULL),
(181, 18, 'analysis', '/əˈnæləsɪs/', 'noun', 'phân tích', 'The analysis of the data took several weeks.', 2, '2026-08-28 16:40:44', NULL),
(182, 18, 'observation', '/ˌɒbzərˈveɪʃən/', 'noun', 'sự quan sát', 'Careful observation is important during a scientific experiment.', 2, '2026-08-28 16:40:44', NULL),
(183, 19, 'building', '/ˈbɪldɪŋ/', 'noun', 'tòa nhà', 'The building was designed by a famous architect.', 2, '2026-08-28 16:40:44', NULL),
(184, 19, 'architect', '/ˈɑːrkɪtekt/', 'noun', 'kiến trúc sư', 'The architect designed a modern office building.', 2, '2026-08-28 16:40:44', NULL),
(185, 19, 'structure', '/ˈstrʌktʃər/', 'noun', 'cấu trúc, công trình', 'The structure can withstand strong winds.', 2, '2026-08-28 16:40:44', NULL),
(186, 19, 'design', '/dɪˈzaɪn/', 'noun', 'thiết kế', 'The building has a modern design.', 2, '2026-08-28 16:40:44', NULL),
(187, 19, 'construction', '/kənˈstrʌkʃən/', 'noun', 'xây dựng', 'Construction of the new bridge starts next month.', 2, '2026-08-28 16:40:44', NULL),
(188, 19, 'concrete', '/ˈkɒŋkriːt/', 'noun', 'bê tông', 'The walls are made of reinforced concrete.', 2, '2026-08-28 16:40:44', NULL),
(189, 19, 'foundation', '/faʊnˈdeɪʃən/', 'noun', 'nền móng', 'The workers are preparing the foundation of the building.', 2, '2026-08-28 16:40:44', NULL),
(190, 19, 'floor', '/flɔːr/', 'noun', 'tầng, sàn', 'The office is located on the fifth floor.', 2, '2026-08-28 16:40:44', NULL),
(191, 19, 'interior', '/ɪnˈtɪəriər/', 'noun', 'nội thất, bên trong', 'The interior of the house is bright and spacious.', 2, '2026-08-28 16:40:44', NULL),
(192, 20, 'happiness', '/ˈhæpinəs/', 'noun', 'hạnh phúc', 'Spending time with family brings her happiness.', 1, '2026-08-28 16:40:44', NULL),
(193, 20, 'sadness', '/ˈsædnəs/', 'noun', 'nỗi buồn', 'Music can sometimes express feelings of sadness.', 1, '2026-08-28 16:40:44', NULL),
(194, 20, 'anger', '/ˈæŋɡər/', 'noun', 'sự tức giận', 'He tried to control his anger.', 1, '2026-08-28 16:40:44', NULL),
(195, 20, 'fear', '/fɪər/', 'noun', 'nỗi sợ', 'She overcame her fear of public speaking.', 1, '2026-08-28 16:40:44', NULL),
(196, 20, 'excitement', '/ɪkˈsaɪtmənt/', 'noun', 'sự phấn khích', 'The children were full of excitement before the trip.', 1, '2026-08-28 16:40:44', NULL),
(197, 20, 'confidence', '/ˈkɒnfɪdəns/', 'noun', 'sự tự tin', 'Practice helped him build confidence.', 1, '2026-08-28 16:40:44', NULL),
(198, 20, 'surprise', '/sərˈpraɪz/', 'noun', 'sự ngạc nhiên', 'The birthday party was a complete surprise.', 1, '2026-08-28 16:40:44', NULL),
(199, 20, 'anxiety', '/æŋˈzaɪəti/', 'noun', 'sự lo lắng', 'Preparing well can reduce anxiety before an exam.', 1, '2026-08-28 16:40:44', NULL),
(200, 20, 'patience', '/ˈpeɪʃəns/', 'noun', 'sự kiên nhẫn', 'Learning a new language requires patience.', 1, '2026-08-28 16:40:44', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `vocabulary_images`
--

CREATE TABLE `vocabulary_images` (
  `id` int NOT NULL,
  `vocabulary_id` int NOT NULL,
  `image_url` varchar(255) NOT NULL,
  `uploaded_by` int DEFAULT NULL,
  `uploaded_at` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `vocabulary_images`
--

INSERT INTO `vocabulary_images` (`id`, `vocabulary_id`, `image_url`, `uploaded_by`, `uploaded_at`) VALUES
(1, 1, 'https://images.unsplash.com/photo-elephant.jpg', 1, '2026-08-28 16:40:44'),
(2, 2, 'https://images.unsplash.com/photo-algorithm.jpg', 1, '2026-08-28 16:40:44');

-- --------------------------------------------------------

--
-- Table structure for table `vocabulary_sets`
--

CREATE TABLE `vocabulary_sets` (
  `id` int NOT NULL,
  `user_id` int NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `vocabulary_set_items`
--

CREATE TABLE `vocabulary_set_items` (
  `id` int NOT NULL,
  `vocabulary_set_id` int NOT NULL,
  `vocabulary_id` int NOT NULL,
  `display_order` int NOT NULL DEFAULT '0',
  `added_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `favorites`
--
ALTER TABLE `favorites`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`vocabulary_id`),
  ADD KEY `vocabulary_id` (`vocabulary_id`);

--
-- Indexes for table `learning_sessions`
--
ALTER TABLE `learning_sessions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `idx_learning_sessions_user_date` (`user_id`,`session_date`),
  ADD KEY `idx_learning_sessions_topic` (`topic_id`),
  ADD KEY `idx_learning_sessions_set` (`vocabulary_set_id`);

--
-- Indexes for table `password_resets`
--
ALTER TABLE `password_resets`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `quiz_answer_details`
--
ALTER TABLE `quiz_answer_details`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_quiz_vocab` (`quiz_result_id`,`vocabulary_id`),
  ADD KEY `idx_quiz_result_id` (`quiz_result_id`),
  ADD KEY `idx_vocabulary_id` (`vocabulary_id`);

--
-- Indexes for table `quiz_results`
--
ALTER TABLE `quiz_results`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`),
  ADD KEY `topic_id` (`topic_id`),
  ADD KEY `idx_quiz_results_set` (`vocabulary_set_id`);

--
-- Indexes for table `review_logs`
--
ALTER TABLE `review_logs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `progress_id` (`progress_id`);

--
-- Indexes for table `system_settings`
--
ALTER TABLE `system_settings`
  ADD PRIMARY KEY (`setting_key`);

--
-- Indexes for table `Topics`
--
ALTER TABLE `Topics`
  ADD PRIMARY KEY (`topicID`),
  ADD KEY `users` (`created_by`);

--
-- Indexes for table `Users`
--
ALTER TABLE `Users`
  ADD PRIMARY KEY (`userID`),
  ADD UNIQUE KEY `email` (`email`);

--
-- Indexes for table `user_login_sessions`
--
ALTER TABLE `user_login_sessions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `session_token` (`session_token`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `user_vocab_progress`
--
ALTER TABLE `user_vocab_progress`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_id` (`user_id`,`vocabulary_id`),
  ADD KEY `vocabulary_id` (`vocabulary_id`);

--
-- Indexes for table `vocabulary`
--
ALTER TABLE `vocabulary`
  ADD PRIMARY KEY (`id`),
  ADD KEY `topic_id` (`topic_id`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `vocabulary_images`
--
ALTER TABLE `vocabulary_images`
  ADD PRIMARY KEY (`id`),
  ADD KEY `vocabulary_id` (`vocabulary_id`),
  ADD KEY `uploaded_by` (`uploaded_by`);

--
-- Indexes for table `vocabulary_sets`
--
ALTER TABLE `vocabulary_sets`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_vocabulary_sets_user_id` (`user_id`);

--
-- Indexes for table `vocabulary_set_items`
--
ALTER TABLE `vocabulary_set_items`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_set_vocabulary` (`vocabulary_set_id`,`vocabulary_id`),
  ADD KEY `idx_set_items_set_id` (`vocabulary_set_id`),
  ADD KEY `idx_set_items_vocabulary_id` (`vocabulary_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `favorites`
--
ALTER TABLE `favorites`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `learning_sessions`
--
ALTER TABLE `learning_sessions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `quiz_answer_details`
--
ALTER TABLE `quiz_answer_details`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `quiz_results`
--
ALTER TABLE `quiz_results`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `review_logs`
--
ALTER TABLE `review_logs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `Topics`
--
ALTER TABLE `Topics`
  MODIFY `topicID` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `Users`
--
ALTER TABLE `Users`
  MODIFY `userID` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `user_login_sessions`
--
ALTER TABLE `user_login_sessions`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `user_vocab_progress`
--
ALTER TABLE `user_vocab_progress`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `vocabulary`
--
ALTER TABLE `vocabulary`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=202;

--
-- AUTO_INCREMENT for table `vocabulary_images`
--
ALTER TABLE `vocabulary_images`
  MODIFY `id` int NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `vocabulary_sets`
--
ALTER TABLE `vocabulary_sets`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `vocabulary_set_items`
--
ALTER TABLE `vocabulary_set_items`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

-- --------------------------------------------------------

--
-- Structure for view `tu_vung`
--
DROP TABLE IF EXISTS `tu_vung`;

CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%` SQL SECURITY DEFINER VIEW `tu_vung`  AS SELECT `vocabulary`.`id` AS `id`, `vocabulary`.`topic_id` AS `topic_id`, `vocabulary`.`word` AS `word`, `vocabulary`.`pronunciation` AS `pronunciation`, `vocabulary`.`part_of_speech` AS `part_of_speech`, `vocabulary`.`meaning` AS `meaning`, `vocabulary`.`example_sentence` AS `example_sentence`, `vocabulary`.`created_by` AS `created_by`, `vocabulary`.`created_at` AS `created_at`, `vocabulary`.`audio_url` AS `audio_url` FROM `vocabulary` ;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `favorites`
--
ALTER TABLE `favorites`
  ADD CONSTRAINT `favorites_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE,
  ADD CONSTRAINT `favorites_ibfk_2` FOREIGN KEY (`vocabulary_id`) REFERENCES `vocabulary` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `learning_sessions`
--
ALTER TABLE `learning_sessions`
  ADD CONSTRAINT `fk_learning_sessions_topic` FOREIGN KEY (`topic_id`) REFERENCES `Topics` (`topicID`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_learning_sessions_set` FOREIGN KEY (`vocabulary_set_id`) REFERENCES `vocabulary_sets` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `learning_sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE;

--
-- Constraints for table `quiz_answer_details`
--
ALTER TABLE `quiz_answer_details`
  ADD CONSTRAINT `fk_quiz_answer_details_result` FOREIGN KEY (`quiz_result_id`) REFERENCES `quiz_results` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_quiz_answer_details_vocabulary` FOREIGN KEY (`vocabulary_id`) REFERENCES `vocabulary` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `quiz_results`
--
ALTER TABLE `quiz_results`
  ADD CONSTRAINT `quiz_results_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE,
  ADD CONSTRAINT `quiz_results_ibfk_2` FOREIGN KEY (`topic_id`) REFERENCES `Topics` (`topicID`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_quiz_results_set` FOREIGN KEY (`vocabulary_set_id`) REFERENCES `vocabulary_sets` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `review_logs`
--
ALTER TABLE `review_logs`
  ADD CONSTRAINT `review_logs_ibfk_1` FOREIGN KEY (`progress_id`) REFERENCES `user_vocab_progress` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `Topics`
--
ALTER TABLE `Topics`
  ADD CONSTRAINT `Topics_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `Users` (`userID`) ON DELETE SET NULL;

--
-- Constraints for table `user_login_sessions`
--
ALTER TABLE `user_login_sessions`
  ADD CONSTRAINT `user_login_sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE;

--
-- Constraints for table `user_vocab_progress`
--
ALTER TABLE `user_vocab_progress`
  ADD CONSTRAINT `user_vocab_progress_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE,
  ADD CONSTRAINT `user_vocab_progress_ibfk_2` FOREIGN KEY (`vocabulary_id`) REFERENCES `vocabulary` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `vocabulary`
--
ALTER TABLE `vocabulary`
  ADD CONSTRAINT `vocabulary_ibfk_1` FOREIGN KEY (`topic_id`) REFERENCES `Topics` (`topicID`) ON DELETE CASCADE,
  ADD CONSTRAINT `vocabulary_ibfk_2` FOREIGN KEY (`created_by`) REFERENCES `Users` (`userID`) ON DELETE SET NULL;

--
-- Constraints for table `vocabulary_images`
--
ALTER TABLE `vocabulary_images`
  ADD CONSTRAINT `vocabulary_images_ibfk_1` FOREIGN KEY (`vocabulary_id`) REFERENCES `vocabulary` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `vocabulary_images_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `Users` (`userID`) ON DELETE SET NULL;

--
-- Constraints for table `vocabulary_sets`
--
ALTER TABLE `vocabulary_sets`
  ADD CONSTRAINT `fk_vocabulary_sets_user` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE;

--
-- Constraints for table `vocabulary_set_items`
--
ALTER TABLE `vocabulary_set_items`
  ADD CONSTRAINT `fk_set_items_set` FOREIGN KEY (`vocabulary_set_id`) REFERENCES `vocabulary_sets` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_set_items_vocabulary` FOREIGN KEY (`vocabulary_id`) REFERENCES `vocabulary` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `learning_attempts`
--
ALTER TABLE `learning_attempts`
  ADD CONSTRAINT `fk_learning_attempts_user` FOREIGN KEY (`user_id`) REFERENCES `Users` (`userID`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
