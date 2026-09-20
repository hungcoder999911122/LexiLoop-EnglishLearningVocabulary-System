document.addEventListener("DOMContentLoaded", () => {
    // 1. Lấy các phần tử DOM
    const progressText = document.getElementById("C_Quiz_progressText");
    const progressFill = document.getElementById("C_Quiz_progressFill");
    const timerCircle = document.getElementById("C_Quiz_timerCircle");
    const questionWord = document.getElementById("C_Quiz_questionWord");
    const optionsGrid = document.getElementById("C_Quiz_optionsGrid");
    const btnCauTruoc = document.getElementById("C_Quiz_btnCauTruoc");
    const btnCauTiep = document.getElementById("C_Quiz_btnCauTiep");
    const btnThoat = document.getElementById("C_Quiz_btnThoat");
    const bubblesRow = document.getElementById("C_Quiz_bubblesRow");

    // Dữ liệu từ PHP truyền sang
    let questions = (typeof quizQuestions !== "undefined" && Array.isArray(quizQuestions))
        ? quizQuestions
        : [];

    function returnToLearningPage() {
        if (quizSessionConfig.source === "review" || quizSessionConfig.mode === "review") {
            window.location.href = "C_Ontaphomnay.php";
            return;
        }
        const sourceQuery = new URLSearchParams({
            source: quizSessionConfig.source,
            id: quizSessionConfig.sourceId,
            limit: quizSessionConfig.limit || "10"
        });
        window.location.href = `C_Gocrenluyen.php?${sourceQuery.toString()}`;
    }

    // Không dùng câu hỏi giả khi database không có dữ liệu.
    if (questions.length === 0) {
        progressText.textContent = "Chưa có câu hỏi";
        questionWord.textContent = "Nguồn học chưa có dữ liệu phù hợp";
        optionsGrid.innerHTML = "";
        timerCircle.textContent = "--";
        btnCauTruoc.disabled = true;
        btnCauTiep.disabled = true;
        btnThoat.disabled = false;
        btnThoat.addEventListener("click", returnToLearningPage);
        return;
    }

    let currentIndex = 0;
    const userAnswers = {}; // Lưu đáp án người dùng chọn: { 0: 1, 1: 0,... }
    let quizStartedAt = Date.now();
    let previousDurationSeconds = 0;
    let isSubmitting = false;
    let isExiting = false;
    
    // Đồng hồ đếm ngược
    const TIME_PER_QUESTION = 15;
    let timeLeft = TIME_PER_QUESTION;
    let timerInterval = null;
    let checkpointQueue = Promise.resolve();
    const remainingTimes = {};

    async function attemptRequest(action, state = null) {
        // Không dùng chung checkpoint giữa Quiz luyện tập và Quiz SRS của cùng chủ đề.
        if (quizSessionConfig.mode === "review") {
            return { success: true, attempt: null };
        }
        const response = await fetch("../api/learning_attempt.php", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                action,
                activity: "quiz",
                csrf: quizSessionConfig.csrf,
                source: quizSessionConfig.source,
                sourceId: quizSessionConfig.sourceId,
                limit: quizSessionConfig.limit || "10",
                state
            })
        });
        const result = await response.json();
        if (!response.ok || !result.success) throw new Error(result.message || "Không thể lưu phiên Quiz.");
        return result;
    }

    function getDurationSeconds() {
        return previousDurationSeconds + Math.round((Date.now() - quizStartedAt) / 1000);
    }

    function getAttemptState() {
        remainingTimes[currentIndex] = timeLeft;
        return { questions, userAnswers, currentIndex, remainingTimes, durationSeconds: getDurationSeconds() };
    }

    function saveCheckpoint() {
        const snapshot = JSON.parse(JSON.stringify(getAttemptState()));
        checkpointQueue = checkpointQueue
            .catch(() => undefined)
            .then(() => attemptRequest("save", snapshot));
        return checkpointQueue.then(() => true).catch((error) => {
            console.error(error);
            return false;
        });
    }

    async function restoreAttempt() {
        try {
            const result = await attemptRequest("load");
            const state = result.attempt?.state;
            if (state && Array.isArray(state.questions) && state.questions.length > 0) {
                questions = state.questions;
                Object.assign(userAnswers, state.userAnswers || {});
                Object.assign(remainingTimes, state.remainingTimes || {});
                currentIndex = Math.min(Math.max(0, Number(state.currentIndex) || 0), questions.length - 1);
                previousDurationSeconds = Math.max(0, Number(state.durationSeconds) || 0);
                quizStartedAt = Date.now();
            } else {
                questions.forEach((question, index) => { remainingTimes[index] = TIME_PER_QUESTION; });
            }
        } catch (error) {
            console.error(error);
            questions.forEach((question, index) => { remainingTimes[index] = TIME_PER_QUESTION; });
        }
    }

    // 2. Tạo danh sách bóng tròn (Bubbles)
    function initBubbles() {
        bubblesRow.innerHTML = "";
        questions.forEach((q, index) => {
            const bubble = document.createElement("span");
            bubble.classList.add("C_Quiz_bubble");
            bubble.textContent = index + 1;
            bubble.addEventListener("click", () => {
                remainingTimes[currentIndex] = timeLeft;
                currentIndex = index;
                renderQuestion();
            });
            bubblesRow.appendChild(bubble);
        });
    }

    // 3. Đếm ngược thời gian
    function startTimer() {
        clearInterval(timerInterval);
        timeLeft = Math.max(0, Number(remainingTimes[currentIndex] ?? TIME_PER_QUESTION));
        timerCircle.textContent = `${timeLeft}s`;
        timerCircle.classList.remove("warning");
        timerCircle.classList.toggle("warning", timeLeft <= 5);

        timerInterval = setInterval(() => {
            timeLeft--;
            remainingTimes[currentIndex] = timeLeft;
            timerCircle.textContent = `${timeLeft}s`;

            if (timeLeft <= 5) {
                timerCircle.classList.add("warning");
            }

            if (timeLeft <= 0) {
                clearInterval(timerInterval);
                // Hết giờ -> tự động sang câu tiếp theo hoặc nộp bài
                handleNext();
            }
        }, 1000);
    }

    // 4. Render câu hỏi hiện tại
    function renderQuestion() {
        const q = questions[currentIndex];

        // Cập nhật text và thanh tiến độ
        progressText.textContent = `Câu ${currentIndex + 1}/${questions.length}`;
        // Cập nhật từ vựng
        questionWord.textContent = q.tu_vung;

        // Cập nhật các nút đáp án
        optionsGrid.innerHTML = "";
        q.dap_an.forEach((optText, optIndex) => {
            const btn = document.createElement("button");
            btn.type = "button";
            btn.classList.add("C_Quiz_optionBtn");
            btn.textContent = optText;

            // Đánh dấu nếu câu này người dùng đã chọn trước đó
            if (userAnswers[currentIndex] === optIndex) {
                btn.classList.add("C_Quiz_optionSelected");
            }

            // Xử lý chọn đáp án
            btn.addEventListener("click", () => {
                userAnswers[currentIndex] = optIndex;
                
                // Xóa chọn ở các nút khác và active nút vừa bấm
                const allBtns = optionsGrid.querySelectorAll(".C_Quiz_optionBtn");
                allBtns.forEach(b => b.classList.remove("C_Quiz_optionSelected"));
                btn.classList.add("C_Quiz_optionSelected");

                updateBubbles();
            });

            optionsGrid.appendChild(btn);
        });

        // Bật/tắt nút "Câu trước"
        btnCauTruoc.disabled = (currentIndex === 0);
        btnCauTiep.disabled = false;

        // Nếu ở câu cuối cùng -> Đổi chữ nút thành "Nộp bài"
        if (currentIndex === questions.length - 1) {
            btnCauTiep.textContent = "Nộp bài 🎉";
        } else {
            btnCauTiep.textContent = "Câu tiếp \u2192";
        }

        updateBubbles();
        startTimer();
    }

    // Cập nhật trạng thái bóng câu hỏi
    function updateBubbles() {
        const bubbles = bubblesRow.querySelectorAll(".C_Quiz_bubble");
        let answeredCount = 0;
        bubbles.forEach((b, index) => {
            b.classList.remove("active");
            if (index === currentIndex) {
                b.classList.add("active");
            }
            if (userAnswers[index] !== undefined) {
                b.classList.add("C_Quiz_bubbleFilled");
                answeredCount++;
            } else {
                b.classList.remove("C_Quiz_bubbleFilled");
            }
        });
        // Tiến độ dựa trên số câu đã trả lời, không dựa trên vị trí đang xem.
        progressFill.style.width = `${(answeredCount / questions.length) * 100}%`;
    }

    // 5. Xử lý nút "Câu tiếp" hoặc "Nộp bài"
    function handleNext() {
        remainingTimes[currentIndex] = timeLeft;
        if (currentIndex < questions.length - 1) {
            currentIndex++;
            renderQuestion();
        } else {
            // Đã làm hết tất cả các câu hỏi -> Hoàn thành Quiz
            submitQuiz();
        }
    }

    // 6. Nộp bài và chuyển sang trang C_KetquaQuiz.php
    async function submitQuiz() {
        if (isSubmitting) return;
        clearInterval(timerInterval);
        isSubmitting = true;
        btnCauTiep.disabled = true;
        btnCauTiep.textContent = "Đang lưu kết quả...";

        // Chỉ gửi đáp án người dùng chọn; PHP tự truy vấn đáp án đúng và tính điểm.
        const answers = questions.map((question, index) => {
            const selectedIndex = userAnswers[index];
            const selectedOption = selectedIndex === undefined ? "" : question.dap_an[selectedIndex];
            return {
                vocabularyId: question.id,
                selectedAnswer: selectedOption.replace(/^[A-D]\.\s*/, "")
            };
        });

        try {
            const response = await fetch("../api/save_quiz_result.php", {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                    csrf: quizSessionConfig.csrf,
                    source: quizSessionConfig.source,
                    sourceId: quizSessionConfig.sourceId,
                    mode: quizSessionConfig.mode || "practice",
                    submissionToken: quizSessionConfig.submissionToken,
                    limit: quizSessionConfig.limit || "10",
                    durationSeconds: getDurationSeconds(),
                    answers
                })
            });
            const result = await response.json();
            if (!response.ok || !result.success) throw new Error(result.message || "Không thể lưu kết quả.");
            await checkpointQueue.catch(console.error);
            const resultQuery = new URLSearchParams({
                id: result.quizResultId,
                source: quizSessionConfig.source,
                mode: quizSessionConfig.mode || "practice",
                limit: quizSessionConfig.limit || "10"
            });
            window.location.href = `C_KetquaQuiz.php?${resultQuery.toString()}`;
        } catch (error) {
            alert(error.message);
            isSubmitting = false;
            btnCauTiep.disabled = false;
            btnCauTiep.textContent = "Nộp bài 🎉";
        }
    }

    // Gắn sự kiện nút
    btnCauTiep.addEventListener("click", handleNext);

    btnCauTruoc.addEventListener("click", () => {
        if (currentIndex > 0) {
            remainingTimes[currentIndex] = timeLeft;
            currentIndex--;
            renderQuestion();
        }
    });

    // Khởi tạo Quiz
    btnCauTruoc.disabled = true;
    btnCauTiep.disabled = true;
    restoreAttempt().finally(() => {
        initBubbles();
        renderQuestion();
    });

    btnThoat.addEventListener("click", async () => {
        if (isSubmitting || isExiting) return;
        const exitMessage = quizSessionConfig.mode === "review"
            ? "Thoát Quiz ôn tập? Tiến độ hiện tại sẽ không được lưu."
            : "Thoát Quiz? Tiến độ hiện tại sẽ được lưu để bạn tiếp tục sau.";
        if (!window.confirm(exitMessage)) return;

        clearInterval(timerInterval);
        btnThoat.disabled = true;
        btnThoat.textContent = "Đang lưu...";

        const saved = await saveCheckpoint();
        if (!saved) {
            alert("Không thể lưu phiên Quiz. Vui lòng thử lại trước khi thoát.");
            btnThoat.disabled = false;
            btnThoat.textContent = "Thoát";
            startTimer();
            return;
        }

        isExiting = true;
        returnToLearningPage();
    });
});
