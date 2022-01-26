SHELL:=/usr/bin/env bash -O globstar
.SHELLFLAGS = -ec
.PHONY: build dist
.DEFAULT_GOAL := list

list:
	@grep '^[^#[:space:]].*:' Makefile

guard-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi

dirname := $(notdir $(patsubst %/,%,$(CURDIR)))

build:
	mkdir -p build
	@if [ -f pyproject.toml ]; then \
		poetry export -f requirements.txt --output build/requirements.txt; \
		poetry run pip install --target build -r build/requirements.txt; \
		rm build/requirements.txt; \
		find ./build -type d -name '__pycache__' | xargs rm -rf; \
		test -f "function.py" && cp function.py build/function.py 2> /dev/null || :; \
	fi
	@if [ -f package.json ]; then \
  		cp package*.json build; \
		cp index.js build; \
  		pushd build; npm install; find -type f -name 'package.json' | xargs rm;  popd; \
  	fi


purge:
	rm -rf .venv || true
	rm -rf node_modules || true
	rm -rf build || true
	rm -rf dist || true
	rm -rf .mypy_cache || true



install:
	if [ -f pyproject.toml ]; then \
		../_shared/poetry-install.sh; \
	fi
	if [ -f package.json ]; then \
  		npm install; \
  		npm prune || true; \
	fi

reinstall: purge install

mypy:
	@if [ -f function.py ]; then \
		poetry run mypy ./ ../../src  --exclude '.venv|\.mypy_cache|build|dist|site-packages|node_modules|__pycache__'; \
	fi

--dist-shared: build
	@if [[ "$(dirname)" =~ ^_layer.* ]]; then \
		mv build python; \
		mkdir -p build; \
		mv python build; \
	fi
	mkdir -p dist	
	find ./build -exec touch -t 201401010000 {} +

#this localstack version exists because localstack free doesn't support lambda layers. 
#so instead it copies the dependencies into the the zip file.
dist-localstack: --dist-shared
	@if [ -f _layer_boto ]; then \
		rsync -a --exclude 'build' --exclude 'dist' ../_layer_boto/build/python/ ./build/; \
	fi; \
	cd build && zip -q -X -r ../dist/$(dirname).zip .

#this target is intended for aws so creates a lambda layers compatible zip file with 
#all the dependencies in a python folder, which is "base" in our project.
dist: --dist-shared
	cd build && zip -q -X -r ../../dist/$(dirname).zip .

clean:
	rm -rf build || true
	rm -rf dist || true

./.venv/bin/pytest:
	@../_shared/poetry-install.sh

test: ./.venv/bin/pytest
	@rc=0;poetry run pytest ./ || rc=$$?; \
	if [ "$${rc}" != "0" ] && [ "$${rc}" != "5" ]; then \
	  echo "tests failed! $${rc}"; \
	  exit $$rc; \
    fi

scan:
	poetry run python -m bandit -r $(dirname)
	poetry export --without-hashes -f requirements.txt | poetry run python -m  safety check --full-report --stdin

echo:
	echo $(dirname)

safety:
	echo "FOUND $$safety_action $$workspace $$detail $$publish_artifacts" \ 
	@if [ -f pyproject.toml ]; then \
		poetry export -f requirements.txt --output requirements.txt;  \
		../../scripts/safety-scan.sh $$safety_action $$workspace $$detail $$publish_artifacts; \
		else \
			echo "Not python package - skipping"; \
	fi