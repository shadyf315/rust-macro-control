<div align="center">

# Утилита для рейдов в Rust

Локальная Windows-утилита с BAT-макросом для последовательного выполнения действий в игровом интерфейсе Rust.

**Версия: v1.1.0** — макрос автоматически ставится на паузу после каждых пяти завершённых циклов.

[![Скачать ZIP](https://img.shields.io/badge/Скачать-ПОСЛЕДНИЙ_ZIP-c3f36b?style=for-the-badge&logo=github&logoColor=101310)](https://github.com/shadyf315/rust-macro-control/archive/refs/heads/main.zip)
[![Открыть сайт](https://img.shields.io/badge/САЙТ-Rust_Macro_Control-202820?style=for-the-badge&logo=googlechrome&logoColor=c3f36b)](https://shadyf315.github.io/rust-macro-control/)
[![Все релизы](https://img.shields.io/badge/GitHub-Релизы-fa8754?style=for-the-badge&logo=github&logoColor=white)](https://github.com/shadyf315/rust-macro-control/releases)

</div>

## Русский

Скачай ZIP-архив проекта по бейджу выше. В нём находятся BAT-файл, список и файлы сайта.

### Как работает пауза для ручного возрождения

После каждых пяти полностью завершённых циклов макрос автоматически ставится на паузу и сохраняет позицию списка. Возродись вручную у первого отмеченного спальника, вернись в игру и нажми **Right Shift**, чтобы продолжить со следующей записи. Клавиша Right Shift также вручную ставит цикл на паузу и возобновляет его. Она не закрывает программу.

### Файлы

- `RustMacroControl.bat` — программа и меню макроса
- `digits.txt` — список четырёхзначных записей, используемый макросом
- `digits.example.txt` — пример формата списка

В `digits.txt` каждая запись находится на отдельной строке. Файл должен лежать рядом с BAT; его можно заменить своим списком.

## English

Download the project ZIP using the badge above. It contains the BAT file, list, and website files.

### Manual respawn pause

After every five fully completed cycles, the macro pauses automatically and saves the list position. Respawn manually at the first marked sleeping bag, switch back to the game, and press **Right Shift** to continue with the next entry. Right Shift also pauses and resumes the cycle manually; it does not exit the program.

### Files

- `RustMacroControl.bat` — macro program and menu
- `digits.txt` — four-digit entries used by the macro
- `digits.example.txt` — example list format

Each entry in `digits.txt` is on a separate line. Keep the file next to the BAT; you can replace it with your own list.
