<?php
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');

$user_id = (int) $_SESSION['user_id'];
if (empty($_SESSION['C_learning_csrf'])) {
    $_SESSION['C_learning_csrf'] = bin2hex(random_bytes(32));
}

$source = $_GET['source'] ?? 'topic';
$source = in_array($source, ['topic', 'set', 'review'], true) ? $source : 'topic';
$source_id = filter_var($_GET['source_id'] ?? $_GET['id'] ?? $_GET['topic_id'] ?? 0, FILTER_VALIDATE_INT) ?: 0;
$mode = $_GET['mode'] ?? 'practice';
$mode = in_array($mode, ['practice', 'review'], true) ? $mode : 'practice';
if ($source === 'review') {
    $mode = 'review';
}
$limit_option = (string) ($_GET['limit'] ?? '10');
if (!in_array($limit_option, ['5', '10', '20', 'all'], true)) {
    $limit_option = '10';
}
if ($source !== 'review' && $source_id <= 0) {
    header('Location: C_Gocrenluyen.php');
    exit;
}

// Mỗi lần mở Quiz có một token nộp bài riêng. Token giúp request gửi lại
// do mạng chậm không tạo thêm kết quả hoặc cộng lịch SRS lần thứ hai.
if (!isset($_SESSION['C_quiz_submissions']) || !is_array($_SESSION['C_quiz_submissions'])) {
    $_SESSION['C_quiz_submissions'] = [];
}
foreach ($_SESSION['C_quiz_submissions'] as $token => $submission) {
    if ((int) ($submission['createdAt'] ?? 0) < time() - 7200) {
        unset($_SESSION['C_quiz_submissions'][$token]);
    }
}
while (count($_SESSION['C_quiz_submissions']) >= 20) {
    array_shift($_SESSION['C_quiz_submissions']);
}
$quiz_submission_token = bin2hex(random_bytes(32));
$_SESSION['C_quiz_submissions'][$quiz_submission_token] = [
    'status' => 'pending',
    'createdAt' => time(),
    'source' => $source,
    'sourceId' => $source_id,
    'mode' => $mode,
];

$id_chu_de = $source === 'topic' ? $source_id : 0;
$ten_chu_de = $source === 'review' ? 'Từ vựng cần ôn tập' : 'Nguồn học';
$danh_sach_cau_hoi = [];

try {
    if ($source !== 'review') {
        $sourceSql = $source === 'set'
            ? 'SELECT source_name FROM vw_learning_sources WHERE source_type = ? AND source_id = ? AND owner_user_id = ? LIMIT 1'
            : 'SELECT source_name FROM vw_learning_sources WHERE source_type = ? AND source_id = ? LIMIT 1';
        $sourceRows = dbSelectView(
            $link,
            $sourceSql,
            $source === 'set' ? 'sii' : 'si',
            $source === 'set' ? [$source, $source_id, $user_id] : [$source, $source_id]
        );
        if (!$sourceRows) {
            header('Location: C_Gocrenluyen.php');
            exit;
        }
        $ten_chu_de = $sourceRows[0]['source_name'];
    }

    if ($source === 'topic') {
        if ($mode === 'review') {
            $topic_words = dbSelectView(
                $link,
                'SELECT i.vocabulary_id AS id, i.word, i.meaning 
                 FROM vw_learning_items i
                 JOIN vw_user_progress p ON i.vocabulary_id = p.vocabulary_id
                 WHERE i.source_type = ? AND i.source_id = ? AND p.user_id = ? AND p.next_review_date <= CURRENT_DATE',
                'sii',
                [$source, $source_id, $user_id]
            );
            $ten_chu_de = "Ôn tập: " . $ten_chu_de;
        } else {
            $topic_words = dbSelectView(
                $link,
                'SELECT vocabulary_id AS id, word, meaning FROM vw_learning_items WHERE source_type = ? AND source_id = ?',
                'si',
                [$source, $source_id]
            );
        }
    } elseif ($source === 'set') {
        $topic_words = dbSelectView(
            $link,
            'SELECT vocabulary_id AS id, word, meaning FROM vw_learning_items WHERE source_type = ? AND source_id = ? AND owner_user_id = ?',
            'sii',
            [$source, $source_id, $user_id]
        );
    } else {
        $topic_words = dbSelectView(
            $link,
            'SELECT vocabulary_id AS id, word, meaning FROM vw_learning_items WHERE source_type = ? AND owner_user_id = ?',
            'si',
            [$source, $user_id]
        );
    }
    shuffle($topic_words);
    if ($limit_option !== 'all') {
        $topic_words = array_slice($topic_words, 0, (int) $limit_option);
    }

    $poolRows = dbSelectView(
        $link,
        'SELECT DISTINCT meaning FROM vw_learning_items WHERE source_type = ? LIMIT 200',
        's',
        ['topic']
    );
    $distractor_pool = array_values(array_filter(array_map(
        static fn(array $row): string => trim((string) $row['meaning']),
        $poolRows
    )));
    $all_topic_meanings = array_column($topic_words, 'meaning');
    $prefixes = ['A. ', 'B. ', 'C. ', 'D. '];

    foreach ($topic_words as $item) {
        $correct_meaning = trim((string) $item['meaning']);
        $wrong_candidates = array_values(array_unique(array_filter(
            array_merge($all_topic_meanings, $distractor_pool),
            static fn($meaning): bool => trim((string) $meaning) !== $correct_meaning && trim((string) $meaning) !== ''
        )));
        shuffle($wrong_candidates);
        $wrong_answers = array_slice($wrong_candidates, 0, 3);
        foreach (['Không xác định', 'Phương án khác', 'Đáp án khác'] as $fallback) {
            if (count($wrong_answers) >= 3) break;
            if ($fallback !== $correct_meaning && !in_array($fallback, $wrong_answers, true)) {
                $wrong_answers[] = $fallback;
            }
        }

        $options = array_merge([$correct_meaning], $wrong_answers);
        shuffle($options);
        $correct_index = array_search($correct_meaning, $options, true);
        $final_options = [];
        foreach ($options as $index => $option) {
            $final_options[] = $prefixes[$index] . $option;
        }
        $danh_sach_cau_hoi[] = [
            'id' => (int) $item['id'],
            'tu_vung' => ucfirst((string) $item['word']),
            'dap_an' => $final_options,
            'dap_an_dung' => (int) $correct_index,
        ];
    }
} catch (Throwable $error) {
    error_log('Lỗi tạo Quiz: ' . $error->getMessage());
}
?>

<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Quiz: <?php echo htmlspecialchars($ten_chu_de); ?> - LexiLoop</title>
    <link rel="stylesheet" href="../../CSS/Style.css">
    <link rel="stylesheet" href="../../CSS/C_Quiz.css">
    <script src="../../JS/theme.js"></script>
</head>
<body class="C_Quiz_body">

    <!-- Header -->
    <header class="C_Quiz_header">
        <h1 class="C_Quiz_logo">Quiz: <?php echo htmlspecialchars($ten_chu_de); ?></h1>
        <div class="C_Quiz_headerActions">
            <span class="C_Quiz_progressText" id="C_Quiz_progressText">Câu 1/<?php echo count($danh_sach_cau_hoi); ?></span>
            <button type="button" class="C_Quiz_exitButton" id="C_Quiz_btnThoat">Thoát</button>
        </div>
    </header>

    <!-- Thanh tiến độ Quiz -->
    <div class="C_Quiz_progressBarWrapper">
        <div class="C_Quiz_progressBar">
            <div class="C_Quiz_progressFill" id="C_Quiz_progressFill" style="width: 0%;"></div>
        </div>
    </div>

    <!-- Nội dung chính câu hỏi -->
    <main class="C_Quiz_main">
        
        <!-- Đồng hồ đếm ngược -->
        <div class="C_Quiz_timerWrapper">
            <div class="C_Quiz_timerCircle" id="C_Quiz_timerCircle">15s</div>
        </div>

        <!-- Từ vựng câu hỏi -->
        <div class="C_Quiz_questionSection">
            <p class="C_Quiz_instruction">Chọn nghĩa đúng của từ:</p>
            <h2 class="C_Quiz_questionWord" id="C_Quiz_questionWord">Airport</h2>
        </div>

        <!-- Lưới 4 đáp án -->
        <div class="C_Quiz_optionsGrid" id="C_Quiz_optionsGrid">
            <button type="button" class="C_Quiz_optionBtn" data-index="0">A. Sân bay</button>
            <button type="button" class="C_Quiz_optionBtn" data-index="1">B. Bến xe</button>
            <button type="button" class="C_Quiz_optionBtn" data-index="2">C. Nhà ga</button>
            <button type="button" class="C_Quiz_optionBtn" data-index="3">D. Bến tàu</button>
        </div>

        <!-- Các nút điều hướng -->
        <div class="C_Quiz_navButtons">
            <button type="button" id="C_Quiz_btnCauTruoc" class="C_Quiz_btnNav C_Quiz_btnWhite">
                &larr; Câu trước
            </button>
            <button type="button" id="C_Quiz_btnCauTiep" class="C_Quiz_btnNav C_Quiz_btnGray">
                Câu tiếp &rarr;
            </button>
        </div>

        <!-- Danh sách bóng câu hỏi -->
        <footer class="C_Quiz_questionListSection">
            <p class="C_Quiz_listLabel">Danh sách câu hỏi</p>
            <div class="C_Quiz_bubblesRow" id="C_Quiz_bubblesRow"> </div>
        </footer>

    </main>

    <script>
        const quizQuestions = <?php echo json_encode($danh_sach_cau_hoi, JSON_UNESCAPED_UNICODE); ?>;
        const quizSessionConfig = <?= json_encode([
                                        'csrf' => $_SESSION['C_learning_csrf'],
                                        'source' => $source,
                                        'sourceId' => $source_id,
                                        'mode' => $mode,
                                        'submissionToken' => $quiz_submission_token,
                                        'limit' => $limit_option
                                    ], JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP) ?>;
    </script>
    <script src="../../JS/C_Quiz.js"></script>
</body>
</html>
