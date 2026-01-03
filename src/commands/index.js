const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const CLAUDE_DIR = path.join(process.env.HOME, '.claude');
const PACKAGE_ROOT = path.resolve(__dirname, '../..');

const colors = {
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  red: '\x1b[31m',
  reset: '\x1b[0m'
};

function log(type, msg) {
  const prefix = {
    success: `${colors.green}[+]${colors.reset}`,
    step: `${colors.yellow}[*]${colors.reset}`,
    error: `${colors.red}[!]${colors.reset}`
  };
  console.log(`${prefix[type] || ''} ${msg}`);
}

function header(title) {
  console.log('');
  console.log(`${colors.blue}===========================================${colors.reset}`);
  console.log(`${colors.blue}  ${title}${colors.reset}`);
  console.log(`${colors.blue}===========================================${colors.reset}`);
  console.log('');
}

function copyDir(src, dest) {
  fs.mkdirSync(dest, { recursive: true });
  const entries = fs.readdirSync(src, { withFileTypes: true });
  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);
    if (entry.isDirectory()) {
      copyDir(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

function init() {
  header('Unsevered Memory - Global Setup');

  // Create directories
  log('step', 'Creating ~/.claude/ directory structure...');
  fs.mkdirSync(path.join(CLAUDE_DIR, 'hooks'), { recursive: true });
  fs.mkdirSync(path.join(CLAUDE_DIR, 'skills/orchestrate'), { recursive: true });
  fs.mkdirSync(path.join(CLAUDE_DIR, 'commands'), { recursive: true });
  log('success', 'Directory structure created');

  // Copy hooks
  log('step', 'Installing hooks...');
  const hooksDir = path.join(PACKAGE_ROOT, 'scripts');
  ['memory-load.sh', 'memory-remind.sh', 'memory-save.sh', 'memory-precompact.sh', 'memory-manifest.sh'].forEach(hook => {
    const src = path.join(hooksDir, hook);
    const dest = path.join(CLAUDE_DIR, 'hooks', hook);
    if (fs.existsSync(src)) {
      fs.copyFileSync(src, dest);
      fs.chmodSync(dest, '755');
    }
  });
  log('success', 'Hooks installed');

  // Copy skill
  log('step', 'Installing orchestrate skill...');
  const skillSrc = path.join(PACKAGE_ROOT, 'skills/orchestrate/SKILL.md');
  const skillDest = path.join(CLAUDE_DIR, 'skills/orchestrate/SKILL.md');
  if (fs.existsSync(skillSrc)) {
    fs.copyFileSync(skillSrc, skillDest);
  }
  log('success', 'Skill installed');

  // Copy command
  log('step', 'Installing /orchestrate command...');
  const cmdSrc = path.join(PACKAGE_ROOT, 'commands/orchestrate.md');
  const cmdDest = path.join(CLAUDE_DIR, 'commands/orchestrate.md');
  if (fs.existsSync(cmdSrc)) {
    fs.copyFileSync(cmdSrc, cmdDest);
  }
  log('success', 'Command installed');

  // Update settings.json
  log('step', 'Configuring hooks in settings.json...');
  const settingsPath = path.join(CLAUDE_DIR, 'settings.json');
  let settings = {};

  if (fs.existsSync(settingsPath)) {
    fs.copyFileSync(settingsPath, settingsPath + '.backup');
    log('step', 'Backed up existing settings.json');
    settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
  }

  settings.hooks = settings.hooks || {};
  settings.hooks.SessionStart = [{ matcher: '', hooks: [{ type: 'command', command: '~/.claude/hooks/memory-load.sh' }] }];
  settings.hooks.UserPromptSubmit = [{ matcher: '', hooks: [{ type: 'command', command: '~/.claude/hooks/memory-remind.sh' }] }];
  settings.hooks.PreCompact = [{ matcher: '', hooks: [{ type: 'command', command: '~/.claude/hooks/memory-precompact.sh' }] }];
  settings.hooks.SessionEnd = [{ matcher: '', hooks: [{ type: 'command', command: '~/.claude/hooks/memory-save.sh' }] }];

  fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
  log('success', 'Hooks configured in settings.json');

  // Copy CLAUDE.md template
  log('step', 'Installing global CLAUDE.md...');
  const claudeMdSrc = path.join(PACKAGE_ROOT, 'templates/CLAUDE.md.template');
  const claudeMdDest = path.join(CLAUDE_DIR, 'CLAUDE.md');
  if (fs.existsSync(claudeMdSrc)) {
    if (fs.existsSync(claudeMdDest)) {
      fs.copyFileSync(claudeMdDest, claudeMdDest + '.backup');
    }
    fs.copyFileSync(claudeMdSrc, claudeMdDest);
  }
  log('success', 'Global CLAUDE.md installed');

  header('Global Setup Complete');
  console.log('Installed to ~/.claude/:');
  console.log('  - CLAUDE.md');
  console.log('  - settings.json');
  console.log('  - hooks/');
  console.log('  - skills/orchestrate/');
  console.log('  - commands/');
  console.log('');
  console.log('Next: Run `unsevered-memory project` in your project directory');
  console.log('');
}

function project(options) {
  const projectDir = path.resolve(options.path || '.');

  header('Unsevered Memory - Project Setup');
  console.log(`Project: ${projectDir}`);
  console.log('');

  // Create .claude/memory/
  log('step', 'Creating .claude/memory/ structure...');
  const memoryDir = path.join(projectDir, '.claude/memory/sessions');
  fs.mkdirSync(memoryDir, { recursive: true });
  fs.mkdirSync(path.join(projectDir, '.claude/memory/checkpoints'), { recursive: true });

  const currentDate = new Date().toISOString().slice(0, 16).replace('T', ' ');

  // context.md
  const contextPath = path.join(projectDir, '.claude/memory/context.md');
  if (!fs.existsSync(contextPath)) {
    fs.writeFileSync(contextPath, `# Project Context

## Current State

[Project initialized with Unsevered Memory]

## Current Task

[No active task]

## Last Session

- Date: N/A
- Accomplished: Initial setup
- Stopped at: N/A

## Next Steps

1. Define project goals
2. Set up development environment
3. Begin implementation

## Notes

[Add project-specific notes here]
`);
    log('success', 'Created context.md');
  }

  // scratchpad.md
  const scratchpadPath = path.join(projectDir, '.claude/memory/scratchpad.md');
  if (!fs.existsSync(scratchpadPath)) {
    fs.writeFileSync(scratchpadPath, `# Scratchpad

Session: ${currentDate}

## Operations

- Project initialized with Unsevered Memory

## Findings

- N/A

## Decisions

- N/A

## Blockers

- None

## Next Steps

- Begin work
`);
    log('success', 'Created scratchpad.md');
  }

  // decisions.md
  const decisionsPath = path.join(projectDir, '.claude/memory/decisions.md');
  if (!fs.existsSync(decisionsPath)) {
    fs.writeFileSync(decisionsPath, `# Decision Log

Architectural and significant decisions for this project.

---

## Template

\`\`\`markdown
## YYYY-MM-DD: [Decision Title]

**Context**: Why was this decision needed?

**Options Considered**:
1. Option A - pros/cons
2. Option B - pros/cons

**Decision**: What was chosen

**Rationale**: Why this option was selected

**Consequences**: What this means going forward
\`\`\`

---

## Decisions

[Decisions will be appended below]
`);
    log('success', 'Created decisions.md');
  }

  // Create .ai/
  log('step', 'Creating .ai/ documentation structure...');
  const aiDirs = ['core', 'patterns', 'workflows'];
  aiDirs.forEach(dir => fs.mkdirSync(path.join(projectDir, '.ai', dir), { recursive: true }));

  // Copy .ai/ templates
  const aiTemplateSrc = path.join(PACKAGE_ROOT, 'templates/.ai');
  if (fs.existsSync(aiTemplateSrc)) {
    copyDir(aiTemplateSrc, path.join(projectDir, '.ai'));
    log('success', 'Created .ai/ structure');
  }

  // Project CLAUDE.md
  const projectClaudeMd = path.join(projectDir, 'CLAUDE.md');
  if (!fs.existsSync(projectClaudeMd)) {
    const templatePath = path.join(PACKAGE_ROOT, 'templates/PROJECT-CLAUDE.md.template');
    if (fs.existsSync(templatePath)) {
      fs.copyFileSync(templatePath, projectClaudeMd);
      log('success', 'Created project CLAUDE.md');
    }
  }

  // Update .gitignore
  log('step', 'Updating .gitignore...');
  const gitignorePath = path.join(projectDir, '.gitignore');
  let gitignore = fs.existsSync(gitignorePath) ? fs.readFileSync(gitignorePath, 'utf8') : '';
  if (!gitignore.includes('# Unsevered Memory')) {
    gitignore += '\n# Unsevered Memory\n.claude/memory/scratchpad.md\n';
    fs.writeFileSync(gitignorePath, gitignore);
    log('success', 'Updated .gitignore');
  }

  header('Project Setup Complete');
  console.log('Structure created:');
  console.log('  .claude/memory/');
  console.log('    - context.md');
  console.log('    - scratchpad.md');
  console.log('    - decisions.md');
  console.log('    - sessions/');
  console.log('    - checkpoints/');
  console.log('');
  console.log('  .ai/');
  console.log('    - core/');
  console.log('    - patterns/');
  console.log('    - workflows/');
  console.log('');
  console.log('Features enabled:');
  console.log('  - PreCompact hook (checkpoint before compaction)');
  console.log('  - Semantic tagging (#tags in scratchpad)');
  console.log('  - MANIFEST.md (just-in-time retrieval)');
  console.log('');
}

function uninstall() {
  header('Unsevered Memory - Uninstall');

  const filesToRemove = [
    path.join(CLAUDE_DIR, 'hooks/memory-load.sh'),
    path.join(CLAUDE_DIR, 'hooks/memory-remind.sh'),
    path.join(CLAUDE_DIR, 'hooks/memory-save.sh'),
    path.join(CLAUDE_DIR, 'hooks/memory-precompact.sh'),
    path.join(CLAUDE_DIR, 'hooks/memory-manifest.sh'),
    path.join(CLAUDE_DIR, 'skills/orchestrate/SKILL.md'),
    path.join(CLAUDE_DIR, 'commands/orchestrate.md')
  ];

  filesToRemove.forEach(file => {
    if (fs.existsSync(file)) {
      fs.unlinkSync(file);
      log('success', `Removed ${path.basename(file)}`);
    }
  });

  // Remove hooks from settings.json
  const settingsPath = path.join(CLAUDE_DIR, 'settings.json');
  if (fs.existsSync(settingsPath)) {
    const settings = JSON.parse(fs.readFileSync(settingsPath, 'utf8'));
    if (settings.hooks) {
      delete settings.hooks.SessionStart;
      delete settings.hooks.UserPromptSubmit;
      delete settings.hooks.PreCompact;
      delete settings.hooks.SessionEnd;
      fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2));
      log('success', 'Removed hooks from settings.json');
    }
  }

  header('Uninstall Complete');
  console.log('Global installation removed.');
  console.log('Project files (.claude/memory/, .ai/) are preserved.');
  console.log('');
}

module.exports = { init, project, uninstall };
