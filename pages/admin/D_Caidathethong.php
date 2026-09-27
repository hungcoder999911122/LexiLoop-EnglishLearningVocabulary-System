<?php
require_once dirname(__DIR__, 2) . '/includes/admin_guard.php';

// Khai báo rõ kết nối dùng chung trước khi gọi View/Stored Procedure.
$link = getDatabaseConnection();

$thongBao = '';
$loaiThongBao = '';

if (empty($_SESSION['admin_settings_csrf'])) {
    $_SESSION['admin_settings_csrf'] = bin2hex(random_bytes(32));
}
$settingsCsrfToken = $_SESSION['admin_settings_csrf'];

$cacTruongWeb = ['site_name', 'site_slogan', 'site_language', 'maintenance_mode'];
// Cấu hình học tập (đã bỏ xp_per_quiz)
$cacTruongHocTap = ['quiz_default_questions', 'daily_word_limit', 'spaced_repetition_intervals'];

try {
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $submittedCsrf = (string) ($_POST['csrf_token'] ?? '');
        if (!hash_equals($settingsCsrfToken, $submittedCsrf)) {
            throw new RuntimeException('Phiên thao tác không hợp lệ. Vui lòng tải lại trang.');
        }

        $action = (string) ($_POST['hanhdong'] ?? '');
        
        $fields = [];
        if ($action === 'luu_web') {
            $fields = $cacTruongWeb;
            if (trim((string) ($_POST['site_name'] ?? '')) === '') {
                throw new RuntimeException('Vui lòng nhập tên website.');
            }
            
            // Xử lý upload ảnh logo
            if (isset($_FILES['site_logo']) && $_FILES['site_logo']['error'] === UPLOAD_ERR_OK) {
                $uploadDir = dirname(__DIR__, 2) . '/assets/images/';
                if (!is_dir($uploadDir)) {
                    mkdir($uploadDir, 0777, true);
                }
                $fileInfo = pathinfo($_FILES['site_logo']['name']);
                $ext = strtolower($fileInfo['extension']);
                if (in_array($ext, ['jpg', 'jpeg', 'png', 'gif', 'svg'])) {
                    $newFileName = 'logo.' . $ext;
                    $targetPath = $uploadDir . $newFileName;
                    if (move_uploaded_file($_FILES['site_logo']['tmp_name'], $targetPath)) {
                        dbCallProcedure($link, 'CALL sp_save_system_setting(?, ?, ?)', 'iss', [$adminUserId, 'site_logo', '/assets/images/' . $newFileName]);
                    }
                }
            }
        }
        if ($action === 'luu_hoctap') {
            $fields = $cacTruongHocTap;
        }

        if (!empty($fields)) {
            foreach ($fields as $key) {
                // Xử lý Checkbox
                if ($key === 'maintenance_mode') {
                    $value = isset($_POST[$key]) ? '1' : '0';
                } else {
                    $value = trim((string) ($_POST[$key] ?? ''));
                }
                
                // Gọi Stored Procedure để lưu cấu hình
                dbCallProcedure($link, 'CALL sp_save_system_setting(?, ?, ?)', 'iss', [$adminUserId, $key, $value]);
            }
            $thongBao = 'Lưu cấu hình hệ thống thành công.';
            $loaiThongBao = 'thanhcong';
        }
    }
} catch (Throwable $error) {
    error_log('Admin settings error: ' . $error->getMessage());
    $thongBao = $error instanceof RuntimeException ? $error->getMessage() : 'Không thể lưu cấu hình lúc này.';
    $loaiThongBao = 'loi';
}

$caiDat = [];
// Sử dụng View để lấy dữ liệu
foreach (dbSelectView($link, 'SELECT setting_key, setting_value FROM vw_system_settings') as $row) {
    $caiDat[$row['setting_key']] = $row['setting_value'];
}

function layGiaTri($caiDat, $key, $macDinh = '') {
    return htmlspecialchars($caiDat[$key] ?? $macDinh);
}
?>
<!doctype html>
<html lang="vi">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>LexiLoop Admin - Cài đặt hệ thống</title>
    <link rel="preconnect" href="https://fonts.googleapis.com" />
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
    <link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700;800&display=swap" rel="stylesheet" />
    <link rel="stylesheet" type="text/css" href="/CSS/D_Caidathethong.css" />
    <script src="/JS/jquery-4.0.0.min.js"></script>
    <link rel="stylesheet" href="/CSS/admin-sidebar.css" />
  </head>

  <body>
    <div class="D_Caidathethong_Wrapper">
      <!-- Topbar Header -->
      <header class="D_Caidathethong_Topbar">
        <div class="D_Caidathethong_Logo">
          <span class="logo-emoji">🌿</span>
          <span class="logo-text">LexiLoop <span class="badge-admin">Admin</span></span>
        </div>
        <div class="D_Caidathethong_TopbarPhai">
          <div class="D_Caidathethong_UserMenu">
            <div class="D_Caidathethong_Avatar"><?php echo strtoupper(substr($_SESSION['full_name'] ?? 'AD', 0, 2)); ?></div>
            <span class="admin-name"><?php echo htmlspecialchars($_SESSION['full_name'] ?? 'Admin'); ?></span>
          </div>
        </div>
      </header>

      <div class="D_Caidathethong_Body">
        <!-- Sidebar Navigation -->
        <nav class="D_Caidathethong_Sidebar admin-sidebar" aria-label="Điều hướng quản trị">
          <div class="sidebar-section-title">QUẢN TRỊ HỆ THỐNG</div>
          <a href="D_Dashboard_admin.php" class="D_Caidathethong_MucMenu">
            <span class="menu-icon">📊</span>
            <span>Dashboard</span>
          </a>
          <a href="D_Quanlynguoidung.php" class="D_Caidathethong_MucMenu">
            <span class="menu-icon">👥</span>
            <span>Người dùng</span>
          </a>
          <a href="D_Quanlychude.php" class="D_Caidathethong_MucMenu">
            <span class="menu-icon">📚</span>
            <span>Chủ đề & Bộ từ</span>
          </a>
          <a href="D_Quanlytuvung.php" class="D_Caidathethong_MucMenu">
            <span class="menu-icon">🔤</span>
            <span>Từ vựng</span>
          </a>
          <a href="D_Caidathethong.php" class="D_Caidathethong_MucMenu D_Caidathethong_DangChon">
            <span class="menu-icon">⚙️</span>
            <span>Cài đặt</span>
          </a>
          <hr class="D_Caidathethong_GachNgang" />
          <a href="../auth/A_DangXuat.php" class="D_Caidathethong_MucMenu D_Caidathethong_DangXuat">
            <span class="menu-icon">🚪</span>
            <span>Đăng xuất</span>
          </a>
        </nav>

        <!-- Main Content -->
        <main class="D_Caidathethong_NoiDung">
          <div class="D_Caidathethong_HangTieuDe">
            <div>
              <h1 class="D_Caidathethong_TieuDe">Cài đặt hệ thống</h1>
              <p class="D_Caidathethong_MoTaTrang">Quản lý cấu hình dịch vụ, tham số học tập và giám sát hệ thống</p>
            </div>
          </div>

          <?php if ($thongBao !== ""): ?>
            <div class="D_Caidathethong_ThongBao D_Caidathethong_ThongBao_<?php echo $loaiThongBao; ?>">
              <?php if ($loaiThongBao === 'thanhcong'): ?>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path><polyline points="22 4 12 14.01 9 11.01"></polyline></svg>
              <?php else: ?>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"></circle><line x1="12" y1="8" x2="12" y2="12"></line><line x1="12" y1="16" x2="12.01" y2="16"></line></svg>
              <?php endif; ?>
              <span><?php echo htmlspecialchars($thongBao); ?></span>
            </div>
          <?php endif; ?>

          <!-- Tabs Navigation -->
          <div class="admin-tabs-nav">
            <button class="admin-tab-btn active" data-tab="chung">🌐 Chung</button>
            <button class="admin-tab-btn" data-tab="hoctap">🧠 Cấu hình Học tập</button>
          </div>

          <div class="admin-tabs-container">
            <!-- TAB 1: Cấu hình Website -->
            <div class="tab-content active" id="tab-chung">
              <form class="D_Caidathethong_Panel" method="post" action="D_Caidathethong.php#chung" enctype="multipart/form-data">
                <div class="panel-header">
                  <div>
                    <h2 class="D_Caidathethong_TieuDePanel">Cấu hình chung Website</h2>
                    <p class="panel-subtitle">Thông tin thương hiệu và chế độ vận hành website</p>
                  </div>
                </div>
                <input type="hidden" name="hanhdong" value="luu_web" />
                <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($settingsCsrfToken, ENT_QUOTES, 'UTF-8'); ?>" />
                
                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Tên website <span class="required">*</span></label>
                  <input type="text" name="site_name" class="D_Caidathethong_ONhap" value="<?php echo layGiaTri($caiDat, 'site_name', 'LexiLoop'); ?>" required />
                </div>
                
                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Slogan</label>
                  <input type="text" name="site_slogan" class="D_Caidathethong_ONhap" placeholder="Nền tảng học từ vựng thông minh..." value="<?php echo layGiaTri($caiDat, 'site_slogan', ''); ?>" />
                </div>

                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Logo</label>
                  <div class="D_Caidathethong_LogoUploadWrapper">
                    <div class="D_Caidathethong_LogoPreviewBox" id="D_Caidathethong_LogoPreview">
                      <?php $currentLogo = layGiaTri($caiDat, 'site_logo', ''); ?>
                      <?php if($currentLogo): ?>
                        <img src="<?php echo $currentLogo; ?>" alt="Site Logo">
                      <?php else: ?>
                        <span>Tải ảnh lên</span>
                      <?php endif; ?>
                    </div>
                    <label class="D_Caidathethong_NutTrang" style="display: inline-block; cursor: pointer;">
                      Chọn file
                      <input type="file" name="site_logo" id="site_logo_input" accept="image/*" style="display: none;" />
                    </label>
                  </div>
                </div>

                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Ngôn ngữ mặc định</label>
                  <select name="site_language" class="D_Caidathethong_ONhap">
                    <option value="vi" <?php echo layGiaTri($caiDat, 'site_language', 'vi') === 'vi' ? 'selected' : ''; ?>>Tiếng Việt</option>
                    <option value="en" <?php echo layGiaTri($caiDat, 'site_language', 'vi') === 'en' ? 'selected' : ''; ?>>Tiếng Anh</option>
                  </select>
                </div>
                
                <div class="form-group-checkbox warning-box">
                  <label class="D_Caidathethong_OCheckbox">
                    <input type="checkbox" id="D_Caidathethong_BatBaoTri" name="maintenance_mode" <?php echo (($caiDat['maintenance_mode'] ?? '0') === '1') ? 'checked' : ''; ?> />
                    <span><strong>Bật chế độ bảo trì</strong></span>
                  </label>
                </div>
                
                <div class="D_Caidathethong_HangNut">
                  <button class="D_Caidathethong_NutChinh" type="submit">Lưu cấu hình</button>
                </div>
              </form>
            </div>

            <!-- TAB 2: Cấu hình Học tập -->
            <div class="tab-content" id="tab-hoctap">
              <form class="D_Caidathethong_Panel" method="post" action="D_Caidathethong.php#hoctap">
                <div class="panel-header">
                  <div>
                    <h2 class="D_Caidathethong_TieuDePanel">Luật và Tham số Học tập (Business Rules)</h2>
                    <p class="panel-subtitle">Cấu hình các thông số phục vụ cho thuật toán hiển thị từ vựng</p>
                  </div>
                </div>
                <input type="hidden" name="hanhdong" value="luu_hoctap" />
                <input type="hidden" name="csrf_token" value="<?php echo htmlspecialchars($settingsCsrfToken, ENT_QUOTES, 'UTF-8'); ?>" />
                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Số câu hỏi mặc định / 1 Quiz</label>
                  <input type="number" name="quiz_default_questions" class="D_Caidathethong_ONhap" placeholder="15" value="<?php echo layGiaTri($caiDat, 'quiz_default_questions', '15'); ?>" min="5" max="100" />
                </div>
                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Giới hạn số từ mới hàng ngày (Tránh Spam)</label>
                  <input type="number" name="daily_word_limit" class="D_Caidathethong_ONhap" placeholder="30" value="<?php echo layGiaTri($caiDat, 'daily_word_limit', '30'); ?>" min="1" />
                </div>
                <div class="form-group">
                  <label class="D_Caidathethong_Nhan">Mảng các mốc Spaced Repetition (Khoảng cách ngày)</label>
                  <input type="text" name="spaced_repetition_intervals" class="D_Caidathethong_ONhap" placeholder="1,3,7,21,30" value="<?php echo layGiaTri($caiDat, 'spaced_repetition_intervals', '1,3,7,21'); ?>" />
                  <p class="panel-subtitle" style="margin-top: 6px;">Các giá trị cách nhau bằng dấu phẩy. VD: 1,3,7 (Ôn lại sau 1 ngày, 3 ngày, 7 ngày).</p>
                </div>
                <div class="D_Caidathethong_HangNut">
                  <button class="D_Caidathethong_NutChinh" type="submit">Lưu cấu hình</button>
                </div>
              </form>
            </div>
          </div>
        </main>
      </div>
    </div>

    <script src="/JS/D_Caidathethong.js"></script>
  </body>
</html>
