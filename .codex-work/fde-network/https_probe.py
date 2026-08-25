from urllib.error import HTTPError
from urllib.request import urlopen


try:
    with urlopen("https://test.ruov.cn/fde-mcp/mcp", timeout=15) as response:
        print(response.status)
except HTTPError as error:
    print(error.code, error.headers.get("Allow"))
