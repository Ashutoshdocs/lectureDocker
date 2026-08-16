# CMD vs ENTRYPOINT — a hands-on Docker practical

A small lab that lets you **see and prove** how Docker's `CMD` and `ENTRYPOINT`
behave, separately and together. Every example uses the same tiny program,
`app-demo/app.py`, which prints exactly which arguments reached it — so you can
literally watch what each instruction does.

---

## The one-line mental model

| Instruction  | What it is                                   | Replaced by `docker run img args`? |
|--------------|----------------------------------------------|------------------------------------|
| `CMD`        | The **default command / default arguments**  | ✅ Yes — fully replaced             |
| `ENTRYPOINT` | The **fixed executable** the container *is*  | ❌ No — args are *appended* to it   |

> **Rule of thumb:** `ENTRYPOINT` says *what always runs*. `CMD` says *the
> default arguments it runs with*. Users override the arguments, not the app.

---

## Folder layout

```
cmd-entrypoint-demo/
├── README.md                  <- you are here (the guide)
├── 01-Dockerfile.cmd          <- CMD only
├── 02-Dockerfile.entrypoint   <- ENTRYPOINT only
├── 03-Dockerfile.both         <- ENTRYPOINT + CMD (the good pattern)
├── 04-Dockerfile.override     <- the shell-form trap + override practice
└── app-demo/
    ├── app.py                 <- the "x-ray" program that prints its argv
    └── Dockerfile             <- a realistic, production-style image
```

## Prerequisites

- Docker installed and running (`docker --version`)
- A terminal opened **inside the `cmd-entrypoint-demo/` folder**

## Build everything (run once)

From the `cmd-entrypoint-demo/` folder:

```bash
docker build -f 01-Dockerfile.cmd        -t demo:cmd        .
docker build -f 02-Dockerfile.entrypoint -t demo:entrypoint .
docker build -f 03-Dockerfile.both       -t demo:both       .
docker build -f 04-Dockerfile.override   -t demo:override   .

# the realistic app (build from inside its own folder)
docker build -t demo:app ./app-demo
```

---

## Lesson 1 — `CMD` only  (`01-Dockerfile.cmd`)

`CMD ["python", "app.py", "default-from-CMD"]`

```bash
# 1a. No args -> the CMD default runs
docker run --rm demo:cmd
#   argument count : 1
#   RESULT: default-from-CMD

# 1b. Give your own command -> CMD is COMPLETELY replaced
docker run --rm demo:cmd python app.py alice
#   RESULT: alice

# 1c. Replace it with something else entirely -> app.py never runs
docker run --rm demo:cmd echo hi
#   hi
```

**Proves:** anything after the image name *throws the whole `CMD` away*. In 1c,
`app.py` is never executed at all.

---

## Lesson 2 — `ENTRYPOINT` only  (`02-Dockerfile.entrypoint`)

`ENTRYPOINT ["python", "app.py"]`

```bash
# 2a. No args -> app runs with nothing
docker run --rm demo:entrypoint
#   argument count : 0
#   RESULT: Hello, world!

# 2b. Args are APPENDED to the entrypoint (not replaced)
docker run --rm demo:entrypoint alice bob
#   RESULT: alice bob

# 2c. "echo hi" becomes ARGUMENTS to app.py — echo is NOT run
docker run --rm demo:entrypoint echo hi
#   RESULT: echo hi

# 2d. ENV is a separate channel from CMD/ENTRYPOINT
docker run --rm -e GREET_NAME=Sam demo:entrypoint
#   RESULT: Hello, Sam!

# 2e. The ONLY way to replace an entrypoint: the --entrypoint flag
docker run --rm --entrypoint echo demo:entrypoint hi there
#   hi there
```

**Proves:** `ENTRYPOINT` is sticky. Run-time words become *its* arguments (2b,
2c). It changes only via `--entrypoint` (2e).

---

## Lesson 3 — `ENTRYPOINT` + `CMD` together  (`03-Dockerfile.both`)  ⭐

```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["default-user"]
```

Docker concatenates them: `ENTRYPOINT` + `CMD` = `python app.py default-user`.

```bash
# 3a. No args -> ENTRYPOINT runs with the CMD default appended
docker run --rm demo:both
#   RESULT: default-user

# 3b. Args replace ONLY the CMD part; the executable stays locked
docker run --rm demo:both alice bob
#   RESULT: alice bob

# 3c. See exactly what Docker stored
docker inspect --format 'ENTRYPOINT={{.Config.Entrypoint}}  CMD={{.Config.Cmd}}' demo:both
#   ENTRYPOINT=[python app.py]  CMD=[default-user]
```

**Proves:** this is the pattern you almost always want — a fixed program with
overridable default arguments.

---

## Lesson 4 — the shell-form trap  (`04-Dockerfile.override`)

```dockerfile
ENTRYPOINT python app.py baked-in   # shell form (intentionally wrong)
CMD ["this-is-ignored"]
```

Shell form makes Docker run `/bin/sh -c "python app.py baked-in"`, so both the
`CMD` and any run-time args are silently dropped.

```bash
# 4a. CMD is ignored
docker run --rm demo:override
#   RESULT: baked-in

# 4b. Run-time args are ALSO ignored (compare with 3b!)
docker run --rm demo:override alice bob
#   RESULT: baked-in      <- your args vanished
```

**Proves:** always prefer **exec form** (`["python", "app.py"]`). Shell form
breaks argument passing *and* signal handling (the app won't be PID 1, so
`Ctrl+C` / `docker stop` won't reach it cleanly).

---

## Putting it together — the realistic app  (`app-demo/Dockerfile`)

```dockerfile
ENTRYPOINT ["python", "app.py"]
CMD ["Hello", "from", "CMD", "defaults"]
```

```bash
# Uses the baked-in CMD defaults
docker run --rm demo:app
#   RESULT: Hello from CMD defaults

# User overrides just the arguments — no need to know it's Python
docker run --rm demo:app good morning team
#   RESULT: good morning team
```

This is the takeaway design: the image *is* the app (`ENTRYPOINT`), and it ships
with friendly defaults (`CMD`) that anyone can override.

---

## Try-it-yourself challenges

1. Predict the output **before** running each command in Lessons 1–4.
2. Make `demo:both` print `Hello, Ada!` **without** editing the Dockerfile.
   <br>*(hint: it needs zero args, so override the entrypoint — `--entrypoint`)*
3. Fix `04-Dockerfile.override` so run-time args work again. Rebuild and rerun 4b.
4. Add a second default arg to `app-demo`'s `CMD` and confirm both appear.

---

## Quick reference / cheat sheet

```
CMD ["exe","arg"]                 default command, fully overridable
CMD ["arg1","arg2"]               default ARGS for an ENTRYPOINT
ENTRYPOINT ["exe","arg"]          fixed executable, args get appended
ENTRYPOINT + CMD                  exe = ENTRYPOINT, default args = CMD

docker run img                    -> ENTRYPOINT + CMD
docker run img a b                -> ENTRYPOINT + [a b]   (CMD dropped)
docker run --entrypoint x img a   -> x a                  (ENTRYPOINT replaced)

exec form  ["a","b"]   ✅ preferred: real PID 1, args + signals work
shell form  a b        ⚠️ runs via /bin/sh -c: ignores args & CMD, no PID 1
```

## Clean up

```bash
docker rmi demo:cmd demo:entrypoint demo:both demo:override demo:app
```
