<?php
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');

$user_id = (int) $_SESSION['user_id'];
$srs_base_ease = 2.5;
$srs_min_interval = 1;
$tu_can_on_tap = 0;
$so_tu_qua_han = 0;
$dueTopics = [];

$levelDefinitions = [
    'Lv0' => ['title' => 'Mới bắt đầu', 'description' => 'Chưa có lần ghi nhớ thành công. Cần ôn kỹ để tạo nền tảng.', 'class' => 'level-0'],
    'Lv1' => ['title' => 'Đang làm quen', 'description' => 'Đã ghi nhớ thành công 1 lần nhưng liên kết trí nhớ còn yếu.', 'class' => 'level-1'],
    'Lv2' => ['title' => 'Đang củng cố', 'description' => 'Đã ghi nhớ thành công 2 lần. Khoảng cách ôn bắt đầu dài hơn.', 'class' => 'level-2'],
    'Lv3+' => ['title' => 'Ghi nhớ ổn định', 'description' => 'Đã ghi nhớ thành công từ 3 lần. Vẫn cần ôn khi hệ thống xếp lịch.', 'class' => 'level-3'],
];

try {
    $userRows = dbSelectView($link, 'SELECT srs_base_ease, srs_min_interval FROM Users WHERE userID = ?', 'i', [$user_id]);
    if ($userRows) {
        $srs_base_ease = (float) ($userRows[0]['srs_base_ease'] ?? 2.5);
        $srs_min_interval = (int) ($userRows[0]['srs_min_interval'] ?? 1);
    }

    $dueTopics = dbSelectView(
        $link,
        'SELECT * FROM vw_srs_due_topics WHERE user_id = ? ORDER BY overdue_days DESC, oldest_due_date ASC',
        'i',
        [$user_id]
    );

    // Mỗi chủ đề có một phân bố level riêng để tránh biểu đồ tổng hợp gây hiểu nhầm.
    $levelRows = dbSelectView(
        $link,
        'SELECT topic_id,
                SUM(CASE WHEN repetitions = 0 THEN 1 ELSE 0 END) AS lv0_count,
                SUM(CASE WHEN repetitions = 1 THEN 1 ELSE 0 END) AS lv1_count,
                SUM(CASE WHEN repetitions = 2 THEN 1 ELSE 0 END) AS lv2_count,
                SUM(CASE WHEN repetitions >= 3 THEN 1 ELSE 0 END) AS lv3_count
           FROM vw_user_progress
          WHERE user_id = ? AND topic_id IS NOT NULL AND next_review_date <= CURRENT_DATE
          GROUP BY topic_id',
        'i',
        [$user_id]
    );

    $levelsByTopic = [];
    foreach ($levelRows as $row) {
        $levelsByTopic[(int) $row['topic_id']] = [
            'Lv0' => (int) $row['lv0_count'],
            'Lv1' => (int) $row['lv1_count'],
            'Lv2' => (int) $row['lv2_count'],
            'Lv3+' => (int) $row['lv3_count'],
        ];
    }

    foreach ($dueTopics as &$topic) {
        $topic['levels'] = $levelsByTopic[(int) $topic['topic_id']] ?? ['Lv0' => 0, 'Lv1' => 0, 'Lv2' => 0, 'Lv3+' => 0];
        $tu_can_on_tap += (int) $topic['due_word_count'];
        if ((int) $topic['overdue_days'] > 0) {
            $so_tu_qua_han += (int) $topic['due_word_count'];
        }
    }
    unset($topic);
} catch (Throwable $error) {
    error_log('Lỗi Ôn tập hôm nay: ' . $error->getMessage());
}

$so_chu_de_den_han = count($dueTopics);
$so_chu_de_qua_han = count(array_filter($dueTopics, static fn(array $topic): bool => (int) $topic['overdue_days'] > 0));
?>
<!DOCTYPE html>
<html lang="vi">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ôn tập hôm nay - LexiLoop</title>
    <link rel="stylesheet" href="../../CSS/Style.css">
    <link rel="stylesheet" href="../../CSS/topheader.css">
    <link rel="stylesheet" href="../../CSS/C_Ontaphomnay.css">
    <link rel="stylesheet" href="../../CSS/responsive.css">
</head>

<body class="C_Ontaphomnay_body">
    <?php
    // Trang ôn tập thuộc nhóm Góc rèn luyện trong điều hướng chung.
    $sidebarActivePage = 'C_Gocrenluyen.php';
    include '../../includes/sidebar_user.php';
    ?>

    <div class="page-content">
        <?php
        $headerTitle = 'Ôn tập hôm nay';
        $topHeaderPageActions = '';
        include '../../includes/topheader.php';
        ?>

        <main class="C_Ontaphomnay_main">
            <section class="C_Ontaphomnay_hero" aria-labelledby="reviewPageTitle">
                <div class="C_Ontaphomnay_heroContent">
                    <span class="C_Ontaphomnay_eyebrow">Ôn đúng lúc · Nhớ lâu hơn</span>
                    <h2 id="reviewPageTitle">SRS - Phiên ôn tập hôm nay</h2>
                    <p>Các chủ đề được hiện thị và nhắc hẹn tại đây. Thực hiện và ôn tập theo phương pháp SRS bất cứ lúc nào mà bạn muốn.</p>
                </div>
                <div class="C_Ontaphomnay_heroStats" aria-label="Tổng quan lịch ôn">
                    <div class="C_Ontaphomnay_stat is-primary"><b><?php echo $tu_can_on_tap; ?></b><span>Từ cần ôn</span></div>
                    <div class="C_Ontaphomnay_stat"><b><?php echo $so_chu_de_den_han; ?></b><span>Chủ đề đến hạn</span></div>
                    <div class="C_Ontaphomnay_stat is-warning"><b><?php echo $so_tu_qua_han; ?></b><span>Từ đang quá hạn</span></div>
                </div>
            </section>

            <?php if ($tu_can_on_tap > 0): ?>
                <section id="C_Ontaphomnay_overview" class="C_Ontaphomnay_overview" aria-labelledby="dueTopicsTitle">
                    <div class="C_Ontaphomnay_sectionHeading">
                        <div><span class="C_Ontaphomnay_kicker">Hàng đợi SRS</span>
                            <h2 id="dueTopicsTitle">Chọn chủ đề cần ôn</h2>
                            <p>Chủ đề quá hạn được ưu tiên. Bấm vào một thẻ để xem biểu đồ riêng.</p>
                        </div>
                        <?php if ($so_chu_de_qua_han > 0): ?><span class="C_Ontaphomnay_priorityBadge"><?php echo $so_chu_de_qua_han; ?> chủ đề cần ưu tiên</span><?php endif; ?>
                    </div>

                    <div class="C_Ontaphomnay_topicGrid">
                        <?php foreach ($dueTopics as $index => $topic): ?>
                            <?php
                            $topicId = (int) $topic['topic_id'];
                            $overdueDays = max(0, (int) $topic['overdue_days']);
                            $levels = $topic['levels'];
                            $experienced = $levels['Lv1'] + $levels['Lv2'] + $levels['Lv3+'];
                            $experiencePercent = (int) round(($experienced / max(1, (int) $topic['due_word_count'])) * 100);
                            ?>
                            <button type="button" class="C_Ontaphomnay_topicCard<?php echo $overdueDays > 0 ? ' is-overdue' : ''; ?>" data-review-topic="<?php echo $topicId; ?>" aria-controls="C_Ontaphomnay_topicDetail_<?php echo $topicId; ?>">
                                <span class="C_Ontaphomnay_cardTopline"><span class="C_Ontaphomnay_topicNumber"><?php echo str_pad((string) ($index + 1), 2, '0', STR_PAD_LEFT); ?></span><span class="C_Ontaphomnay_dueStatus"><?php echo $overdueDays > 0 ? 'Quá hạn ' . $overdueDays . ' ngày' : 'Đến hạn hôm nay'; ?></span></span>
                                <span class="C_Ontaphomnay_topicCategory"><?php echo htmlspecialchars((string) $topic['category']); ?></span>
                                <strong class="C_Ontaphomnay_topicTitle"><?php echo htmlspecialchars((string) $topic['topic_name']); ?></strong>
                                <span class="C_Ontaphomnay_topicSummary"><span><b><?php echo (int) $topic['due_word_count']; ?></b> từ cần ôn</span><span><b><?php echo $experiencePercent; ?>%</b> đã có nhịp nhớ</span></span>
                                <span class="C_Ontaphomnay_levelPreview" aria-label="Phân bố level thu gọn">
                                    <?php foreach ($levelDefinitions as $level => $definition): ?><span class="<?php echo $definition['class']; ?>" style="--segment:<?php echo max(1, (int) $levels[$level]); ?>" title="<?php echo $level . ': ' . (int) $levels[$level] . ' từ'; ?>"></span><?php endforeach; ?>
                                </span>
                                <span class="C_Ontaphomnay_cardAction">Xem tiến độ <span aria-hidden="true">→</span></span>
                            </button>
                        <?php endforeach; ?>
                    </div>

                    <aside class="C_Ontaphomnay_levelGuide" aria-labelledby="levelGuideTitle">
                        <div class="C_Ontaphomnay_levelGuideIntro"><span class="C_Ontaphomnay_kicker">Cách đọc level</span>
                            <h2 id="levelGuideTitle">Mỗi level đang nói điều gì?</h2>
                            <p>Level suy ra từ số lần ghi nhớ thành công, không phải điểm số cố định.</p>
                        </div>
                        <div class="C_Ontaphomnay_levelGuideGrid">
                            <?php foreach ($levelDefinitions as $level => $definition): ?>
                                <article class="C_Ontaphomnay_levelNote <?php echo $definition['class']; ?>"><span class="C_Ontaphomnay_levelBadge"><?php echo $level; ?></span>
                                    <div>
                                        <h3><?php echo $definition['title']; ?></h3>
                                        <p><?php echo $definition['description']; ?></p>
                                    </div>
                                </article>
                            <?php endforeach; ?>
                        </div>
                    </aside>
                </section>

                <?php foreach ($dueTopics as $topic): ?>
                    <?php $topicId = (int) $topic['topic_id'];
                    $levels = $topic['levels'];
                    $maxLevelCount = max(1, max($levels));
                    $overdueDays = max(0, (int) $topic['overdue_days']); ?>
                    <section id="C_Ontaphomnay_topicDetail_<?php echo $topicId; ?>" class="C_Ontaphomnay_topicDetail" data-topic-detail="<?php echo $topicId; ?>" hidden>
                        <button type="button" class="C_Ontaphomnay_detailBack" data-back-to-topics><span aria-hidden="true">←</span> Chọn chủ đề khác</button>
                        <div class="C_Ontaphomnay_detailHeader">
                            <div><span class="C_Ontaphomnay_topicCategory"><?php echo htmlspecialchars((string) $topic['category']); ?></span>
                                <h2><?php echo htmlspecialchars((string) $topic['topic_name']); ?></h2>
                                <p><?php echo (int) $topic['due_word_count']; ?> từ đang chờ ôn · <?php echo $overdueDays > 0 ? 'Từ cũ nhất quá hạn ' . $overdueDays . ' ngày' : 'Lịch ôn đúng hôm nay'; ?></p>
                            </div>
                            <a href="C_Quiz.php?source=topic&amp;id=<?php echo $topicId; ?>&amp;mode=review" class="C_Ontaphomnay_btnAction C_Ontaphomnay_btnStart"><span aria-hidden="true">▶</span> Bắt đầu ôn tập</a>
                        </div>
                        <div class="C_Ontaphomnay_detailLayout">
                            <section class="C_Ontaphomnay_chartBox">
                                <div class="C_Ontaphomnay_chartHeading">
                                    <div><span class="C_Ontaphomnay_kicker">Biểu đồ theo chủ đề</span>
                                        <h3>Phân bố từ đến hạn theo level</h3>
                                    </div><span class="C_Ontaphomnay_chartTotal"><?php echo (int) $topic['due_word_count']; ?> từ</span>
                                </div>
                                <div class="C_Ontaphomnay_chartContainer">
                                    <?php foreach ($levelDefinitions as $level => $definition): $count = (int) $levels[$level];
                                        $height = $count > 0 ? max(10, ($count / $maxLevelCount) * 100) : 3; ?>
                                        <div class="C_Ontaphomnay_chartColumn <?php echo $definition['class']; ?>"><span class="C_Ontaphomnay_chartValue"><?php echo $count; ?></span>
                                            <div class="C_Ontaphomnay_chartTrack" aria-hidden="true"><span class="C_Ontaphomnay_chartBar" style="--bar-height:<?php echo $height; ?>%"></span></div><span class="C_Ontaphomnay_chartLabel"><?php echo $level; ?></span><small><?php echo $definition['title']; ?></small>
                                        </div>
                                    <?php endforeach; ?>
                                </div>
                            </section>
                            <aside class="C_Ontaphomnay_detailNotes"><span class="C_Ontaphomnay_kicker">Gợi ý phiên học</span>
                                <h3>Nên bắt đầu từ đâu?</h3>
                                <p>Quiz chỉ lấy các từ đang đến hạn trong chủ đề này. Từ level thấp cần được chú ý nhiều hơn.</p>
                                <ul>
                                    <?php foreach ($levelDefinitions as $level => $definition): ?><li class="<?php echo $definition['class']; ?>"><span class="C_Ontaphomnay_noteDot" aria-hidden="true"></span><span><b><?php echo $level; ?> · <?php echo (int) $levels[$level]; ?> từ:</b> <?php echo $definition['title']; ?></span></li><?php endforeach; ?>
                                </ul>
                                <p class="C_Ontaphomnay_detailHint"><span aria-hidden="true">ℹ</span> Trả lời sai không phải thất bại; hệ thống sẽ rút ngắn khoảng ôn để bạn có thể ôn lại từ sớm hơn.</p>
                            </aside>
                        </div>
                        <div class="C_Ontaphomnay_mobileAction"><a href="C_Quiz.php?source=topic&amp;id=<?php echo $topicId; ?>&amp;mode=review" class="C_Ontaphomnay_btnAction"><span aria-hidden="true">▶</span> Bắt đầu ôn tập</a></div>
                    </section>
                <?php endforeach; ?>
            <?php else: ?>
                <section class="C_Ontaphomnay_emptyState"><span class="C_Ontaphomnay_emptyIcon" aria-hidden="true">✓</span><span class="C_Ontaphomnay_kicker">Hàng đợi đã sạch</span>
                    <h2>Bạn đã hoàn thành lịch ôn tập SRS hôm nay</h2>
                    <p>Hiện không có từ nào đến hạn. Bạn có thể học thêm chủ đề mới và quay lại sau.</p><a href="../main/B_DanhSachChuDe.php" class="C_Ontaphomnay_btnAction C_Ontaphomnay_btnInline">Khám phá chủ đề mới</a>
                </section>
            <?php endif; ?>

            <details class="C_Ontaphomnay_settings">
                <summary><span><b>Tùy chỉnh nhịp ôn SRS</b><small>Dành cho người muốn tinh chỉnh thuật toán</small></span><span aria-hidden="true">⚙</span></summary>
                <div class="C_Ontaphomnay_srsPanel">
                    <div class="C_Ontaphomnay_srsExplanation">
                        <h2>Hai tham số này ảnh hưởng thế nào?</h2>
                        <p><b>Ease</b> quyết định khoảng ôn tăng nhanh đến mức nào. <b>Khoảng tối thiểu</b> là số ngày sớm nhất một từ có thể được xếp lịch lại.</p>
                    </div>
                    <form id="formSrsConfig" class="C_Ontaphomnay_srsForm">
                        <label class="C_Ontaphomnay_formGroup" for="srs_base_ease"><span>Hệ số Ease ban đầu</span><input type="number" id="srs_base_ease" step="0.1" min="1.3" max="3.0" value="<?php echo htmlspecialchars((string) $srs_base_ease); ?>"><small>Khoảng hợp lệ: 1.3–3.0. Mặc định 2.5.</small></label>
                        <label class="C_Ontaphomnay_formGroup" for="srs_min_interval"><span>Khoảng cách tối thiểu</span><span class="C_Ontaphomnay_inputSuffix"><input type="number" id="srs_min_interval" min="1" max="10" value="<?php echo htmlspecialchars((string) $srs_min_interval); ?>"><span>ngày</span></span><small>Khoảng hợp lệ: 1–10 ngày.</small></label>
                        <div class="C_Ontaphomnay_formActions"><button type="submit" id="btnSaveSrsConfig" class="C_Ontaphomnay_btnAction C_Ontaphomnay_btnInline">Lưu cấu hình</button>
                            <div id="srsConfigMessage" class="srs-message" role="status" aria-live="polite"></div>
                        </div>
                    </form>
                </div>
            </details>
        </main>
    </div>
    <script src="../../JS/C_Ontaphomnay.js"></script>
</body>

</html>