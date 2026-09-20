<?php
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');

$user_id = (int) $_SESSION['user_id'];
if (empty($_SESSION['C_learning_csrf'])) {
    $_SESSION['C_learning_csrf'] = bin2hex(random_bytes(32));
}

if (!isset($_SESSION['C_flashcard_submissions']) || !is_array($_SESSION['C_flashcard_submissions'])) {
    $_SESSION['C_flashcard_submissions'] = [];
}
foreach ($_SESSION['C_flashcard_submissions'] as $token => $submission) {
    if ((int) ($submission['createdAt'] ?? 0) < time() - 7200) {
        unset($_SESSION['C_flashcard_submissions'][$token]);
    }
}
while (count($_SESSION['C_flashcard_submissions']) >= 20) {
    array_shift($_SESSION['C_flashcard_submissions']);
}

$source = $_GET['source'] ?? 'topic';
$mode = $_GET['mode'] ?? '';
if ($mode === 'review') {
    $source = 'review';
}
$source = in_array($source, ['topic', 'set', 'review'], true) ? $source : 'topic';
$source_id = filter_var($_GET['source_id'] ?? $_GET['id'] ?? $_GET['topic_id'] ?? 0, FILTER_VALIDATE_INT) ?: 0;
$limit_option = (string) ($_GET['limit'] ?? '10');
if (!in_array($limit_option, ['5', '10', '20', 'all'], true)) {
    $limit_option = '10';
}
if ($source !== 'review' && $source_id <= 0) {
    header('Location: C_Gocrenluyen.php');
    exit;
}

$mode = $source === 'review' ? 'review' : '';
$flashcard_submission_token = bin2hex(random_bytes(32));
$_SESSION['C_flashcard_submissions'][$flashcard_submission_token] = [
    'status' => 'pending',
    'source' => $source,
    'sourceId' => $source_id,
    'createdAt' => time(),
];
$id_chu_de = $source === 'topic' ? $source_id : 0;
$ten_chu_de = $source === 'review' ? 'Từ vựng cần ôn tập' : 'Nguồn học';
$danh_sach_tu = [];

try {
    if ($source !== 'review') {
        $sourceSql = $source === 'set'
            ? 'SELECT source_name FROM vw_learning_sources WHERE source_type = ? AND source_id = ? AND owner_user_id = ? LIMIT 1'
            : 'SELECT source_name FROM vw_learning_sources WHERE source_type = ? AND source_id = ? LIMIT 1';
        $sourceTypes = $source === 'set' ? 'sii' : 'si';
        $sourceParams = $source === 'set'
            ? [$source, $source_id, $user_id]
            : [$source, $source_id];
        $sourceRows = dbSelectView($link, $sourceSql, $sourceTypes, $sourceParams);
        if (!$sourceRows) {
            header('Location: C_Gocrenluyen.php');
            exit;
        }
        $ten_chu_de = $sourceRows[0]['source_name'];
    }

    if ($source === 'topic') {
        $itemRows = dbSelectView(
            $link,
            'SELECT * FROM vw_learning_items WHERE source_type = ? AND source_id = ? ORDER BY display_order, vocabulary_id',
            'si',
            [$source, $source_id]
        );
        $progressRows = dbSelectView(
            $link,
            'SELECT vocabulary_id, next_review_date FROM vw_user_progress WHERE user_id = ? AND topic_id = ?',
            'ii',
            [$user_id, $source_id]
        );
        $reviewDates = [];
        foreach ($progressRows as $progress) {
            $reviewDates[(int) $progress['vocabulary_id']] = $progress['next_review_date'];
        }
        foreach ($itemRows as &$itemRow) {
            $itemRow['next_review_date'] = $reviewDates[(int) $itemRow['vocabulary_id']] ?? null;
        }
        unset($itemRow);
    } elseif ($source === 'set') {
        $itemRows = dbSelectView(
            $link,
            'SELECT * FROM vw_learning_items WHERE source_type = ? AND source_id = ? AND owner_user_id = ? ORDER BY display_order, vocabulary_id',
            'sii',
            [$source, $source_id, $user_id]
        );
    } else {
        $itemRows = dbSelectView(
            $link,
            'SELECT * FROM vw_learning_items WHERE source_type = ? AND owner_user_id = ? ORDER BY next_review_date, vocabulary_id',
            'si',
            [$source, $user_id]
        );
    }

    $today = date('Y-m-d');
    foreach ($itemRows as $row) {
        $danh_sach_tu[] = [
            'id' => (int) $row['vocabulary_id'],
            'tu_vung' => $row['word'],
            'nghia' => $row['meaning'],
            'phien_am' => $row['pronunciation'] ?? '',
            'loai_tu' => $row['part_of_speech'] ?? '',
            'vi_du' => $row['example_sentence'] ?? '',
            'audio_url' => $row['audio_url'] ?? '',
            'is_review' => $source === 'review'
                || (!empty($row['next_review_date']) && $row['next_review_date'] <= $today),
        ];
    }
} catch (Throwable $error) {
    error_log('Lỗi Flashcard: ' . $error->getMessage());
}

if ($limit_option !== 'all') {
    $danh_sach_tu = array_slice($danh_sach_tu, 0, (int) $limit_option);
}
?>

<!DOCTYPE html>
<html lang="vi">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Học FlashCard - LexiLoop</title>
    <link rel="stylesheet" href="../../CSS/Style.css">
    <link rel="stylesheet" href="../../CSS/C_HocFlashcard.css">

    <link rel="stylesheet" href="../../CSS/responsive.css">
    <script src="../../JS/theme.js"></script>
</head>

<body class="C_HocFlashcard_body">

    <!-- Header -->
    <header class="C_HocFlashcard_header">

        <h1 class="C_HocFlashcard_logo">
            <?php echo $mode === 'review'
                ? 'Ôn tập Flashcard'
                : 'Học từ mới: ' . htmlspecialchars($ten_chu_de); ?>
        </h1>

        <div class="C_HocFlashcard_headerActions">
            <span class="C_HocFlashcard_progressText" id="C_HocFlashcard_progressText">Thẻ 1/5</span>
            <button type="button" class="C_HocFlashcard_exitButton" id="C_HocFlashcard_btnThoatHeader" title="Thoát phiên học">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <line x1="18" y1="6" x2="6" y2="18"></line>
                    <line x1="6" y1="6" x2="18" y2="18"></line>
                </svg>
                <span>Thoát</span>
            </button>
        </div>
    </header>

    <!-- Thanh tiến độ học -->
    <div class="C_HocFlashcard_progressBarWrapper">
        <div class="C_HocFlashcard_progressBar">
            <div class="C_HocFlashcard_progressFill" id="C_HocFlashcard_progressFill"></div>
        </div>
    </div>

    <!-- Khu vực thẻ học và điều hướng -->
    <main class="C_HocFlashcard_main">
        <div class="C_HocFlashcard_cardArea">
            <!-- Nút từ trước -->
            <button type="button" id="C_HocFlashcard_btnPrev" class="C_HocFlashcard_navBtn" title="Thẻ trước">&larr;</button>

            <!-- Hộp thẻ Flashcard -->
            <div class="C_HocFlashcard_cardBox" id="C_HocFlashcard_cardBox">
                <div class="C_HocFlashcard_cardInner" id="C_HocFlashcard_cardInner">
                    <!-- MẶT TRƯỚC (Từ tiếng Anh) -->
                    <div class="C_HocFlashcard_cardFront">
                        <!-- Badge R (Ôn tập - Review) -->
                        <div class="C_HocFlashcard_badgeR" id="C_HocFlashcard_badgeR" title="Thẻ cần ôn tập">R</div>
                        <h2 class="C_HocFlashcard_word" id="C_HocFlashcard_wordFront">Software</h2>
                        
                        <div class="C_HocFlashcard_pronunciationArea" id="C_HocFlashcard_pronunciationAreaFront">
                            <p class="C_HocFlashcard_pronunciation" id="C_HocFlashcard_pronunciationFront">/.../</p>
                            <button type="button" class="C_HocFlashcard_audioButton" id="C_HocFlashcard_audioButtonFront" hidden>🔊 Nghe phát âm</button>
                        </div>
                        <p class="C_HocFlashcard_hint" id="C_HocFlashcard_hintFront">Nhấn để xem nghĩa</p>
                    </div>

                    <!-- MẶT SAU (Nghĩa tiếng Việt, ví dụ) -->
                    <div class="C_HocFlashcard_cardBack">
                        <div class="C_HocFlashcard_badgeR" id="C_HocFlashcard_badgeRBack" title="Thẻ cần ôn tập" hidden>R</div>
                        <h2 class="C_HocFlashcard_word" id="C_HocFlashcard_wordBack">Phần mềm</h2>
                        
                        <div class="C_HocFlashcard_pronunciationArea" id="C_HocFlashcard_pronunciationAreaBack">
                            <p class="C_HocFlashcard_pronunciation" id="C_HocFlashcard_pronunciationBack" hidden>/.../</p>
                            <button type="button" class="C_HocFlashcard_audioButton" id="C_HocFlashcard_audioButtonBack" hidden>🔊 Nghe phát âm</button>
                        </div>

                        <p class="C_HocFlashcard_partOfSpeech" id="C_HocFlashcard_partOfSpeech" hidden></p>
                        <p class="C_HocFlashcard_example" id="C_HocFlashcard_example" hidden></p>

                        <p class="C_HocFlashcard_hint" id="C_HocFlashcard_hintBack">Nhấn để xem lại từ tiếng Anh</p>
                    </div>
                </div>

                <audio id="C_HocFlashcard_audioPlayer" preload="none"></audio>
            </div>

            <!-- Nút từ tiếp theo -->
            <button type="button" id="C_HocFlashcard_btnNext" class="C_HocFlashcard_navBtn" title="Thẻ tiếp theo">&rarr;</button>
        </div>

        <!-- 2 Nút Đánh Giá -->
        <!-- aria-pressed giúp trình duyệt và công cụ hỗ trợ biết trạng thái nút đang được chọn. Đúng chuẩn accessibility. -->
        <div class="C_HocFlashcard_btnGroup">
            <button
                type="button"
                id="C_HocFlashcard_btnChuaNho"
                class="C_HocFlashcard_btn C_HocFlashcard_btnWhite"
                data-status="chua_nho"
                aria-pressed="false">
                Chưa nhớ
            </button>

            <button
                type="button"
                id="C_HocFlashcard_btnDaNho"
                class="C_HocFlashcard_btn C_HocFlashcard_btnGray"
                data-status="da_nho"
                aria-pressed="false">
                Đã nhớ
            </button>
        </div>
    </main>

    <!-- Footer thống kê và Kết thúc sớm -->
    <footer class="C_HocFlashcard_footerWrapper">
        <div class="C_HocFlashcard_footerBox">
            <div class="C_HocFlashcard_stats" id="C_HocFlashcard_stats">
                Đã học: 0 &bull; Đã nhớ: 0 &bull; Chưa nhớ: 0
            </div>

            <button
                type="button"
                id="C_HocFlashcard_btnKetThuc"
                class="C_HocFlashcard_btnKetThuc">
                <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                    <polyline points="16 17 21 12 16 7"></polyline>
                    <line x1="21" y1="12" x2="9" y2="12"></line>
                </svg>
                <span>Kết thúc sớm</span>
            </button>
        </div>
    </footer>

    <script>
        /*
         * Dữ liệu thẻ được PHP lấy từ database.
         * JavaScript chỉ dùng để hiển thị giao diện.
         */
        const flashcardsData = <?php
                                echo json_encode(
                                    $danh_sach_tu,
                                    JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP
                                );
                                ?>;

        /*
         * Metadata của phiên học.
         * topicId sẽ được dùng khi lưu phiên học và tạo Quiz.
         */
        const flashcardSessionConfig = <?php
                                        echo json_encode(
                                            [
                                                'topicId' => $id_chu_de,
                                                'source' => $mode === 'review' ? 'review' : $source,
                                                'sourceId' => $source_id,
                                                'limit' => $limit_option,
                                                'csrf' => $_SESSION['C_learning_csrf'],
                                                'submissionToken' => $flashcard_submission_token,
                                                'topicName' => $ten_chu_de,
                                                'mode' => $mode === 'review' ? 'review' : 'new_learning'
                                            ],
                                            JSON_UNESCAPED_UNICODE | JSON_HEX_TAG | JSON_HEX_AMP
                                        );
                                        ?>;
    </script>
    <script src="../../JS/C_HocFlashcard.js"></script>
</body>

</html>
