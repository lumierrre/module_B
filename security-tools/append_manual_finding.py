#!/usr/bin/env python3
"""Дополняет копию JSON Semgrep результатом ручной проверки авторизации."""
import argparse
import json
import sys
from pathlib import Path

FINDING_ID = "manual.bank.idor-bola"


def authorization_finding():
    return {
        "check_id": FINDING_ID,
        "path": "app/crud.py",
        "start": {"line": 43, "col": 1},
        "end": {"line": 66, "col": 46},
        "extra": {
            "severity": "ERROR",
            "message": (
                "Контроль принадлежности счёта и выборка истории используют "
                "идентификатор клиента, полученный из непроверенного X-User-Id. "
                "При работоспособном API это допускает доступ к данным и "
                "операциям другого клиента."
            ),
            "metadata": {
                "source": "manual_review",
                "cwe": ["CWE-639"],
                "related": ["CWE-306"],
                "status": "conditional_static",
                "runtime_tested": False,
                "evidence": [
                    "app/security.py:3-13",
                    "app/main.py:13-24",
                    "app/crud.py:5-16",
                    "app/crud.py:43-66",
                ],
                "precondition": "Корректное связывание импортов и запуск API.",
                "recommendation": (
                    "Получать идентичность из проверенного токена, связывать "
                    "права с владельцем объекта и проверять изоляцию клиентов."
                ),
            },
        },
    }


def enrich(source: Path, destination: Path):
    if source.resolve() == destination.resolve():
        raise ValueError("Входной и выходной отчёты должны различаться.")
    if destination.exists() and source.samefile(destination):
        raise ValueError("Нельзя перезаписывать оригинальный отчёт.")
    data = json.loads(source.read_text(encoding="utf-8"))
    if (not isinstance(data, dict) or not isinstance(data.get("version"), str)
            or not isinstance(data.get("results"), list)
            or not all(isinstance(item, dict) for item in data["results"])):
        raise ValueError("Ожидается JSON-отчёт Semgrep с полями version и results.")
    if data.get("errors"):
        print("Внимание: отчёт содержит ошибки сканирования.", file=sys.stderr)

    results = data["results"]
    added = not any(item.get("check_id") == FINDING_ID for item in results)
    if added:
        results.append(authorization_finding())

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    return added, len(results)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Исходный JSON Semgrep")
    parser.add_argument("destination", type=Path, help="Дополненный JSON")
    args = parser.parse_args()
    try:
        added, count = enrich(args.source, args.destination)
    except (OSError, ValueError) as exc:
        parser.exit(1, f"Ошибка: {exc}\n")
    print(f"{'IDOR добавлена' if added else 'IDOR уже присутствует'}. Всего находок: {count}")


if __name__ == "__main__":
    main()
