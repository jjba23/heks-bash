# Vision

`heks-bash` generates a `.bashrc` from Scheme: the data half — identity, variables, aliases, functions, greetings, the path — is a parameterised module, and the procedural half is plain Bash that is spliced in verbatim. That split is the project's real subject. A prompt engine, a Git segment and the 984 lines behind the `n` command are not data and never will be; a list of aliases and five variables that say which machine this is are data and should never be a script again. This document is about where that boundary should move next, and about the two front ends — this shell and the Emacs configuration — that share exactly one file format and, at the moment, no test.

## Where heks-bash is today

`(heks-bash bash)` exports `install-bash` and the parameters that make it configurable: `bash-identity` (the five `CC_*` variables — flavour, host kind, sigil, accent, rc file), `bash-vars`, `bash-aliases`, `bash-shared-aliases`, `bash-git-shortcuts`, `bash-functions`, `bash-prelude`, `bash-postlude`, `bash-path-prepends`, `bash-greetings`, `heks-bash-clone-dir`, `shell-lib-filename`, `notes-filename`, `notes-directory`, `lesskey-filename` and `lesskey-target-path`, plus the serialisers that turn each of them into Bash (`serialize-bash-assignment`, `serialize-bash-alias`, `serialize-bash-var`, `serialize-bash-function`, `serialize-bash-path-prepend`, and `bash-config`, which assembles the whole file). `install-bash` writes `~/.bashrc` and copies `lesskey` to `$XDG_CONFIG_HOME/lesskey`, which is the first place `less` 582 and later look — no `lesskey` compile step, and older `less` simply keeps its own keys.

The toolchain is pinned rather than installed. `maak install-bash` runs the module inside `time-machine-manifest-shell`, which is `guix time-machine` over the pinned `channels.scm` (Guix master at `3b4e873`, with the introduction that authenticates it) and the small `manifest.scm` beside it: `guile-next`, `guile-json@4`, `texinfo`, `guile-gcrypt`, `guile-documenta` and `guile-ares-rs`. The same repository is packaged as `guile-heks-bash` in the jointhefreeworld channel, as a library — which is the honest description of what it is: something another configuration calls, not something you install and run.

The prompt is the part a person actually sees, and it is built on every command by `__cc_prompt` from four small functions: `__cc_palette` for the 256-colour accents, `__cc_trim_path` to keep the last three components, `__cc_env_badge` to say whether a Guix shell, a Nix shell or a Python virtualenv is active, and `__cc_git_sync` for the branch, ahead/behind, changed files, conflicts and stashes. All of that comes from one fork: a single `git status --porcelain=v2 --branch`, which is why the segment costs about four milliseconds and needs no plugin. `CC_PLAIN=1`, `NO_COLOR` or `TERM=dumb` renders exactly the same prompt without colour, because a prompt that is only legible in a GUI terminal is a prompt that fails in the place you need it most.

Around the prompt, the library is a set of habits rather than a framework: `about` (machine identity, shell and Git versions, the prompt legend), `pager-keys`, `hist-top`, `rc-time`, `hgrep`, `gunlog`, `mkcd`, `up`, `extract`, `serve`, `psg`, `kport`, `ports`, `notify`, `bak`, `calc`, `json`, `paths`, `ff`, `cdroot`, `reload`, and the terse Git shortcuts. `cc_boot` runs `stty -ixon` so `C-s` is forward-search in readline instead of a frozen terminal, and the pager is `less` everywhere with Emacs keys and `delta` for Git's diffs.

Two integrations deserve to be read as design decisions. `ble.sh` is sourced at startup when it is present, which is what gives the shell syntax highlighting, autosuggestion and a completion menu without changing what a Bash user typed; `install-ble-sh` clones it shallow with its vendored submodules and points `make install` at `~/.local`, so nothing outside the home directory is touched. And `ai` runs the ECA chat with `--workspace` set to the root of the current project, which is a four-line function whose whole point is that the agent starts where the code is.

The `n` command is the largest single thing here: 984 lines of plain Bash that capture, find, search, file, index and bookmark Org notes, with `fzf` pickers when `fzf` is present and plain prompts when it is not. It reads and writes exactly the same files, in exactly the same formats, as the Emacs side — one Org file per note, `todo.org` with an inbox, `habits.org` with repeaters, index pages per topic — and it writes index pages that are byte-identical to the ones Emacs writes. The two implementations share no code; they share a format, and the format is documented in `heks-emacs/docs/notes.org`.

What the project does not have is as clear as what it has. There is no `test/` directory and no `check` task — the Maak file has three tasks, `install-bash`, `install-ble-sh` and `agents` (which regenerates `AGENTS.md` from pinned skills) — so nothing asserts that the generated `.bashrc` sources cleanly, that the prompt renders, or that `n index` writes what Emacs writes. `shellcheck` is not run. And the twins are kept in step by hand: `shell-lib.zsh` in `cask-and-cons` and `shell-lib.bash` here, `lesskey` byte-identical in three repositories, `notes.zsh` and `notes.bash` implementing the same commands twice.

## The vision

1. **One description, two shells, no copies.** The identity, the aliases that both shells can express, the pager keymap and the notes format come from one source, and the `.bashrc` and the `.zshrc` are two renderings of it. Today that source is a convention and three repositories that agree by discipline.

   What has to be true first: the shared shell code becomes a released artefact that the three repositories pin — a file published from one place, not a fourth copy.

2. **The generated configuration is proven to work.** A test sources the generated `.bashrc` in a container, asserts that `about` answers, that the prompt renders in plain mode, that every alias points at something that resolves, and that `n` writes an index page Emacs would write. `maak check` runs it, and `shellcheck` runs over the shell it can see.

   What has to be true first: a harness that runs a shell with a synthetic home, and a decision about what a task may assert without touching the real `~/.bashrc`.

3. **The shell is fast, and the speed is a number the project keeps.** Startup and prompt cost are measured — `rc-time` already averages the startup — and a budget for both fails the build when a change makes an interactive shell slower. A prompt that forks twice is a bug, not a matter of taste.

   What has to be true first: a measurement that is stable enough to gate on, which means a fixed number of runs and a median rather than a mean.

4. **The notes format is a contract with two implementations, and both are tested against it.** `n` and Emacs share the files; the byte-identical index page is a promise, and a promise with no test is a hope. A shared fixture tree, two writers, two outputs and one diff.

   What has to be true first: the fixture lives somewhere both repositories can see, which is the same problem as the shared shell library and has the same answer.

5. **The configuration is portable to a machine that is not this one.** Nothing here should require Guix to *use*, only to build: a Bash on openSUSE or macOS with `fzf` and `less` gets the same prompt, the same helpers and the same `n`, and the machine's differences are five identity variables.

   What has to be true first: the Guix assumptions are enumerated — the profile paths in `PATH`, the `guix env` badge, the `ai` function's dependency on `eca-cli` — and each one degrades rather than breaks.

## Features that are in scope and not built yet

The design anticipates these; each is a seam the current design leaves open.

- **A test harness for the generated file.** Everything is a pure function of parameters to a string, so half the tests are trivial; the other half need a shell in a synthetic home. The hard part is the boundary: what may be asserted about a file whose whole job is to affect an interactive session.
- **`shellcheck` over the shell that exists.** `shell-lib.bash`, `notes.bash` and the ble.sh installer are real Bash with real quoting. The hard part is the noise: a prompt engine uses `printf` with colour codes that `shellcheck` will discuss, and a baseline has to be a decision rather than a `# shellcheck disable`.
- **A pinned `ble.sh`.** `install-ble-sh` clones upstream and points `make install` at `~/.local`, and `ble-update` is how it moves. The hard part is that ble.sh builds itself, so a pin means a version, a commit and a rebuild step — but a shell configuration that changes under you on an upstream push is not reproducible.
- **The shared library as a released artefact.** `shell-lib.bash`, `shell-lib.zsh`, `lesskey`, `notes.bash` and `notes.zsh` are five files with three homes. The hard part is not publishing a tarball; it is deciding which of them is the source and which are renderings.
- **An `n` that knows it is behind.** The notes format has a schema in prose. A version marker per file, or a check that a note has the front matter the index expects, would let `n` say what is wrong instead of writing something Emacs cannot read.
- **The `ai` function's dependency made explicit.** It needs `eca-cli` on the path and says so with the exact command to install it, which is the right instinct. The hard part is that the same instinct is needed for `fzf`, `direnv`, `delta` and `less`: one place that names them and degrades gracefully when one is absent.
- **Startup cost as a test.** `rc-time` measures and nothing gates. The hard part is the threshold: a median over N runs on a machine that is also running the rest of CI.
- **A `guix` assumption audit.** `bash-path-prepends` adds profile paths, `__cc_env_badge` names an active Guix or Nix shell, and `install-ble-sh` clones upstream. Each is a fine assumption for the machine this was written on and a broken promise on a machine without Guix. The hard part is enumerating them, which is a reading of `shell-lib.bash` rather than a design.
- **A per-host greeting.** `bash-greetings` is a pool in Scheme, printed once per startup. The hard part is choosing honestly — by host kind, by time of day, or not at all — which is a decision about the project's voice rather than about its code.

## New features that would be worth having

- **`n doctor`.** Which of the formats the notes tree is in, which topics are indexed, which index pages are stale, which notes have no front matter, which links point at nothing. The `n` command already reads all of that; saying it out loud is the feature.
- **A prompt segment for the working tree's state that costs nothing.** The Git segment is one call. A `[dirty]` marker for a directory that is not a repository, a `[nogit]` for one that should be, and a warning when the current directory is inside a `guix shell` whose manifest has changed since it started — each is a line and each removes a surprise.
- **`about --json`.** Machine identity, versions and tool presence as data, so the same answer can be read by the other three shells, by Emacs and by a `maak` task. The prompt already carries the identity; making it queryable is a small feature with a wide reach.
- **A `n` that works over SSH with no `fzf` and no clipboard.** The fallbacks exist — plain prompts, a TTY check, a `__n_clipboard` that tries more than one mechanism — and they are the least tested code in the library. A mode that forces them, `n --plain`, would make the fallback path a thing someone runs on purpose.
- **Completion for `n` and for `caco`.** `ble.sh` is there precisely to make completion good. A generated completion function — the subcommands are a list in the source — is the natural companion to the pickers.
- **A greeting that is a function of the machine.** The greetings are a pool in Scheme, printed once per interactive startup. Choosing from the pool by host kind, by time of day or by whether the last command failed is a small, characteristic feature: it is one of the few places this configuration has a voice.
- **`heks-bash --print`.** Render the `.bashrc` to standard output instead of installing it. The serialisers already return strings; `install-bash` is what writes them. It makes the diff and the golden file possible, and it is the same feature the sibling project wants for the same reason.
- **A `maak` task the other machines can call.** `install-bash` needs Guix to build the toolchain and the shell to be Bash. A `render` that writes the file anywhere, plus a documented list of the runtime dependencies (`fzf`, `less`, `delta`, `direnv`, `eca-cli`), is what makes this installable on the machine that has no Guix.
- **A `history` report that is not just `hist-top`.** `hist-top` counts commands. The interesting report is the one that says which aliases and functions were never used, which is how a configuration gets pruned instead of growing: the history file already has the answer, and 500,000 entries of it are kept.

## Contributions that would move the needle

Ranked roughly by value per hour.

1. **`maak check` with a shell harness.** The single change that makes every claim in the README testable: source the generated rc in a subshell with `HOME` pointed at a temporary directory, assert `about` answers, that the prompt renders under `CC_PLAIN=1`, and that the file is byte-identical when rendered twice.
2. **`heks-bash --print`, and goldens from it.** A task that writes the rendered file to a path instead of `~/.bashrc` costs a parameter and gives the tests their input and reviewers their diff.
3. **`shellcheck` with a written baseline.** Run it, read the findings, disable the ones that are decisions with a comment that says why, and gate on the rest.
4. **The `n`/Emacs format test.** One fixture tree, two writers, one diff. It belongs to this repository as much as to `heks-emacs`, and whoever writes it settles the question of where the fixture lives.
5. **`about --json`.** Small, useful to three other codebases, and a good first contribution because it touches one function.
6. **`n doctor`.** The most useful thing a user of the notes system could be given, and mostly a matter of collecting what the code already computes.
7. **A pinned `ble.sh`, with the version recorded in the README.** Reproducibility for the one component that builds itself.
8. **`n --plain`.** A mode that forces the fallback paths, so the code that runs when `fzf` is absent is the code someone tested.
9. **A written inventory of the runtime dependencies.** `fzf`, `less`, `delta`, `direnv`, `ble.sh`, `eca-cli`, `guix`, `nix` — each already detected somewhere in the library. One table saying what each is for and what happens without it is the single document that makes this configuration usable on a machine that is not the one it was written on.
10. **The ble.sh and lesskey story in one paragraph each.** Both are installed by the configuration, both are someone else's software, and both are explained only in passing. A contributor who wants to change either needs to know which file wins and why.

## Compared to related projects

| Project | What it is | Where heks-bash differs |
|---|---|---|
| oh-my-bash, bash-it | Frameworks of themes, plugins and aliases that your `.bashrc` sources | They are libraries you source and configure with variables; this generates the file. A framework's plugin order is a runtime question, and here it is a list in Scheme that is serialised in order |
| Starship | A cross-shell prompt written in Rust, configured with TOML, spawned per prompt | Starship is a process; this is a function. The Git segment here is one `git` call inside the shell, which is why `rc-time` reports milliseconds rather than a startup cost per prompt, and why the prompt can read `CC_*` variables that only this machine has |
| ble.sh | A line editor for Bash with syntax highlighting, autosuggestion and a completion menu | Not a competitor — a dependency, sourced at startup, and the reason this configuration has completion at all. `heks-bash` is what decides that it should be there and where it is installed |
| zsh-autosuggestions, oh-my-zsh, powerlevel10k | The same family of tools for Zsh: plugins, frameworks, and an extremely fast prompt | The reason this project has a Zsh twin. The prompt here was written to look the same on both shells, which is a requirement none of those tools has: they are each excellent on one shell, and a person running both ends up with two prompts |
| liquidprompt | An adaptive prompt for Bash and Zsh that shows context and integrates with version control | Closest in spirit: a prompt that knows about Git, virtualenvs and load. The difference is generation — liquidprompt is a large script you source and configure with a config file, and this is a small library plus a data declaration |
| GNU Guix Home's `home-bash-service-type` | A Guix service that writes `~/.bashrc` with declared aliases and environment variables | The nearest neighbour in mechanism, and it stops where the interesting part starts: a service can declare a file, not a 564-line prompt engine and a 984-line notes command. This project is what you write when the declarative layer is Guix and the shell is still yours |
| Nix `home-manager`'s `programs.bash` | The same idea for Nix: a module that writes the rc file from Nix expressions | Same mechanism, a different language, and the same omission — the prompt is a string or a `starship` invocation |
| A hand-written `.bashrc` from a dotfiles repository | The default: a long file of exports, aliases and conditionals, copied between machines | The competition that actually matters. A hand-written rc is edited in place and drifts; this one is generated from parameters and can be re-rendered, which is the difference the whole project rests on |

The others do two things this project could add. Starship's portability is the real competition: one binary, any shell, a configuration in a file. What it does not have is the rest of a shell — the aliases, the helpers, the pager keymap, the notes command — and that is why the comparison ends where it does. And oh-my-bash's ecosystem is the thing a framework really offers: other people's plugins. Nothing stops `heks-bash` from declaring a list of sourced plugin paths, and it would be a data definition rather than a rewrite.

The Guix Home and home-manager rows are the most instructive, because they are the shape this project would have if it had been written by someone else. A service that declares `~/.bashrc` with an `(aliases '((ll "ls -l")))` form is exactly the data half of `heks-bash` — and the reason both stop there is that the interesting content is procedural. The lesson is not that they are wrong; it is that a declarative shell needs a way to carry a script, and splicing one verbatim is a legitimate answer that neither of them takes.

Where `heks-bash` is ahead and should stay ahead: the prompt costs one `git` call and no process, and that is measurable; the same prompt, palette and helpers run on three machines and two shells, which no single-shell tool attempts; the generated file is a file a person can read, edit and diff, with the data that produced it in Scheme next door; and the `n` command makes the terminal a real front end to the notes system rather than a viewer for it.

Where `heks-bash` is ahead and should stay ahead: the prompt costs one `git` call and no process, and that is measurable; the same prompt, palette and helpers run on three machines and two shells, which no single-shell tool attempts; the generated file is a file a person can read, edit and diff, with the data that produced it in Scheme next door; and the `n` command makes the terminal a real front end to the notes system rather than a viewer for it.

## In the long run

- **The shell as the second front end of one system.** The identity record, the pager keymap, the notes format and the prompt are the same on every machine this person uses. The bet is that the description moves into one place and the shells become renderings — and that this repository is the one that holds the Bash rendering rather than the copy.
- **A shell configuration that is tested like software.** With `--print`, goldens, a shell harness and `shellcheck`, the claims in the README become checks. The bet is that a configuration people copy from becomes a configuration people can trust, which is a different kind of project.
- **Milliseconds as a design constraint.** `rc-time` exists because someone noticed. The bet is that prompt latency stays a budget rather than a hope, and that the constraint shapes what gets added — no subprocess in the prompt, no plugin system, no theme engine.
- **The notes format outliving both implementations.** Org files with front matter and generated index pages will still be readable when `n` and the Emacs modules are gone. The bet is that the format is documented as a format, with a fixture and two writers agreeing on it, rather than as two programs that happen to write the same thing.
- **A configuration that runs where Guix does not.** Guix is how it is built; Bash is where it runs. The bet is that the build stays pinned and reproducible while the thing it produces needs nothing but a shell, which is the same bargain the rest of this collection makes in other languages.
- **A shell library with a version.** Five files, three homes, one meaning. The bet is that the shared half is eventually published and consumed the way any other library is — with a version, a changelog and a pin — and that the two shells are then two renderings of one document rather than two documents that agree.
- **A prompt that is a data structure.** `__cc_prompt` builds a string from parts. The parts — user, host, badge, path, environment, git, sigil — are already the interesting data, and the bet is that they become a list a machine can add to, so a new segment is a declaration and not an edit to a 50-line function.

## A closing note

The decision worth protecting here is the boundary between the two halves: data in Scheme, procedure in Bash, spliced rather than generated. A prompt engine written as Scheme string literals would be unreadable, and an alias list written as Bash would be unreviewable. Everything above — the tests, the shared library, the portability — depends on that boundary staying where it is and the seam staying visible.

The other thing worth keeping is the honesty about what a shell is for. `cc_boot` runs `stty -ixon` so `C-s` searches instead of freezing; `CC_PLAIN=1` keeps the prompt legible in a terminal that cannot do colour; `n` falls back to plain prompts when `fzf` is absent; `about` prints the legend when the sigils stop meaning anything. Every one of those is a small admission that the environment is not always the good one, and together they are the reason this configuration is usable rather than merely pretty.

*This document describes intent, not commitments: it names directions the maintainer finds worth taking, and nothing here is a promise that a given feature will exist, in the order listed, or at all.*
