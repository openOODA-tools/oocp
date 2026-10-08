Name:           oocp
Version:        0.2.0
Release:        1%{?dist}
Summary:        Zero-copy clone-capable file and directory copier using io_uring and copy_file_range.
License:        ASL 2.0
URL:            https://github.com/openOODA-tools/oocp
Source0:        oocp-linux-x86_64
Source1:        uninstall.sh
BuildArch:      x86_64
Requires:       glibc

%description
oocp is a sovereign, capability-bounded COPY ENGINE written
in pure openOODA, featuring zero ambient authority, oote color themes,
recursive directory replication, and an MCP stdio server.

%install
mkdir -p %{buildroot}/usr/bin
install -m 0755 %{SOURCE0} %{buildroot}/usr/bin/oocp
install -m 0755 %{SOURCE1} %{buildroot}/usr/bin/oocp-uninstall

%files
/usr/bin/oocp
/usr/bin/oocp-uninstall

%changelog
* Wed Oct 07 2026 openOODA-tools <ops@openooda.org> - 0.2.0-1
- Sovereign pure openOODA implementation with recursive copying and MCP surface
