<?php
// MỚI - phương thức phù hợp và tránh được vài trường hợp có thể cải thiện thêm !!!
require_once($_SERVER['DOCUMENT_ROOT'] . "/Connect.php");
require_once($_SERVER['DOCUMENT_ROOT'] . "/includes/database_objects.php");

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

$loi = "";
$thanhCong = "";

// Nhận diện thông báo từ đăng ký hoặc đổi mật khẩu
if (isset($_GET['register']) && $_GET['register'] === 'success') {
	$thanhCong = "Đăng ký tài khoản thành công! Vui lòng đăng nhập.";
} elseif (isset($_GET['reset']) && $_GET['reset'] === 'success') {
	$thanhCong = "Đặt lại mật khẩu thành công! Hãy đăng nhập với mật khẩu mới.";
} elseif (isset($_GET['reason']) && $_GET['reason'] === 'account_inactive') {
	// Guard chuyển về đây khi admin đã khóa tài khoản trong lúc user còn đăng nhập.
	$loi = "Tài khoản đã bị khóa hoặc phiên đăng nhập không còn hợp lệ.";
}

if ($_SERVER['REQUEST_METHOD'] == 'POST') 
{
	$email    = trim($_POST['A_DangNhap_Email'] ?? '');
	$password = $_POST['A_DangNhap_password'] ?? '';

	if (empty($email) || empty($password)) 
	{
		$loi = "Vui lòng nhập đầy đủ email và mật khẩu.";
	} else {
		$accounts = dbCallProcedure($link, 'CALL sp_auth_get_account_by_email(?)', 's', [strtolower($email)]);
		$row = $accounts[0] ?? null;

		// This public form authenticates learners only. Administrators must use
		// the separate admin-login endpoint so their session has admin scope.
		if (!$row || $row['status'] !== 'active' || $row['role'] !== 'user')
		{
			$loi = "Email hoặc mật khẩu không chính xác.";
		} else 
		{
			if (!password_verify($password, $row['password_hash'])) {
				$loi = "Email hoặc mật khẩu không chính xác.";
			} else {
				// Tạo session mới sau khi đăng nhập thành công
				session_regenerate_id(true);

				$_SESSION['user_id']   = (int) $row['userID'];
				$_SESSION['full_name'] = $row['full_name'];
				$_SESSION['email']     = $row['email'];
				$_SESSION['avatar_url'] = $row['avatar_url'] ?? '';
				$_SESSION['user_profile_ngay_sinh'] = $row['date_of_birth'] ?? '2002-05-15';
				$_SESSION['user_profile_trinh_do'] = $row['target_level'] ?? 'Trung cấp (B1)';
				$_SESSION['role']      = $row['role'];
				$_SESSION['auth_scope'] = 'user';

				// Chuyển đến Dashboard theo quyền
				if ($row['role'] === 'admin') {
					header("Location: ../admin/D_Dashboard_admin.php?login=success");
				} else {
					header("Location: ../user/C_Dashboard_user.php?login=success");
				}
				exit();
			}
		}

		mysqli_close($link);
	}
}
?>
<!DOCTYPE html>
<html lang="vi">

<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>Đăng nhập - <?= htmlspecialchars($sysSiteName ?? 'LexiLoop') ?></title>
	<link rel="preconnect" href="https://fonts.googleapis.com">
	<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
	<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet">
	<link rel="stylesheet" type="text/css" href="/CSS/Style.css">
	<link rel="stylesheet" type="text/css" href="/CSS/A_DangNhap.css">
	<script src="/JS/jquery-4.0.0.min.js"></script>
</head>

<body class="login-body">
	<div class="login-wrapper">
		<div class="login-card">
			<!-- Header / Brand -->
			<div class="login-header">
				<a href="/pages/main/B_homepage.html" class="login-logo">
					<?php if (!empty($sysSiteLogo)): ?>
						<img src="<?= htmlspecialchars($sysSiteLogo) ?>" alt="Logo" style="height: 32px; object-fit: contain; max-width: 40px; margin-right: 8px;">
					<?php else: ?>
						<span class="login-logo-icon">🌿</span>
					<?php endif; ?>
					<span class="login-logo-text"><?= htmlspecialchars($sysSiteName ?? 'LexiLoop') ?></span>
				</a>
				<h1 class="login-title">Chào mừng trở lại!</h1>
				<p class="login-subtitle">Đăng nhập để tiếp tục hành trình học từ vựng mỗi ngày</p>
			</div>

			<!-- Thông báo thành công -->
			<?php if (!empty($thanhCong)) { ?>
				<div class="login-alert login-alert-success" role="status">
					<svg class="login-alert-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
						<polyline points="22 4 12 14.01 9 11.01"></polyline>
					</svg>
					<span><?php echo htmlspecialchars($thanhCong); ?></span>
				</div>
			<?php } ?>

			<!-- Thông báo lỗi -->
			<?php if (!empty($loi)) { ?>
				<div class="login-alert login-alert-error" role="alert">
					<svg class="login-alert-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<circle cx="12" cy="12" r="10"></circle>
						<line x1="12" y1="8" x2="12" y2="12"></line>
						<line x1="12" y1="16" x2="12.01" y2="16"></line>
					</svg>
					<span><?php echo htmlspecialchars($loi); ?></span>
				</div>
			<?php } ?>

			<!-- Form đăng nhập -->
			<form method="POST" action="" class="login-form" autocomplete="on">
				<!-- Email input group -->
				<div class="form-group">
					<label for="A_DangNhap_Email" class="form-label">Email</label>
					<div class="input-wrapper">
						<svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"></path>
							<polyline points="22,6 12,13 2,6"></polyline>
						</svg>
						<input 
							type="email" 
							id="A_DangNhap_Email" 
							name="A_DangNhap_Email" 
							class="form-input" 
							placeholder="name@example.com" 
							value="<?php echo htmlspecialchars($_POST['A_DangNhap_Email'] ?? ''); ?>"
							required
							autocomplete="email"
						>
					</div>
				</div>

				<!-- Password input group -->
				<div class="form-group">
					<div class="form-label-row">
						<label for="A_DangNhap_password" class="form-label">Mật khẩu</label>
						<a href="A_QuenMatKhau.php" class="forgot-link">Quên mật khẩu?</a>
					</div>
					<div class="input-wrapper">
						<svg class="input-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
							<rect x="3" y="11" width="18" height="11" rx="2" ry="2"></rect>
							<path d="M7 11V7a5 5 0 0 1 10 0v4"></path>
						</svg>
						<input 
							type="password" 
							id="A_DangNhap_password" 
							name="A_DangNhap_password" 
							class="form-input" 
							placeholder="Nhập mật khẩu của bạn" 
							required
							autocomplete="current-password"
						>
						<button type="button" class="toggle-password-btn" id="togglePasswordBtn" aria-label="Ẩn hoặc hiện mật khẩu" tabindex="-1">
							<svg class="eye-icon eye-show" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>
								<circle cx="12" cy="12" r="3"></circle>
							</svg>
							<svg class="eye-icon eye-hide" style="display:none;" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
								<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>
								<line x1="1" y1="1" x2="23" y2="23"></line>
							</svg>
						</button>
					</div>
				</div>

				<!-- Nút submit đăng nhập -->
				<button type="submit" name="DangNhap_btn" id="DangNhap_btn" class="login-submit-btn">
					<span>Đăng nhập</span>
					<svg class="btn-arrow" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="5" y1="12" x2="19" y2="12"></line>
						<polyline points="12 5 19 12 12 19"></polyline>
					</svg>
				</button>
			</form>

			<!-- Phân cách -->
			<div class="login-divider">
				<span>hoặc</span>
			</div>

			<!-- Nút tạo tài khoản mới -->
			<a href="A_DangKy.php" class="login-register-btn" id="A_DangNhap_TaoTaiKhoan">
				Tạo tài khoản mới
			</a>

			<!-- Footer điều hướng -->
			<div class="login-footer">
				<a href="/pages/main/B_homepage.html" class="back-home-link">
					<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
						<line x1="19" y1="12" x2="5" y2="12"></line>
						<polyline points="12 19 5 12 12 5"></polyline>
					</svg>
					<span>Quay về trang chủ</span>
				</a>
			</div>
		</div>
	</div>

	<script>
		$(document).ready(function () {
			// Nút ẩn / hiện mật khẩu
			$('#togglePasswordBtn').on('click', function () {
				const passInput = $('#A_DangNhap_password');
				const isPassword = passInput.attr('type') === 'password';
				passInput.attr('type', isPassword ? 'text' : 'password');
				$(this).find('.eye-show').toggle(!isPassword);
				$(this).find('.eye-hide').toggle(isPassword);
			});
		});
	</script>
</body>

</html>
