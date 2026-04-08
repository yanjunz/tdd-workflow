import chalk from 'chalk';
import ora from 'ora';
import { SUPPORTED_TOOLS, detectTools } from '../core/tools.js';
import { installForTool, detectInstalled, type DeliveryMode } from '../core/installer.js';
import { getPackageInfo } from '../core/config.js';

export interface UpdateOptions {
  delivery: DeliveryMode;
}

export async function runUpdate(options: UpdateOptions): Promise<void> {
  const pkg = getPackageInfo();
  const projectDir = process.cwd();

  console.log(chalk.bold(`\n🧪 TDD Workflow v${pkg.version} — Update\n`));

  // Find tools that already have TDD installed
  const installed = detectInstalled(projectDir, SUPPORTED_TOOLS);

  if (installed.length === 0) {
    console.log(
      chalk.yellow(
        'No existing TDD workflow installation found. Run `tdd-workflow init` first.',
      ),
    );
    process.exit(0);
  }

  console.log(
    chalk.dim('Found TDD workflow installed for: ') +
      installed.map((t) => chalk.cyan(t.name)).join(', '),
  );

  const spinner = ora('Updating TDD workflow files…').start();

  let totalUpdated = 0;
  for (const tool of installed) {
    const result = installForTool(projectDir, tool, options.delivery, true /* force */);
    totalUpdated += result.filesWritten.length;
  }

  spinner.succeed('Update complete!');
  console.log(chalk.bold.green(`\n  ✓ ${totalUpdated} files updated\n`));
}
