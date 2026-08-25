from __future__ import annotations

import argparse
import getpass
import json

import fde_publish_support as fde


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--account", required=True)
    parser.add_argument("--employee-id", required=True)
    args = parser.parse_args()

    token = fde.login(
        args.url,
        args.user,
        getpass.getpass(f"FDE password ({args.user}): "),
    )
    names = fde.call_tool(
        args.url,
        "list_account_custom_employee_names",
        {"session_token": token, "account": args.account},
    )
    matching_names = [
        row
        for row in names
        if isinstance(row, dict) and row.get("employee_id") == args.employee_id
    ] if isinstance(names, list) else names
    print(json.dumps({"matching_names": matching_names}, ensure_ascii=False))

    for tool in ("get_release_state", "get_employee_mounts"):
        try:
            result = fde.call_tool(
                args.url,
                tool,
                {
                    "session_token": token,
                    "account": args.account,
                    "employee_id": args.employee_id,
                },
            )
            payload = {"tool": tool, "ok": True, "result": result}
        except Exception as error:
            payload = {"tool": tool, "ok": False, "error": str(error)}
        print(json.dumps(payload, ensure_ascii=False))


if __name__ == "__main__":
    main()
