#!/bin/bash

read -p "Do you want to reset claude (will delete all caches, session history/records)? " reply

if [[ "$reply" =~ [Yy].* ]]; then
	rm -rf ~/.claude*
fi

if [ ! -s ~/.claude.json ]; then
	claude
fi

if [ ! -s ~/.claude.json ]; then
	echo "Please run claude once to create ~/.claude.json"
	exit
fi


pycode='
#!/usr/bin/env python3

import json
import pathlib

SETTINGS = pathlib.Path.home() / ".claude.json"

existing = json.loads(SETTINGS.read_text())
existing["hasCompletedOnboarding"] = True
existing["primaryApiKey"] = "dummy"

SETTINGS.write_text(json.dumps(existing, indent=2) + "\n")
'

python -c "$pycode"

claude

