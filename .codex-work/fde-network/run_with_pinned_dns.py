"""Run one Python script while pinning one hostname to one verified IP address.

The requested URL and TLS hostname remain unchanged; only process-local DNS
resolution is replaced. This avoids a local fake-IP DNS mapping without
disabling certificate verification or editing the reviewed publisher.
"""

from __future__ import annotations

import argparse
import ipaddress
import runpy
import socket
import sys
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", required=True)
    parser.add_argument("--ip", required=True)
    parser.add_argument("script", type=Path)
    parser.add_argument("args", nargs=argparse.REMAINDER)
    options = parser.parse_args()

    pinned_host = options.host.rstrip(".").lower()
    pinned_ip = str(ipaddress.ip_address(options.ip))
    original_getaddrinfo = socket.getaddrinfo

    def pinned_getaddrinfo(host, port, family=0, type=0, proto=0, flags=0):
        normalized = host.rstrip(".").lower() if isinstance(host, str) else host
        resolved_host = pinned_ip if normalized == pinned_host else host
        return original_getaddrinfo(
            resolved_host, port, family, type, proto, flags
        )

    socket.getaddrinfo = pinned_getaddrinfo
    script = options.script.resolve(strict=True)
    sys.path.insert(0, str(script.parent))
    sys.argv = [str(script), *options.args]
    runpy.run_path(str(script), run_name="__main__")


if __name__ == "__main__":
    main()
