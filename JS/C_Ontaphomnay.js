document.addEventListener("DOMContentLoaded", () => {
    const overview = document.getElementById("C_Ontaphomnay_overview");
    const topicButtons = [...document.querySelectorAll("[data-review-topic]")];
    const topicDetails = [...document.querySelectorAll("[data-topic-detail]")];
    const backButtons = [...document.querySelectorAll("[data-back-to-topics]")];

    function getTopicIdFromHash() {
        const match = window.location.hash.match(/^#topic-(\d+)$/);
        return match ? match[1] : null;
    }

    function showOverview({ focus = false } = {}) {
        if (!overview) return;

        overview.hidden = false;
        topicDetails.forEach((detail) => { detail.hidden = true; });
        if (focus) {
            overview.querySelector("h2")?.focus({ preventScroll: true });
            overview.scrollIntoView({ behavior: "smooth", block: "start" });
        }
    }

    function showTopicDetail(topicId, { focus = true } = {}) {
        const selectedDetail = topicDetails.find((detail) => detail.dataset.topicDetail === String(topicId));
        if (!overview || !selectedDetail) {
            showOverview();
            return false;
        }

        overview.hidden = true;
        topicDetails.forEach((detail) => { detail.hidden = detail !== selectedDetail; });

        if (focus) {
            selectedDetail.scrollIntoView({ behavior: "smooth", block: "start" });
            const title = selectedDetail.querySelector("h2");
            if (title) {
                title.tabIndex = -1;
                title.focus({ preventScroll: true });
            }
        }
        return true;
    }

    topicButtons.forEach((button) => {
        button.addEventListener("click", () => {
            const topicId = button.dataset.reviewTopic;
            if (!showTopicDetail(topicId)) return;
            window.history.pushState({ reviewTopic: topicId }, "", `#topic-${topicId}`);
        });
    });

    backButtons.forEach((button) => {
        button.addEventListener("click", () => {
            window.history.pushState({}, "", window.location.pathname + window.location.search);
            showOverview({ focus: true });
        });
    });

    window.addEventListener("popstate", () => {
        const topicId = getTopicIdFromHash();
        if (topicId) showTopicDetail(topicId, { focus: false });
        else showOverview();
    });

    const initialTopicId = getTopicIdFromHash();
    if (initialTopicId) showTopicDetail(initialTopicId, { focus: false });

    const configForm = document.getElementById("formSrsConfig");
    const configMessage = document.getElementById("srsConfigMessage");

    configForm?.addEventListener("submit", async (event) => {
        event.preventDefault();
        const saveButton = document.getElementById("btnSaveSrsConfig");
        const easeInput = document.getElementById("srs_base_ease");
        const intervalInput = document.getElementById("srs_min_interval");

        if (!easeInput || !intervalInput || !configMessage) return;

        const data = {
            srs_base_ease: Number.parseFloat(easeInput.value),
            srs_min_interval: Number.parseInt(intervalInput.value, 10),
        };

        if (!Number.isFinite(data.srs_base_ease) || data.srs_base_ease < 1.3 || data.srs_base_ease > 3) {
            configMessage.textContent = "Hệ số Ease phải nằm trong khoảng 1.3–3.0.";
            configMessage.className = "srs-message error";
            easeInput.focus();
            return;
        }
        if (!Number.isInteger(data.srs_min_interval) || data.srs_min_interval < 1 || data.srs_min_interval > 10) {
            configMessage.textContent = "Khoảng cách tối thiểu phải từ 1–10 ngày.";
            configMessage.className = "srs-message error";
            intervalInput.focus();
            return;
        }

        if (saveButton) saveButton.disabled = true;
        configMessage.textContent = "Đang lưu cấu hình…";
        configMessage.className = "srs-message";

        try {
            const response = await fetch("../api/save_srs_config.php", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify(data),
            });
            const result = await response.json();
            if (!response.ok || !result.success) {
                throw new Error(result.message || "Không thể lưu cấu hình SRS.");
            }
            configMessage.textContent = result.message || "Đã lưu cấu hình SRS.";
            configMessage.className = "srs-message success";
        } catch (error) {
            console.error("SRS config error:", error);
            configMessage.textContent = error.message || "Không thể kết nối máy chủ.";
            configMessage.className = "srs-message error";
        } finally {
            if (saveButton) saveButton.disabled = false;
        }
    });
});
