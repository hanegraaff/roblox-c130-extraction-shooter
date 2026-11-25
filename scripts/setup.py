"""Install the pinned toolchain/dependency set; curl uses the system certificate store.

Supports macOS/Linux arm64/x86_64. Rokit and engine-definition downloads are hash
verified. Generated tools/packages remain ignored; no Roblox account is needed.
"""
from pathlib import Path
import hashlib
import os
import platform
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
ROKIT_HASHES = {
    "linux-aarch64": "b9ba200dd70620d9dbc11bbb0b368a62c6891328e6bc5fab4b7f68200089553a",
    "linux-x86_64": "951a7f3ec3d2a5e021fd1867d32f69f010ee4c2927f644b759578afc59c65fc0",
    "macos-aarch64": "eb8e6b4f8026db2b80ad0887c50f342958ecdbacbdeda2fd6028b3c4f774a3ee",
    "macos-x86_64": "9643ca30421e9c3dda1f4996bb03b3a43b08dfdc17c28198843e2233e446ba10",
}
DEFINITIONS_URL = "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/1.70.1/scripts/globalTypes.d.luau"
DEFINITIONS_SHA256 = "2857efa8245485f8c25c19c018ee1ef9b46afab4efd2ea70fc3257cd3faf7080"


def download(url: str, path: Path, digest: str) -> None:
    """Fetch a pinned artifact and fail closed on transfer or integrity errors."""
    subprocess.run(["curl", "--fail", "--location", "--silent", "--show-error", url, "--output", str(path)], check=True)
    if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
        path.unlink()
        raise RuntimeError(f"SHA256 mismatch for {url}")


def main() -> None:
    """Bootstrap Rokit, its exact project pins, Wally packages and genuine Roblox types."""
    tools = ROOT / ".tools"
    tools.mkdir(exist_ok=True)
    system = {"Darwin": "macos", "Linux": "linux"}.get(platform.system(), "unsupported")
    machine = {"arm64": "aarch64", "aarch64": "aarch64", "x86_64": "x86_64"}.get(platform.machine(), "unsupported")
    target = f"{system}-{machine}"
    if target not in ROKIT_HASHES:
        raise RuntimeError("Use Rokit 1.2.0 manually on this platform; setup.py supports macOS and Linux.")
    archive = tools / "rokit.zip"
    download(f"https://github.com/rojo-rbx/rokit/releases/download/v1.2.0/rokit-1.2.0-{target}.zip", archive, ROKIT_HASHES[target])
    with zipfile.ZipFile(archive) as bundle:
        (tools / "rokit").write_bytes(bundle.read("rokit"))
    (tools / "rokit").chmod(0o755)
    environment = dict(os.environ, PATH=str(Path.home() / ".rokit/bin") + os.pathsep + os.environ.get("PATH", ""))
    subprocess.run([str(tools / "rokit"), "install", "--no-trust-check"], cwd=ROOT, env=environment, check=True)
    subprocess.run(["wally", "install"], cwd=ROOT, env=environment, check=True)
    subprocess.run(["lune", "setup"], cwd=ROOT, env=environment, check=True)
    download(DEFINITIONS_URL, tools / "globalTypes.d.luau", DEFINITIONS_SHA256)
    print("Pinned tools, Wally TestEZ and engine definitions installed.")


if __name__ == "__main__":
    main()
