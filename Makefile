SCENARIO ?= domain

ifeq ($(OS),Windows_NT)
RENTALCTL := ./bin/rentalctl.exe
else
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)
ifeq ($(UNAME_S),Darwin)
ifeq ($(UNAME_M),x86_64)
RENTALCTL := ./bin/rentalctl-darwin-amd64
else
RENTALCTL := ./bin/rentalctl-darwin-arm64
endif
else
RENTALCTL := ./bin/rentalctl-linux-amd64
endif
endif

.PHONY: up clear verify demo down

up:
	$(RENTALCTL) cluster up

clear:
	$(RENTALCTL) cluster clear

verify:
	$(RENTALCTL) verify

demo:
	$(RENTALCTL) demo $(SCENARIO)

down:
	$(RENTALCTL) cluster down
