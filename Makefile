.PHONY: help docker-up docker-down ci ai-install ai-run ai-test mobile-get mobile-test

help:
	@echo "MyAaptha development commands"
	@echo "  make docker-up      Start local infrastructure"
	@echo "  make docker-down    Stop local infrastructure"
	@echo "  make ci             Run validation steps"
	@echo "  make ai-install     Install AI service dependencies"
	@echo "  make ai-run         Run AI service locally"
	@echo "  make ai-test        Run AI service tests"
	@echo "  make mobile-get     Install Flutter mobile dependencies"
	@echo "  make mobile-test    Run Flutter mobile tests"

docker-up:
	docker compose up -d

docker-down:
	docker compose down

ci:
	$(MAKE) ai-test
	cd frontend/nextjs-app && npm ci && npm run build
	cd backend/spring-boot-app && mvn --batch-mode test
	cd mobile/flutter-app && flutter test

ai-install:
	python -m pip install -r ai/agent-service/requirements.txt

ai-run:
	uvicorn ai_service.main:app --app-dir ai/agent-service/src --host 0.0.0.0 --port 8081

ai-test:
	python -m pytest ai/agent-service/tests -q

mobile-get:
	flutter pub get --directory mobile/flutter-app

mobile-test:
	cd mobile/flutter-app && flutter analyze && flutter test test
