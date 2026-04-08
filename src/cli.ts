import { Command } from 'commander';
import { getPackageInfo } from './core/config.js';
import { runInit } from './commands/init.js';
import { runUpdate } from './commands/update.js';
import type { DeliveryMode } from './core/installer.js';

const pkg = getPackageInfo();

const program = new Command();

program
  .name('tdd-workflow')
  .description('Install TDD Workflow skills for AI coding tools')
  .version(pkg.version);

program
  .command('init')
  .description('Initialize TDD workflow in the current project')
  .option('--tools <tools>', 'Comma-separated list of tools (claude,cursor,cline,windsurf,codebuddy,copilot)')
  .option('--delivery <mode>', 'Installation mode: skills, commands, or both', 'both')
  .option('--force', 'Overwrite existing files', false)
  .action(async (opts: { tools?: string; delivery: string; force: boolean }) => {
    await runInit({
      tools: opts.tools,
      delivery: opts.delivery as DeliveryMode,
      force: opts.force,
    });
  });

program
  .command('update')
  .description('Update TDD workflow files for already-installed tools')
  .option('--delivery <mode>', 'Installation mode: skills, commands, or both', 'both')
  .action(async (opts: { delivery: string }) => {
    await runUpdate({
      delivery: opts.delivery as DeliveryMode,
    });
  });

program.parse();
