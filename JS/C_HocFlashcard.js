document.addEventListener("DOMContentLoaded", () => {
    const cardBox = document.getElementById("C_HocFlashcard_cardBox");
    
    // Mặt trước
    const wordTextFront = document.getElementById("C_HocFlashcard_wordFront");
    const hintTextFront = document.getElementById("C_HocFlashcard_hintFront");
    const badgeRFront = document.getElementById("C_HocFlashcard_badgeR");
    const pronunciationAreaFront = document.getElementById("C_HocFlashcard_pronunciationAreaFront");
    const pronunciationTextFront = document.getElementById("C_HocFlashcard_pronunciationFront");
    const audioButtonFront = document.getElementById("C_HocFlashcard_audioButtonFront");

    // Mặt sau
    const wordTextBack = document.getElementById("C_HocFlashcard_wordBack");
    const hintTextBack = document.getElementById("C_HocFlashcard_hintBack");
    const badgeRBack = document.getElementById("C_HocFlashcard_badgeRBack");
    const pronunciationAreaBack = document.getElementById("C_HocFlashcard_pronunciationAreaBack");
    const pronunciationTextBack = document.getElementById("C_HocFlashcard_pronunciationBack");
    const audioButtonBack = document.getElementById("C_HocFlashcard_audioButtonBack");
    const partOfSpeechBack = document.getElementById("C_HocFlashcard_partOfSpeech");
    const exampleBack = document.getElementById("C_HocFlashcard_example");

    const audioPlayer = document.getElementById("C_HocFlashcard_audioPlayer");

    const progressText = document.getElementById(
        "C_HocFlashcard_progressText"
    );
    const progressFill = document.getElementById(
        "C_HocFlashcard_progressFill"
    );
    const statsText = document.getElementById(
        "C_HocFlashcard_stats"
    );

    const btnPrev = document.getElementById(
        "C_HocFlashcard_btnPrev"
    );
    const btnNext = document.getElementById(
        "C_HocFlashcard_btnNext"
    );
    const btnChuaNho = document.getElementById(
        "C_HocFlashcard_btnChuaNho"
    );
    const btnDaNho = document.getElementById(
        "C_HocFlashcard_btnDaNho"
    );
    const btnKetThuc = document.getElementById(
        "C_HocFlashcard_btnKetThuc"
    );
    const btnThoatHeader = document.getElementById(
        "C_HocFlashcard_btnThoatHeader"
    );

    /*
     * Không tạo dữ liệu giả khi database không trả về từ nào.
     * Dữ liệu giả có thể khiến người dùng tưởng rằng đang học
     * một từ thật thuộc chủ đề.
     */
    let cards = Array.isArray(flashcardsData)
        ? flashcardsData
        : [];

    const sessionConfig = flashcardSessionConfig || {
        topicId: 0,
        mode: "new_learning"
    };

    let currentIndex = 0;
    let isFlipped = false;
    let sessionStartedAt = Date.now();
    let previousDurationSeconds = 0;
    let isSaving = false;
    let isAssessing = false;
    let isCompleting = false;
    let hasCompletedSession = false;
    let checkpointQueue = Promise.resolve();

    /*
     * Lưu một trạng thái duy nhất cho mỗi từ:
     *
     * {
     *   15: "da_nho",
     *   16: "chua_nho"
     * }
     *
     * Nếu người dùng đổi ý, giá trị cũ bị thay thế chứ không
     * bị cộng thêm vào thống kê.
     */
    const cardStatuses = {};

    async function attemptRequest(action, state = null) {
        const response = await fetch("../api/learning_attempt.php", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                action,
                activity: "flashcard",
                csrf: sessionConfig.csrf,
                source: sessionConfig.source,
                sourceId: sessionConfig.sourceId,
                limit: sessionConfig.limit || "10",
                state
            })
        });
        const result = await response.json();
        if (!response.ok || !result.success) {
            throw new Error(result.message || "Không thể lưu phiên Flashcard.");
        }
        return result;
    }

    function getElapsedSeconds() {
        return previousDurationSeconds + Math.round((Date.now() - sessionStartedAt) / 1000);
    }

    function getAttemptState() {
        return {
            currentIndex,
            cardStatuses,
            cardIds: cards.map((card) => Number(card.id)),
            durationSeconds: getElapsedSeconds()
        };
    }

    function saveCheckpoint() {
        if (cards.length === 0) return true;
        const snapshot = JSON.parse(JSON.stringify(getAttemptState()));
        checkpointQueue = checkpointQueue
            .catch(() => undefined)
            .then(() => attemptRequest("save", snapshot));
        return checkpointQueue.then(() => true).catch((error) => {
            console.error(error);
            return false;
        });
    }

    function saveCheckpointOnExit() {
        if (cards.length === 0 || isCompleting) return;
        const payload = JSON.stringify({
            action: "save",
            activity: "flashcard",
            csrf: sessionConfig.csrf,
            source: sessionConfig.source,
            sourceId: sessionConfig.sourceId,
            limit: sessionConfig.limit || "10",
            state: getAttemptState()
        });
        navigator.sendBeacon("../api/learning_attempt.php", new Blob([payload], { type: "application/json" }));
    }

    async function restoreAttempt() {
        if (cards.length === 0) return;
        try {
            const result = await attemptRequest("load");
            const state = result.attempt?.state;
            if (state && Array.isArray(state.cardIds)) {
                const cardsById = new Map(cards.map((card) => [Number(card.id), card]));
                const restoredCards = state.cardIds.map((id) => cardsById.get(Number(id))).filter(Boolean);
                const restoredIds = new Set(restoredCards.map((card) => Number(card.id)));
                cards = restoredCards.concat(cards.filter((card) => !restoredIds.has(Number(card.id))));
                const validIds = new Set(cards.map((card) => String(card.id)));
                Object.entries(state.cardStatuses || {}).forEach(([id, status]) => {
                    if (validIds.has(String(id))) cardStatuses[id] = status;
                });
                currentIndex = Math.min(Math.max(0, Number(state.currentIndex) || 0), cards.length - 1);
                previousDurationSeconds = Math.max(0, Number(state.durationSeconds) || 0);
                sessionStartedAt = Date.now();
            } else {
                await saveCheckpoint();
            }
        } catch (error) {
            // Nếu migration chưa chạy, người dùng vẫn học được nhưng chưa thể resume.
            console.error(error);
        }
    }

    function getCurrentCard() {
        return cards[currentIndex];
    }

    function renderEmptyState() {
        wordTextFront.textContent = "Chủ đề này chưa có từ vựng";
        wordTextBack.textContent = "Chủ đề này chưa có từ vựng";
        hintTextFront.textContent = "Hãy quay lại và chọn chủ đề khác.";
        hintTextBack.textContent = "";

        pronunciationTextFront.textContent = "";
        pronunciationTextBack.textContent = "";
        audioButtonFront.hidden = true;
        audioButtonBack.hidden = true;

        progressText.textContent = "Thẻ 0/0";
        progressFill.style.width = "0%";

        btnPrev.disabled = true;
        btnNext.disabled = true;
        btnChuaNho.disabled = true;
        btnDaNho.disabled = true;
    }

    function renderPronunciation(card) {
        const pronunciation = card.phien_am?.trim();
        const displayPronunciation = pronunciation || "Chưa có phiên âm";

        pronunciationTextFront.textContent = displayPronunciation;
        pronunciationTextBack.textContent = displayPronunciation;

        const audioUrl = card.audio_url?.trim();
        if (audioUrl) {
            audioButtonFront.hidden = false;
            audioButtonBack.hidden = false;
            audioPlayer.src = audioUrl;
        } else {
            audioButtonFront.hidden = true;
            audioButtonBack.hidden = true;
            audioPlayer.removeAttribute("src");
        }
    }

    function renderAssessmentButtons(cardId) {
        const currentStatus = cardStatuses[cardId] || null;

        const isRemembered = currentStatus === "da_nho";
        const isNotRemembered = currentStatus === "chua_nho";

        btnDaNho.classList.toggle(
            "C_HocFlashcard_btnSelected",
            isRemembered
        );

        btnChuaNho.classList.toggle(
            "C_HocFlashcard_btnSelected",
            isNotRemembered
        );

        btnDaNho.setAttribute("aria-pressed", String(isRemembered));
        btnChuaNho.setAttribute("aria-pressed", String(isNotRemembered));
    }

    function renderCard() {
        if (cards.length === 0) {
            renderEmptyState();
            return;
        }

        const currentCard = getCurrentCard();

        isFlipped = false;
        cardBox.classList.remove("is-flipped");

        wordTextFront.textContent = currentCard.tu_vung;
        wordTextBack.textContent = currentCard.nghia;

        if (currentCard.loai_tu) {
            partOfSpeechBack.textContent = `(${currentCard.loai_tu})`;
            partOfSpeechBack.hidden = false;
        } else {
            partOfSpeechBack.hidden = true;
        }

        if (currentCard.vi_du) {
            exampleBack.textContent = `VD: ${currentCard.vi_du}`;
            exampleBack.hidden = false;
        } else {
            exampleBack.hidden = true;
        }

        progressText.textContent =
            `Thẻ ${currentIndex + 1}/${cards.length}`;

        badgeRFront.style.display = currentCard.is_review ? "flex" : "none";
        badgeRBack.style.display = currentCard.is_review ? "flex" : "none";

        renderPronunciation(currentCard);
        renderAssessmentButtons(currentCard.id);

        btnPrev.disabled = currentIndex === 0;
        btnNext.disabled = currentIndex === cards.length - 1;
        btnChuaNho.disabled = false;
        btnDaNho.disabled = false;

        renderStats();
    }

    function getStatistics() {
        let rememberedCount = 0;
        let notRememberedCount = 0;

        Object.values(cardStatuses).forEach((status) => {
            if (status === "da_nho") {
                rememberedCount++;
            }

            if (status === "chua_nho") {
                notRememberedCount++;
            }
        });

        return {
            rememberedCount,
            notRememberedCount,
            assessedCount: rememberedCount + notRememberedCount
        };
    }

    function renderStats() {
        const statistics = getStatistics();

        statsText.innerHTML = `
            Đã đánh giá: <strong>${statistics.assessedCount}</strong>
            &nbsp;&bull;&nbsp;
            Đã nhớ: <strong>${statistics.rememberedCount}</strong>
            &nbsp;&bull;&nbsp;
            Chưa nhớ: <strong>${statistics.notRememberedCount}</strong>
        `;

        const progressPercent = cards.length > 0
            ? (statistics.assessedCount / cards.length) * 100
            : 0;
        progressFill.style.width = `${progressPercent}%`;

        if (statistics.assessedCount === cards.length) {
            statsText.insertAdjacentText("beforeend", " • Đã đánh giá 100%");
        }
    }

    function setCardStatus(status) {
        const currentCard = getCurrentCard();

        if (!currentCard) {
            return;
        }

        /*
         * Gán đè trạng thái cũ. Đây là điểm giúp tránh việc
         * bấm nhiều lần dẫn đến thống kê sai.
         */
        cardStatuses[currentCard.id] = status;

        renderAssessmentButtons(currentCard.id);
        renderStats();
    }

    function moveToCard(nextIndex) {
        if (nextIndex < 0 || nextIndex >= cards.length) {
            return;
        }

        currentIndex = nextIndex;
        renderCard();
    }

    async function saveProgress(isFinal = true) {
        if (Object.keys(cardStatuses).length === 0) return true;
        if (isSaving) return false;
        isSaving = true;
        try {
            const response = await fetch("../api/save_flashcard_progress.php", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    csrf: sessionConfig.csrf,
                    source: sessionConfig.source,
                    sourceId: sessionConfig.sourceId,
                    submissionToken: sessionConfig.submissionToken,
                    durationSeconds: getElapsedSeconds(),
                    isFinal,
                    statuses: cardStatuses
                })
            });
            const result = await response.json();
            if (!response.ok || !result.success) throw new Error(result.message || "Không thể lưu tiến trình.");
            return true;
        } catch (error) {
            console.error("Lỗi saveProgress:", error);
            if (isFinal) {
                alert(error.message || "Không thể lưu tiến trình Flashcard.");
            }
            return false;
        } finally {
            isSaving = false;
        }
    }

    async function completeFlashcardIfFinished() {
        // SRS cần cả đánh giá "Đã nhớ" lẫn "Chưa nhớ". Phiên hoàn tất khi
        // mọi thẻ đã được đánh giá, không bắt người dùng phải nhớ 100%.
        if (hasCompletedSession || getStatistics().assessedCount !== cards.length) return;

        hasCompletedSession = true;
        isCompleting = true;
        await checkpointQueue.catch(console.error);
        const saved = await saveProgress(true);
        if (!saved) {
            hasCompletedSession = false;
            isCompleting = false;
            return;
        }
        await attemptRequest("complete").catch(console.error);
        btnDaNho.disabled = true;
        btnChuaNho.disabled = true;
        btnKetThuc.innerHTML = `
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
                <polyline points="20 6 9 17 4 12"></polyline>
            </svg>
            <span>Hoàn tất & Quay lại</span>
        `;
        btnKetThuc.classList.add("C_HocFlashcard_btnCompleted");
    }

    cardBox.addEventListener("click", () => {
        if (cards.length === 0) {
            return;
        }

        isFlipped = !isFlipped;
        cardBox.classList.toggle("is-flipped", isFlipped);
    });

    audioButtonFront.addEventListener("click", (e) => {
        e.stopPropagation();
        audioPlayer.currentTime = 0;
        audioPlayer.play().catch(() => {
            alert("Không thể phát audio của từ này.");
        });
    });

    audioButtonBack.addEventListener("click", (e) => {
        e.stopPropagation();
        audioPlayer.currentTime = 0;
        audioPlayer.play().catch(() => {
            alert("Không thể phát audio của từ này.");
        });
    });

    btnDaNho.addEventListener("click", async () => {
        if (isAssessing) return;
        isAssessing = true;
        try {
            setCardStatus("da_nho");
            // Đánh giá xong một thẻ thì chuyển ngay sang thẻ tiếp theo.
            if (currentIndex < cards.length - 1) moveToCard(currentIndex + 1);
            await saveCheckpoint();
            await completeFlashcardIfFinished();
        } finally {
            isAssessing = false;
        }
    });

    btnChuaNho.addEventListener("click", async () => {
        if (isAssessing) return;
        isAssessing = true;
        try {
            setCardStatus("chua_nho");
            if (currentIndex < cards.length - 1) moveToCard(currentIndex + 1);
            await saveCheckpoint();
            await completeFlashcardIfFinished();
        } finally {
            isAssessing = false;
        }
    });

    btnPrev.addEventListener("click", async () => {
        moveToCard(currentIndex - 1);
        await saveCheckpoint();
    });

    btnNext.addEventListener("click", async () => {
        moveToCard(currentIndex + 1);
        await saveCheckpoint();
    });

    async function exitSession(forcePrompt = false) {
        if (!hasCompletedSession || forcePrompt) {
            const shouldEnd = confirm(
                "Bạn có chắc chắn muốn thoát phiên học? Tiến trình các thẻ đã học sẽ được lưu lại."
            );
            if (!shouldEnd) return;

            // Thoát sớm chỉ lưu checkpoint. Tiến độ SRS được ghi đúng một lần
            // khi toàn bộ thẻ đã được đánh giá, tránh áp dụng lặp cùng đánh giá.
            const checkpointSaved = await saveCheckpoint();
            if (!checkpointSaved) {
                alert("Không thể lưu phiên Flashcard. Vui lòng thử lại trước khi thoát.");
                return;
            }
        }

        if (sessionConfig.source === "review") {
            window.location.href = "C_Ontaphomnay.php";
            return;
        }
        const sourceQuery = new URLSearchParams({
            source: sessionConfig.source || "topic",
            id: sessionConfig.sourceId || sessionConfig.topicId,
            limit: sessionConfig.limit || "10"
        });
        window.location.href = `C_Gocrenluyen.php?${sourceQuery.toString()}`;
    }

    if (btnThoatHeader) {
        btnThoatHeader.addEventListener("click", () => exitSession(true));
    }

    btnKetThuc.addEventListener("click", () => exitSession(false));

    window.addEventListener("pagehide", saveCheckpointOnExit);

    btnPrev.disabled = true;
    btnNext.disabled = true;
    btnChuaNho.disabled = true;
    btnDaNho.disabled = true;
    restoreAttempt().finally(renderCard);
});
