#!/usr/bin/env python3

from http.server import HTTPServer, SimpleHTTPRequestHandler  # type: ignore
from pathlib import Path
import os
import sys
import argparse
import subprocess


class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store, max-age=0")
        super().end_headers()


def shell_open(url):
    if sys.platform == "win32":
        os.startfile(url)
    else:
        opener = "open" if sys.platform == "darwin" else "xdg-open"
        subprocess.call([opener, url])


def browser_url(bind_host, port):
    if bind_host in {"", "0.0.0.0", "::"}:
        return f"http://127.0.0.1:{port}"
    return f"http://{bind_host}:{port}"


def serve(root, port, run_browser, bind_host):
    os.chdir(root)
    url = browser_url(bind_host, port)
    server = HTTPServer((bind_host, port), CORSRequestHandler)

    if bind_host in {"", "0.0.0.0", "::"}:
        print(f"Serving HTTP on {bind_host or '0.0.0.0'} port {port}.")
        print(f"Open {url}/ in Chrome; do not open http://0.0.0.0:{port}/ because it is not a secure context.")
    else:
        print(f"Serving HTTP on {bind_host} port {port} ({url}/).")

    if run_browser:
        # Open the served page in the user's default browser.
        print("Opening the served URL in the default browser (use `--no-browser` or `-n` to disable this).")
        shell_open(url)

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nKeyboard interrupt received, exiting.")
    finally:
        server.server_close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", help="port to listen on", default=8060, type=int)
    parser.add_argument("-r", "--root", help="path to serve as root", default=".", type=Path)
    parser.add_argument(
        "-b",
        "--bind",
        help="address to bind to; use 0.0.0.0 for LAN testing, but open localhost/127.0.0.1 in Chrome locally",
        default="127.0.0.1",
    )
    browser_parser = parser.add_mutually_exclusive_group(required=False)
    browser_parser.add_argument(
        "-n", "--no-browser", help="don't open default web browser automatically", dest="browser", action="store_false"
    )
    parser.set_defaults(browser=True)
    args = parser.parse_args()

    # Change to the directory where the script is located,
    # so that the script can be run from any location.
    os.chdir(Path(__file__).resolve().parent)

    serve(args.root, args.port, args.browser, args.bind)
