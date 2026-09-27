<?php
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
require_once($_SERVER['DOCUMENT_ROOT'] . "/Connect.php");

// Khi bảo trì kết thúc, quay về request GET nội bộ đã bị chặn trước đó. Nếu
// không có đích an toàn (ví dụ request ban đầu là POST), quay về đăng nhập.
if (getSystemSetting($link, 'maintenance_mode') !== '1') {
    $returnUri = $_SESSION['maintenance_return_uri'] ?? '/pages/auth/A_DangNhap.php';
    unset($_SESSION['maintenance_return_uri']);

    if (!is_string($returnUri)
        || !str_starts_with($returnUri, '/')
        || str_starts_with($returnUri, '//')
        || str_contains($returnUri, "\r")
        || str_contains($returnUri, "\n")
        || str_contains($returnUri, '/pages/main/maintenance.php')
        || str_contains($returnUri, '/pages/admin/')
    ) {
        $returnUri = '/pages/auth/A_DangNhap.php';
    }

    header('Location: ' . $returnUri, true, 302);
    exit();
}

// Lấy thông tin cấu hình hiển thị
$siteName = getSystemSetting($link, 'site_name', 'LexiLoop');
$siteLogo = getSystemSetting($link, 'site_logo', '/assets/images/logo.png');
?>
<!DOCTYPE html>
<html lang="vi">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="refresh" content="10">
    <title>Bảo trì hệ thống - <?php echo htmlspecialchars($siteName); ?></title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background-color: #f8f9fa;
            color: #333;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
            text-align: center;
        }
        .maintenance-container {
            background-color: #fff;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            max-width: 500px;
            width: 90%;
        }
        .maintenance-logo {
            max-width: 150px;
            margin-bottom: 20px;
        }
        h1 {
            font-size: 24px;
            color: #e74c3c;
            margin-bottom: 10px;
        }
        p {
            font-size: 16px;
            line-height: 1.5;
            color: #555;
            margin-bottom: 20px;
        }
        .btn-admin {
            display: inline-block;
            padding: 10px 20px;
            background-color: #3498db;
            color: #fff;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
            transition: background-color 0.3s;
        }
        .btn-admin:hover {
            background-color: #2980b9;
        }
    </style>
</head>
<body>
    <div class="maintenance-container">
        <img src="<?php echo htmlspecialchars($siteLogo); ?>" alt="Logo" class="maintenance-logo">
        <h1>Hệ thống đang bảo trì</h1>
        <p>Xin lỗi vì sự bất tiện này. Chúng tôi đang thực hiện nâng cấp hệ thống và sẽ sớm quay lại. Vui lòng thử lại sau ít phút.</p>
        <p>Trang sẽ tự kiểm tra lại sau mỗi 10 giây và đưa bạn về trang trước đó khi hệ thống hoạt động trở lại.</p>
        <button type="button" class="btn-admin" onclick="window.location.reload()">Kiểm tra lại ngay</button>
    </div>
</body>
</html>
