#!/usr/bin/env bash

# force a clean poetry env (so won't inherit another active env)
source deactivate || true
poetry install --remove-untracked
