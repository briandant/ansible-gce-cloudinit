DJANGO_IMAGE_NAME = dataexchange_production_django
POSTGRES_IMAGE_NAME = dataexchange_production_postgres
TRAEFIK_IMAGE_NAME = dataexchange_production_traefik
REDIS_IMAGE_NAME = redis:5.0
CELERYWORKER_IMAGE_NAME = dataexchange_production_celeryworker
CELERYBEAT_IMAGE_NAME = dataexchange_production_celerybeat
CELERYFLOWER_IMAGE_NAME = dataexchange_production_flower

GCR_PREFIX = gcr.io/dataexchange-redux-313019

DOCKER_COMPOSE ?= docker-compose
DOCKER ?= docker

# ============= Docker (Dockerfiles and Images) =============== #
.PHONY: push-images
push-images:
	@${DOCKER} tag ${DJANGO_IMAGE_NAME} ${GCR_PREFIX}/${DJANGO_IMAGE_NAME}
	@${DOCKER} tag ${POSTGRES_IMAGE_NAME} ${GCR_PREFIX}/${POSTGRES_IMAGE_NAME}
	@${DOCKER} tag ${TRAEFIK_IMAGE_NAME} ${GCR_PREFIX}/${TRAEFIK_IMAGE_NAME}
	@${DOCKER} tag ${REDIS_IMAGE_NAME} ${GCR_PREFIX}/${REDIS_IMAGE_NAME}
	@${DOCKER} tag ${CELERYWORKER_IMAGE_NAME} ${GCR_PREFIX}/${CELERYWORKER_IMAGE_NAME}
	@${DOCKER} tag ${CELERYBEAT_IMAGE_NAME} ${GCR_PREFIX}/${CELERYBEAT_IMAGE_NAME}
	@${DOCKER} tag ${CELERYFLOWER_IMAGE_NAME} ${GCR_PREFIX}/${CELERYFLOWER_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${DJANGO_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${POSTGRES_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${TRAEFIK_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${REDIS_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${CELERYWORKER_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${CELERYBEAT_IMAGE_NAME}
	@${DOCKER} push ${GCR_PREFIX}/${CELERYFLOWER_IMAGE_NAME}

.PHONY: webpack
webpack:
	$(eval LOCAL_USER_ID ?= $(shell id -u $$USER))
	@${DOCKER} run --rm -t \
		-e LOCAL_USER_ID=$(LOCAL_USER_ID) \
		-v `pwd`:/opt/wharf \
		--label $(WHARF_SYSTEM_CONTAINER_LABEL)=1 \
		${FRONTEND_IMAGE_NAME} /bin/bash -c \
	"cd /opt/wharf && npm run -s build-all"

.PHONY: pull
pull:
	# pull baked images
	@${DOCKER} pull $(IMAGE_NAME):$(WHARF_REPO_VERSION)
	@${DOCKER} pull $(IMAGE_NAME):latest

# You might need to run `make build-code-checks` first
.PHONY: perform-code-checks
perform-code-checks:
	@${DOCKER} run --rm -t \
		-e LOCAL_USER_ID=$(LOCAL_USER_ID) \
		-v `pwd`:/opt/wharf \
		--label $(WHARF_SYSTEM_CONTAINER_LABEL)=1 \
		${IMAGE_NAME} /bin/bash -c \
	"cd /opt/wharf && flake8 wharf"
	@${DOCKER} run --rm -t \
		-e LOCAL_USER_ID=$(LOCAL_USER_ID) \
		-v `pwd`:/opt/wharf \
		--label $(WHARF_SYSTEM_CONTAINER_LABEL)=1 \
		${FRONTEND_IMAGE_NAME} /bin/bash -c \
	"cd /opt/wharf && npm run -s eslint"


# ============== Misc ================ #
.PHONY: clean
clean:
	@rm -rf .coverage cover
	@find . -name '*.pyc' -exec rm '{}' ';'
	@find . -name '*.orig' -exec rm '{}' ';'

# Removes Docker Compose containers
docker-clean: clean
	@${DOCKER_COMPOSE} rm -s -f

init:
	@make migrate
	@make create-ISC-image-settings
	@make createsuperuser

# # "bash -c" doesn't open an interactive session so we run another bash instance from it
.PHONY: bash
bash:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf; bash"

.PHONY: db-restore
db-restore:
	@if [ ! -f wharfdb.sql ]; then \
		echo "Aborting! Can't find backup file. Database backup file must be named wharfdb.sql and located in the current directory!"; \
		exit 1; \
	fi
	@echo "Restoring database from backup file: wharfdb.sql"
	@cat wharfdb.sql | docker exec -i `$(DOCKER_COMPOSE) ps -q postgres` psql -Upostgres

.PHONY: pip-install
pip-install:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/requirements/ && pip install -r production.txt"


# ================ Django Tests =================== #

## To pass additional parameters to py.test, use e.g. `make test what='-k TestContainerAccessPoints'`
## -- that will run only the tests from the TestContainerAccessPoints test case
##
## Read more at https://pytest.org/latest/usage.html#specifying-tests-selecting-tests
## See also pytest.ini
.PHONY: test
test:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && py.test $(what)"

# Run the tests but only show a small traceback.
.PHONY: test-minimal
test-minimal:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && py.test --tb=line $(what)"

## More options: https://pytest-cov.readthedocs.io/en/latest/readme.html
.PHONY: coverage
coverage:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && py.test --cov"

# =========== Django Commands ================= #
.PHONY: makemigrations
makemigrations:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py makemigrations $(app)"

# `--clear` doesn't work if the directory doesn't exist (this was fixed in Django 1.9: https://github.com/django/django/commit/87d78241a2fc85e5715fb51c554fe06e91deee58)
.PHONY: collectstatic
collectstatic:
	@${DOCKER} exec -i `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && rm -rf collected_static && python manage.py collectstatic --noinput"

.PHONY: createsuperuser
createsuperuser:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py createsuperuser"

.PHONY: refresh-everything
refresh-everything:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py refresh_everything"

.PHONY: shell-plus
shell-plus:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && ./manage.py shell_plus"

.PHONY: psql
psql:
	@echo "Starting interactive database prompt (current dir mounted to /tmp/codebase)...";
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q postgres` psql -Upostgres

.PHONY: migrate
migrate:
## make migrate what="wharf 0001"
	@${DOCKER} exec -i `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py migrate $(what)"

.PHONY: import-from-docker
import-from-docker:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py import_from_docker"

.PHONY: create-ISC-image-settings
create-ISC-image-settings:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py create_ISC_image_settings"

.PHONY: create-reserved-host-ports
create-reserved-host-ports:
	@${DOCKER} exec -it `$(DOCKER_COMPOSE) ps -q web` /bin/bash -c "cd /opt/wharf/wharf && python manage.py create_reserved_host_ports"

# =========== MkDocs ================= #
.PHONY: servedocs
servedocs:
	@mkdocs serve

# Do not change the name of this directive; our
# app that builds docs needs this directive.
# See: https://git.io/fj7MP.
.PHONY: docs-build
docs-build:
	@mkdocs build
