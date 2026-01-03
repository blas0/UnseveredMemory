#!/usr/bin/env node

const { program } = require('commander');
const { init, project, uninstall } = require('../src/commands');

program
  .name('unsevered-memory')
  .description('Persistent memory system for Claude Code')
  .version('2.0.0');

program
  .command('init')
  .description('Install globally to ~/.claude/')
  .action(init);

program
  .command('project')
  .description('Set up memory in current project')
  .option('-p, --path <path>', 'Project path', '.')
  .action(project);

program
  .command('uninstall')
  .description('Remove global installation')
  .action(uninstall);

program.parse();
