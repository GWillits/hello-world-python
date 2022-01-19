install:
	poetry install --remove-untracked

install-poetry:
	python3 -m pip install --user --upgrade pip && \
	python3 -m pip install --user poetry