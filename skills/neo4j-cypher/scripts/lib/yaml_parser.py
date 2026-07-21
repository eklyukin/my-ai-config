#!/usr/bin/env python3
"""
Minimal YAML to JSON Converter for Neo4j Skill
Single responsibility: Parse YAML from stdin, output JSON to stdout
No business logic - pure conversion only
"""
import yaml
import json
import sys

def main():
    try:
        # Read YAML from stdin
        yaml_content = sys.stdin.read()

        # Parse YAML
        data = yaml.safe_load(yaml_content)

        # Output as JSON
        print(json.dumps(data, indent=2))
        return 0

    except yaml.YAMLError as e:
        sys.stderr.write(f"YAML parsing error: {e}\n")
        return 1
    except Exception as e:
        sys.stderr.write(f"Unexpected error: {e}\n")
        return 1

if __name__ == "__main__":
    sys.exit(main())
