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
;    4. ЗАСТАВКА ПРИ ЗАПУСКЕ (без Fade-In — эффект "разрастания")
;    5. ГЛАВНОЕ ОКНО (GUI)
;    6. ТЕНЬ ОКНА / ПЕРЕТАСКИВАНИЕ ЗА ЛЮБУЮ ОБЛАСТЬ
;    7. РЕГИСТРАЦИЯ ГОРЯЧИХ КЛАВИШ
;    8. ТРЕЙ (значок в системном трее)
;    9. ЛОГИКА: БЛОКИРОВКА / РАЗБЛОКИРОВКА IP (netsh advfirewall)
;   10. ЛОГИКА: ЗАМОРОЗКА / РАЗМОРОЗКА ПРОЦЕССА (NtSuspend/NtResumeProcess)
;   11. ОКНО СМЕНЫ БИНДОВ (кнопка ⌨)
;   
;   13. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (тултипы, уведомления, монитор брандмауэра)
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
ScriptVersion     := "1.1"  ; версия текущего скрипта — меняй при каждом релизе
; Ссылки на "сырые" файлы в твоём репозитории (замени USERNAME/REPO/BRANCH):
UpdateVersionURL  := "https://raw.githubusercontent.com/D31DARA/Nova-Void/main/version.txt"
UpdateScriptURL   := "https://raw.githubusercontent.com/D31DARA/Nova-Void/main/NovaSync.ahk"

global g_hProcess    := 0
global g_isSuspended := false

; ============================================================================
;   2. ЦВЕТОВАЯ ПАЛИТРА
; ============================================================================
COLOR_BG      := "141414"   ; фон окна — почти чёрный
COLOR_PANEL   := "232323"   ; фон элементов управления — тёмно-серый
COLOR_ACCENT  := "C1121F"   ; акцентный красный — заголовки, важные кнопки
COLOR_ACCENT2 := "2E2E2E"   ; второй акцент — нейтральные кнопки/панели
COLOR_TEXT    := "E5E5E5"   ; основной текст
COLOR_MUTED   := "9C9C9C"   ; второстепенный текст

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
;   4. ЗАСТАВКА ПРИ ЗАПУСКЕ (эффект "разрастания" из центра, без Fade-In)
; ============================================================================
ShowSplash()

ShowSplash() {
    global COLOR_BG, COLOR_ACCENT, COLOR_TEXT

    splash := Gui("-Caption +AlwaysOnTop +ToolWindow", "Splash")
    splash.BackColor := COLOR_BG
    splash.SetFont("s20 Bold c" . COLOR_ACCENT, "Segoe UI")
    splash.Add("Text", "w300 h60 Center x20 y25", "◈ NOVA VOID")
    splash.SetFont("s9 c" . COLOR_MUTED, "Segoe UI")
    splash.Add("Text", "w300 h20 Center x20 y+5", "Cayo Perico Toolkit")

    targetW := 340, targetH := 130
    startW  := 40,  startH  := 16
    cx := A_ScreenWidth  // 2
    cy := A_ScreenHeight // 2

    splash.Show("Hide w" . targetW . " h" . targetH)

    steps := 14
    Loop steps {
        f := A_Index / steps
        ; ease-out — быстрый рост в начале, плавное замедление к концу
        f := 1 - (1 - f)**2
        w := Round(startW + (targetW - startW) * f)
        h := Round(startH + (targetH - startH) * f)
        x := cx - w // 2
        y := cy - h // 2
        splash.Show("x" . x . " y" . y . " w" . w . " h" . h . " NoActivate")
        Sleep(16)
    }

    Sleep(650)
    splash.Destroy()
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
MyGui.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
KeyBtn   := MyGui.Add("Button", "w30 h30 x260 y15 Background" . COLOR_PANEL, "⌨")
HelpBtn  := MyGui.Add("Button", "w30 h30 x295 y15 Background" . COLOR_PANEL, "?")
MinBtn   := MyGui.Add("Button", "w30 h30 x330 y15 Background" . COLOR_PANEL, "▁")
CloseBtn := MyGui.Add("Button", "w30 h30 x365 y15 Background" . COLOR_PANEL, "✕")
KeyBtn.OnEvent("Click", OpenBindEditor)
HelpBtn.OnEvent("Click", OnHelpClick)
MinBtn.OnEvent("Click", MinimizeToTray)
CloseBtn.OnEvent("Click", (*) => ExitApp())  ; крестик полностью закрывает скрипт

; --- Статус блокировки IP ---
MyGui.SetFont("s10 c" . COLOR_TEXT, "Segoe UI")
StatusText := MyGui.Add("Text", "w375 h22 x20 y+10 Center", "Статус: " . CurrentStatus)

; --- Кнопки блокировки/разблокировки IP ---
MyGui.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
DisableBtn := MyGui.Add("Button", "w375 h45 x20 y+15 Background" . COLOR_ACCENT,
    "🔒  ЗАБЛОКИРОВАТЬ IP  (" . Binds["Block"] . ")")
EnableBtn  := MyGui.Add("Button", "w375 h45 x20 y+10 Background" . COLOR_ACCENT2,
    "🔓  РАЗБЛОКИРОВАТЬ IP  (" . Binds["Unblock"] . ")")
DisableBtn.OnEvent("Click", DisableInternet)
EnableBtn.OnEvent("Click", EnableInternet)

; --- Разделитель перед новым блоком ---
MyGui.Add("Text", "w375 x20 h1 y+15 Background" . COLOR_PANEL)

; --- Заморозка процесса: поле с именем процесса ---
MyGui.SetFont("s9 Norm c" . COLOR_MUTED, "Segoe UI")
MyGui.Add("Text", "w375 h20 x20 y+10", "Процесс для заморозки:")
EditField := MyGui.Add("Edit", "w375 x20 y+5 h25 Background" . COLOR_PANEL . " c" . COLOR_TEXT, ProcessName)

; --- Кнопка заморозки на 10 секунд ---
MyGui.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
FreezeBtn := MyGui.Add("Button", "w375 h45 x20 y+10 Background" . COLOR_ACCENT2,
    "⏸  ЗАМОРОЗИТЬ  (" . Binds["Freeze"] . ")")
FreezeBtn.OnEvent("Click", OnFreezeClick)

; --- Статус заморозки ---
MyGui.SetFont("s9 Norm c" . COLOR_MUTED, "Segoe UI")
FreezeStatusText := MyGui.Add("Text", "w375 h20 x20 Center y+10", "Статус заморозки: ожидание")

; --- Копирайт ---
MyGui.SetFont("s10 c" . COLOR_MUTED, "Segoe UI")
MyGui.Add("Text", "w375 h20 x20 Center y+15", "© Turtle V")

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
MyGui.Show("w415 h435")

; Тихая проверка обновлений через несколько секунд после запуска
SetTimer(() => CheckForUpdates(true), -3000)

OnMessage(0x0201, WM_LBUTTONDOWN)
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global MyGui
    if (hwnd = MyGui.Hwnd) {
        PostMessage(0xA1, 2, 0, , "ahk_id " . hwnd)
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
    global MyGui
    MyGui.Show()
}

TrayCheckUpdates(*) {
    CheckForUpdates(false)
}

TrayExitApp(*) {
    ExitApp()
}

MinimizeToTray(*) {
    global MyGui
    MyGui.Hide()
    TrayTip("Nova Void", "Скрипт свёрнут в трей.`nЛКМ по иконке — открыть окно.")
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

; ============================================================================
;   10. ЛОГИКА: ЗАМОРОЗКА / РАЗМОРОЗКА ПРОЦЕССА
; ============================================================================
OnFreezeClick(*) {
    FreezeProcess()
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

    ShowTip("'" . targetProcess . "' приостановлен на 10 секунд")
    FreezeStatusText.Text := "Статус заморозки: заморожен на 10 сек..."

    SetTimer(ResumeProcess, -10000)
}

ResumeProcess() {
    global g_hProcess, g_isSuspended, FreezeStatusText

    if (!g_hProcess)
        return

    DllCall("ntdll.dll\NtResumeProcess", "Ptr", g_hProcess, "Int")

    ShowTip("Процесс возобновлён")
    FreezeStatusText.Text := "Статус заморозки: возобновлён"
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
    closeBtn.OnEvent("Click", (*) => BindGuiRef.Destroy())

    BindGuiRef.Show("w400")
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
;   
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
        . " При закрытии скрипта правило удаляется автоматически.`n`n"
        . " " . Binds["Freeze"] . " / кнопка ЗАМОРОЗИТЬ — приостанавливает`n"
        . "процесс из поля ввода (по умолчанию '" . ProcessName . "') на 10 сек.`n"
        . "Работает через NtSuspendProcess (стоп всех потоков сразу),`n"
        . "через 10 сек сама вызывает NtResumeProcess и возобновляет.`n`n"
        . "⌨ Кнопка — открывает окно смены биндов. Нажмите 'Изменить'`n"
        . "у нужного действия и сразу нажмите новую клавишу (5 сек на ввод).`n"
        . "Бинды хранятся только в памяти скрипта, без .ini файла —`n"
        . "при перезапуске скрипта они сбрасываются на значения по умолчанию.`n`n"
        . " Кнопка ▁ — сворачивает окно в трей, скрипт работает в фоне.`n"
        . " Кнопка ✕ — полностью закрывает скрипт (правило брандмауэра будет удалено).`n"
        . " Также можно закрыть через трей — ПКМ по иконке → 'Выход'.`n`n"
        . " Окно можно двигать за любую пустую часть.`n`n"
        . " Автообновление: ПКМ по иконке в трее → 'Проверить обновления'.`n"
        . "Скрипт сверяется с version.txt в GitHub-репозитории и, если`n"
        . "там версия новее, предлагает скачать и применить обновление."

    HelpGuiRef.Add("Text", "w440 x20 y+20", helpText)

    HelpGuiRef.SetFont("s11 Bold c" . COLOR_TEXT, "Segoe UI")
    OkBtn := HelpGuiRef.Add("Button", "w440 h35 x20 y+15 Background" . COLOR_PANEL, "Понятно")
    OkBtn.OnEvent("Click", (*) => HelpGuiRef.Destroy())

    HelpGuiRef.Show("w480")
}

; ============================================================================
;   13. ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
; ============================================================================
ShowNotification(text, color) {
    global NotifyGuiRef
    if IsSet(NotifyGuiRef) && NotifyGuiRef
        try NotifyGuiRef.Destroy()

    NotifyGuiRef := Gui("-Caption +AlwaysOnTop +ToolWindow")
    NotifyGuiRef.BackColor := color
    NotifyGuiRef.SetFont("s16 cWhite Bold", "Segoe UI")
    NotifyGuiRef.Add("Text", "Center w300 h50", text)
    NotifyGuiRef.Show("NoActivate w300 h50 xCenter y20")
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
        whr.Open("GET", UpdateVersionURL, false)
        whr.SetRequestHeader("Cache-Control", "no-cache")
        whr.Send()
        if (whr.Status = 200)
            remoteVersion := Trim(whr.ResponseText)
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
        whr.Open("GET", UpdateScriptURL, false)
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
