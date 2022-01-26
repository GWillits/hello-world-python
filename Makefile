install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry

install-ci:
	poetry install --no-dev --remove-untracked


map-py-requirements:
	@if [ ! -f requirements.txt  ]; then poetry export -f requirements.txt --output requirements.txt; fi;

safety: map-py-requirements 
	@./scripts/safety-scan.sh

safety-ci: map-py-requirements
	@pip install safety
	@./scripts/safety-scan.sh ${action} ${workspace} ${detail} ${publish_artifacts}

safety-ci-lambdas: map-py-requirements
	@pip install safety
	@make -C lambda safety safety_action=${action} publish_artifacts=${publish_artifacts}

install-sonar-cli:
	if [ ! -f scanner/sonar-scanner.zip  ]; then \
		wget https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-4.6.2.2472-linux.zip -O scanner/sonar-scanner.zip; \
		unzip ./scanner/sonar-scanner.zip -d scanner/sonar-scanner; \
	fi; \


sonar-scan-code: 
	@./scripts/setup-sonar.sh 
