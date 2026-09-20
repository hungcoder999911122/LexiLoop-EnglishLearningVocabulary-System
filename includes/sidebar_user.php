<?php
/*
|--------------------------------------------------------------------------
| Xác định trang hiện tại
|--------------------------------------------------------------------------
| basename($_SERVER['PHP_SELF']) trả về tên file đang chạy.
| Ví dụ: C_Lichsuontap.php
*/
$currentPage = $sidebarActivePage ?? basename($_SERVER['PHP_SELF']);

/*
|--------------------------------------------------------------------------
| Hàm kiểm tra menu có đang active hay không
|--------------------------------------------------------------------------
| Giúp tránh lặp lại điều kiện PHP dài trên mỗi thẻ <a>.
*/
if (!function_exists('isSidebarActive')) {
    function isSidebarActive(string $pageName, string $currentPage): string
    {
        return $pageName === $currentPage ? 'active' : '';
    }
}
?>

<!-- Sidebar dành cho người dùng đã đăng nhập -->
<aside class="sidebar">

    <!-- Logo: dùng đường dẫn tương đối phù hợp cho pages/main và pages/user -->
    <a href="../user/C_Dashboard_user.php" class="sidebar-logo">
        <?php if (!empty($sysSiteLogo)): ?>
            <img src="<?= htmlspecialchars($sysSiteLogo) ?>" alt="Logo" style="height: 32px; object-fit: contain; max-width: 40px;">
        <?php else: ?>
            <span class="logo-badge" aria-hidden="true">🌿</span>
        <?php endif; ?>
        <span><?= htmlspecialchars($sysSiteName) ?></span>
    </a>

    <!-- Điều hướng chính -->
    <nav class="sidebar-nav" aria-label="Điều hướng người dùng">

        <a
            href="../user/C_Dashboard_user.php"
            class="sidebar-link <?= isSidebarActive('C_Dashboard_user.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">


                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-house">
                    <path d="M15 21v-8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v8" />
                    <path d="M3 10a2 2 0 0 1 .709-1.528l7-6a2 2 0 0 1 2.582 0l7 6A2 2 0 0 1 21 10v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" />
                </svg>

            </span>
            <span> Trang chủ </span>
        </a>

        <a
            href="../main/B_DanhSachChuDe.php"
            class="sidebar-link <?= isSidebarActive('B_DanhSachChuDe.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">

                <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" stroke-width="2"
                    stroke-linecap="round" stroke-linejoin="round">
                    <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"></path>
                    <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"></path>
                </svg>

            </span>
            <span>Chủ đề</span>
        </a>

        <a
            href="../user/C_Botuvung.php"
            class="sidebar-link <?= isSidebarActive('C_Botuvung.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">

                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-folder-heart">
                    <path d="M10.638 20H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h3.9a2 2 0 0 1 1.69.9l.81 1.2a2 2 0 0 0 1.67.9H20a2 2 0 0 1 2 2v3.417" />
                    <path d="M14.62 18.8A2.25 2.25 0 1 1 18 15.836a2.25 2.25 0 1 1 3.38 2.966l-2.626 2.856a.998.998 0 0 1-1.507 0z" />
                </svg>

            </span>
            <span>Bộ từ vựng</span>
        </a>



        <a
            href="../user/C_Tuvungcuatoi.php"
            class="sidebar-link <?= isSidebarActive('C_Tuvungcuatoi.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">

                <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" stroke-width="2"
                    stroke-linecap="round" stroke-linejoin="round">
                    <line x1="8" y1="6" x2="21" y2="6"></line>
                    <line x1="8" y1="12" x2="21" y2="12"></line>
                    <line x1="8" y1="18" x2="21" y2="18"></line>
                    <line x1="3" y1="6" x2="3.01" y2="6"></line>
                    <line x1="3" y1="12" x2="3.01" y2="12"></line>
                    <line x1="3" y1="18" x2="3.01" y2="18"></line>
                </svg>

            </span>
            <span> Từ vựng </span>
        </a>

        <a
            href="../user/C_Gocrenluyen.php"
            class="sidebar-link <?= isSidebarActive('C_Gocrenluyen.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">

                <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="lucide lucide-play">
                    <path d="M5 5a2 2 0 0 1 3.008-1.728l11.997 6.998a2 2 0 0 1 .003 3.458l-12 7A2 2 0 0 1 5 19z" />
                </svg>

            </span>
            <span> Góc rèn luyện </span>
        </a>


        <a
            href="../user/C_Lichsuontap.php"
            class="sidebar-link <?= isSidebarActive('C_Lichsuontap.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">

                <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" stroke-width="2"
                    stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="10"></circle>
                    <polyline points="12 6 12 12 16 14"></polyline>
                </svg>

            </span>
            <span>Lịch sử ôn tập</span>
        </a>

    </nav>

    <!-- Hành động phụ đặt cuối sidebar -->
    <div class="sidebar-bottom">
        <a
            href="../auth/A_Caidattaikhoan.php"
            class="sidebar-link <?= isSidebarActive('A_Caidattaikhoan.php', $currentPage) ?>">
            <span class="sidebar-icon" aria-hidden="true">
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" stroke-width="2"
                    stroke-linecap="round" stroke-linejoin="round">
                    <circle cx="12" cy="12" r="3"></circle>
                    <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"></path>
                </svg>
            </span>
            <span>Cài đặt</span>
        </a>

        <a href="../auth/A_DangXuat.php" class="sidebar-link sidebar-logout" data-action="logout">
            <span class="sidebar-icon" aria-hidden="true">

                <svg width="20" height="20" viewBox="0 0 24 24" fill="none"
                    stroke="currentColor" stroke-width="2"
                    stroke-linecap="round" stroke-linejoin="round">
                    <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"></path>
                    <polyline points="16 17 21 12 16 7"></polyline>
                    <line x1="21" y1="12" x2="9" y2="12"></line>
                </svg>

            </span>
            <span>Đăng xuất</span>
        </a>
    </div>
</aside>
