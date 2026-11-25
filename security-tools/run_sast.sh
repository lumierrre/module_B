#!/usr/bin/env bash
# Запуск статического анализа без изменения файлов микросервиса.
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
project_dir=$(cd -- "$script_dir/.." && pwd)
source_dir=${SOURCE_DIR:-"$project_dir/microservice"}
config=${SEMGREP_RULES:-"$project_dir/static-analysis/config/semgrep-rules.yml"}
results_dir=${1:-}

fail() { printf 'Ошибка: %s\n' "$1" >&2; exit 1; }
command -v semgrep >/dev/null 2>&1 || fail 'Semgrep не установлен.'
[[ -d "$source_dir/app" && -f "$source_dir/docker-compose.yml" ]] || fail "Не найден исходный проект: $source_dir"
[[ -f "$config" ]] || fail "Не найден файл правил: $config"
[[ ${ADD_MANUAL_IDOR:-1} == 0 || ${ADD_MANUAL_IDOR:-1} == 1 ]] || fail 'ADD_MANUAL_IDOR должен быть 0 или 1.'
if [[ ${ADD_MANUAL_IDOR:-1} == 1 ]]; then
    command -v python3 >/dev/null 2>&1 || fail 'Требуется Python 3.'
fi

config=$(cd -- "$(dirname -- "$config")" && printf '%s/%s\n' "$PWD" "$(basename -- "$config")")
if [[ -z "$results_dir" ]]; then
    mkdir -p -- "$project_dir/static-analysis/generated"
    results_dir=$(mktemp -d "$project_dir/static-analysis/generated/run-XXXXXXXX")
else
    mkdir -p -- "$results_dir"
fi
results_dir=$(cd -- "$results_dir" && pwd)
for name in semgrep-results.json semgrep-results-with-idor.json semgrep-version.txt; do
    [[ ! -e "$results_dir/$name" && ! -L "$results_dir/$name" ]] || fail "Отказ от перезаписи: $results_dir/$name"
done
[[ "$results_dir" != "$project_dir/static-analysis/reports" ]] || fail 'Каталог reports зарезервирован для исходных доказательств.' 
export SEMGREP_SEND_METRICS=off

cd -- "$source_dir"
printf 'Проверка конфигурации Semgrep...\n'
semgrep --version | tee "$results_dir/semgrep-version.txt"
semgrep scan --validate --config "$config" --metrics=off

printf 'Анализ Python и Docker Compose...\n'
raw="$results_dir/semgrep-results.json"
semgrep scan \
    --config "$config" \
    --metrics=off \
    --no-git-ignore \
    --no-rewrite-rule-ids \
    --json --output "$raw" \
    app/*.py docker-compose.yml

if [[ ${ADD_MANUAL_IDOR:-1} == 1 ]]; then
    python3 "$script_dir/append_manual_finding.py" \
        "$raw" "$results_dir/semgrep-results-with-idor.json"
fi
printf 'Отчёты сохранены: %s\n' "$results_dir"
