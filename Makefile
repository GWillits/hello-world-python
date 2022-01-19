SAFETY_OUTPUT := "bare"

install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry

install-ci:
	
	poetry install --no-dev --remove-untracked
	. .venv/bin/activate
	poetry run pip list

safety-ci:
	. .venv/bin/activate
	@echo "$(shell sh -c 'poetry run safety check --$(SAFETY_OUTPUT)')"
