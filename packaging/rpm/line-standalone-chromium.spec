Name:           line-standalone-chromium
Version:        1.0.0
Release:        1%{?dist}
Summary:        Standalone LINE desktop app via Chromium (side-loaded extension)

License:        MIT
URL:            https://github.com/jerem/line-standalone-app
BuildArch:      noarch

# The launcher (Source0) and desktop entry (Source1) live in the repo.
Source0:        line-chromium.sh
Source1:        line-standalone-chromium.desktop

# Chromium is required because Google Chrome refuses --load-extension.
Requires:       chromium
Requires:       python3
Requires:       curl

# The LINE extension itself is NOT bundled: the launcher fetches it at first run.
# This package ships only the launcher and desktop integration.

%global appid chrome-ophjlpahpchlmihnnnihgmmeilfjmjjc__index.html-Default

%description
Runs the official LINE Chrome extension as a standalone desktop app using
Chromium's --app mode. The extension is fetched from Google's update service on
first launch (no Chrome Web Store install needed) and run in a dedicated,
isolated Chromium profile.

Note: this side-loads the extension via --load-extension, which only Chromium
(not Google Chrome) allows. Login persists across restarts; push notifications
may be unreliable. See the project README for the full trade-offs.

%prep
# nothing to unpack

%build
# nothing to build (shell + python)

%install
install -Dm0755 %{SOURCE0} %{buildroot}%{_bindir}/line-chromium
install -Dm0644 %{SOURCE1} %{buildroot}%{_datadir}/applications/%{appid}.desktop

%post
update-desktop-database &>/dev/null || :

%postun
update-desktop-database &>/dev/null || :

%files
%{_bindir}/line-chromium
%{_datadir}/applications/%{appid}.desktop

%changelog
* Tue Jul 21 2026 jerem <jeremy@newlogic.com> - 1.0.0-1
- Initial package: Chromium-based standalone LINE launcher.
