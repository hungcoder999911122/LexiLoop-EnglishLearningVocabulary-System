<?php
header('Content-Type: application/json; charset=utf-8');

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
if (!isset($_SESSION['user_id']) || ($_SESSION['auth_scope'] ?? '') !== 'user') {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Quyền truy cập bị từ chối hoặc phiên đã hết hạn.']);
    exit;
}

require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');
$userId = (int) $_SESSION['user_id'];
$payload = json_decode(file_get_contents('php://input'), true);

if (!is_array($payload)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Dữ liệu gửi lên không hợp lệ.']);
    exit;
}

$csrf = $payload['csrf'] ?? '';
if (!is_string($csrf) || empty($_SESSION['C_learning_csrf']) || !hash_equals($_SESSION['C_learning_csrf'], $csrf)) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'CSRF token không hợp lệ.']);
    exit;
}

$source = $payload['source'] ?? '';
$sourceId = filter_var($payload['sourceId'] ?? 0, FILTER_VALIDATE_INT) ?: 0;
$submissionToken = $payload['submissionToken'] ?? '';
$duration = max(0, min(86400, (int) ($payload['durationSeconds'] ?? 0)));
$isFinal = filter_var($payload['isFinal'] ?? true, FILTER_VALIDATE_BOOLEAN);
$statuses = is_array($payload['statuses'] ?? null) ? $payload['statuses'] : [];

if (!in_array($source, ['topic', 'set', 'review'], true)
    || ($source !== 'review' && $sourceId <= 0)
    || !is_string($submissionToken)
    || !preg_match('/^[a-f0-9]{64}$/', $submissionToken)
    || !$statuses) {
    http_response_code(422);
    echo json_encode(['success' => false, 'message' => 'Nguồn học hoặc tiến trình không hợp lệ.']);
    exit;
}

$submission = $_SESSION['C_flashcard_submissions'][$submissionToken] ?? null;
if (!is_array($submission)
    || ($submission['source'] ?? null) !== $source
    || (int) ($submission['sourceId'] ?? 0) !== $sourceId) {
    http_response_code(409);
    echo json_encode(['success' => false, 'message' => 'Phiên lưu Flashcard không hợp lệ hoặc đã hết hạn.']);
    exit;
}

if (($submission['status'] ?? '') === 'completed' && is_array($submission['response'] ?? null)) {
    echo json_encode($submission['response']);
    exit;
}

try {
    $validStatuses = [];
    foreach ($statuses as $vocabularyIdRaw => $answer) {
        $vocabularyId = filter_var($vocabularyIdRaw, FILTER_VALIDATE_INT) ?: 0;
        if ($vocabularyId <= 0 || !in_array($answer, ['da_nho', 'chua_nho'], true)) {
            throw new InvalidArgumentException('Trạng thái Flashcard không hợp lệ.');
        }
        $validStatuses[(string) $vocabularyId] = $answer;
    }

    $statusesJson = json_encode($validStatuses, JSON_THROW_ON_ERROR);
    $sourceIdForDb = $source === 'review' ? null : $sourceId;
    
    $rows = dbCallProcedure(
        $link,
        'CALL sp_save_flashcard_session(?, ?, ?, ?, ?, ?)',
        'isisii',
        [$userId, $source, $sourceIdForDb, $statusesJson, $duration, $isFinal ? 1 : 0]
    );
    $learningSessionId = (int) ($rows[0]['learning_session_id'] ?? 0);
    $savedWordCount = (int) ($rows[0]['word_count'] ?? 0);
    if (!$isFinal || $learningSessionId <= 0 || $savedWordCount !== count($validStatuses)) {
        throw new RuntimeException('Stored Procedure không trả về phiên Flashcard hợp lệ.');
    }

    $responsePayload = [
        'success' => true,
        'learningSessionId' => $learningSessionId,
        'wordCount' => $savedWordCount,
    ];
    $_SESSION['C_flashcard_submissions'][$submissionToken]['status'] = 'completed';
    $_SESSION['C_flashcard_submissions'][$submissionToken]['response'] = $responsePayload;
    echo json_encode($responsePayload);
} catch (Throwable $error) {
    error_log('Lỗi lưu Flashcard: ' . $error->getMessage());
    http_response_code($error instanceof InvalidArgumentException ? 422 : 500);
    echo json_encode(['success' => false, 'message' => 'Không thể lưu tiến trình Flashcard.']);
}
