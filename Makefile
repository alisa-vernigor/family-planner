.PHONY: test test-watch coverage coverage-report

test:
	flutter test

test-watch:
	flutter test --watch

# Показать coverage-статистику (требует lcov, ставится brew install lcov)
coverage:
	flutter test --coverage
	@echo ""
	@lcov --summary coverage/lcov.info 2>&1 | grep -E 'lines\.*:' | sed 's/^/  /'

# Сгенерировать HTML-отчёт и проверить порог (по умолчанию 60%)
coverage-report:
	@./scripts/check_coverage.sh 60

# Открыть HTML-отчёт в браузере
coverage-open:
	open coverage/report/index.html
