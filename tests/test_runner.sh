#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_DIR="$SCRIPT_DIR/test_env"
CLEANUP_SH="$SCRIPT_DIR/../src/cleanup.sh"


fail() {
    echo "Ошибка: $1" >&2
    rm -rf "$TEST_DIR"
    exit 1
}

prepare_env() {
    rm -rf "$TEST_DIR"
    mkdir -p "$TEST_DIR/log" "$TEST_DIR/backup"
}

make_file() {
    dd if=/dev/zero of="$TEST_DIR/log/$1" bs=1048576 count="$2" 2>/dev/null
    touch -t "$3" "$TEST_DIR/log/$1"
}

count_backups() {
    ls "$TEST_DIR/backup" | wc -l | tr -d ' '
}


echo "=========================================="
echo "Запуск теста 1: Заполнение ниже порога"
echo "=========================================="
prepare_env
make_file file1.log 200 202001010000
make_file file2.log 200 202001020000
make_file file3.log 200 202001030000
echo "Создано файлов на 600 MB (требование >= 0.5 GB соблюдено)"

"$CLEANUP_SH" "$TEST_DIR/log" 70 "$TEST_DIR/backup" 1200

[ "$(count_backups)" -eq 0 ]       || fail "архив не должен был создаваться!"
[ -f "$TEST_DIR/log/file1.log" ]   || fail "файлы не должны были удаляться!"
echo "Тест 1 успешно пройден!"


echo "=========================================="
echo "Запуск теста 2: Заполнение выше порога (tar.gz)"
echo "=========================================="
prepare_env
make_file app_old.log  180 202001010000
make_file app_mid1.log 120 202001020000
make_file app_mid2.log 250 202001030000
make_file app_new.log  300 202001040000
echo "Создано файлов на 850 MB (требование >= 0.5 GB соблюдено)"

"$CLEANUP_SH" "$TEST_DIR/log" 70 "$TEST_DIR/backup" 1000

[ ! -f "$TEST_DIR/log/app_old.log" ]  || fail "старый файл не был удален!"
[ -f "$TEST_DIR/log/app_mid1.log" ]   || fail "свежие файлы были ошибочно удалены!"
ls "$TEST_DIR"/backup/*.tar.gz >/dev/null 2>&1 || fail "архив tar.gz не найден!"
tar -tzf "$TEST_DIR"/backup/*.tar.gz | grep -q "app_old.log" \
                                      || fail "app_old.log отсутствует в архиве!"
echo "Тест 2 успешно пройден!"


echo "=========================================="
echo "Запуск теста 3: Удаление нескольких файлов по возрасту"
echo "=========================================="
prepare_env
make_file log_1.log 150 202001010000
make_file log_2.log 200 202001020000
make_file log_3.log 250 202001030000
make_file log_4.log 300 202001040000
echo "Создано файлов на 900 MB (требование >= 0.5 GB соблюдено)"

"$CLEANUP_SH" "$TEST_DIR/log" 60 "$TEST_DIR/backup" 1000

[ ! -f "$TEST_DIR/log/log_1.log" ] || fail "log_1.log не удален!"
[ ! -f "$TEST_DIR/log/log_2.log" ] || fail "log_2.log не удален!"
[ -f "$TEST_DIR/log/log_3.log" ]   || fail "log_3.log был ошибочно удален!"
echo "Тест 3 успешно пройден!"


echo "=========================================="
echo "Запуск теста 4 (на 9-10 баллов): LZMA сжатие"
echo "=========================================="
prepare_env
make_file data_old.log 200 202001010000
make_file data_new.log 600 202001020000
echo "Создано файлов на 800 MB (требование >= 0.5 GB соблюдено)"

LAB1_MAX_COMPRESSION=1 "$CLEANUP_SH" "$TEST_DIR/log" 70 "$TEST_DIR/backup" 1000

ls "$TEST_DIR"/backup/*.tar.lzma >/dev/null 2>&1 || fail "архив tar.lzma не найден!"
[ ! -f "$TEST_DIR/log/data_old.log" ]            || fail "старый файл не удален!"
echo "Тест 4 успешно пройден!"


rm -rf "$TEST_DIR"

echo "=========================================="
echo "Все тесты успешно пройдены!"
echo "=========================================="