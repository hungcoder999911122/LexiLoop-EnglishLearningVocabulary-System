<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

/**
 * Hủy phiên khi tài khoản không còn được phép sử dụng hệ thống.
 *
 * Session chỉ là thông tin đăng nhập đã được tạo từ trước; nó không tự cập nhật
 * khi admin khóa tài khoản trong bảng Users. Vì vậy cần xóa session này ngay.
 */
function destroyInvalidUserSession(): void
{
    $_SESSION = [];

    if (session_status() === PHP_SESSION_ACTIVE) {
        session_destroy();
    }
}

/**
 * Trả phản hồi phù hợp cho trang HTML hoặc API rồi dừng request.
 */
function denyInvalidUserSession(): never
{
    global $authGuardResponseType;

    destroyInvalidUserSession();

    if (($authGuardResponseType ?? 'html') === 'json') {
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'message' => 'Tài khoản đã bị khóa hoặc phiên đăng nhập không còn hợp lệ.',
        ], JSON_UNESCAPED_UNICODE);
        exit;
    }

    header('Location: /pages/auth/A_DangNhap.php?reason=account_inactive');
    exit;
}

// Bắt buộc phải là user. Nếu là admin (auth_scope = admin), chuyển hướng về trang dashboard admin.
if (!isset($_SESSION['user_id']) || ($_SESSION['auth_scope'] ?? '') !== 'user') {
    if (isset($_SESSION['auth_scope']) && $_SESSION['auth_scope'] === 'admin') {
        header('Location: ../admin/D_Dashboard_admin.php');
    } else {
        denyInvalidUserSession();
    }
    exit;
}

require_once dirname(__DIR__) . '/Connect.php';

// Kiểm tra lại quyền và trạng thái từ database ở MỖI request. Đây là bước
// giúp việc khóa tài khoản có hiệu lực ngay cả khi user chưa tự đăng xuất.
$userId = (int) $_SESSION['user_id'];
$requiredRole = 'user';
$requiredStatus = 'active';
try {
    $statement = mysqli_prepare(
        $link,
        'SELECT 1 FROM Users WHERE userID = ? AND role = ? AND status = ? LIMIT 1'
    );
    mysqli_stmt_bind_param($statement, 'iss', $userId, $requiredRole, $requiredStatus);
    mysqli_stmt_execute($statement);
    $result = mysqli_stmt_get_result($statement);
    $isActiveUser = $result instanceof mysqli_result && mysqli_num_rows($result) === 1;
    if ($result instanceof mysqli_result) {
        mysqli_free_result($result);
    }
    mysqli_stmt_close($statement);
} catch (Throwable $error) {
    error_log('User session validation failed: ' . $error->getMessage());
    $isActiveUser = false;
}

if (!$isActiveUser) {
    denyInvalidUserSession();
}
