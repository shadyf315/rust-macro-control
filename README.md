# Rust Macro Control

Локальная Windows-утилита с BAT-макросом для действий в игровом интерфейсе Rust.

**Текущая стабильная версия: v2.0.0**

[![Скачать последний релиз](https://img.shields.io/badge/Скачать-Последний_релиз-c3f36b?style=for-the-badge&logo=github&logoColor=101310)](https://github.com/shadyf315/rust-macro-control/releases/latest)
[![Открыть сайт](https://img.shields.io/badge/Сайт-Rust_Macro_Control-202820?style=for-the-badge&logo=googlechrome&logoColor=c3f36b)](https://shadyf315.github.io/rust-macro-control/)
[![Все релизы](https://img.shields.io/badge/GitHub-Релизы-fa8754?style=for-the-badge&logo=github&logoColor=white)](https://github.com/shadyf315/rust-macro-control/releases)

## Русский

### Перед запуском

1. Скачай и распакуй ZIP последнего релиза.
2. Оставь `RustMacroControl.bat` и `digits.txt` в одной папке. В архиве есть список цифр.
3. При запуске выбери язык: `1` — русский, `2` — английский.

### Управление

1. В главном меню выбери пункт управления.
2. Перед панелью управления появится обязательная инструкция. Прочитай её и введи `1` для подтверждения; `0` закрывает программу.
3. Переключись в Rust и нажми **Right Shift**, чтобы запустить макрос. Повторное нажатие Right Shift ставит его на паузу или продолжает с текущего шага.
4. Цифровые команды меню работают, когда окно BAT в фокусе: `1` запуск/продолжение, `2` сброс списка, `3` пропуск записи, `4` просмотр списка, `0` выход.
5. После каждых пяти завершённых циклов макрос ставится на паузу. Возродись вручную у первого отмеченного спальника и нажми Right Shift, чтобы продолжить со следующей записью.
6. Позиция списка хранится в `.digits-index`. Не удаляй этот файл, если нужно продолжить с сохранённой позиции.

## English

### Before you start

1. Download and extract the latest release ZIP.
2. Keep `RustMacroControl.bat` and `digits.txt` in the same folder. The ZIP includes the digit list.
3. At startup, choose a language: `1` for Russian or `2` for English.

### Controls

1. Choose the control option in the main menu.
2. A required guide appears before the control panel. Read it and enter `1` to confirm; `0` exits.
3. Switch to Rust and press **Right Shift** to start the macro. Press Right Shift again to pause or resume from the current step.
4. Number commands work while the BAT window is focused: `1` start/resume, `2` reset list, `3` skip entry, `4` view list, `0` exit.
5. The macro pauses after every five completed cycles. Respawn manually at the first marked sleeping bag, then press Right Shift to continue with the next entry.
6. The list position is stored in `.digits-index`. Keep this file to resume from the saved position.

---

Independent community project. Not affiliated with Facepunch or Rust.
