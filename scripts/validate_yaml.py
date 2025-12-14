#!/usr/bin/env python3
"""
Basic YAML syntax validator for Home Assistant configuration files.
This script checks for basic YAML syntax errors before deployment.

Usage:
    python3 scripts/validate_yaml.py
    python3 scripts/validate_yaml.py <specific_file.yaml>
"""

import sys
import yaml
from pathlib import Path


def validate_yaml_file(file_path):
    """Validate a single YAML file for syntax errors."""
    try:
        with open(file_path, "r") as f:
            yaml.safe_load(f)
        return True, None
    except yaml.YAMLError as e:
        return False, str(e)
    except Exception as e:
        return False, f"Error reading file: {str(e)}"


def main():
    """Main validation function."""
    config_dir = Path(__file__).parent.parent

    # If specific file provided, validate only that file
    if len(sys.argv) > 1:
        file_path = Path(sys.argv[1])
        if not file_path.exists():
            print(f"❌ File not found: {file_path}")
            sys.exit(1)

        valid, error = validate_yaml_file(file_path)
        if valid:
            print(f"✅ {file_path.name} - Valid YAML")
            sys.exit(0)
        else:
            print(f"❌ {file_path.name} - Invalid YAML:")
            print(f"   {error}")
            sys.exit(1)

    # Otherwise, validate all YAML files
    yaml_files = list(config_dir.glob("*.yaml"))
    yaml_files.extend(config_dir.glob("automation/*.yaml"))
    yaml_files.extend(config_dir.glob("config/*.yaml"))
    yaml_files.extend(config_dir.glob("scripts/*.yaml"))
    yaml_files.extend(config_dir.glob("shell/*.yaml"))

    # Filter out files to ignore
    ignore_patterns = [".storage", "secrets.yaml", "known_devices.yaml"]
    yaml_files = [
        f
        for f in yaml_files
        if not any(pattern in str(f) for pattern in ignore_patterns)
    ]

    print(f"Validating {len(yaml_files)} YAML files...\n")

    errors = []
    for file_path in sorted(yaml_files):
        valid, error = validate_yaml_file(file_path)
        relative_path = file_path.relative_to(config_dir)

        if valid:
            print(f"✅ {relative_path}")
        else:
            print(f"❌ {relative_path}")
            errors.append((relative_path, error))

    print(f"\n{'=' * 60}")
    if errors:
        print(f"❌ Validation failed: {len(errors)} file(s) with errors\n")
        for file_path, error in errors:
            print(f"{file_path}:")
            print(f"  {error}\n")
        sys.exit(1)
    else:
        print(f"✅ All YAML files are valid!")
        sys.exit(0)


if __name__ == "__main__":
    main()
