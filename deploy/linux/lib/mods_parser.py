#!/usr/bin/env python3
"""
mods_parser.py — Parser e validação declarativa de mods/manifest.yaml
Uso em scripts bash e CI/CD (sem interação).
"""
from __future__ import annotations

import argparse
import glob
import os
import re
import sys
from pathlib import Path
from typing import Any

try:
    import yaml
except ImportError:
    print("ERROR: python3-yaml required (apt install python3-yaml)", file=sys.stderr)
    sys.exit(2)


DEFAULTS = {
    "required": True,
    "enabled": True,
    "load_order": 100,
    "depends_on": [],
}


def load_manifest(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Manifest not found: {path}")
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise ValueError("manifest.yaml root must be a mapping")
    return data


def normalize_local(entry: Any) -> dict[str, Any]:
    if isinstance(entry, str):
        return {
            "name": entry,
            "folder": entry,
            "required": DEFAULTS["required"],
            "enabled": DEFAULTS["enabled"],
            "load_order": DEFAULTS["load_order"],
            "depends_on": list(DEFAULTS["depends_on"]),
        }
    if isinstance(entry, dict):
        folder = entry.get("folder") or entry.get("name")
        if not folder:
            raise ValueError(f"local_mod missing folder: {entry}")
        return {
            "name": entry.get("name", folder),
            "folder": folder,
            "required": entry.get("required", DEFAULTS["required"]),
            "enabled": entry.get("enabled", DEFAULTS["enabled"]),
            "load_order": entry.get("load_order", DEFAULTS["load_order"]),
            "depends_on": list(entry.get("depends_on") or []),
        }
    raise ValueError(f"Invalid local_mod entry: {entry}")


def normalize_workshop(mod: dict[str, Any], section: str) -> dict[str, Any]:
    if not mod.get("folder"):
        raise ValueError(f"{section} mod missing folder: {mod}")
    return {
        "name": mod.get("name", mod["folder"]),
        "id": str(mod["id"]) if mod.get("id") is not None else None,
        "folder": mod["folder"],
        "required": mod.get("required", DEFAULTS["required"]),
        "enabled": mod.get("enabled", DEFAULTS["enabled"]),
        "load_order": mod.get("load_order", DEFAULTS["load_order"]),
        "depends_on": list(mod.get("depends_on") or []),
        "section": section,
    }


def enabled_mods(data: dict[str, Any], section: str) -> list[dict[str, Any]]:
    mods: list[dict[str, Any]] = []
    if section == "client":
        for m in data.get("client_mods") or []:
            if not isinstance(m, dict):
                continue
            mod = normalize_workshop(m, "client_mods")
            if mod["enabled"]:
                mods.append(mod)
        for entry in data.get("local_mods") or []:
            mod = normalize_local(entry)
            mod["section"] = "local_mods"
            if mod["enabled"]:
                mods.append(mod)
    elif section == "server":
        for m in data.get("server_mods") or []:
            if not isinstance(m, dict):
                continue
            mod = normalize_workshop(m, "server_mods")
            if mod["enabled"]:
                mods.append(mod)
    mods.sort(key=lambda x: (x.get("load_order", 100), x["folder"]))
    return mods


def join_folders(mods: list[dict[str, Any]]) -> str:
    return ";".join(m["folder"] for m in mods)


def workshop_app_id(data: dict[str, Any]) -> str:
    return str(data.get("workshop_app_id", 221100))


def parse_mission_template(server_cfg: Path) -> str | None:
    if not server_cfg.is_file():
        return None
    text = server_cfg.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r'template\s*=\s*"([^"]+)"', text)
    return m.group(1) if m else None


def find_bikeys(mod_dir: Path) -> list[Path]:
    keys_dir = mod_dir / "keys"
    if keys_dir.is_dir():
        return sorted(keys_dir.glob("*.bikey"))
    return []


def validate_bikeys(mod_dir: Path, server_keys: Path, folder: str) -> list[str]:
    errors: list[str] = []
    bikeys = find_bikeys(mod_dir)
    if not bikeys:
        return errors
    for bk in bikeys:
        dest = server_keys / bk.name
        if not dest.is_file():
            errors.append(f"CRITICAL: .bikey ausente em server/keys: {bk.name} (mod {folder})")
    return errors


class Validator:
    def __init__(
        self,
        manifest_path: Path,
        server_dir: Path,
        project_dir: Path,
        profiles_dir: Path,
        config_name: str = "serverDZ.cfg",
    ):
        self.manifest_path = manifest_path
        self.server_dir = server_dir
        self.project_dir = project_dir
        self.profiles_dir = profiles_dir
        self.config_name = config_name
        self.errors: list[str] = []
        self.warnings: list[str] = []
        self.data: dict[str, Any] = {}

    def add_critical(self, msg: str) -> None:
        self.errors.append(msg)

    def add_warn(self, msg: str) -> None:
        self.warnings.append(msg)

    def run(self) -> int:
        try:
            self.data = load_manifest(self.manifest_path)
        except Exception as e:
            self.add_critical(f"manifest.yaml inválido: {e}")
            return 1

        if self.data.get("version") is None:
            self.add_warn("manifest.yaml: campo 'version' ausente")

        self._check_duplicates()
        self._check_directories()
        self._check_server_config()
        self._check_mission()
        self._check_mods()
        self._check_depends_on()

        for w in self.warnings:
            print(f"WARN: {w}", file=sys.stderr)
        for e in self.errors:
            print(f"ERROR: {e}", file=sys.stderr)

        return 1 if self.errors else 0

    def _all_mod_entries(self) -> list[dict[str, Any]]:
        entries: list[dict[str, Any]] = []
        for m in self.data.get("client_mods") or []:
            if isinstance(m, dict) and m.get("enabled", True):
                entries.append(normalize_workshop(m, "client_mods"))
        for m in self.data.get("server_mods") or []:
            if isinstance(m, dict) and m.get("enabled", True):
                entries.append(normalize_workshop(m, "server_mods"))
        for entry in self.data.get("local_mods") or []:
            mod = normalize_local(entry)
            if mod["enabled"]:
                mod["section"] = "local_mods"
                entries.append(mod)
        return entries

    def _check_duplicates(self) -> None:
        ids: dict[str, str] = {}
        folders: dict[str, str] = {}
        for mod in self._all_mod_entries():
            if mod.get("id"):
                wid = mod["id"]
                if wid in ids:
                    self.add_critical(
                        f"Workshop ID duplicado: {wid} ({ids[wid]} e {mod['folder']})"
                    )
                else:
                    ids[wid] = mod["folder"]
            folder = mod["folder"]
            if folder in folders:
                self.add_critical(
                    f"Pasta duplicada: {folder} ({folders[folder]} e {mod.get('name')})"
                )
            else:
                folders[folder] = mod.get("name", folder)

    def _check_directories(self) -> None:
        required = [
            ("server", self.server_dir),
            ("profiles", self.profiles_dir),
            ("project", self.project_dir),
        ]
        for label, path in required:
            if not path.is_dir():
                self.add_critical(f"Diretório obrigatório ausente ({label}): {path}")

    def _check_server_config(self) -> None:
        cfg = self.server_dir / self.config_name
        project_cfg = self.project_dir / "config" / self.config_name
        if not cfg.is_file() and not project_cfg.is_file():
            self.add_critical(f"serverDZ.cfg não encontrado em {cfg} nem em {project_cfg}")

    def _check_mission(self) -> None:
        cfg = self.server_dir / self.config_name
        if not cfg.is_file():
            cfg = self.project_dir / "config" / self.config_name
        template = parse_mission_template(cfg) if cfg.is_file() else None
        if not template:
            self.add_warn("Não foi possível ler template da missão em serverDZ.cfg")
            return
        mission_dir = self.server_dir / "mpmissions" / template
        if not mission_dir.is_dir():
            self.add_critical(
                f"Missão configurada não encontrada: mpmissions/{template}"
            )

    def _check_mods(self) -> None:
        server_keys = self.server_dir / "keys"
        local_root = self.project_dir / "mods" / "local"

        for mod in self._all_mod_entries():
            folder = mod["folder"]
            required = mod.get("required", True)
            section = mod.get("section", "")
            server_mod_path = self.server_dir / folder.lstrip("/")

            if section == "local_mods":
                local_path = local_root / folder
                if not local_path.is_dir():
                    msg = f"Mod local ausente no repositório: mods/local/{folder}"
                    if required:
                        self.add_critical(msg)
                    else:
                        self.add_warn(msg)
                    continue

            if not server_mod_path.is_dir():
                msg = f"Mod declarado mas ausente no servidor: {server_mod_path}"
                if required:
                    self.add_critical(msg)
                else:
                    self.add_warn(msg)
                continue

            addons = list(server_mod_path.glob("addons/*.pbo"))
            if not addons and required:
                self.add_warn(f"Mod sem addons/*.pbo detectados: {folder}")

            if server_keys.is_dir():
                for err in validate_bikeys(server_mod_path, server_keys, folder):
                    if required:
                        self.add_critical(err)
                    else:
                        self.add_warn(err.replace("CRITICAL: ", ""))

    def _check_depends_on(self) -> None:
        enabled_folders = {m["folder"] for m in self._all_mod_entries()}
        for mod in self._all_mod_entries():
            for dep in mod.get("depends_on") or []:
                if dep not in enabled_folders:
                    self.add_critical(
                        f"Dependência não satisfeita: {mod['folder']} depende de {dep}"
                    )
                dep_order = next(
                    (m.get("load_order", 100) for m in self._all_mod_entries() if m["folder"] == dep),
                    None,
                )
                if dep_order is not None and dep_order >= mod.get("load_order", 100):
                    self.add_warn(
                        f"load_order: {mod['folder']} ({mod.get('load_order')}) "
                        f"deveria ser maior que {dep} ({dep_order})"
                    )


def cmd_validate(args: argparse.Namespace) -> int:
    v = Validator(
        Path(args.manifest),
        Path(args.server_dir),
        Path(args.project_dir),
        Path(args.profiles_dir),
        args.config,
    )
    return v.run()


def cmd_mod_arg(args: argparse.Namespace) -> int:
    data = load_manifest(Path(args.manifest))
    section = "client" if args.section == "client" else "server"
    mods = enabled_mods(data, section)
    print(join_folders(mods))
    return 0


def cmd_list_mods(args: argparse.Namespace) -> int:
    data = load_manifest(Path(args.manifest))
    section = "client" if args.section == "client" else "server"
    for mod in enabled_mods(data, section):
        print(
            f"{mod['folder']}\t{mod.get('load_order', 100)}\t"
            f"{mod.get('name', '')}\t{mod.get('section', '')}"
        )
    return 0


def cmd_workshop_mods(args: argparse.Namespace) -> int:
    data = load_manifest(Path(args.manifest))
    section = args.workshop_section
    for m in data.get(section) or []:
        if not isinstance(m, dict):
            continue
        mod = normalize_workshop(m, section)
        if mod["enabled"] and mod.get("id"):
            print(f"{mod['id']}\t{mod['folder']}\t{mod.get('name', '')}")
    return 0


def cmd_workshop_app_id(args: argparse.Namespace) -> int:
    data = load_manifest(Path(args.manifest))
    print(workshop_app_id(data))
    return 0


def cmd_mission(args: argparse.Namespace) -> int:
    cfg = Path(args.server_dir) / args.config
    if not cfg.is_file():
        cfg = Path(args.project_dir) / "config" / args.config
    template = parse_mission_template(cfg) if cfg.is_file() else None
    print(template or "")
    return 0


def cmd_server_build(args: argparse.Namespace) -> int:
    manifest_file = Path(args.server_dir) / "steamapps" / "appmanifest_223350.acf"
    if not manifest_file.is_file():
        print("unknown")
        return 0
    text = manifest_file.read_text(encoding="utf-8", errors="ignore")
    m = re.search(r'"buildid"\s+"(\d+)"', text)
    print(m.group(1) if m else "unknown")
    return 0


def main() -> int:
    p = argparse.ArgumentParser(description="DayZ mods manifest parser")
    sub = p.add_subparsers(dest="command", required=True)

    v = sub.add_parser("validate", help="Validate manifest and environment")
    v.add_argument("--manifest", required=True)
    v.add_argument("--server-dir", required=True)
    v.add_argument("--project-dir", required=True)
    v.add_argument("--profiles-dir", required=True)
    v.add_argument("--config", default="serverDZ.cfg")
    v.set_defaults(func=cmd_validate)

    for name, section in [("client-mod-arg", "client"), ("server-mod-arg", "server")]:
        c = sub.add_parser(name)
        c.add_argument("--manifest", required=True)
        c.add_argument("--section", default=section)
        c.set_defaults(func=cmd_mod_arg, section=section)

    for name, section in [("list-client-mods", "client"), ("list-server-mods", "server")]:
        c = sub.add_parser(name)
        c.add_argument("--manifest", required=True)
        c.set_defaults(func=cmd_list_mods, section=section)

    w = sub.add_parser("workshop-client-mods")
    w.add_argument("--manifest", required=True)
    w.set_defaults(func=cmd_workshop_mods, workshop_section="client_mods")

    ws = sub.add_parser("workshop-server-mods")
    ws.add_argument("--manifest", required=True)
    ws.set_defaults(func=cmd_workshop_mods, workshop_section="server_mods")

    wa = sub.add_parser("workshop-app-id")
    wa.add_argument("--manifest", required=True)
    wa.set_defaults(func=cmd_workshop_app_id)

    m = sub.add_parser("mission")
    m.add_argument("--manifest", required=True)
    m.add_argument("--server-dir", required=True)
    m.add_argument("--project-dir", required=True)
    m.add_argument("--config", default="serverDZ.cfg")
    m.set_defaults(func=cmd_mission)

    b = sub.add_parser("server-build")
    b.add_argument("--server-dir", required=True)
    b.set_defaults(func=cmd_server_build)

    args = p.parse_args()
    try:
        return args.func(args)
    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
