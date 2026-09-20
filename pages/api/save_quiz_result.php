<?php
header('Content-Type: application/json; charset=utf-8');

if (session_status() === PHP_SESSION_NONE) session_start();
if (!isset($_SESSION['user_id']) || ($_SESSION['auth_scope'] ?? '') !== 'user') {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Quyền truy cập bị từ chối hoặc phiên đã hết hạn.']);
    exit;
}

require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');
$userId = (int) $_SESSION['user_id'];
$payload = json_decode(file_get_contents('php://input'), true);
$csrf = is_array($payload) ? ($payload['csrf'] ?? '') : '';

if (!is_string($csrf) || empty($_SESSION['C_learning_csrf']) || !hash_equals($_SESSION['C_learning_csrf'], $csrf)) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'CSRF token không hợp lệ.']);
    exit;
}

$source = $payload['source'] ?? '';
$sourceId = filter_var($payload['sourceId'] ?? 0, FILTER_VALIDATE_INT) ?: 0;
$mode = $payload['mode'] ?? 'practice';
$submissionToken = $payload['submissionToken'] ?? '';
$itemLimit = (string) ($payload['limit'] ?? '10');
$answers = is_array($payload['answers'] ?? null) ? $payload['answers'] : [];
$duration = max(0, min(86400, (int) ($payload['durationSeconds'] ?? 0)));

if (!in_array($source, ['topic', 'set', 'review'], true)
    || ($source !== 'review' && $sourceId <= 0)
    || !in_array($mode, ['practice', 'review'], true)
    || ($source === 'review' && $mode !== 'review')
    || ($mode === 'review' && !in_array($source, ['topic', 'review'], true))
    || !is_string($submissionToken)
    || !preg_match('/^[a-f0-9]{64}$/', $submissionToken)
    || !in_array($itemLimit, ['5', '10', '20', 'all'], true)
    || !$answers) {
    http_response_code(422);
    echo json_encode(['success' => false, 'message' => 'Kết quả Quiz không hợp lệ.']);
    exit;
}

$submission = $_SESSION['C_quiz_submissions'][$submissionToken] ?? null;
if (!is_array($submission)
    || ($submission['source'] ?? null) !== $source
    || (int) ($submission['sourceId'] ?? 0) !== $sourceId
    || ($submission['mode'] ?? null) !== $mode) {
    http_response_code(409);
    echo json_encode(['success' => false, 'message' => 'Phiên nộp Quiz không hợp lệ hoặc đã hết hạn.']);
    exit;
}

// Trả lại chính kết quả đã ghi nếu trình duyệt gửi lại cùng request.
if (($submission['status'] ?? '') === 'completed' && is_array($submission['response'] ?? null)) {
    echo json_encode($submission['response']);
    exit;
}

try {
    $validatedAnswers = [];
    $seenVocabularyIds = [];
    foreach ($answers as $answer) {
        if (!is_array($answer)) {
            throw new InvalidArgumentException('Câu trả lời Quiz không hợp lệ.');
        }
        $vocabularyId = filter_var($answer['vocabularyId'] ?? 0, FILTER_VALIDATE_INT) ?: 0;
        $selectedAnswer = trim((string) ($answer['selectedAnswer'] ?? ''));
        if ($vocabularyId <= 0) {
            throw new InvalidArgumentException('ID từ vựng không hợp lệ.');
        }
        if (isset($seenVocabularyIds[$vocabularyId])) {
            throw new InvalidArgumentException('Quiz chứa từ vựng bị lặp.');
        }
        $seenVocabularyIds[$vocabularyId] = true;
        $validatedAnswers[] = [
            'vocabularyId' => $vocabularyId,
            'selectedAnswer' => $selectedAnswer,
            'responseTimeMs' => isset($answer['responseTimeMs']) ? max(0, (int) $answer['responseTimeMs']) : null,
        ];
    }
    $answersJson = json_encode($validatedAnswers, JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE);
    $sourceIdForDb = $source === 'review' ? null : $sourceId;
    $rows = dbCallProcedure(
        $link,
        'CALL sp_submit_quiz(?, ?, ?, ?, ?, ?, ?)',
        'isisssi',
        [$userId, $source, $sourceIdForDb, $mode, $itemLimit, $answersJson, $duration]
    );
    $result = $rows[0] ?? [];
    $quizResultId = (int) ($result['quiz_result_id'] ?? 0);
    $correctCount = (int) ($result['correct_count'] ?? 0);
    $total = (int) ($result['total_questions'] ?? 0);

    if ($quizResultId <= 0 || $total !== count($validatedAnswers)) {
        throw new RuntimeException('Stored Procedure không trả về kết quả Quiz hợp lệ.');
    }

    // Chỉ phản hồi thành công sau khi đọc lại được bản ghi đã commit.
    $savedRows = dbSelectView(
        $link,
        'SELECT id, total_questions, correct_answers, finished_at FROM quiz_results WHERE id = ? AND user_id = ? LIMIT 1',
        'ii',
        [$quizResultId, $userId]
    );
    $savedResult = $savedRows[0] ?? null;
    if (!$savedResult
        || (int) $savedResult['total_questions'] !== $total
        || (int) $savedResult['correct_answers'] !== $correctCount
        || empty($savedResult['finished_at'])) {
        throw new RuntimeException('Không thể xác nhận kết quả Quiz sau khi lưu.');
    }

    $responsePayload = [
        'success' => true,
        'quizResultId' => $quizResultId,
        'correctCount' => $correctCount,
        'totalQuestions' => $total,
        'isPerfect' => $correctCount === $total,
        'recordedAt' => $savedResult['finished_at'],
    ];
    $_SESSION['C_quiz_submissions'][$submissionToken]['status'] = 'completed';
    $_SESSION['C_quiz_submissions'][$submissionToken]['response'] = $responsePayload;
    echo json_encode($responsePayload);
} catch (Throwable $error) {
    error_log('Lỗi lưu Quiz: ' . $error->getMessage());
    http_response_code($error instanceof InvalidArgumentException ? 422 : 500);
    echo json_encode(['success' => false, 'message' => 'Không thể lưu kết quả Quiz.']);
}
