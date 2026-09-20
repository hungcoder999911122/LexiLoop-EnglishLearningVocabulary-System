<?php
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');
$userId = (int) $_SESSION['user_id'];

$userRows = dbSelectView($link, 'SELECT userID, full_name, avatar_url, daily_target_words FROM vw_users WHERE userID = ? LIMIT 1', 'i', [$userId]);
if (!$userRows) { exit('Không tìm thấy thông tin người dùng.'); }
$user = $userRows[0];
$fullName = $user['full_name'];
$dailyTarget = (int) $user['daily_target_words'];
$streakRows = dbSelectView($link, 'SELECT fn_get_current_streak(?) AS value', 'i', [$userId]);
$streak = (int) ($streakRows[0]['value'] ?? 0);
$learningRows = dbSelectView($link, "SELECT COUNT(*) AS total FROM vw_user_progress WHERE user_id = ? AND status = 'learning'", 'i', [$userId]);
$learningWords = (int) ($learningRows[0]['total'] ?? 0);
$masteredRows = dbSelectView($link, "SELECT COUNT(*) AS total FROM vw_user_progress WHERE user_id = ? AND status = 'mastered'", 'i', [$userId]);
$masteredWords = (int) ($masteredRows[0]['total'] ?? 0);
$quizStatsRows = dbSelectView($link, 'SELECT COUNT(*) AS total_quizzes, AVG(score) AS avg_score FROM vw_quiz_results WHERE user_id = ?', 'i', [$userId]);
$totalQuizzes = (int) ($quizStatsRows[0]['total_quizzes'] ?? 0);
$avgQuizScore = $totalQuizzes > 0 && isset($quizStatsRows[0]['avg_score']) ? (int) round((float) $quizStatsRows[0]['avg_score']) : null;
$avgQuizScoreDisplay = $avgQuizScore !== null ? $avgQuizScore . '%' : '--';
$reviewRows = dbSelectView($link, 'SELECT COUNT(*) AS total FROM vw_user_progress WHERE user_id = ? AND next_review_date <= CURRENT_DATE', 'i', [$userId]);
$reviewToday = (int) ($reviewRows[0]['total'] ?? 0);
// Một từ chỉ được tính một lần trong ngày, dù user học lặp hoặc dùng cả
// Flashcard và Quiz. Quy tắc loại trùng được đặt tập trung trong View.
$todayRows = dbSelectView($link, 'SELECT unique_words_count AS total FROM vw_user_daily_learning_summary WHERE user_id = ? AND activity_date = CURRENT_DATE', 'i', [$userId]);
$todayWords = (int) ($todayRows[0]['total'] ?? 0);
$targetPercent = $dailyTarget > 0 ? min(100, $todayWords * 100 / $dailyTarget) : 0;
$remainingWords = max($dailyTarget - $todayWords, 0);

$recentActivities = dbSelectView($link, 'SELECT * FROM vw_user_recent_activity WHERE user_id = ? ORDER BY activity_time DESC, id DESC LIMIT 5', 'i', [$userId]);
foreach ($recentActivities as &$row) {
    $row['display_time'] = $row['activity_time'] ? date('H:i, d/m/Y', strtotime($row['activity_time'])) : 'Chưa ghi nhận thời gian';
    if (!(int) $row['has_exact_time'] && $row['activity_time']) {
        $row['display_time'] = 'Ngày ' . date('d/m/Y', strtotime($row['activity_time'])) . ' · chưa lưu giờ';
    }
    $seconds = max(0, (int) $row['duration_seconds']);
    $row['duration_text'] = $seconds >= 60 ? intdiv($seconds, 60) . ' phút' : $seconds . ' giây';
    if ($row['activity_type'] === 'quiz') {
        $row['score_percent'] = (int) $row['total_questions'] > 0 ? (int) round((int) $row['correct_answers'] * 100 / (int) $row['total_questions']) : 0;
    }
}
unset($row);
?>

<!DOCTYPE html>
<html lang="vi">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - LexiLoop</title>
    <link rel="stylesheet" href="../../CSS/Style.css">
    <link rel="stylesheet" href="../../CSS/C_Dashboard_user.css">

    <link rel="stylesheet" href="../../CSS/topheader.css">
    <link rel="stylesheet" href="../../CSS/responsive.css">
</head>

<body class="C_Dashboard_user_body">

    <!-- Header dùng chung; tên người dùng lấy từ session, không query lại database. -->
    <?php
    $headerTitle = 'Dashboard';
    include '../../includes/topheader.php';
    ?>

    <!-- SIDEBAR -->
    <?php include '../../includes/sidebar_user.php'; ?>

    <main class="C_Dashboard_user_mainContent">
        <!-- Tổng quan đầu trang: chào mừng, chỉ số và chuỗi học liên tục. -->
        <section class="C_Dashboard_user_overview" aria-labelledby="dashboard-welcome-title">
            <div class="C_Dashboard_user_welcomeCard">
                <span class="C_Dashboard_user_eyebrow">TỔNG QUAN HÔM NAY</span>
                <h2 id="dashboard-welcome-title">Chào mừng trở lại, <?= htmlspecialchars($fullName) ?>!</h2>
                <p>
                    <?php if ($reviewToday > 0): ?>
                        Có <strong><?= $reviewToday ?> chủ đề</strong> đang chờ bạn ôn tập hôm nay.
                    <?php else: ?>
                        Hôm nay chưa có chủ đề đến hạn. Bạn có thể tự chọn và học thêm các từ của chủ đề mới.
                    <?php endif; ?>
                </p>
                <a href="C_Ontaphomnay.php" class="C_Dashboard_user_primaryButton">
                    Ôn tập ngay <span aria-hidden="true">→</span>
                </a>
                <span class="C_Dashboard_user_decorWord" aria-hidden="true">Aa</span>
            </div>

            <div class="C_Dashboard_user_statsCard" aria-label="Thống kê học tập">
                <div class="C_Dashboard_user_statItem C_Dashboard_user_statItem--blue">
                    <span class="C_Dashboard_user_statIcon" aria-hidden="true">↗</span>
                    <strong><?= $learningWords ?></strong>
                    <span>Đang học</span>
                    <!-- <small>Đã bắt đầu, chưa đạt 5 lần ôn đúng</small> -->
                </div>
                <div class="C_Dashboard_user_statItem C_Dashboard_user_statItem--green">
                    <span class="C_Dashboard_user_statIcon" aria-hidden="true">✓</span>
                    <strong><?= $masteredWords ?></strong>
                    <span>Đã thuộc</span>
                    <!-- <small>Đạt từ 5 lần ôn thành công</small> -->
                </div>
                <div class="C_Dashboard_user_statItem C_Dashboard_user_statItem--violet">
                    <span class="C_Dashboard_user_statIcon" aria-hidden="true">★</span>
                    <strong><?= $avgQuizScoreDisplay ?></strong>
                    <span>Điểm TB Quiz</span>
                    <small><?= $totalQuizzes > 0 ? $totalQuizzes . ' bài đã làm' :  ' Chưa làm bài quiz nào' ?></small>
                </div>
                <div class="C_Dashboard_user_statItem C_Dashboard_user_statItem--orange">
                    <span class="C_Dashboard_user_statIcon" aria-hidden="true">◎</span>
                    <strong><?= $todayWords ?></strong>
                    <span>Lượt từ luyện hôm nay</span>
                </div>
            </div>

            <div class="C_Dashboard_user_streakCard">
                <div class="C_Dashboard_user_streakLabel"><span aria-hidden="true">🔥</span> Chuỗi ngày học</div>
                <div class="C_Dashboard_user_streakValue"><strong><?= $streak ?></strong><span>ngày</span></div>
                <p><?= $streak > 0 ? 'Duy trì nhịp học mỗi ngày nhé!' : 'Bắt đầu chuỗi học đầu tiên hôm nay.' ?></p>
                <div class="C_Dashboard_user_streakTip"><span aria-hidden="true">✦</span> Mỗi ngày một bước tiến</div>
            </div>
        </section>

        <section class="C_Dashboard_user_quickSection" aria-labelledby="quick-access-title">
            <div class="C_Dashboard_user_sectionHeader">
                <div>
                    <span class="C_Dashboard_user_eyebrow">BẮT ĐẦU HỌC</span>
                    <h3 id="quick-access-title">Truy cập nhanh</h3>
                </div>
            </div>
            <div class="C_Dashboard_user_quickGrid">
                <a href="C_Botuvung.php" class="C_Dashboard_user_quickCard C_Dashboard_user_quickCard--blue">
                    <span class="C_Dashboard_user_quickIcon" aria-hidden="true">＋</span>
                    <span><strong>Bộ từ vựng</strong><small>Tạo và quản lý bộ từ cá nhân</small></span>
                    <b aria-hidden="true">→</b>
                </a>
                <a href="../main/B_DanhSachChuDe.php" class="C_Dashboard_user_quickCard C_Dashboard_user_quickCard--violet">
                    <span class="C_Dashboard_user_quickIcon" aria-hidden="true">⚡</span>
                    <span><strong>Học theo chủ đề</strong><small>Khám phá kho từ vựng có sẵn</small></span>
                    <b aria-hidden="true">→</b>
                </a>
                <a href="C_Tuvungcuatoi.php" class="C_Dashboard_user_quickCard C_Dashboard_user_quickCard--green">
                    <span class="C_Dashboard_user_quickIcon" aria-hidden="true">▤</span>
                    <span><strong>Từ vựng của tôi</strong><small>Xem lại danh sách đã lưu</small></span>
                    <b aria-hidden="true">→</b>
                </a>
                <a href="C_Lichsuontap.php" class="C_Dashboard_user_quickCard C_Dashboard_user_quickCard--orange">
                    <span class="C_Dashboard_user_quickIcon" aria-hidden="true">◷</span>
                    <span><strong>Lịch sử ôn tập</strong><small>Theo dõi quá trình học chi tiết</small></span>
                    <b aria-hidden="true">→</b>
                </a>
            </div>
        </section>

        <div class="C_Dashboard_user_contentGrid">
            <section class="C_Dashboard_user_panel" aria-labelledby="today-target-title">
                <div class="C_Dashboard_user_sectionHeader">
                    <div>
                        <span class="C_Dashboard_user_eyebrow">NHỊP HỌC CÁ NHÂN</span>
                        <h3 id="today-target-title">Mục tiêu hôm nay</h3>
                    </div>
                    <strong class="C_Dashboard_user_targetPercent"><?= round($targetPercent) ?>%</strong>
                </div>
                <div class="C_Dashboard_user_targetNumbers">
                    <strong><?= $todayWords ?></strong><span>/ <?= $dailyTarget ?> từ</span>
                </div>
                <div class="C_Dashboard_user_targetProgress" role="progressbar" aria-valuemin="0" aria-valuemax="100" aria-valuenow="<?= round($targetPercent) ?>">
                    <div class="C_Dashboard_user_targetProgressBar" style="width: <?= $targetPercent ?>%;"></div>
                </div>
                <p class="C_Dashboard_user_targetNote">
                    <?= $remainingWords > 0
                        ? 'Còn ' . $remainingWords . ' từ nữa để hoàn thành mục tiêu.'
                        : 'Bạn đã hoàn thành mục tiêu hôm nay.' ?>
                </p>
                <a href="../main/B_DanhSachChuDe.php" class="C_Dashboard_user_textLink">Tiếp tục học từ mới →</a>
            </section>

            <section class="C_Dashboard_user_panel" aria-labelledby="recent-activity-title">
                <div class="C_Dashboard_user_sectionHeader">
                    <div>
                        <span class="C_Dashboard_user_eyebrow">DÒNG THỜI GIAN HỌC TẬP</span>
                        <h3 id="recent-activity-title">Hoạt động gần đây</h3>
                    </div>
                    <a href="C_Lichsuontap.php" class="C_Dashboard_user_textLink">Xem lịch sử</a>
                </div>
                <div class="C_Dashboard_user_activityList">
                    <?php if (empty($recentActivities)): ?>
                        <div class="C_Dashboard_user_emptyState">
                            <span aria-hidden="true">✦</span>
                            <p>Chưa có hoạt động Flashcard hoặc Quiz gần đây.</p>
                        </div>
                    <?php else: ?>
                        <?php foreach ($recentActivities as $activity): ?>
                            <div class="C_Dashboard_user_activityRow">
                                <span class="C_Dashboard_user_activityIcon C_Dashboard_user_activityIcon--<?= $activity['activity_type'] ?>" aria-hidden="true">
                                    <?= $activity['activity_type'] === 'quiz' ? '✓' : '▤' ?>
                                </span>
                                <span class="C_Dashboard_user_activityInfo">
                                    <strong><?= $activity['activity_type'] === 'quiz' ? 'Quiz' : 'Flashcard' ?> - <?= htmlspecialchars($activity['source_name']) ?></strong>
                                    <small><?= htmlspecialchars($activity['display_time']) ?> · <?= htmlspecialchars($activity['duration_text']) ?></small>
                                </span>
                                <strong class="C_Dashboard_user_activityScore">
                                    <?php if ($activity['activity_type'] === 'quiz'): ?>
                                        Đúng <?= (int) $activity['correct_answers'] ?>/<?= (int) $activity['total_questions'] ?>
                                    <?php else: ?>
                                        Đã học <?= (int) $activity['words_studied'] ?> từ
                                    <?php endif; ?>
                                </strong>
                            </div>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </div>
            </section>
        </div>
    </main>
    <script src="../../JS/jquery-4.0.0.min.js"></script>
    <script src="../../JS/auth.js"></script>
</body>

</html>
