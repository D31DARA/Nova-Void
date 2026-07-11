; ============================================================================
;   NOVA VOID — (Cayo Perico Toolkit)
;   © Turtle V
; ============================================================================
;
;   НАВИГАЦИЯ ПО СКРИПТУ (ищите заголовки блоков ниже по тексту)
;   ------------------------------------------------------------------------
;    1. НАСТРОЙКИ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
;    2. ЦВЕТОВАЯ ПАЛИТРА
;    3. СИСТЕМА БИНДОВ (хранится в памяти скрипта, без .ini файла)
;    4. ЗАСТАВКА ПРИ ЗАПУСКЕ (рост из центра + глитч-эффект + typewriter)
;    5. ГЛАВНОЕ ОКНО (GUI, анимации кнопок Pulse, свой тумблер AlwaysOnTop)
;    6. ТЕНЬ ОКНА / ПЕРЕТАСКИВАНИЕ ЗА ЛЮБУЮ ОБЛАСТЬ
;    7. РЕГИСТРАЦИЯ ГОРЯЧИХ КЛАВИШ
;    8. ТРЕЙ (значок в трее + bounce-анимации сворачивания/восстановления)
;    9. ЛОГИКА: БЛОКИРОВКА / РАЗБЛОКИРОВКА IP (netsh advfirewall)
;   10. ЛОГИКА: ЗАМОРОЗКА / РАЗМОРОЗКА ПРОЦЕССА (NtSuspend/NtResumeProcess,
;       ИСПРАВЛЕН баг с невозможностью повторной заморозки — см. п.10)
;   11. ОКНО СМЕНЫ БИНДОВ (кнопка ⌨)
;   12. ОКНО СПРАВКИ (кнопка ?)
;   13. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (Pulse-анимация кнопок, тултипы, уведомления)
; ============================================================================
;
;   ИЗМЕНЕНИЯ В ЭТОЙ ВЕРСИИ
;   • ИСПРАВЛЕН критичный баг: после разморозки процесс нельзя было заморозить
;     повторно, т.к. флаг g_isSuspended никогда не сбрасывался обратно в false.
;     Теперь ResumeProcess() корректно сбрасывает g_isSuspended и g_hProcess,
;     поэтому повторная заморозка работает без перезапуска скрипта.
;   • Перенесены и оптимизированы все анимации из тестовой версии: заставка
;     с глитч-эффектом, Pulse-анимация нажатия кнопок, анимация закрытия
;     (сжатие окна), bounce-анимации сворачивания/восстановления из трея,
;     кастомный тумблер "Поверх всех окон", уведомление о заморозке с
;     обратным таймером и вращающимся индикатором.
; ============================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

DetectHiddenWindows(true)

; --- Проверка прав администратора (нужны для netsh) ---
if !A_IsAdmin {
    try Run('*RunAs "' A_ScriptFullPath '"')
    ExitApp()
}

; ============================================================================
;   1. НАСТРОЙКИ И ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
; ============================================================================
BlockIP        := "192.81.241.171"   ; IP-адрес, который блокируется через брандмауэр
FwRuleName     := "NovaVoid_BlockIP" ; имя правила брандмауэра Windows
ProcessName    := "GTA5_Enhanced.exe" ; имя процесса, который нужно морозить
CurrentStatus  := "Неизвестно"

; --- Автообновление через GitHub ---
ScriptVersion     := "2.0"  ; версия текущего скрипта — меняй при каждом релизе
UpdateVersionURL  := "https://raw.githubusercontent.com/D31DARA/Nova-Void/main/version.txt"
UpdateScriptURL   := "https://raw.githubusercontent.com/D31DARA/Nova-Void/main/Nova%20Void.ahk"

; --- НОВОЕ (п.5): кастомный звук заморозки, скачивается с GitHub при первом запуске ---
; Замени ссылку на прямую ссылку на свой .wav/.mp3 файл в репозитории
CustomSoundURL  := "https://raw.githubusercontent.com/USERNAME/REPO/main/freeze_sound.wav"
CustomSoundPath := A_ScriptDir . "\freeze_sound.wav"

global g_hProcess    := 0
global g_isSuspended := false

; НОВОЕ (исправление бага): переменные позиции окна ДОЛЖНЫ быть инициализированы заранее.
; Раньше они получали значение только внутри MinimizeToTray() — если пользователь открывал
; окно из трея ДО первого сворачивания, чтение неинициализированных переменных вызывало ошибку.
global g_LastWinX   := ""
global g_LastWinY   := ""
global g_IsMinimized := false

; ============================================================================
;   2. ЦВЕТОВАЯ ПАЛИТРА
; ============================================================================
COLOR_BG      := "141414"   ; фон окна — почти чёрный
COLOR_PANEL   := "232323"   ; фон элементов управления — тёмно-серый
COLOR_ACCENT  := "C1121F"   ; акцентный красный — заголовки, важные кнопки
COLOR_ACCENT2 := "2E2E2E"   ; второй акцент — нейтральные кнопки/панели
COLOR_TEXT    := "E5E5E5"   ; основной текст
COLOR_MUTED   := "9C9C9C"   ; второстепенный текст
COLOR_INFO    := "1C7ED6"   ; НОВОЕ: голубой акцент — уведомление о заморозке (обратный таймер)

; ============================================================================
;   3. СИСТЕМА БИНДОВ (без .ini — хранится в памяти в течение сессии)
; ============================================================================
global Binds := Map(
    "Block",   "F9",
    "Unblock", "F8",
    "Freeze",  "F7"
)
global BindLabels := Map()   ; ссылки на текстовые контролы окна биндов

; ============================================================================
;   4. ЗАСТАВКА ПРИ ЗАПУСКЕ (рост из центра + глитч-эффект)
; ============================================================================
ShowSplash()

ShowSplash() {
    global COLOR_BG, COLOR_ACCENT, COLOR_TEXT, COLOR_MUTED

    splash := Gui("-Caption +AlwaysOnTop +ToolWindow", "Splash")
    splash.BackColor := COLOR_BG

    ; --- Основной текст ---
    splash.SetFont("s20 Bold c" . COLOR_ACCENT, "Segoe UI")
    TitleTxt := splash.Add("Text", "w300 h60 Center x20 y25", "◈ NOVA VOID")
    splash.SetFont("s9 c" . COLOR_MUTED, "Segoe UI")
    SubTxt := splash.Add("Text", "w300 h20 Center x20 y+5", "")

    ; --- "Призрачные" слои для хроматической аберрации (RGB-расслоение) ---
    splash.SetFont("s20 Bold cFF3355", "Segoe UI")
    GhostRed := splash.Add("Text", "w300 h60 Center x20 y25", "◈ NOVA VOID")
    splash.SetFont("s20 Bold c33E5FF", "Segoe UI")
    GhostCyan := splash.Add("Text", "w300 h60 Center x20 y25", "◈ NOVA VOID")
    GhostRed.Visible  := false
    GhostCyan.Visible := false

    targetW := 340, targetH := 130
    startW  := 40,  startH  := 16
    cx := A_ScreenWidth  // 2
    cy := A_ScreenHeight // 2
    fx := cx - targetW // 2
    fy := cy - targetH // 2

    splash.Show("Hide w" . targetW . " h" . targetH)

    ; ---- Фаза 1: рост из центра с лёгким дребезгом позиции ----
    steps := 14
    Loop steps {
        f := A_Index / steps
        f := 1 - (1 - f)**2   ; ease-out
        w := Round(startW + (targetW - startW) * f)
        h := Round(startH + (targetH - startH) * f)
        jx := (A_Index > 4 && Random(1, 4) = 1) ? Random(-2, 2) : 0
        jy := (A_Index > 4 && Random(1, 4) = 1) ? Random(-1, 1) : 0
        x := cx - w // 2 + jx
        y := cy - h // 2 + jy
        splash.Show("x" . x . " y" . y . " w" . w . " h" . h . " NoActivate")
        Sleep(16)
    }
    splash.Show("x" . fx . " y" . fy . " w" . targetW . " h" . targetH . " NoActivate")

    ; ---- НОВОЕ: печатающийся текст (typewriter) для подзаголовка ----
    TypewriterText(SubTxt, "Cayo Perico Toolkit", 22)

    ; ---- Фаза 2: глитч-вспышки (RGB-расслоение + "рассыпание" текста + тряска) ----
    finalTitle  := "◈ NOVA VOID"
    glitchChars := "!@#$%&<>/\|~▓▒░■01"

    bursts := 6
    Loop bursts {
        ; смещаем цветные "призраки" в случайную сторону — эффект расслоения канала
        GhostRed.Move(20 + Random(-4, 4), 25 + Random(-2, 2))
        GhostCyan.Move(20 + Random(-4, 4), 25 + Random(-2, 2))
        GhostRed.Visible  := true
        GhostCyan.Visible := true

        ; "рассыпаем" заголовок на случайные символы
        scrambled := ""
        Loop Parse finalTitle
            scrambled .= (A_LoopField = " ") ? " " : SubStr(glitchChars, Random(1, StrLen(glitchChars)), 1)
        TitleTxt.Text := scrambled

        ; лёгкая тряска всего окна
        splash.Show("x" . (fx + Random(-3, 3)) . " y" . (fy + Random(-2, 2)) . " NoActivate")
        Sleep(Random(30, 60))

        ; возврат в чистое состояние между вспышками
        GhostRed.Visible  := false
        GhostCyan.Visible := false
        TitleTxt.Text := finalTitle
        splash.Show("x" . fx . " y" . fy . " NoActivate")
        Sleep(Random(50, 100))
    }

    ; ---- Фаза 3: финальная стабилизация ----
    TitleTxt.Text := finalTitle
    splash.Show("x" . fx . " y" . fy . " w" . targetW . " h" . targetH . " NoActivate")

    Sleep(500)
    splash.Destroy()
}

; --- НОВОЕ: печатающийся текст — раскрывает строку посимвольно ---
TypewriterText(ctrl, text, delay := 22) {
    ctrl.Text := ""
    out := ""
    Loop Parse text {
        out .= A_LoopField
        ctrl.Text := out
        Sleep(delay)
    }
}

; ============================================================================
;   5. ГЛАВНОЕ ОКНО (GUI)
; ============================================================================
MyGui := Gui("-Caption +Border +ToolWindow", "Nova Void")
MyGui.BackColor := COLOR_BG
MyGui.MarginX := 20
MyGui.MarginY := 20

; --- Заголовок ---
MyGui.SetFont("s14 Bold c" . COLOR_ACCENT, "Segoe UI Symbol")
MyGui.Add("Text", "w220 h30 x20 y20", "◈ NOVA VOID")

; --- Кнопки управления в правом верхнем углу ---
; ИЗМЕНЕНО: кнопка биндов перенесена вниз с понятной текстовой подписью (см. п.2)
MyGui.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
																				   
HelpBtn  := MyGui.Add("Button", "w30 h30 x295 y15 Background" . COLOR_PANEL, "?")
MinBtn   := MyGui.Add("Button", "w30 h30 x330 y15 Background" . COLOR_PANEL, "▁")
CloseBtn := MyGui.Add("Button", "w30 h30 x365 y15 Background" . COLOR_PANEL, "✕")
									   
HelpBtn.OnEvent("Click", WrapWithPulse(OnHelpClick))
MinBtn.OnEvent("Click", WrapWithPulse(MinimizeToTray))
CloseBtn.OnEvent("Click", (*) => ExitWithAnimation())  ; НОВОЕ (п.4): анимация сжатия перед выходом

; --- НОВОЕ (п.4): анимация закрытия — окно быстро сжимается к своему центру, затем ExitApp() ---
ExitWithAnimation() {
    global MyGui
    try {
        MyGui.GetPos(&x, &y, &w, &h)
        cx := x + w // 2
        cy := y + h // 2
        steps := 8
        Loop steps {
            f := A_Index / steps
            scale := 1 - f**1.3   ; ускоряющееся сжатие
            curW := Max(10, Round(w * scale))
            curH := Max(8, Round(h * scale))
            curX := cx - curW // 2
            curY := cy - curH // 2
            MyGui.Move(curX, curY, curW, curH)
            Sleep(9)
        }
    }
    ExitApp()
}

; --- Статус блокировки IP ---
MyGui.SetFont("s10 c" . COLOR_TEXT, "Segoe UI")
StatusText := MyGui.Add("Text", "w375 h22 x20 y+8 Center", "Статус: " . CurrentStatus)

; --- Кнопки блокировки/разблокировки IP ---
MyGui.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
DisableBtn := MyGui.Add("Button", "w375 h45 x20 y+10 Background" . COLOR_ACCENT,
    "🔒  ЗАБЛОКИРОВАТЬ IP  (" . Binds["Block"] . ")")
EnableBtn  := MyGui.Add("Button", "w375 h45 x20 y+8 Background" . COLOR_ACCENT2,
    "🔓  РАЗБЛОКИРОВАТЬ IP  (" . Binds["Unblock"] . ")")
DisableBtn.OnEvent("Click", WrapWithPulse(DisableInternet))
EnableBtn.OnEvent("Click", WrapWithPulse(EnableInternet))

; --- Разделитель перед новым блоком ---
MyGui.Add("Text", "w375 x20 h1 y+10 Background" . COLOR_PANEL)

; --- Заморозка процесса: поле с именем процесса ---
MyGui.SetFont("s9 Norm c" . COLOR_MUTED, "Segoe UI")
MyGui.Add("Text", "w375 h20 x20 y+8", "Процесс для заморозки:")
EditField := MyGui.Add("Edit", "w375 x20 y+4 h25 Background" . COLOR_PANEL . " c" . COLOR_TEXT, ProcessName)

; --- Кнопка заморозки на 10 секунд ---
MyGui.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
FreezeBtn := MyGui.Add("Button", "w375 h45 x20 y+8 Background" . COLOR_ACCENT2,
    "⏸  ЗАМОРОЗИТЬ  (" . Binds["Freeze"] . ")")
FreezeBtn.OnEvent("Click", WrapWithPulse(OnFreezeClick))

; --- Статус заморозки ---
MyGui.SetFont("s9 Norm c" . COLOR_MUTED, "Segoe UI")
FreezeStatusText := MyGui.Add("Text", "w375 h20 x20 Center y+8", "Статус заморозки: ожидание")

; --- ИЗМЕНЕНО (п.2): "Поверх всех окон" теперь кастомная кнопка-тумблер в стиле тёмной темы,
; а не нативный Windows-чекбокс (тот рисуется белым квадратом и не вписывается в дизайн) ---
global g_AlwaysOnTop := false
MyGui.SetFont("s10 Bold c" . COLOR_TEXT, "Segoe UI")
AlwaysOnTopChk := MyGui.Add("Button", "w375 h36 x20 y+10 Background" . COLOR_PANEL, "📌  Поверх всех окон:  ВЫКЛ")
AlwaysOnTopChk.OnEvent("Click", WrapWithPulse(OnAlwaysOnTopToggle))

; --- НОВОЕ (п.2): кнопка настройки биндов с понятной подписью (была маленькой иконкой ⌨) ---
MyGui.SetFont("s10 Bold c" . COLOR_TEXT, "Segoe UI")
BindEditorBtn := MyGui.Add("Button", "w375 h38 x20 y+8 Background" . COLOR_PANEL, "⌨  Настройка клавиш")
BindEditorBtn.OnEvent("Click", WrapWithPulse(OpenBindEditor))

; --- НОВОЕ (п.3): кнопка ручной проверки обновлений ---
UpdateCheckBtn := MyGui.Add("Button", "w375 h38 x20 y+8 Background" . COLOR_PANEL, "🔄  Проверить обновления")
UpdateCheckBtn.OnEvent("Click", WrapWithPulse((*) => CheckForUpdates(false)))

; --- Копирайт ---
MyGui.SetFont("s10 c" . COLOR_MUTED, "Segoe UI")
MyGui.Add("Text", "w375 h20 x20 Center y+10", "© Turtle V")

; --- ИЗМЕНЕНО (п.2): переключатель "Поверх всех окон" — своя логика вкл/выкл + смена текста и цвета кнопки ---
OnAlwaysOnTopToggle(ctrl, *) {
    global MyGui, g_AlwaysOnTop, COLOR_PANEL, COLOR_ACCENT

    g_AlwaysOnTop := !g_AlwaysOnTop

    if (g_AlwaysOnTop) {
        MyGui.Opt("+AlwaysOnTop")
        ctrl.Text := "📌  Поверх всех окон:  ВКЛ"
        ctrl.Opt("Background" . COLOR_ACCENT)
    } else {
        MyGui.Opt("-AlwaysOnTop")
        ctrl.Text := "📌  Поверх всех окон:  ВЫКЛ"
        ctrl.Opt("Background" . COLOR_PANEL)
    }
}

; ============================================================================
;   6. ТЕНЬ ОКНА / ПЕРЕТАСКИВАНИЕ ЗА ЛЮБУЮ ОБЛАСТЬ
; ============================================================================
ApplyWindowShadow(MyGui.Hwnd)

ApplyWindowShadow(hwnd) {
    MARGINS := Buffer(16, 0)
    NumPut("Int", 1, MARGINS, 0)
    NumPut("Int", 1, MARGINS, 4)
    NumPut("Int", 1, MARGINS, 8)
    NumPut("Int", 1, MARGINS, 12)
    DllCall("dwmapi\DwmExtendFrameIntoClientArea", "Ptr", hwnd, "Ptr", MARGINS)
}

; Показываем окно сразу после заставки, без Fade-In
MyGui.Show("w415 h535")

; Тихая проверка обновлений через несколько секунд после запуска
SetTimer(() => CheckForUpdates(true), -3000)
; НОВОЕ (п.5): тихая загрузка кастомного звука заморозки, если его ещё нет
SetTimer(EnsureCustomSound, -1000)

; ИЗМЕНЕНО: перетаскивание теперь работает не только для главного окна,
; но и для окна справки (HelpGuiRef) и окна смены биндов (BindGuiRef) —
; у них тоже нет системного заголовка (+Caption), поэтому без этого
; обработчика их вообще нельзя было бы подвинуть.
OnMessage(0x0201, WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global MyGui, HelpGuiRef, BindGuiRef

    ; ИСПРАВЛЕНО: после Destroy() переменные HelpGuiRef/BindGuiRef всё ещё
    ; ссылаются на уже уничтоженный объект Gui — обращение к .Hwnd у такого
    ; объекта вызывает ошибку. Оборачиваем в try, чтобы скрипт не падал,
    ; даже если где-то ссылка не была вовремя очищена.
    try {
        if (hwnd = MyGui.Hwnd) {
            PostMessage(0xA1, 2, 0, , "ahk_id " . hwnd)
            return
        }
    }
    try {
        if (IsSet(HelpGuiRef) && HelpGuiRef && hwnd = HelpGuiRef.Hwnd) {
            PostMessage(0xA1, 2, 0, , "ahk_id " . hwnd)
            return
        }
    }
    try {
        if (IsSet(BindGuiRef) && BindGuiRef && hwnd = BindGuiRef.Hwnd) {
            PostMessage(0xA1, 2, 0, , "ahk_id " . hwnd)
            return
        }
    }
}

; ============================================================================
;   7. РЕГИСТРАЦИЯ ГОРЯЧИХ КЛАВИШ
; ============================================================================
RegisterHotkeys()

RegisterHotkeys() {
    global Binds
    static registered := Map()

    for actionKey, keyName in registered {
        try Hotkey(keyName, "Off")
    }

    try Hotkey(Binds["Block"],   DisableInternet, "On")
    try Hotkey(Binds["Unblock"], EnableInternet, "On")
    try Hotkey(Binds["Freeze"],  (*) => FreezeProcess(), "On")

    registered := Binds.Clone()
}

; ============================================================================
;   8. ТРЕЙ
; ============================================================================
A_TrayMenu.Delete()
A_TrayMenu.Add("Открыть окно", TrayShowWindow)
A_TrayMenu.Add("Проверить обновления", TrayCheckUpdates)
A_TrayMenu.Add("Выход", TrayExitApp)
A_TrayMenu.Default := "Открыть окно"
A_IconTip := "Nova Void"

TrayShowWindow(*) {
    global MyGui, g_LastWinX, g_LastWinY, g_IsMinimized

    if (!g_IsMinimized) {
        ; ИСПРАВЛЕНО (баг из п.1): окно уже открыто (не было свёрнуто в трей) —
        ; просто выводим его на передний план, без повторного проигрывания bounce-анимации.
        MyGui.Show()
        try WinActivate("ahk_id " . MyGui.Hwnd)
        return
    }

    BounceInAndShow(MyGui, g_LastWinX, g_LastWinY)
    g_IsMinimized := false
}

TrayCheckUpdates(*) {
    CheckForUpdates(false)
}

TrayExitApp(*) {
    ExitApp()
}

MinimizeToTray(*) {
    global MyGui, g_LastWinX, g_LastWinY, g_IsMinimized
    MyGui.GetPos(&x, &y, &w, &h)
    g_LastWinX := x
    g_LastWinY := y
    g_IsMinimized := true
    BounceOutAndHide(MyGui, x, y, w, h)
    TrayTip("Nova Void", "Скрипт свёрнут в трей.`nЛКМ по иконке — открыть окно.")
}

; --- НОВОЕ: анимация "сворачивания" — окно сжимается к своему центру и прячется ---
BounceOutAndHide(guiObj, x, y, w, h) {
    cx := x + w // 2
    cy := y + h // 2
    steps := 9
    Loop steps {
        f := A_Index / steps
        scale := 1 - f**1.5   ; ускоряющееся сжатие
        curW := Max(20, Round(w * scale))
        curH := Max(14, Round(h * scale))
        curX := cx - curW // 2
        curY := cy - curH // 2
        guiObj.Move(curX, curY, curW, curH)
        Sleep(10)
    }
    guiObj.Hide()
    guiObj.Move(x, y, w, h)  ; возвращаем реальный размер, пока окно скрыто
}

; --- НОВОЕ: анимация "восстановления" — окно вырастает с эффектом пружины (overshoot) ---
BounceInAndShow(guiObj, x, y) {
    targetW := 415, targetH := 535

    if (x = "" || y = "") {
        guiObj.Show()  ; окно ещё ни разу не сворачивалось — показываем как обычно
        return
    }

    cx := x + targetW // 2
    cy := y + targetH // 2

    scales := [0.3, 0.7, 1.15, 0.95, 1.0]  ; доли от целевого размера — эффект пружины/отскока
    for scale in scales {
        w := Round(targetW * scale)
        h := Round(targetH * scale)
        curX := cx - w // 2
        curY := cy - h // 2
        guiObj.Show("x" . curX . " y" . curY . " w" . w . " h" . h)
        Sleep(45)
    }
    guiObj.Show("x" . x . " y" . y . " w" . targetW . " h" . targetH)
}

; ============================================================================
;   9. ЛОГИКА: БЛОКИРОВКА / РАЗБЛОКИРОВКА IP
; ============================================================================
DisableInternet(*) {
    global BlockIP, FwRuleName, StatusText, COLOR_ACCENT
    RunWait(A_ComSpec . ' /c netsh advfirewall firewall add rule name="' . FwRuleName
        . '" dir=out action=block remoteip="' . BlockIP . '"', , "Hide")
    StatusText.Text := "Статус: IP ЗАБЛОКИРОВАН ⛔"
    ShowNotification("IP ЗАБЛОКИРОВАН", COLOR_ACCENT)
}

EnableInternet(*) {
    global FwRuleName, StatusText, COLOR_ACCENT2
    RunWait(A_ComSpec . ' /c netsh advfirewall firewall delete rule name="' . FwRuleName . '"', , "Hide")
    StatusText.Text := "Статус: IP РАЗБЛОКИРОВАН ✅"
    ShowNotification("IP РАЗБЛОКИРОВАН", COLOR_ACCENT2)
}

OnExit(CleanupFirewallRule)
CleanupFirewallRule(*) {
    global FwRuleName
    RunWait(A_ComSpec . ' /c netsh advfirewall firewall delete rule name="' . FwRuleName . '"', , "Hide")
}

; НОВОЕ (оптимизация): если скрипт закрывают, пока процесс ещё заморожен —
; принудительно возобновляем его, иначе он останется висеть в suspended
; навсегда (пользователь потеряет доступ к игре без явной причины).
OnExit(ForceResumeOnExit)
ForceResumeOnExit(*) {
    global g_hProcess, g_isSuspended
    if (g_isSuspended && g_hProcess) {
        try DllCall("ntdll.dll\NtResumeProcess", "Ptr", g_hProcess, "Int")
        try DllCall("CloseHandle", "Ptr", g_hProcess)
        g_isSuspended := false
        g_hProcess    := 0
    }
}

; ============================================================================
;   10. ЛОГИКА: ЗАМОРОЗКА / РАЗМОРОЗКА ПРОЦЕССА
; ============================================================================
OnFreezeClick(*) {
    FreezeProcess()
}

; --- НОВОЕ (п.5): проигрывание кастомного звука заморозки (если скачан) ---
PlayFreezeSound() {
    global CustomSoundPath
    if FileExist(CustomSoundPath) {
        try {
            SoundPlay(CustomSoundPath)
            return
        }
    }
    ; запасной вариант, если файл ещё не скачан или SoundPlay не смог его открыть
    SoundBeep(450, 200)  ; п.4: пониженная тональность (было 900 Гц)
}

; --- НОВОЕ (п.5): скачивание кастомного звука с GitHub, если его ещё нет локально ---
EnsureCustomSound() {
    global CustomSoundURL, CustomSoundPath
    if FileExist(CustomSoundPath)
        return
    try {
        result := DllCall("urlmon\URLDownloadToFileW", "Ptr", 0, "WStr", CustomSoundURL,
            "WStr", CustomSoundPath, "UInt", 0, "Ptr", 0)
        if (result != 0 && FileExist(CustomSoundPath))
            FileDelete(CustomSoundPath)  ; неудачная/частичная загрузка — удаляем, чтобы не мешала
    } catch {
        ; тихо игнорируем — при заморозке просто прозвучит запасной SoundBeep
    }
}

FreezeProcess() {
    global g_hProcess, g_isSuspended, EditField, FreezeStatusText

    targetProcess := Trim(EditField.Value)

    if (g_isSuspended) {
        ShowTip("Процесс уже приостановлен, ждите авторазморозки...")
        return
    }

    PID := ProcessExist(targetProcess)
    if (!PID) {
        ShowTip("Процесс '" . targetProcess . "' не найден!")
        FreezeStatusText.Text := "Статус заморозки: процесс не найден"
        return
    }

    hProcess := DllCall("OpenProcess", "UInt", 0x0800, "Int", false, "UInt", PID, "Ptr")
    if (!hProcess) {
        ShowTip("Не удалось открыть процесс (не хватает прав доступа)")
        return
    }

    result := DllCall("ntdll.dll\NtSuspendProcess", "Ptr", hProcess, "Int")
    if (result != 0) {
        DllCall("CloseHandle", "Ptr", hProcess)
        ShowTip("Ошибка при попытке приостановить процесс")
        return
    }

    g_hProcess    := hProcess
    g_isSuspended := true

    ; ИЗМЕНЕНО (п.4/5): играем кастомный звук, если он скачан, иначе — тихий Beep (450 Гц)
    PlayFreezeSound()
    ; НОВОЕ: цветное уведомление с обратным таймером и вращающимся индикатором вместо ShowTip
    ShowFreezeCountdown(10, targetProcess)
    FreezeStatusText.Text := "Статус заморозки: заморожен на 10 сек..."

    SetTimer(ResumeProcess, -10000)
}

ResumeProcess() {
    global g_hProcess, g_isSuspended, FreezeStatusText

    if (!g_hProcess)
        return

    DllCall("ntdll.dll\NtResumeProcess", "Ptr", g_hProcess, "Int")

    CloseFreezeCountdown()  ; НОВОЕ: гарантированно закрываем уведомление с таймером, если оно ещё висит

    ; ИСПРАВЛЕНО: раньше эти строки отсутствовали, из-за чего g_isSuspended
    ; навсегда оставался true после первой заморозки, и FreezeProcess() всегда
    ; выходил по условию "процесс уже приостановлен" — повторная заморозка
    ; была невозможна без перезапуска скрипта. Теперь состояние сбрасывается,
    ; а хэндл процесса закрывается, чтобы не копить утечку хэндлов.
    DllCall("CloseHandle", "Ptr", g_hProcess)
    g_isSuspended := false
    g_hProcess    := 0

    SoundBeep(350, 200)  ; ИЗМЕНЕНО (п.4): тише/ниже, чем было раньше (400 Гц вместо резкого сигнала)
    ShowTip("Процесс возобновлён")
    FreezeStatusText.Text := "Статус заморозки: возобновлён"
}

; ============================================================================
;   НОВОЕ: УВЕДОМЛЕНИЕ О ЗАМОРОЗКЕ — ОБРАТНЫЙ ТАЙМЕР + ВРАЩАЮЩИЙСЯ ИНДИКАТОР
; ============================================================================
; ИСПРАВЛЕНО: раньше имя процесса и текст таймера лежали в одном Text-контроле
; со стилем +0x200 (SS_CENTERIMAGE). Этот стиль рассчитан на однострочный текст
; и ломает перенос строки (`n), из-за чего длинные имена вроде
; "GTA5_Enhanced.exe" визуально обрезались. Теперь это два отдельных
; контрола (имя процесса / таймер) без SS_CENTERIMAGE, а ширина окна
; подбирается под длину имени процесса, так что оно никогда не обрезается.
ShowFreezeCountdown(seconds, processName) {
    global COLOR_INFO, g_FreezeNotifyGui, g_FreezeSpinnerCtrl, g_FreezeNameCtrl, g_FreezeTimerCtrl
    global g_FreezeSecondsLeft, g_FreezeSpinnerIndex, g_FreezeProcessLabel

    if IsSet(g_FreezeNotifyGui) && g_FreezeNotifyGui
        try g_FreezeNotifyGui.Destroy()

    g_FreezeSecondsLeft  := seconds
    g_FreezeSpinnerIndex := 1
    g_FreezeProcessLabel := processName

    ; --- Автоширина: под каждый символ имени процесса ~9px (Segoe UI Bold, s12) ---
    nameLine   := "⏸ «" . processName . "»"
    textW      := Max(290, StrLen(nameLine) * 10)
    winW       := 80 + textW  ; 80 = место под спиннер + отступы
    winW       := Min(winW, A_ScreenWidth - 40)  ; не выходим за пределы экрана

    g_FreezeNotifyGui := Gui("-Caption +AlwaysOnTop +ToolWindow")
    g_FreezeNotifyGui.BackColor := COLOR_INFO

    g_FreezeNotifyGui.SetFont("s22 cWhite Bold", "Segoe UI")
    g_FreezeSpinnerCtrl := g_FreezeNotifyGui.Add("Text", "w60 h60 Center x8 y0", "◐")

    ; --- Имя процесса: своя строка, без SS_CENTERIMAGE, не обрезается ---
    g_FreezeNotifyGui.SetFont("s12 cWhite Bold", "Segoe UI")
    g_FreezeNameCtrl := g_FreezeNotifyGui.Add("Text", "w" . textW . " Center x70 y10", nameLine)

    ; --- Строка таймера — отдельно снизу ---
    g_FreezeNotifyGui.SetFont("s10 cWhite Norm", "Segoe UI")
    g_FreezeTimerCtrl := g_FreezeNotifyGui.Add("Text", "w" . textW . " Center x70 y+2",
        "осталось: " . seconds . " сек")

    g_FreezeNotifyGui.Show("NoActivate w" . winW . " h60 xCenter y20")

    SetTimer(FreezeSpinnerTick, 120)     ; вращение индикатора ◐◓◑◒
    SetTimer(FreezeCountdownTick, 1000)  ; уменьшение счётчика раз в секунду
}

FreezeSpinnerTick() {
    global g_FreezeSpinnerCtrl, g_FreezeSpinnerIndex
    static frames := ["◐", "◓", "◑", "◒"]

    if !(IsSet(g_FreezeSpinnerCtrl) && g_FreezeSpinnerCtrl) {
        SetTimer(FreezeSpinnerTick, 0)
        return
    }
    g_FreezeSpinnerIndex := Mod(g_FreezeSpinnerIndex, 4) + 1
    try g_FreezeSpinnerCtrl.Text := frames[g_FreezeSpinnerIndex]
}

FreezeCountdownTick() {
    global g_FreezeSecondsLeft, g_FreezeTimerCtrl

    g_FreezeSecondsLeft--

    if (g_FreezeSecondsLeft <= 0) {
        CloseFreezeCountdown()
        return
    }
    if (IsSet(g_FreezeTimerCtrl) && g_FreezeTimerCtrl)
        try g_FreezeTimerCtrl.Text := "осталось: " . g_FreezeSecondsLeft . " сек"
}

CloseFreezeCountdown() {
    global g_FreezeNotifyGui
    SetTimer(FreezeCountdownTick, 0)
    SetTimer(FreezeSpinnerTick, 0)
    if IsSet(g_FreezeNotifyGui) && g_FreezeNotifyGui
        try g_FreezeNotifyGui.Destroy()
}


; ============================================================================
;   11. ОКНО СМЕНЫ БИНДОВ (кнопка ⌨)
; ============================================================================
OpenBindEditor(*) {
    global BindGuiRef, BindLabels, Binds, COLOR_BG, COLOR_PANEL, COLOR_ACCENT, COLOR_ACCENT2, COLOR_TEXT

    if IsSet(BindGuiRef) && BindGuiRef
        try BindGuiRef.Destroy()

    BindGuiRef := Gui("-Caption +AlwaysOnTop +Border +ToolWindow", "Bindings")
    BindGuiRef.BackColor := COLOR_BG
    BindGuiRef.MarginX := 20
    BindGuiRef.MarginY := 20

    BindGuiRef.SetFont("s13 Bold c" . COLOR_ACCENT, "Segoe UI")
    BindGuiRef.Add("Text", "w320 h30", "⌨ Смена биндов")

    rows := [["Block", "Заблокировать IP"], ["Unblock", "Разблокировать IP"], ["Freeze", "Заморозить процесс"]]

    BindLabels := Map()
    for item in rows {
        actionKey := item[1]
        label     := item[2]

        BindGuiRef.SetFont("s10 c" . COLOR_TEXT, "Segoe UI")
        BindGuiRef.Add("Text", "w190 x20 y+18", label . ":")

        BindGuiRef.SetFont("s10 Bold c" . COLOR_ACCENT, "Segoe UI")
        lbl := BindGuiRef.Add("Text", "w60 x210 yp", Binds[actionKey])
        BindLabels[actionKey] := lbl

        BindGuiRef.SetFont("s9 Bold c" . COLOR_TEXT, "Segoe UI")
        btn := BindGuiRef.Add("Button", "w80 h24 x280 yp-2 Background" . COLOR_PANEL, "Изменить")
        btn.OnEvent("Click", MakeRebindHandler(actionKey, label))
    }

    BindGuiRef.SetFont("s10 Bold c" . COLOR_TEXT, "Segoe UI")
    closeBtn := BindGuiRef.Add("Button", "w360 h32 x20 y+25 Background" . COLOR_ACCENT2, "Закрыть")
    ; ИСПРАВЛЕНО: обнуляем BindGuiRef после закрытия, иначе ссылка на
    ; уничтоженный объект остаётся и ломает следующую проверку в drag-обработчике.
    closeBtn.OnEvent("Click", (*) => CloseBindEditor())

    BindGuiRef.Show("w400")
}

; НОВОЕ: единая функция закрытия окна биндов — уничтожает Gui и
; обязательно обнуляет BindGuiRef, чтобы не осталось "мёртвой" ссылки.
CloseBindEditor(*) {
    global BindGuiRef
    if IsSet(BindGuiRef) && BindGuiRef
        try BindGuiRef.Destroy()
    BindGuiRef := ""
}

MakeRebindHandler(actionKey, label) {
    return (*) => StartRebind(actionKey, label)
}

StartRebind(actionKey, label) {
    global Binds, BindLabels

    ShowTip("Нажмите новую клавишу для «" . label . "»...")
    newKey := CaptureKey()

    if (newKey = "") {
        ShowTip("Отменено — клавиша не нажата")
        return
    }

    Binds[actionKey] := newKey
    RegisterHotkeys()

    if BindLabels.Has(actionKey)
        BindLabels[actionKey].Text := newKey

    UpdateMainButtonLabels()
    ShowTip("«" . label . "» теперь на клавише: " . newKey)
}

CaptureKey() {
    ih := InputHook("L0 T5")
    ih.KeyOpt("{All}", "E")
    ih.Start()
    ih.Wait()
    return ih.EndKey
}

UpdateMainButtonLabels() {
    global DisableBtn, EnableBtn, FreezeBtn, Binds
    DisableBtn.Text := "🔒  ЗАБЛОКИРОВАТЬ IP  (" . Binds["Block"] . ")"
    EnableBtn.Text  := "🔓  РАЗБЛОКИРОВАТЬ IP  (" . Binds["Unblock"] . ")"
    FreezeBtn.Text  := "⏸  ЗАМОРОЗИТЬ  (" . Binds["Freeze"] . ")"
}

; ============================================================================
;   12. ОКНО СПРАВКИ (кнопка ?)
; ============================================================================
OnHelpClick(*) {
    global HelpGuiRef, BlockIP, ProcessName, Binds, COLOR_BG, COLOR_PANEL, COLOR_ACCENT, COLOR_TEXT

    if IsSet(HelpGuiRef) && HelpGuiRef
        try HelpGuiRef.Destroy()

    HelpGuiRef := Gui("-Caption +AlwaysOnTop +Border +ToolWindow", "Справка")
    HelpGuiRef.BackColor := COLOR_BG
    HelpGuiRef.MarginX := 20
    HelpGuiRef.MarginY := 20

    HelpGuiRef.SetFont("s13 Bold c" . COLOR_ACCENT, "Segoe UI")
    HelpGuiRef.Add("Text", "w340 h30 x20 y20", "◈ Как работает скрипт")

    HelpGuiRef.SetFont("s9 Bold c" . COLOR_TEXT, "Segoe UI")
    FwMonitorBtn := HelpGuiRef.Add("Button", "w100 h24 x360 y22 Background" . COLOR_PANEL, "🛡 Монитор")
    FwMonitorBtn.OnEvent("Click", OpenFirewallMonitor)

    HelpGuiRef.SetFont("s9 c" . COLOR_TEXT, "Segoe UI")
    helpText :=
        "🌐 Адрес '" . BlockIP . "' блокируется через правило брандмауэра Windows (netsh).`n`n"
        . " Условия работы:`n"
        . "• Нужны права администратора (иначе netsh не сработает).`n"
        . "• Правило создаётся и удаляется под именем NovaVoid_BlockIP.`n`n"
        . " " . Binds["Block"] . " / кнопка ЗАБЛОКИРОВАТЬ IP — добавляет правило,`n"
        . "  блокирующее исходящий трафик на указанный адрес.`n"
        . " " . Binds["Unblock"] . " / кнопка РАЗБЛОКИРОВАТЬ IP — удаляет это правило.`n"
        . " При закрытии скрипта правило удаляется автоматически.`n"
        . " " . Binds["Freeze"] . " / кнопка ЗАМОРОЗИТЬ — приостанавливает`n"
        . "процесс из поля ввода (по умолчанию '" . ProcessName . "') на 10 сек.`n"
        . "Работает через NtSuspendProcess (стоп всех потоков сразу),`n"
        . "через 10 сек сама вызывает NtResumeProcess и возобновляет.`n`n"
        . "Кнопка 'Поверх всех окон' — закрепляет окно поверх других приложений.`n"
        . "Настройка клавиш — открывает окно смены биндов. Нажмите 'Изменить'`n"
        . "у нужного действия и сразу нажмите новую клавишу (5 сек на ввод).`n"
        . "Бинды хранятся только в памяти скрипта, без .ini файла —`n"
        . "при перезапуске скрипта они сбрасываются на значения по умолчанию.`n"
        . " Кнопка ▁ — сворачивает окно в трей, скрипт работает в фоне.`n"
        . " Кнопка ✕ — полностью закрывает скрипт (правило брандмауэра будет удалено).`n"
        . " Также можно закрыть через трей — ПКМ по иконке → 'Выход'.`n`n"
        . " Все окна можно двигать за любую пустую часть.`n`n"

    HelpGuiRef.Add("Text", "w440 x20 y+20", helpText)

    HelpGuiRef.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
    OkBtn := HelpGuiRef.Add("Button", "w440 h35 x20 y+15 Background" . COLOR_PANEL, "Понятно")
    ; ИСПРАВЛЕНО: обнуляем HelpGuiRef после закрытия, иначе ссылка на
    ; уничтоженный объект остаётся и ломает следующую проверку в drag-обработчике
    ; (WM_LBUTTONDOWN) — именно из-за этого при повторном открытии справки
    ; выскакивала ошибка на HelpGuiRef.Hwnd.
    OkBtn.OnEvent("Click", (*) => CloseHelpWindow())

    HelpGuiRef.Show("w480")
}

; НОВОЕ: единая функция закрытия окна справки — уничтожает Gui и
; обязательно обнуляет HelpGuiRef, чтобы не осталось "мёртвой" ссылки.
CloseHelpWindow(*) {
    global HelpGuiRef
    if IsSet(HelpGuiRef) && HelpGuiRef
        try HelpGuiRef.Destroy()
    HelpGuiRef := ""
}

; ============================================================================
;   13. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
; ============================================================================

; --- НОВОЕ: анимация нажатия кнопки — короткое "сжатие" и возврат к исходному размеру ---
PulseButton(ctrl) {
    try {
        ctrl.GetPos(&x, &y, &w, &h)
    } catch {
        return
    }
    shrink := 3
    ctrl.Move(x + shrink, y + shrink // 2, w - shrink * 2, h - shrink)
    Sleep(35)
    ctrl.Move(x, y, w, h)
}

; --- НОВОЕ: обёртка — добавляет PulseButton к любому обработчику Click, не меняя его логику ---
WrapWithPulse(originalHandler) {
    return (ctrl, info) => (PulseButton(ctrl), originalHandler(ctrl, info))
}

ShowNotification(text, color) {
    global NotifyGuiRef
    if IsSet(NotifyGuiRef) && NotifyGuiRef
        try NotifyGuiRef.Destroy()

    NotifyGuiRef := Gui("-Caption +AlwaysOnTop +ToolWindow")
    NotifyGuiRef.BackColor := color
    NotifyGuiRef.SetFont("s19 cWhite Bold", "Segoe UI")
    NotifyGuiRef.Add("Text", "Center w300 h50", text)
    NotifyGuiRef.Show("NoActivate w330 h50 xCenter y50")
    SetTimer(CloseNotify, -1500)
}

CloseNotify() {
    global NotifyGuiRef
    if IsSet(NotifyGuiRef) && NotifyGuiRef
        try NotifyGuiRef.Destroy()
}

ShowTip(text) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -1500)
}

OpenFirewallMonitor(*) {
    try Run("wf.msc")
    catch {
        ShowTip("Не удалось открыть монитор брандмауэра")
    }
}

; ============================================================================
;   АВТООБНОВЛЕНИЕ ЧЕРЕЗ GITHUB
; ============================================================================
; Проверяет version.txt в репозитории, и если там версия новее той,
; что зашита в ScriptVersion — предлагает скачать и применить обновление.
CheckForUpdates(silent := false) {
    global ScriptVersion, UpdateVersionURL

    remoteVersion := ""
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", UpdateVersionURL . "?cb=" . A_TickCount, false)
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()
        if (whr.Status = 200)
            remoteVersion := Trim(whr.ResponseText, " `t`r`n")
    } catch {
        if !silent
            ShowTip("Не удалось проверить обновления (нет соединения?)")
        return
    }

    if (remoteVersion = "") {
        if !silent
            ShowTip("Не удалось получить данные о версии")
        return
    }

    if (remoteVersion != ScriptVersion) {
        result := MsgBox(
            "Доступна новая версия: " . remoteVersion . "`nТекущая версия: " . ScriptVersion . "`n`nОбновить сейчас?",
            "Nova Void — обновление", "YesNo Icon!")
        if (result = "Yes")
            DownloadAndApplyUpdate()
    } else if !silent {
        ShowTip("У вас установлена последняя версия (" . ScriptVersion . ")")
    }
}

; Скачивает актуальный .ahk из репозитория, подменяет им текущий файл
; скрипта и перезапускает его через Reload().
DownloadAndApplyUpdate() {
    global UpdateScriptURL

    tempPath := A_Temp . "\NovaVoid_update.ahk"

    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", UpdateScriptURL . "?cb=" . A_TickCount, false)
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()

        if (whr.Status != 200 || whr.ResponseText = "") {
            ShowTip("Ошибка загрузки обновления (код " . whr.Status . ")")
            return
        }

        if FileExist(tempPath)
            FileDelete(tempPath)
        FileAppend(whr.ResponseText, tempPath, "UTF-8")
    } catch as e {
        ShowTip("Ошибка загрузки: " . e.Message)
        return
    }

    try {
        FileCopy(tempPath, A_ScriptFullPath, true)
        ShowTip("Обновление применено, перезапуск...")
        Sleep(800)
        Reload()
    } catch as e {
        ShowTip("Не удалось применить обновление: " . e.Message)
    }
}
