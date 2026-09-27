<?php
header('Content-Type: application/json; charset=utf-8');

// Dùng cùng kiểm tra status với trang HTML, nhưng phản hồi JSON cho fetch/AJAX.
$authGuardResponseType = 'json';
require_once($_SERVER['DOCUMENT_ROOT'] . '/includes/auth_guard.php');
require_once($_SERVER['DOCUMENT_ROOT'] . '/Connect.php');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Phương thức không hợp lệ.']);
    exit;
}

$user_id = $_SESSION['user_id'] ?? null;
if (!$user_id) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Bạn chưa đăng nhập.']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
if (!$input) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Dữ liệu không hợp lệ.']);
    exit;
}

$srs_base_ease = isset($input['srs_base_ease']) ? (float) $input['srs_base_ease'] : 2.5;
$srs_min_interval = isset($input['srs_min_interval']) ? (int) $input['srs_min_interval'] : 1;

// Validate
if ($srs_base_ease < 1.3 || $srs_base_ease > 3.0) {
    echo json_encode(['success' => false, 'message' => 'Hệ số Ease phải từ 1.3 đến 3.0']);
    exit;
}
if ($srs_min_interval < 1 || $srs_min_interval > 10) {
    echo json_encode(['success' => false, 'message' => 'Khoảng cách tối thiểu phải từ 1 đến 10 ngày']);
    exit;
}

try {
    $stmt = $link->prepare("UPDATE Users SET srs_base_ease = ?, srs_min_interval = ? WHERE userID = ? AND status = 'active'");
    if (!$stmt) {
        throw new Exception("Lỗi prepare statement.");
    }
    
    $stmt->bind_param("dii", $srs_base_ease, $srs_min_interval, $user_id);
    if (!$stmt->execute()) {
        throw new Exception("Không thể cập nhật cấu hình.");
    }

    echo json_encode(['success' => true, 'message' => 'Đã lưu cấu hình thuật toán SRS.']);
} catch (Exception $e) {
    error_log("Lỗi lưu SRS config: " . $e->getMessage());
    echo json_encode(['success' => false, 'message' => 'Lỗi hệ thống: ' . $e->getMessage()]);
}
