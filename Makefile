DEB ?= $(shell ls LM-Studio-*-x64.deb 2>/dev/null | head -1)
SPEC ?= lm-studio.spec
RPM_DIR ?= rpms
BUILD_ROOT := lm-studio-buildroot


.PHONY: help
help:
	@echo "LM Studio RPM Builder"
	@echo ""
	@echo "Usage:"
	@echo "  make [target]"
	@echo ""
	@echo "Targets:"
	@echo "  spec         Generate spec file from deb package"
	@echo "  rpm          Build RPM using rpmbuild (local)"
	@echo "  mock-srpm    Build SRPM using mock"
	@echo "  mock         Build RPM using mock"
	@echo "  all          Build spec and RPM using mock"
	@echo "  sources      Download/verify sources for spec"
	@echo "  clean        Remove build artifacts"
	@echo "  test         Test metadata extraction"
	@echo "  install-deps Install required build dependencies"
	@echo ""
	@echo "Variables:"
	@echo "  DEB          Path to deb package (default: first LM-Studio-*-x64.deb)"
	@echo "  SPEC         Output spec file path (default: auto-generated)"
	@echo "  RPM_DIR      Directory for RPM output (default: ./rpms/)"



.PHONY: all
all: spec mock


.PHONY: spec
spec: gen_spec.py
	@echo "Generating spec file from deb package..."
	./gen_spec.py "$(DEB)" -o "$(SPEC)"


.PHONY: rpm
rpm: spec
	@echo "Building RPM package..."
	rpmbuild -bb --target x86_64 "$(SPEC)"
	# mv *.rpm "$(RPM_DIR)/" 2>/dev/null || true
	@echo "RPM built successfully!"


.PHONY: sources
sources:
	@spectool -g -S ./*.spec


.PHONY: mock-srpm
mock-srpm: spec sources
	@echo "Building SRPM with mock..."
	mkdir -p "$(RPM_DIR)"
	mock --buildsrpm --sources=./ --spec ./*.spec --resultdir="$(RPM_DIR)/"


.PHONY: mock
mock: spec sources
	@echo "Building RPM with mock..."
	mkdir -p "$(RPM_DIR)"
	mock --rebuild "$(RPM_DIR)"/*.src.rpm --resultdir="$(RPM_DIR)/"
	@echo "RPM built successfully in $(RPM_DIR)/"



.PHONY: clean
clean:
	rm -rf "$(BUILD_ROOT)" "$(RPM_DIR)" lm-studio.spec *.rpm lm-studio/
	@echo "Cleaned build artifacts"



.PHONY: test
test:
	@echo "Testing deb package metadata extraction..."
	./gen_spec.py "$(DEB)" -o /dev/stdout



.PHONY: install-deps
install-deps:
	@echo "Installing build dependencies..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get install -y rpm build-essential dpkg-dev mock rpm; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y rpm-build dpkg mock; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y rpm-build dpkg mock; \
	elif command -v zypper >/dev/null 2>&1; then \
		sudo zypper install -y rpm-build dpkg mock; \
	else \
		echo "Cannot detect package manager. Please install: rpm-build, dpkg-dev, mock"; \
		exit 1; \
	fi
