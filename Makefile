PACKER=$(shell which packer)
VAR_FILE=${PWD}/variables.pkr.hcl
CONFIG_FILE=${PWD}/aws-ubuntu-devbox.pkr.hcl

DEFAULT_GOAL := build
.PHONY: build validate fmt

init:
	${PACKER} init ${VAR_FILE}

build:
	${PACKER} build -var-file=${VAR_FILE} ${CONFIG_FILE}

validate:
	${PACKER} validate -var-file=${VAR_FILE} ${CONFIG_FILE} 

fmt:
	${PACKER} fmt .
