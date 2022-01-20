install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry

install-ci:
	
	poetry install --no-dev --remove-untracked
	. .venv/bin/activate
	poetry run pip list

map-requirements:
	poetry export -f requirements.txt --output requirements.txt

safety:
	@./scripts/safety-scan.sh ${safety_action}
safety-ci:
	@pip install safety
	@./scripts/safety-scan.sh ${safety_action}

