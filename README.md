# Модуль B — порядок сдачи

Исходники `microservice.zip` не изменялись. В комплекте:

- `module_b_report.pdf` — самостоятельно сформированный отчёт, не нативный экспорт OWASP Threat Dragon.
- `threat_dragon_model.json` — редактируемая модель в формате Threat Dragon v2.x, составленная по схеме и примерам. Импорт и рендеринг в самом приложении не проверены.
- `findings_review.json` — ручной реестр (15 находок/рисков, один неподтверждённый SQLi-кандидат и один блокер запуска); IDOR уже включена как V-02.
- `idor_manual.json` — отдельная ручная находка IDOR.
- `semgrep_rules.yml` — 10 локальных правил (часть из них отмечает кандидатов на ручную проверку, а не доказанные уязвимости).
- `rule_regex_precheck.json` — проверка регулярных выражений с помощью Python re, 11 совпадений; это НЕ вывод Semgrep.
- `merge_idor.py` — добавление IDOR к реально полученному JSON без изменения сырого отчёта.
- `tool_install.log` — результат попыток установки/доступа к инструментам в рабочей среде.

## 1. OWASP Threat Dragon

Установить настольную версию: https://www.threatdragon.com/docs/install/desktop.html или https://github.com/OWASP/threat-dragon/releases .
Открыть приложение, выбрать Open an existing threat model / Local, указать `threat_dragon_model.json`. Открыть диаграмму, проверить элементы, границы, подписи потоков и три угрозы. При необходимости поправить размещение элементов в интерфейсе. В модели severity = High (уровень Threat Dragon), а поле score указывает экспертную оценку Critical. Выбрать Report и Save as PDF / PDF Report (либо Print → Save as PDF). Сохранить как `threat_dragon_export.pdf`. Этот файл будет требуемым оригинальным экспортом. Владелец и рецензент не заполнены, поскольку ФИО не предоставлены.

Документация: https://www.threatdragon.com/docs/usage/getting-started.html

## 2. Semgrep

Распакуйте `microservice.zip` в отдельный каталог `microservice`. Распакуйте этот комплект в соседний каталог `module_b`. В терминале с Python 3 и доступом к PyPI выполните:

```bash
python -m pip install semgrep
semgrep --version
cd microservice
semgrep scan --validate --config ../module_b/semgrep_rules.yml
semgrep scan --config ../module_b/semgrep_rules.yml --metrics=off --disable-version-check --json --output ../module_b/semgrep_raw.json .
```

Дополнительно, при наличии доступа к реестру правил и согласованной политике безопасности:

```bash
semgrep scan --config auto --metrics=off --json --output ../module_b/semgrep_registry.json .
```

Проверить `errors`, `paths` и `results` в полученном JSON, наличие app/*.py и docker-compose.yml в охвате. При неполном охвате добавить `--include '*.py' --include '*.yml'`. Сохранить оригинал отдельно. Правила ориентированы на конкретную версию архива; совпадение с dynamic-sql-review не считать SQL Injection без анализа параметризации. Не выдавать результаты Python re за Semgrep. Если Semgrep не проходит валидацию, сверить синтаксис правил с установленной версией.

## 3. Добавление IDOR вручную

Из каталога `microservice`:

```bash
python ../module_b/merge_idor.py ../module_b/semgrep_raw.json ../module_b/idor_manual.json ../module_b/semgrep_with_idor.json
```

Скрипт сохраняет автоматические `results` без изменений и добавляет IDOR с явным `source: manual_review`. Не подменяет ошибочный или отсутствующий отчёт. Для сдачи приложить `semgrep_raw.json`, `semgrep_with_idor.json`, `semgrep_rules.yml`, нативный `threat_dragon_export.pdf` и модель. Данные статического анализа не доказывают эксплуатацию запущенного приложения. Исходники содержат несовпадающие импорты; динамические проверки вне области этой работы.
