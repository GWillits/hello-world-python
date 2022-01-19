install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry

install-ci:
	. .venv/bin/activate
	poetry install --no-dev --remove-untracked
	pip list

safety-check:
	poetry run safety check --bare