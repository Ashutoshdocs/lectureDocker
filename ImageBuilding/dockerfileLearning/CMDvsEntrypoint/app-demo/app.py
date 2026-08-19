#!/usr/bin/env python3
"""
app.py  -  a tiny "x-ray" program for CMD vs ENTRYPOINT.

It does one useful thing: it PRINTS exactly how it was launched.
By reading its output you can literally SEE which arguments Docker
handed to it, and therefore prove how CMD and ENTRYPOINT behave.

    argv[0]  = the program name  (always "app.py" here)
    argv[1:] = the arguments that actually reached the app
"""
import os
import sys


def main() -> None:
    args = sys.argv[1:]

    print("=" * 46)
    print("  app.py is running INSIDE the container")
    print("=" * 46)
    print(f"program name (argv[0]) : {sys.argv[0]}")
    print(f"argument count         : {len(args)}")

    if args:
        for i, value in enumerate(args, start=1):
            print(f"  arg[{i}] -> {value!r}")
    else:
        print("  (no arguments were passed)")

    # An env var, to show ENV is a separate channel from CMD/ENTRYPOINT.
    name = os.environ.get("GREET_NAME", "world")

    # Build a visible result from whatever we received.
    result = " ".join(args) if args else f"Hello, {name}!"

    print("-" * 46)
    print(f"RESULT: {result}")
    print("=" * 46)


if __name__ == "__main__":
    main()
