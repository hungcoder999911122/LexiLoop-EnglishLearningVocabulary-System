<?php
header('Content-Type: application/json; charset=utf-8');

// Dùng cùng kiểm tra status với trang HTML, nhưng phản hồi JSON cho fetch/AJAX.
$authGuardResponseType = 'json';
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');

require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/database_objects.php');

$userId = (int) $_SESSION['user_id'];
$payload = json_decode(file_get_contents('php://input'), true);
if (!is_array($payload)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Dữ liệu phiên học không hợp lệ.']);
    exit;
}

$csrf = $payload['csrf'] ?? '';
if (!is_string($csrf) || empty($_SESSION['C_learning_csrf']) || !hash_equals($_SESSION['C_learning_csrf'], $csrf)) {
    http_response_code(403);
    echo json_encode(['success' => false, 'message' => 'CSRF token không hợp lệ.']);
    exit;
}

$action = $payload['action'] ?? '';
$activity = $payload['activity'] ?? '';
$source = $payload['source'] ?? '';
$sourceId = filter_var($payload['sourceId'] ?? 0, FILTER_VALIDATE_INT) ?: 0;
$itemLimit = (string) ($payload['limit'] ?? '10');
$state = $payload['state'] ?? null;

if (!in_array($action, ['load', 'save', 'complete', 'restart'], true)
    || !in_array($activity, ['flashcard', 'quiz'], true)
    || !in_array($source, ['topic', 'set', 'review'], true)
    || ($source !== 'review' && $sourceId <= 0)
    || !in_array($itemLimit, ['5', '10', '20', 'all'], true)) {
    http_response_code(422);
    echo json_encode(['success' => false, 'message' => 'Thông tin phiên học không hợp lệ.']);
    exit;
}

try {
    $sourceIdForDb = $source === 'review' ? null : $sourceId;
    if ($action === 'save' && !is_array($state)) {
        http_response_code(422);
        echo json_encode(['success' => false, 'message' => 'Trạng thái cần lưu không hợp lệ.']);
        exit;
    }
    $stateJson = $action === 'save'
        ? json_encode($state, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR)
        : null;
    if ($stateJson !== null && strlen($stateJson) > 1000000) {
        http_response_code(413);
        echo json_encode(['success' => false, 'message' => 'Dữ liệu phiên học vượt quá giới hạn.']);
        exit;
    }
    $rows = dbCallProcedure(
        $link,
        'CALL sp_manage_learning_attempt(?, ?, ?, ?, ?, ?, ?)',
        'isssiss',
        [$userId, $action, $activity, $source, $sourceIdForDb, $itemLimit, $stateJson]
    );
    $row = $rows[0] ?? null;
    if ($action === 'load') {
        echo json_encode([
            'success' => true,
            'attempt' => $row && isset($row['id']) ? [
                'id' => (int) $row['id'],
                'state' => json_decode($row['state_json'], true),
                'startedAt' => $row['started_at'],
                'updatedAt' => $row['updated_at'],
            ] : null,
        ]);
    } else {
        echo json_encode(['success' => true, 'attemptId' => isset($row['attempt_id']) ? (int) $row['attempt_id'] : null]);
    }
} catch (Throwable $error) {
    error_log('Lỗi phiên học: ' . $error->getMessage());
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Không thể lưu phiên học. Hãy chạy migration learning_attempts.']);
}
