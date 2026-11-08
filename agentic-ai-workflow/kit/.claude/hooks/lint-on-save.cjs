// PostToolUse hook (BUILD): lint the file Claude just edited.
// Config: .claude/workflow/lint-on-save.json { enabled, pattern, command, timeoutSeconds }.
// "{file}" in command is replaced by the repo-relative path. Exit 2 sends the
// linter output back to Claude to fix. Missing or disabled config = no-op.
const { spawnSync } = require("node:child_process");
const fs = require("node:fs");
const path = require("node:path");

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  const projectDir = process.env.CLAUDE_PROJECT_DIR || input.cwd || process.cwd();
  let config;
  try {
    config = JSON.parse(fs.readFileSync(path.join(projectDir, ".claude/workflow/lint-on-save.json"), "utf8"));
  } catch {
    process.exit(0);
  }
  if (!config.enabled || !config.command || !config.pattern) process.exit(0);

  const filePath = input.tool_input && input.tool_input.file_path;
  if (!filePath) process.exit(0);

  const relative = path.relative(projectDir, path.resolve(projectDir, filePath)).split(path.sep).join("/");
  if (!new RegExp(config.pattern).test(relative)) process.exit(0);

  const command = config.command.split("{file}").join(JSON.stringify(relative));
  const result = spawnSync(command, {
    cwd: projectDir,
    encoding: "utf8",
    shell: true,
    timeout: (config.timeoutSeconds || 50) * 1000,
  });

  if (result.status === 0) process.exit(0);
  if (result.error) process.exit(0);

  process.stderr.write(`Lint found problems in ${relative}. Fix them before moving on:\n${result.stdout}${result.stderr}`);
  process.exit(2);
});
