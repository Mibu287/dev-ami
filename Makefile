PACKER=$(shell which packer)
VAR_FILE=${PWD}/variables.pkr.hcl
CONFIG_FILE=${PWD}/aws-ubuntu-arm64-devbox.pkr.hcl

.DEFAULT_GOAL := build
.PHONY: init build validate fmt

init:
	${PACKER} init ${CONFIG_FILE}

build: fmt validate
	${PACKER} build -var-file=${VAR_FILE} ${CONFIG_FILE}

validate:
	${PACKER} validate -var-file=${VAR_FILE} ${CONFIG_FILE} 

fmt:
	${PACKER} fmt .
