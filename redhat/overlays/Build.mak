
# Set version variables for LDFLAGS
GIT_VERSION ?= $(shell git describe --tags --always --dirty)
GIT_HASH ?= $(shell git rev-parse HEAD)
DATE_FMT = +%Y-%m-%dT%H:%M:%SZ
SOURCE_DATE_EPOCH ?= $(shell git log -1 --pretty=%ct)
ifdef SOURCE_DATE_EPOCH
    BUILD_DATE ?= $(shell date -u -d "@$(SOURCE_DATE_EPOCH)" "$(DATE_FMT)" 2>/dev/null || date -u -r "$(SOURCE_DATE_EPOCH)" "$(DATE_FMT)" 2>/dev/null || date -u "$(DATE_FMT)")
else
    BUILD_DATE ?= $(shell date "$(DATE_FMT)")
endif
GIT_TREESTATE = "clean"
DIFF = $(shell git diff --quiet >/dev/null 2>&1; if [ $$? -eq 1 ]; then echo "1"; fi)
ifeq ($(DIFF), 1)
    GIT_TREESTATE = "dirty"
endif

GHCR_PREFIX ?= ghcr.io/sigstore/rekor
GOBIN ?= $(shell go env GOPATH)/bin


REKOR_LDFLAGS=-X sigs.k8s.io/release-utils/version.gitVersion=$(GIT_VERSION) \
              -X sigs.k8s.io/release-utils/version.gitCommit=$(GIT_HASH) \
              -X sigs.k8s.io/release-utils/version.gitTreeState=$(GIT_TREESTATE) \
              -X sigs.k8s.io/release-utils/version.buildDate=$(BUILD_DATE)

CLI_LDFLAGS=$(REKOR_LDFLAGS)
SERVER_LDFLAGS=$(REKOR_LDFLAGS)

.PHONY: 
cross-platform: rekor-cli-darwin-arm64 rekor-cli-darwin-amd64 rekor-cli-linux-amd64 rekor-cli-linux-arm64 rekor-cli-linux-ppc64le rekor-cli-linux-s390x rekor-cli-windows ## Build all distributable (cross-platform) binaries

.PHONY:	rekor-cli-darwin-arm64
rekor-cli-darwin-arm64: $(SRCS)## Build for mac M1
	env CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -v -o rekor_cli_darwin_arm64 -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli

.PHONY: rekor-cli-darwin-amd64
rekor-cli-darwin-amd64:  $(SRCS)## Build for Darwin (macOS)
	env CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o rekor_cli_darwin_amd64 -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli

.PHONY: rekor-cli-linux-amd64 
rekor-cli-linux-amd64: $(SRCS)## Build for Linux amd64
	env CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o rekor_cli_linux_amd64 -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli

.PHONY: rekor-cli-linux-arm64
rekor-cli-linux-arm64: $(SRCS) ## Build for Linux arm64
	env CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -o rekor_cli_linux_arm64 -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli

.PHONY: rekor-cli-linux-ppc64le
rekor-cli-linux-ppc64le: $(SRCS)## Build for Linux ppc64le
	env CGO_ENABLED=0 GOOS=linux GOARCH=ppc64le go build -o rekor_cli_linux_ppc64le -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli

.PHONY: rekor-cli-linux-s390x
rekor-cli-linux-s390x: $(SRCS) ## Build for Linux s390x
	env CGO_ENABLED=0 GOOS=linux GOARCH=s390x go build -o rekor_cli_linux_s390x -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli

.PHONY: rekor-cli-windows
rekor-cli-windows: $(SRCS) ## Build for Windows
	env CGO_ENABLED=0 GOOS=windows GOARCH=amd64 go build -o rekor_cli_windows_amd64.exe -trimpath -ldflags "$(CLI_LDFLAGS) -w -s" ./cmd/rekor-cli
