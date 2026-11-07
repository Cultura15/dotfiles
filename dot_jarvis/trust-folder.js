const fs = require("fs");
const path = require("path");
const os = require("os");

const folder = process.argv[2];
if (!folder) {
  console.error("Usage: node trust-folder.js <folder>");
  process.exit(1);
}

const file = path.join(os.homedir(), ".claude.json");
const key = folder.replace(/\\/g, "/");

let config = {};
if (fs.existsSync(file)) {
  try {
    config = JSON.parse(fs.readFileSync(file, "utf8"));
  } catch (e) {
    process.exit(1);
  }
}

config.projects = config.projects || {};
const project = (config.projects[key] = config.projects[key] || {});
if (project.hasTrustDialogAccepted === true) process.exit(0);
project.hasTrustDialogAccepted = true;

const tmp = file + ".jarvis.tmp";
fs.writeFileSync(tmp, JSON.stringify(config, null, 2));
fs.renameSync(tmp, file);
