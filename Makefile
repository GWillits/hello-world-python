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
	@if [ ! -f requirements.txt  ]; then poetry export -f requirements.txt --output requirements.txt; fi;

safety: map-requirements
	@./scripts/safety-scan.sh ${safety_action}

safety-ci: map-requirements
	#@pip install safety && \
	./scripts/safety-scan.sh ${safety_action} ${workspace}

