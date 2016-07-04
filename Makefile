.PHONY: all test clean

KOHAENV ?= dev

ifdef NOVAGRANT
CMD=bash
KOHAPATH=$(shell pwd)
NOVAGRANT=true
HOST ?= localhost
DOCKER_GW=172.19.0.1
else
CMD=vagrant ssh $(SHIP)
KOHAPATH=/vagrant
HOST ?= 192.168.50.1
DOCKER_GW=$(HOST)
NOVAGRANT=false
endif

all: reload build run

reload: halt up provision

halt:
	@$(NOVAGRANT) || vagrant halt
	@$(NOVAGRANT) && sudo $(CMD) -c "cd $(KOHAPATH)/docker-compose && sudo docker-compose down" || true

up:                                              ##
	@$(NOVAGRANT) || vagrant up
	@$(NOVAGRANT) && sudo $(CMD) -c "cd $(KOHAPATH)/docker-compose && sudo docker-compose up -d" || true

shell_provision:					## Run ONLY shell provisioners
	@$(NOVAGRANT) || vagrant provision --provision-with shell
	-@$(NOVAGRANT) && ./provision.sh $(KOHAENV) $(KOHAPATH)

provision:  shell_provision   	## Full provision

wait_until_ready:
	@echo "=======    wait until ready    ======\n"
	$(CMD) -c 'sudo docker exec -t koha_$(KOHAENV) ./wait_until_ready.py'

rebuild=$(CMD) -c "cd $(KOHAPATH)/docker-compose &&\
	  sudo docker-compose stop $(1) || true &&\
	  sudo docker-compose rm -f $(1) || true &&\
	  sudo docker-compose build $(1) &&\
	  sudo docker-compose up --force-recreate --no-deps -d $(1)"

rebuild:
	@echo "======= FORCE RECREATING koha_$(KOHAENV)======\n"
	$(call rebuild,koha_$(KOHAENV))

build_debianfiles:
	@echo "======= BUILDING KOHA CONTAINER FROM LOCAL DEBIANFILES ======\n"
	$(CMD) -c 'sudo docker build -f $(KOHAPATH)/Dockerfile.debianfiles -t digibib/koha $(KOHAPATH) '

run: delete
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose up -d koha_$(KOHAENV)'

stop:
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose stop koha_$(KOHAENV) || true'

delete: stop
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose rm -fv koha_$(KOHAENV) || true'

logs:
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose logs koha_$(KOHAENV)'

logs-nocolor:
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose logs --no-color koha_$(KOHAENV)'

logs-f:
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose logs -f koha_$(KOHAENV)'

logs-f-nocolor:
	$(CMD) -c 'cd $(KOHAPATH)/docker-compose && docker-compose logs -f --no-color koha_$(KOHAENV)'

browser:
	$(CMD) -c 'firefox "http://localhost:8081/" > firefox.log 2> firefox.err < /dev/null' &

test: wait_until_ready
	@echo "======= TESTING KOHA CONTAINER ======\n"

login: # needs EMAIL, PASSWORD, USERNAME
	@ $(CMD) -c 'sudo docker login --email=$(EMAIL) --username=$(USERNAME) --password=$(PASSWORD)'

tag = "$(shell git rev-parse HEAD)"

tag:
	$(CMD) -c 'sudo docker tag -f digibib/koha digibib/koha:$(tag)'

push: tag
	@echo "======= PUSHING KOHA CONTAINER ======\n"
	$(CMD) -c 'sudo docker push digibib/koha'

docker_cleanup:						## Clean up unused docker containers and images
	@echo "cleaning up unused containers, images and volumes"
	#$(CMD) -c 'sudo docker rm $$(sudo docker ps -aq -f status=exited) 2> /dev/null || true'
	$(CMD) -c 'sudo docker rmi $$(sudo docker images -aq -f dangling=true) 2> /dev/null || true'
	$(CMD) -c 'sudo docker volume rm $$(sudo docker volume ls -q -f=dangling=true) 2> /dev/null || true'

######### OLD MAKE TARGETS ############
# for REAL forwarding, set env FORWARD_SMTP to receiving smtp service
gosmtp_start:
	@echo "restarting gosmtpd container  ..."; \
	vagrant ssh -c 'sudo docker stop gosmtp && sudo docker rm gosmtp'; \
	vagrant ssh -c 'sudo docker run -d --name gosmtp -p 8000:8000 \
		-e FORWARD_SMTP=$(FORWARD_SMTP) \
		-t digibib/gosmtpd:e51ec0b872867560461ab1e8c12b10fd63f5d3c1 ' ;\

# Start a fake listener at local port 8102 inside container
gosms_fake_listener:
	vagrant ssh -c "docker exec -d gosms sh -c 'while true; do { echo -e \"HTTP/1.1 200 OK\r\n\"; } | nc -l -p 8102; done'"

# for REAL forwarding, set env SMS_FORWARD_URL to receiving sms http service at HOST:PORT
gosms_start:
	@echo "restarting gosms container  ..."; \
	vagrant ssh -c 'docker stop gosms && sudo docker rm gosms'; \
	vagrant ssh -c 'docker run -d --name gosms -p 8101:8101 \
		-t digibib/tcp-proxy:7660632e2afa09593941fd35ba09d6c3a948f342 \
		/app/tcp-proxy -l :8101 -vv -r $(SMS_FORWARD_URL)' ;\

