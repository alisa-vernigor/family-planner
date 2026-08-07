.PHONY: test test-watch coverage coverage-report analyze analyze-file coverage-open analyze analyze-file

test:
	flutter test

test-watch:
	flutter test --watch

# Быстрая итерация: точечный анализ файла (секунды вместо минут)
# Использование: make analyze-file FILE=lib/features/tasks/domain/entities/task.dart
analyze-file:
	dart analyze $(FILE)

# Полный анализ (медленно — только в финале, см. /verify)
analyze:
	dart analyze lib test

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
