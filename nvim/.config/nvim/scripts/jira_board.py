#!/usr/bin/env python3
"""Print the issues on a Jira board as JSON lines, in board-column order and then by rank.

jira-cli cannot list a board: it returns at most 100 issues and limits every query to one
project, while a board's filter can span several. This reads the board API directly.

Usage: jira_board.py BOARD_ID [EXTRA_JQL]

Uses the same credentials as jira-cli: JIRA_API_TOKEN, or the server's entry in ~/.netrc.
"""

import base64
import json
import netrc
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request

FIELDS = "issuetype,assignee,status,summary,labels"


def jira_config():
    path = os.environ.get("JIRA_CONFIG_FILE") or os.path.expanduser("~/.config/.jira/.config.yml")
    conf = {}
    with open(path, encoding="utf-8") as f:
        for line in f:
            match = re.match(r"^(server|login):\s*(\S+)", line)
            if match:
                conf[match[1]] = match[2]
    return conf


def auth_header(server, login):
    host = urllib.parse.urlparse(server).hostname
    token = os.environ.get("JIRA_API_TOKEN")
    if not token:
        try:
            entry = netrc.netrc().authenticators(host)
        except (FileNotFoundError, netrc.NetrcParseError):
            entry = None
        if entry:
            login, token = entry[0], entry[2]
    if not token:
        sys.exit(f"jira_board: no credentials for {host} in JIRA_API_TOKEN or ~/.netrc")
    return "Basic " + base64.b64encode(f"{login}:{token}".encode()).decode()


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    board, jql = sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else ""
    conf = jira_config()
    server = conf["server"].rstrip("/")
    headers = {"Authorization": auth_header(server, conf.get("login", "")), "Accept": "application/json"}

    def get(path, **params):
        query = urllib.parse.urlencode({k: v for k, v in params.items() if v != ""})
        request = urllib.request.Request(f"{server}{path}?{query}", headers=headers)
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        except urllib.error.HTTPError as err:
            sys.exit(f"jira_board: {err.code} {err.reason} for {path}: {err.read().decode(errors='replace')[:300]}")

    columns = get(f"/rest/agile/1.0/board/{board}/configuration")["columnConfig"]["columns"]
    column_of = {s["id"]: (i, c["name"]) for i, c in enumerate(columns) for s in c["statuses"]}

    issues = []
    while True:
        page = get(f"/rest/agile/1.0/board/{board}/issue", startAt=len(issues), maxResults=100, fields=FIELDS, jql=jql)
        issues += page["issues"]
        if not page["issues"] or len(issues) >= page["total"]:
            break

    rows = []
    for issue in issues:
        fields = issue["fields"]
        status = fields["status"]
        # statuses the board does not map to a column go last, under their own name
        index, column = column_of.get(status["id"], (len(columns), status["name"]))
        assignee = fields.get("assignee") or {}
        rows.append((index, {
            "type": fields["issuetype"]["name"],
            "key": issue["key"],
            "assignee": assignee.get("displayName", ""),
            "status": status["name"],
            "summary": fields["summary"],
            "labels": ",".join(fields.get("labels") or []),
            "column": column.upper(),
        }))
    rows.sort(key=lambda row: row[0])  # stable, so issues keep their rank order within a column
    for _, row in rows:
        print(json.dumps(row, ensure_ascii=False))


if __name__ == "__main__":
    main()
