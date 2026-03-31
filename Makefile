DEB ?= $(shell ls LM-Studio-*-x64.deb 2>/dev/null | head -1)
SPEC ?= lm-studio.spec
RPM_DIR ?= .
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
	@echo "  rpm          Build RPM from existing spec file"
	@echo "  clean        Remove build artifacts"
	@echo "  test         Test metadata extraction"
	@echo "  install-deps Install required build dependencies"
	@echo ""
	@echo "Variables:"
	@echo "  DEB          Path to deb package (default: first LM-Studio-*-x64.deb)"
	@echo "  SPEC         Output spec file path (default: auto-generated)"
	@echo "  RPM_DIR      Directory for RPM output (default: .)"



.PHONY: all
all: spec rpm




.PHONY: spec
spec: gen_spec.py
	@echo "Generating spec file from deb package..."
	./gen_spec.py "$(DEB)" -o "$(SPEC)"



.PHONY: rpm
rpm: spec
	@echo "Building RPM package..."
	@mkdir -p "$(RPM_DIR)"
	@mkdir -p "$(BUILD_ROOT)"
	@dpkg-deb -x "$(DEB)" "$(BUILD_ROOT)"
	@if test -d "$(BUILD_ROOT)/usr/share/icons/hicolor/0x0"; then \
		mv "$(BUILD_ROOT)/usr/share/icons/hicolor/0x0" "$(BUILD_ROOT)/usr/share/icons/hicolor/1024x1024"; \
	fi
	rpmbuild --buildroot="$(PWD)/$(BUILD_ROOT)" -bb --target x86_64 "$(SPEC)"
	@rm -rf "$(BUILD_ROOT)"
	@echo "RPM built successfully!"



.PHONY: clean
clean:
	@rm -rf "$(BUILD_ROOT)" lm-studio.spec *.rpm lm-studio/
	@echo "Cleaned build artifacts"



.PHONY: test
test:
	@echo "Testing deb package metadata extraction..."
	./gen_spec.py "$(DEB)" -o /dev/stdout



.PHONY: install-deps
install-deps:
	@echo "Installing build dependencies..."
	@if command -v apt-get >/dev/null 2>&1; then \
		sudo apt-get install -y rpm build-essential dpkg-dev; \
	elif command -v dnf >/dev/null 2>&1; then \
		sudo dnf install -y rpm-build dpkg; \
	elif command -v yum >/dev/null 2>&1; then \
		sudo yum install -y rpm-build dpkg; \
	elif command -v zypper >/dev/null 2>&1; then \
		sudo zypper install -y rpm-build dpkg; \
	else \
		echo "Cannot detect package manager. Please install: rpm-build, dpkg-dev"; \
		exit 1; \
	fi
