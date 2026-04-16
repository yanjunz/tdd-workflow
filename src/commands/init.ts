import chalk from 'chalk';
import ora from 'ora';
import { detectTools, resolveToolIds } from '../core/tools.js';
import type { AITool } from '../core/tools.js';
import { installForTool, ensureSpecsDir, type DeliveryMode, type InstallResult } from '../core/installer.js';
import { getPackageInfo } from '../core/config.js';
import { promptToolSelection } from '../ui/prompts.js';

export interface InitOptions {
  tools?: string;
  delivery: DeliveryMode;
  force: boolean;
}

export async function runInit(options: InitOptions): Promise<void> {
  const pkg = getPackageInfo();
  const projectDir = process.cwd();

  console.log(chalk.bold(`\n🧪 TDD Workflow v${pkg.version}\n`));

  // ── 1. Environment check ──
  const nodeVersion = parseInt(process.version.slice(1), 10);
  if (nodeVersion < 18) {
    console.error(chalk.red('✗ Node.js >= 18 is required.'));
    process.exit(1);
  }

  // ── 2. Detect tools ──
  const detected = detectTools(projectDir);
  if (detected.length > 0) {
    console.log(
      chalk.dim('Detected AI tools: ') +
        detected.map((t) => chalk.cyan(t.name)).join(', '),
    );
  } else {
    console.log(chalk.dim('No AI tool directories detected.'));
  }

  // ── 3. Select tools ──
  let selectedTools: AITool[];

  if (options.tools) {
    const ids = options.tools.split(',').map((s) => s.trim());
    try {
      selectedTools = resolveToolIds(ids);
    } catch (err) {
      console.error(chalk.red((err as Error).message));
      process.exit(1);
    }
    console.log(
      chalk.dim('Tools (from --tools): ') +
        selectedTools.map((t) => chalk.cyan(t.name)).join(', '),
    );
  } else {
    selectedTools = await promptToolSelection(detected);
  }

  // ── 4. Delivery mode ──
  console.log(chalk.dim(`Delivery mode: ${chalk.cyan(options.delivery)}`));

  // ── 5. Install files ──
  const spinner = ora('Installing TDD workflow files…').start();
  const results: InstallResult[] = [];

  for (const tool of selectedTools) {
    const result = installForTool(projectDir, tool, options.delivery, options.force);
    results.push(result);
  }

  // ── 6. Create tdd-specs/ ──
  ensureSpecsDir(projectDir);

  spinner.succeed('Installation complete!');

  // ── 7. Report ──
  console.log('');
  for (const r of results) {
    console.log(chalk.bold(`  ${r.tool.name}:`));
    if (r.filesWritten.length > 0) {
      console.log(chalk.green(`    ✓ ${r.filesWritten.length} files written`));
    }
    if (r.hooksInstalled) {
      console.log(chalk.green(`    ✓ hooks installed + settings.json updated`));
    }
    if (r.skipped.length > 0) {
      console.log(
        chalk.yellow(`    ⚠ ${r.skipped.length} files skipped (use --force to overwrite)`),
      );
    }
  }

  const totalWritten = results.reduce((s, r) => s + r.filesWritten.length, 0);
  const totalSkipped = results.reduce((s, r) => s + r.skipped.length, 0);

  console.log('');
  console.log(
    chalk.bold.green(`  ✓ ${totalWritten} files installed`) +
      (totalSkipped > 0 ? chalk.yellow(`, ${totalSkipped} skipped`) : ''),
  );
  console.log(chalk.dim('  ✓ tdd-specs/ directory ready'));
  console.log('');
  console.log(chalk.dim('  Next steps:'));
  console.log(chalk.dim('    1. Open your AI coding tool'));
  console.log(chalk.dim('    2. Use /tdd:new to start a TDD workflow'));
  console.log('');
}
