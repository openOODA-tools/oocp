# oocp v0.2.0 Makefile

OODA_COMPILER ?= $(firstword $(wildcard $(HOME)/.openooda/bin/oodac $(CURDIR)/../../openOODA/oodac/bin/oodac))
OODACODEX ?= $(HOME)/.openooda/northstar.oot
OO_LIST_AMBIENT_QUOTA ?= 8589934592
BIN := dist/oocp

PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

SRC := $(wildcard *.oo) $(wildcard */*.oo)
VERSION ?= $(shell cat VERSION 2>/dev/null || echo 0.2.0)

.PHONY: build check line-cap file-law academy density verify clean test package package-deb package-rpm package-arch install uninstall

build: $(BIN)

$(BIN): $(SRC)
	@mkdir -p dist .ooda-cache/ooda-tmp
	OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) build main.oo -o $(BIN)
	@chmod +x $(BIN)
	@cp -a $(BIN) dist/oocp-linux-x86_64
	@sha256sum dist/oocp-linux-x86_64 > dist/oocp-linux-x86_64.sha256
	@echo "built $(BIN) (and dist/oocp-linux-x86_64)"

# --- Verification gate ---------------------------------------------------------

line-cap:
	@violations=0; \
	for f in $$(find . -name "*.oo" -o -name "*.oot" | grep -v "/dist/" | grep -v "/.ooda-cache/"); do \
		n=$$(wc -l < "$$f"); \
		if [ $$n -gt 256 ]; then \
			echo "VIOLATION: $$f = $$n lines (exceeds 256)"; violations=$$((violations+1)); \
		fi; \
		code=$$(grep -vE '^[[:space:]]*(//.*)?$$' "$$f" | grep -cvE '^[[:space:]]*import[[:space:]]+"'); \
		if [ "$$code" = "0" ]; then continue; fi; \
		if [ $$n -lt 16 ]; then \
			echo "VIOLATION: $$f = $$n lines (under 16-line floor, not a shim)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations files violate the Page Rule"; exit 1; fi; \
	echo "PASS: Page Rule sizing (16-256 lines, shims exempt from floor) holds"

file-law:
	@forbidden="js ts rb pl json yaml toml"; \
	violations=0; \
	for ext in $$forbidden; do \
		found=$$(find . -name "*.$$ext" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null | head -3); \
		if [ -n "$$found" ]; then \
			echo "VIOLATION: .$$ext forbidden:"; echo "$$found"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.md" -not -path "./.git/*" -not -path "./.github/*" -not -path "./dist/*" -not -path "./.ooda-cache/*" 2>/dev/null); do \
		if [ "$$f" != "./README.md" ] && [ "$$f" != "./AGENTS.md" ]; then \
			echo "VIOLATION: .md forbidden outside README.md and AGENTS.md: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	for f in $$(find . -name "*.sh" -not -path "./.git/*" -not -path "./dist/*" 2>/dev/null); do \
		if [ "$$f" != "./install.sh" ] && [ "$$f" != "./uninstall.sh" ]; then \
			echo "VIOLATION: .sh forbidden outside install.sh and uninstall.sh: $$f"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: file-law violations"; exit 1; fi; \
	echo "PASS: file law holds"

academy:
	@failures=0; \
	for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		header=$$(head -7 "$$f"); \
		missing=""; \
		echo "$$header" | grep -q "^// # "        || missing="$$missing title"; \
		echo "$$header" | grep -q "^// Logline:"  || missing="$$missing logline"; \
		echo "$$header" | grep -q "^// Setup:"    || missing="$$missing setup"; \
		echo "$$header" | grep -q "^// Beats:"    || missing="$$missing beats"; \
		if [ -n "$$missing" ]; then \
			echo "FAIL: $$f missing Academy element(s):$$missing"; failures=$$((failures+1)); \
		fi; \
	done; \
	if [ $$failures -gt 0 ]; then echo "FAIL: $$failures academy header violations"; exit 1; fi; \
	echo "PASS: academy headers hold (all 4 elements present in first 7 lines)"

density:
	@violations=0; \
	for d in $$(find . -type d -not -path "./.git*" -not -path "./dist*" -not -path "./.ooda-cache*" -not -path "./packaging*" -not -path "./qa*"); do \
		n=$$(ls "$$d"/*.oo "$$d"/*.oot 2>/dev/null | grep -v '\*' | wc -l); \
		if [ $$n -gt 8 ]; then \
			echo "VIOLATION: $$d holds $$n pages (exceeds 8)"; violations=$$((violations+1)); \
		fi; \
	done; \
	if [ $$violations -gt 0 ]; then echo "FAIL: $$violations directories exceed the density bound"; exit 1; fi; \
	echo "PASS: directory density (<= 8 pages per directory) holds"

check:
	@for f in $$(find . -name "*.oo" -not -path "./dist/*"); do \
		OO_LIST_AMBIENT_QUOTA=$(OO_LIST_AMBIENT_QUOTA) OODACODEX=$(OODACODEX) OODA_COMPILER=$(OODA_COMPILER) OODA_NO_JAIL=1 $(OODA_COMPILER) check "$$f" > /dev/null || exit 1; \
	done; \
	echo "PASS: oodac check holds on all .oo files"

verify: line-cap file-law academy density check

test: $(BIN)
	@echo "=== testing --help ==="
	@./$(BIN) --help > /dev/null && echo "PASS: --help"
	@echo "=== testing --version ==="
	@./$(BIN) --version | grep -q "0.2.0" && echo "PASS: --version"
	@echo "=== testing --demo ==="
	@./$(BIN) --demo | grep -q "sovereign-agent" && echo "PASS: --demo"
	@echo "=== testing --demo --json ==="
	@./$(BIN) --demo --json | grep -q '"tool":"oocp"' && echo "PASS: --demo --json"
	@echo "=== testing single file copy ==="
	@printf "sovereign file content\n" > dist/f1.txt
	@./$(BIN) dist/f1.txt dist/f2.txt
	@grep -q "sovereign file content" dist/f2.txt && echo "PASS: single file copy"
	@echo "=== testing backup copy ==="
	@printf "modified file content\n" > dist/f1.txt
	@./$(BIN) -b dist/f1.txt dist/f2.txt
	@grep -q "modified file content" dist/f2.txt && echo "PASS: overwrite file"
	@grep -q "sovereign file content" dist/f2.txt~ && echo "PASS: backup file created"
	@echo "=== testing recursive directory copy ==="
	@mkdir -p dist/d1/sub
	@printf "nested tree content\n" > dist/d1/sub/leaf.txt
	@./$(BIN) -r dist/d1 dist/d2
	@grep -q "nested tree content" dist/d2/sub/leaf.txt && echo "PASS: recursive directory copy"
	@echo "=== testing MCP initialize ==="
	@printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}\n' | ./$(BIN) --mcp | grep -q "protocolVersion" && echo "PASS: MCP initialize"
	@echo "=== testing MCP tools/list ==="
	@printf '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}\n' | ./$(BIN) --mcp | grep -q "cp_copy_file" && echo "PASS: MCP tools/list"
	@echo "=== testing MCP tools/call cp_copy_file ==="
	@printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","name":"cp_copy_file","source":"dist/f1.txt","destination":"dist/f3.txt"}\n' | ./$(BIN) --mcp | grep -q 'success' && echo "PASS: MCP cp_copy_file"
	@echo "=== testing MCP tools/call cp_inspect_source ==="
	@printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","name":"cp_inspect_source","source":"dist/f1.txt","destination":"dist/f3.txt"}\n' | ./$(BIN) --mcp | grep -q 'source_exists' && echo "PASS: MCP cp_inspect_source"
	@echo "=== testing MCP tools/call cp_dry_run ==="
	@printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","name":"cp_dry_run","source":"dist/d1","destination":"dist/d3"}\n' | ./$(BIN) --mcp | grep -q 'Plan' && echo "PASS: MCP cp_dry_run"
	@echo "=== testing MCP tools/call cp_stats ==="
	@printf '{"jsonrpc":"2.0","id":6,"method":"tools/call","name":"cp_stats","source":"dist/f1.txt"}\n' | ./$(BIN) --mcp | grep -q 'bytes' && echo "PASS: MCP cp_stats"
	@echo "=== testing MCP tools/call cp_reflink ==="
	@printf '{"jsonrpc":"2.0","id":7,"method":"tools/call","name":"cp_reflink","source":"dist/f1.txt","destination":"dist/f4.txt"}\n' | ./$(BIN) --mcp | grep -q 'reflink' && echo "PASS: MCP cp_reflink"
	@echo "=== testing MCP tools/call cp_copy_tree ==="
	@printf '{"jsonrpc":"2.0","id":8,"method":"tools/call","name":"cp_copy_tree","source_dir":"dist/d1","target_dir":"dist/d4"}\n' | ./$(BIN) --mcp | grep -q 'total_files' && echo "PASS: MCP cp_copy_tree"
	@rm -rf dist/f1.txt dist/f2.txt dist/f2.txt~ dist/f3.txt dist/f4.txt dist/d1 dist/d2 dist/d3 dist/d4
	@echo "ALL TESTS PASSED"

install: $(BIN)
	@mkdir -p $(DESTDIR)$(BINDIR)
	install -m 0755 $(BIN) $(DESTDIR)$(BINDIR)/oocp
	install -m 0755 uninstall.sh $(DESTDIR)$(BINDIR)/oocp-uninstall
	@echo "installed oocp and oocp-uninstall to $(DESTDIR)$(BINDIR)"

uninstall:
	@rm -f $(DESTDIR)$(BINDIR)/oocp $(DESTDIR)$(BINDIR)/oocp-uninstall
	@if [ "$(PURGE)" = "1" ]; then rm -rf $(HOME)/.cache/oocp $(HOME)/.config/oocp; echo "purged user cache and config"; fi
	@echo "uninstalled oocp and oocp-uninstall from $(DESTDIR)$(BINDIR)"

package-deb: $(BIN)
	@mkdir -p dist/deb-root/DEBIAN dist/deb-root/usr/bin
	@sed "s/^Version:.*/Version: $(VERSION)-1/" packaging/debian/control.binary > dist/deb-root/DEBIAN/control
	@cp $(BIN) dist/deb-root/usr/bin/oocp
	@chmod 0755 dist/deb-root/usr/bin/oocp
	@cp uninstall.sh dist/deb-root/usr/bin/oocp-uninstall
	@chmod 0755 dist/deb-root/usr/bin/oocp-uninstall
	@dpkg-deb --build --root-owner-group dist/deb-root dist/oocp_$(VERSION)-1_amd64.deb
	@rm -rf dist/deb-root
	@echo "built dist/oocp_$(VERSION)-1_amd64.deb"

package-rpm: $(BIN)
	@mkdir -p ~/rpmbuild/SOURCES ~/rpmbuild/SPECS ~/rpmbuild/RPMS
	@cp $(BIN) ~/rpmbuild/SOURCES/oocp-linux-x86_64
	@cp uninstall.sh ~/rpmbuild/SOURCES/uninstall.sh
	@sed "s/^Version:.*/Version: $(VERSION)/" packaging/oocp.spec > ~/rpmbuild/SPECS/oocp.spec
	@rpmbuild -bb ~/rpmbuild/SPECS/oocp.spec
	@cp ~/rpmbuild/RPMS/x86_64/oocp-$(VERSION)*.rpm dist/
	@echo "built dist RPM package"

package-arch: $(BIN)
	@mkdir -p dist/arch-pkg/usr/bin
	@cp $(BIN) dist/arch-pkg/usr/bin/oocp
	@chmod 0755 dist/arch-pkg/usr/bin/oocp
	@cp uninstall.sh dist/arch-pkg/usr/bin/oocp-uninstall
	@chmod 0755 dist/arch-pkg/usr/bin/oocp-uninstall
	@printf "pkgname = oocp\npkgbase = oocp\npkgver = $(VERSION)-1\npkgdesc = Zero-copy clone-capable file and directory copier using io_uring and copy_file_range.\nurl = https://github.com/openOODA-tools/oocp\nbuilddate = $$(date +%s)\npackager = openOODA-tools <ops@openooda.org>\nsize = $$(stat -c %s $(BIN))\narch = x86_64\nlicense = Apache-2.0\ndepend = glibc\nprovides = oocp\n" > dist/arch-pkg/.PKGINFO
	@tar --zstd -cf dist/oocp-$(VERSION)-1-x86_64.pkg.tar.zst -C dist/arch-pkg .PKGINFO usr
	@rm -rf dist/arch-pkg
	@bash -n packaging/arch/PKGBUILD
	@cp packaging/arch/PKGBUILD packaging/PKGBUILD
	@echo "built dist/oocp-$(VERSION)-1-x86_64.pkg.tar.zst and validated PKGBUILD"

package: package-deb package-rpm package-arch
	@cd dist && sha256sum oocp* > checksums.txt 2>/dev/null || true
	@echo "built all packages and dist/checksums.txt"

clean:
	@rm -rf dist .ooda-cache
	@echo "cleaned"
