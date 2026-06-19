# jiravel

A lil tool to see JIRA project velocity. Counts up how many tickets have been moved to "DONE" or "DEV-DONE" in a week.

## Usage

```
./jiravel.rb PROJECT_KEY [--weeks-ago=N] [--years-ago=N] [-q] [-d]
```

- `PROJECT_KEY` — JIRA project name
- `--weeks-ago=N` — look at a week N weeks in the past (default: current week)
- `--years-ago=N` — shift the anchor year back N years
- `-q / --quiet` — print only the summary line, no ticket list
- `-d / --debug` — print the JQL query before executing

## Environment Variables

| Variable | Description |
|---|---|
| `JIRA_URL` | Base URL of your JIRA instance (e.g. `https://you.atlassian.net`) |
| `JIRA_EMAIL` | Email address for JIRA authentication |
| `JIRA_API_TOKEN` | JIRA classic API token |

## mise

If you use mise you can toss env vars in a `mise.toml` in the same directory as this guy and they'll be loaded automatically. Even if you are running him from a different dir (like if you symlink this to ~/.local/bin or some other bin dir in your path)
