<?php
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');
require_once($_SERVER['DOCUMENT_ROOT'] . "/Connect.php");

// auth_guard.php đã xác thực session trước khi trang sử dụng user_id.
$user_id = (int) $_SESSION['user_id'];

// Khởi tạo các giá trị mặc định
$diem_so      = 0;
$tong_cau     = 0;
$thoi_gian    = "0:00";
$cau_sai      = [];
$retry_url    = 'C_Gocrenluyen.php';
$retry_label  = 'Làm lại Quiz';
$result_saved = false;
$result_error = '';
$quiz_result_id = isset($_GET['id']) ? intval($_GET['id']) : (isset($_GET['quiz_id']) ? intval($_GET['quiz_id']) : 0);
$result_source = $_GET['source'] ?? '';
$result_mode = ($_GET['mode'] ?? 'practice') === 'review' ? 'review' : 'practice';
$retry_limit = (string) ($_GET['limit'] ?? '10');
if (!in_array($retry_limit, ['5', '10', '20', 'all'], true)) {
    $retry_limit = '10';
}
if ($result_source === 'review' || $result_mode === 'review') {
    $retry_url = 'C_Ontaphomnay.php';
    $retry_label = 'Quay lại ôn tập';
}

// Hàm định dạng số giây thành "Phút:Giây"
if (!function_exists('dinhDangThoiGianLam')) {
    function dinhDangThoiGianLam($seconds)
    {
        $seconds = max(0, intval($seconds));
        $m = floor($seconds / 60);
        $s = $seconds % 60;
        return sprintf("%d:%02d", $m, $s);
    }
}

try {
    require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');

    $summarySql = $quiz_result_id > 0
        ? 'SELECT * FROM vw_quiz_result_summary WHERE quiz_result_id = ? AND user_id = ? LIMIT 1'
        : 'SELECT * FROM vw_quiz_result_summary WHERE user_id = ? ORDER BY COALESCE(finished_at, started_at) DESC, quiz_result_id DESC LIMIT 1';
    $summaryRows = $quiz_result_id > 0
        ? dbSelectView($link, $summarySql, 'ii', [$quiz_result_id, $user_id])
        : dbSelectView($link, $summarySql, 'i', [$user_id]);

    if ($summaryRows) {
        $result_saved = true;
        $row = $summaryRows[0];
        $quiz_result_id = (int) $row['quiz_result_id'];
        $diem_so = (int) $row['correct_answers'];
        $tong_cau = (int) $row['total_questions'];
        $thoi_gian = dinhDangThoiGianLam($row['duration_seconds'] ?? 0);
        if ($result_mode !== 'review' && !empty($row['vocabulary_set_id'])) {
            $retry_url = 'C_Quiz.php?' . http_build_query([
                'source' => 'set', 'id' => (int) $row['vocabulary_set_id'],
                'mode' => $result_mode, 'limit' => $retry_limit,
            ]);
        } elseif ($result_mode !== 'review' && !empty($row['topic_id'])) {
            $retry_url = 'C_Quiz.php?' . http_build_query([
                'source' => 'topic', 'id' => (int) $row['topic_id'],
                'mode' => $result_mode, 'limit' => $retry_limit,
            ]);
        }
    } else {
        $result_error = 'Không tìm thấy kết quả Quiz đã lưu cho tài khoản này.';
    }

    if ($quiz_result_id > 0) {
        $detailRows = dbSelectView(
            $link,
            'SELECT question_order, word, selected_answer, correct_answer
             FROM vw_quiz_incorrect_answers
             WHERE user_id = ? AND quiz_result_id = ?
             ORDER BY question_order',
            'ii',
            [$user_id, $quiz_result_id]
        );
        foreach ($detailRows as $detail) {
            $cau_sai[] = [
                'cau' => (int) $detail['question_order'],
                'tu' => $detail['word'],
                'da_chon' => $detail['selected_answer'] ?: 'Chưa trả lời',
                'nghia_dung' => $detail['correct_answer'],
            ];
        }
    }
} catch (Throwable $error) {
    error_log('Lỗi Kết quả Quiz: ' . $error->getMessage());
    $result_error = 'Không thể tải bản ghi kết quả Quiz.';
}

// --- TÍNH TOÁN TỶ LỆ VÀ XẾP LOẠI ---
$phan_tram = ($tong_cau > 0) ? round(($diem_so / $tong_cau) * 100) : 0;
$do_chinh_xac = $phan_tram . "%";

if ($phan_tram >= 90) {
    $xep_hang = "Xuất sắc";
    $feedback = "Tuyệt vời! Bạn nắm từ vựng rất vững!";
} elseif ($phan_tram >= 70) {
    $xep_hang = "Khá";
    $feedback = "Bạn làm rất tốt! Cố gắng phát huy nhé!";
} elseif ($phan_tram >= 50) {
    $xep_hang = "Trung bình";
    $feedback = "Khá ổn! Hãy ôn tập thêm để cải thiện phản xạ nhé!";
} else {
    $xep_hang = "Yếu";
    $feedback = "Hãy ôn lại các từ chưa nhớ và thử lại nhé!";
}

// Nếu đúng 100% thì danh sách câu sai là rỗng
if ($diem_so >= $tong_cau) {
    $cau_sai = [];
}
?>

<!DOCTYPE html>
<html lang="vi">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kết quả Quiz - LexiLoop</title>
    <link rel="stylesheet" href="../../CSS/C_KetquaQuiz.css">
</head>

<body class="C_KetquaQuiz_body">

    <!-- Header Focus Mode -->
    <header class="C_KetquaQuiz_header">
        <h1 class="C_KetquaQuiz_logo">Kết quả Quiz</h1>
        <button type="button" id="C_KetquaQuiz_btnDong" class="C_KetquaQuiz_btnClose" title="Đóng">
            &times; Thoát
        </button>
    </header>

    <main class="C_KetquaQuiz_main">

        <div class="C_KetquaQuiz_saveStatus <?php echo $result_saved ? 'is-saved' : 'is-error'; ?>" role="status">
            <span aria-hidden="true"><?php echo $result_saved ? '✓' : '!'; ?></span>
            <?php echo htmlspecialchars($result_saved ? 'Kết quả và tiến độ ôn tập đã được ghi nhận.' : $result_error); ?>
        </div>

        <!-- Vòng tròn hiển thị điểm -->
        <div class="C_KetquaQuiz_scoreCircle" id="C_KetquaQuiz_scoreCircle">
            <span class="C_KetquaQuiz_scoreText" id="C_KetquaQuiz_scoreText">
                <?php echo "{$diem_so}/{$tong_cau}"; ?>
            </span>
        </div>

        <!-- Lời khen / Nhận xét -->
        <p class="C_KetquaQuiz_feedback" id="C_KetquaQuiz_feedback">
            <?php echo $feedback; ?>
        </p>

        <!-- 3 Thẻ thống kê chi tiết -->
        <section class="C_KetquaQuiz_statsContainer">
            <div class="C_KetquaQuiz_statCard">
                <span class="C_KetquaQuiz_statLabel">Thời gian</span>
                <span class="C_KetquaQuiz_statValue" id="C_KetquaQuiz_statTime"><?php echo $thoi_gian; ?></span>
            </div>

            <div class="C_KetquaQuiz_statCard">
                <span class="C_KetquaQuiz_statLabel">Độ chính xác</span>
                <span class="C_KetquaQuiz_statValue" id="C_KetquaQuiz_statAccuracy"><?php echo $do_chinh_xac; ?></span>
            </div>

            <div class="C_KetquaQuiz_statCard">
                <span class="C_KetquaQuiz_statLabel">Xếp hạng</span>
                <span class="C_KetquaQuiz_statValue" id="C_KetquaQuiz_statRank"><?php echo $xep_hang; ?></span>
            </div>
        </section>

        <!-- Cụm 3 nút hành động -->
        <div class="C_KetquaQuiz_btnGroup">
            <button type="button" id="C_KetquaQuiz_btnXemLai" class="C_KetquaQuiz_btn C_KetquaQuiz_btnWhite">
                Xem lại câu sai
            </button>
            <button type="button" id="C_KetquaQuiz_btnLamLai" class="C_KetquaQuiz_btn C_KetquaQuiz_btnPrimary">
                <?php echo htmlspecialchars($retry_label); ?>
            </button>
            <button type="button" id="C_KetquaQuiz_btnDashboard" class="C_KetquaQuiz_btn C_KetquaQuiz_btnWhite">
                Về Dashboard
            </button>
        </div>

        <!-- Khối hiển thị chi tiết câu sai (có thể bấm mở rộng) -->
        <footer class="C_KetquaQuiz_wrongBoxContainer">
            <div class="C_KetquaQuiz_wrongBox" id="C_KetquaQuiz_wrongBox">
                <span class="wrong-icon">⚠️</span>
                <span>
                    <strong>Câu cần xem lại:</strong>
                    <?= empty($cau_sai) ? 'Không có câu sai.' : count($cau_sai) . ' câu - nhấn để xem chi tiết.' ?>
                </span>
            </div>

            <div class="C_KetquaQuiz_wrongDetail" id="C_KetquaQuiz_wrongDetail" style="display: none;">
                <ul>
                    <?php foreach ($cau_sai as $item): ?>
                        <li>
                            <strong>Câu <?= $item['cau'] ?>:</strong>
                            <?= htmlspecialchars($item['tu']) ?> — Đã chọn: <?= htmlspecialchars($item['da_chon']) ?>;
                            nghĩa đúng: <span class="correct-text"><?= htmlspecialchars($item['nghia_dung']) ?></span>
                        </li>
                    <?php endforeach; ?>
                </ul>
            </div>
        </footer>

    </main>

    <script>const quizResultRetryUrl = <?= json_encode($retry_url, JSON_HEX_TAG | JSON_HEX_AMP) ?>;</script>
    <script src="../../JS/C_KetquaQuiz.js"></script>
</body>

</html>
