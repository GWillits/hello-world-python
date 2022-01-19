install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry

install-ci:
	poetry install --no-dev --remove-untracked
	source $(poetry env info --path)/bin/activate
	pip list

safety-check:
	poetry run safety check --bare