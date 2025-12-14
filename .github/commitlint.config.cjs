module.exports = {
  extends: ["@commitlint/config-conventional"],
  ignores: [
    (msg) => /Signed-off-by: dependabot\[bot\]/m.test(msg),
    (msg) => msg.startsWith("Merge "),
    (msg) => msg.startsWith("Revert "),
  ],
  rules: {
    "body-max-line-length": [2, "always", 300],
    "type-empty": [0, "never"],
    "subject-empty": [0, "never"],
    "header-max-length": [0, "always", 0],
    "scope-empty": [0, "never"],
  },
};
