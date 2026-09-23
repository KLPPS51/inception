# =============================================================
#  Inception - Makefile
#
#  `make` builds and starts the whole stack. See `make help`.
# =============================================================

LOGIN        := mobullad
DOMAIN_NAME  := $(LOGIN).42.fr
DATA_PATH    := /home/$(LOGIN)/data

COMPOSE_FILE := srcs/docker-compose.yml
ENV_FILE     := srcs/.env
ENV_TEMPLATE := srcs/.env.example
COMPOSE      := docker compose -f $(COMPOSE_FILE) --env-file $(ENV_FILE)

SERVICES     := nginx wordpress mariadb
IMAGES       := nginx:inception wordpress:inception mariadb:inception

.PHONY: all up build down stop start re clean fclean logs ps status \
        secrets dirs hosts credentials help

all: up

# -- Lifecycle ------------------------------------------------

## Build the images and start the stack in the background
up: $(ENV_FILE) secrets dirs
	$(COMPOSE) up -d --build
	@echo ""
	@echo "Stack is up. Open https://$(DOMAIN_NAME)"
	@echo "If the name does not resolve, run: make hosts"

## Build the images without starting anything
build: $(ENV_FILE) secrets dirs
	$(COMPOSE) build

## Stop and remove the containers (named volumes are kept)
down: $(ENV_FILE)
	$(COMPOSE) down

stop: $(ENV_FILE)
	$(COMPOSE) stop

start: $(ENV_FILE)
	$(COMPOSE) start

## Full rebuild from scratch
re: fclean up

# -- Setup ----------------------------------------------------

# srcs/.env is generated from the versioned template. It is listed
# in .gitignore so that no local configuration is ever committed.
$(ENV_FILE): $(ENV_TEMPLATE)
	@cp $(ENV_TEMPLATE) $(ENV_FILE)
	@echo "[env] $(ENV_FILE) generated from $(ENV_TEMPLATE)"

## Generate the password files consumed as Docker secrets
secrets:
	@sh tools/gen_secrets.sh

## Create the host directories backing the two named volumes
dirs:
	@mkdir -p $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress

## Point $(DOMAIN_NAME) at the loopback address
hosts:
	@grep -q "$(DOMAIN_NAME)" /etc/hosts || echo "127.0.0.1 $(DOMAIN_NAME)" | sudo tee -a /etc/hosts
	@echo "[hosts] $(DOMAIN_NAME) resolves to 127.0.0.1"

## Print the generated credentials (read from secrets/)
credentials: $(ENV_FILE) secrets
	@echo "WordPress administrator : $$(grep '^WP_ADMIN_USER=' $(ENV_FILE) | cut -d= -f2)"
	@echo "  password              : $$(cat secrets/wp_admin_password.txt)"
	@echo "WordPress author        : $$(grep '^WP_USER=' $(ENV_FILE) | cut -d= -f2)"
	@echo "  password              : $$(cat secrets/wp_user_password.txt)"
	@echo "MariaDB user            : $$(grep '^MYSQL_USER=' $(ENV_FILE) | cut -d= -f2)"
	@echo "  password              : $$(cat secrets/db_password.txt)"
	@echo "MariaDB root password   : $$(cat secrets/db_root_password.txt)"

# -- Inspection -----------------------------------------------

## Follow the logs of the three containers
logs: $(ENV_FILE)
	$(COMPOSE) logs -f

## Show the state of the containers
ps status: $(ENV_FILE)
	$(COMPOSE) ps

# -- Cleaning -------------------------------------------------

## Remove the containers and the named volumes
clean: $(ENV_FILE)
	$(COMPOSE) down -v --remove-orphans

## clean + remove the images and the persisted data
fclean: clean
	-docker rmi -f $(IMAGES) 2>/dev/null || true
	-docker system prune -af --volumes
	-sudo rm -rf $(DATA_PATH)/mariadb $(DATA_PATH)/wordpress

help:
	@echo "make up           build the images and start the stack"
	@echo "make down         stop and remove the containers"
	@echo "make re           full rebuild (fclean then up)"
	@echo "make logs         follow the logs"
	@echo "make ps           show the state of the containers"
	@echo "make hosts        add $(DOMAIN_NAME) to /etc/hosts"
	@echo "make credentials  print the generated passwords"
	@echo "make secrets      generate the missing secret files"
	@echo "make clean        remove the containers and volumes"
	@echo "make fclean       clean + remove the images and the data"
