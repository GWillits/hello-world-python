install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry

install-ci:
	source $(poetry env info --path)/bin/activate
	poetry install --no-dev --remove-untracked
	pip list