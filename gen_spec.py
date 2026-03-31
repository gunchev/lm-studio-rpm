#!/usr/bin/env python3
import argparse
import gzip
import os
import re
import subprocess
import sys
import tarfile
from pathlib import Path


def extract_deb_control(deb_path: str) -> dict:
    result = subprocess.run(
        ["dpkg-deb", "--info", deb_path, "control"], capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error extracting control: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    control = {}
    for line in result.stdout.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            control[key.strip()] = value.strip()
    return control


def extract_deb_scripts(deb_path: str) -> dict:
    scripts = {}
    for script in ["preinst", "postinst", "prerm", "postrm"]:
        result = subprocess.run(
            ["dpkg-deb", "--info", deb_path, script], capture_output=True, text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            scripts[script] = result.stdout
    return scripts


def extract_deb_files(deb_path: str) -> list:
    result = subprocess.run(
        ["dpkg-deb", "--fsys-tarfile", deb_path], capture_output=True
    )
    if result.returncode != 0:
        print(f"Error extracting files: {result.stderr}", file=sys.stderr)
        sys.exit(1)

    files = []
    with tarfile.open(
        fileobj=gzip.GzipFile(fileobj=BytesIO(result.stdout)), mode="r"
    ) as tar:
        for member in tar.getmembers():
            files.append(member.name)
    return files


def parse_version(version_str: str) -> tuple:
    match = re.match(r"(\d+)\.(\d+)\.(\d+)", version_str)
    if match:
        return match.groups()
    match = re.match(r"(\d+)\.(\d+)", version_str)
    if match:
        return (*match.groups(), "0")
    return ("0", "0", "0")


def generate_spec(control: dict, scripts: dict, files: list, output: str):
    name = control.get("Package", "lm-studio")
    version = control.get("Version", "0.0.0")
    major, minor, patch = parse_version(version)
    description = control.get("Description", "No description available")
    maintainer = control.get("Maintainer", "Unknown")

    version_release = f"{major}.{minor}.{patch}-1"
    changelog_date = subprocess.run(
        ["date", "+%a %b %d %Y"], capture_output=True, text=True
    ).stdout.strip()

    spec_content = f"""%define _rpmdir ./
%define _rpmfilename %%{{NAME}}-%%{{VERSION}}-%%{{RELEASE}}.%%{{ARCH}}.rpm
%define _unpackaged_files_terminate_build 0

Name: {name}
Version: {major}.{minor}.{patch}
Release: 1
Summary: {control.get("Description", "").split(chr(10))[0] or "No summary"}
License: see /usr/share/doc/{name}/copyright
Vendor: {maintainer}
URL: https://lmstudio.ai
BuildArch: x86_64

## dpkg-deb --info "${{DEB}}" control ##
%description
{description.strip()}



## dpkg-deb --info "${{DEB}}" postinst ##
%post
"""

    if "postinst" in scripts:
        spec_content += convert_shell_script(scripts["postinst"], name)
    else:
        spec_content += f"""if type update-alternatives 2>/dev/null >&1; then
    # Remove previous link if it doesn't use update-alternatives
    if [ -L '/usr/bin/{name}' -a -e '/usr/bin/{name}' -a "`readlink '/usr/bin/{name}'`" != '/etc/alternatives/{name}' ]; then
        rm -f '/usr/bin/{name}'
    fi
    update-alternatives --install '/usr/bin/{name}' '{name}' '/opt/LM-Studio/{name}' 100 || ln -sf '/opt/LM-Studio/{name}' '/usr/bin/{name}'
else
    ln -sf '/opt/LM-Studio/{name}' '/usr/bin/{name}'
fi

# SUID chrome-sandbox for Electron 5+
chmod 4755 '/opt/LM-Studio/chrome-sandbox' || true

if hash update-mime-database 2>/dev/null; then
    update-mime-database /usr/share/mime || true
fi

if hash update-desktop-database 2>/dev/null; then
    update-desktop-database /usr/share/applications || true
fi

"""

    postrm_content = (
        convert_shell_script(scripts["postrm"], name)
        if "postrm" in scripts
        else """# Delete the link to the binary
if type update-alternatives >/dev/null 2>&1; then
    update-alternatives --remove '{name}' '/usr/bin/{name}' 2>/dev/null || true
else
    rm -f '/usr/bin/{name}'
fi
"""
    )
    spec_content += f"""

## dpkg-deb --info "${{DEB}}" postrm ##
%postun
{postrm_content}


%files
/usr/share/doc/{name}
/usr/share/applications/{name}.desktop
/usr/share/icons/hicolor/1024x1024/apps/{name}.png
/opt/LM-Studio



%changelog
* {changelog_date} {maintainer} - {version_release}
- Converted from deb package {version}
"""

    Path(output).write_text(spec_content)
    print(f"Spec file written to: {output}")


def convert_shell_script(script: str, name: str) -> str:
    converted = script

    if "/usr/bin/lm-studio" not in converted and "/opt/LM-Studio" in converted:
        converted = converted.replace(
            "/opt/LM-Studio/lm-studio", "/opt/LM-Studio/lm-studio"
        )

    return converted


def main():
    parser = argparse.ArgumentParser(
        description="Generate RPM spec file from Debian package"
    )
    parser.add_argument(
        "deb",
        nargs="?",
        default="LM-Studio-*-x64.deb",
        help="Path to deb package (default: LM-Studio-*-x64.deb)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default=None,
        help="Output spec file path (default: derived from deb name)",
    )

    args = parser.parse_args()

    import glob

    deb_files = glob.glob(args.deb)
    if not deb_files:
        print(f"No deb files found matching: {args.deb}", file=sys.stderr)
        sys.exit(1)

    deb_path = deb_files[0]
    print(f"Processing: {deb_path}")

    if args.output:
        output_spec = args.output
    else:
        deb_name = os.path.basename(deb_path)
        match = re.match(r"(.+?)[-_](\d+[\d.-]*)[-_]", deb_name)
        if match:
            base_name = match.group(1).replace("-", "_")
            output_spec = f"{base_name}.spec"
        else:
            output_spec = "lm-studio.spec"

    control = extract_deb_control(deb_path)
    scripts = extract_deb_scripts(deb_path)

    generate_spec(control, scripts, [], output_spec)

    return 0


if __name__ == "__main__":
    from io import BytesIO

    sys.exit(main())
