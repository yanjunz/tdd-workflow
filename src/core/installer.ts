import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { AITool } from './tools.js';

export type DeliveryMode = 'skills' | 'commands' | 'both';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Resolve the path to the bundled skills/ directory (relative to dist/core/).
 * In the built output this is ../../skills/ from dist/core/installer.js.
 */
function getSkillsRoot(): string {
  // __dirname is dist/core/ at runtime
  return join(__dirname, '..', '..', 'skills');
}

export interface InstallResult {
  tool: AITool;
  filesWritten: string[];
  skipped: string[];
}

/**
 * Install TDD workflow files for a single AI tool into the given project.
 */
export function installForTool(
  projectDir: string,
  tool: AITool,
  delivery: DeliveryMode,
  force: boolean,
): InstallResult {
  const skillsRoot = getSkillsRoot();
  const result: InstallResult = { tool, filesWritten: [], skipped: [] };

  if (delivery === 'skills' || delivery === 'both') {
    // Copy SKILL.md
    copyFile(
      join(skillsRoot, 'SKILL.md'),
      join(projectDir, tool.skillsDir, 'SKILL.md'),
      force,
      result,
    );

    // Copy templates/
    const templatesDir = join(skillsRoot, 'templates');
    if (existsSync(templatesDir)) {
      for (const file of readdirSync(templatesDir)) {
        copyFile(
          join(templatesDir, file),
          join(projectDir, tool.skillsDir, 'templates', file),
          force,
          result,
        );
      }
    }
  }

  if (delivery === 'commands' || delivery === 'both') {
    // Copy commands/
    const commandsDir = join(skillsRoot, 'commands');
    if (existsSync(commandsDir)) {
      for (const file of readdirSync(commandsDir)) {
        copyFile(
          join(commandsDir, file),
          join(projectDir, tool.commandsDir, file),
          force,
          result,
        );
      }
    }
  }

  return result;
}

/**
 * Ensure the tdd-specs/ directory exists with a .gitkeep.
 */
export function ensureSpecsDir(projectDir: string): void {
  const specsDir = join(projectDir, 'tdd-specs');
  mkdirSync(specsDir, { recursive: true });
  const gitkeep = join(specsDir, '.gitkeep');
  if (!existsSync(gitkeep)) {
    writeFileSync(gitkeep, '');
  }
}

/**
 * Detect which tools already have TDD workflow installed.
 */
export function detectInstalled(projectDir: string, tools: AITool[]): AITool[] {
  return tools.filter((tool) =>
    existsSync(join(projectDir, tool.skillsDir, 'SKILL.md')) ||
    existsSync(join(projectDir, tool.commandsDir)),
  );
}

// ── helpers ──

function copyFile(
  src: string,
  dest: string,
  force: boolean,
  result: InstallResult,
): void {
  if (existsSync(dest) && !force) {
    result.skipped.push(dest);
    return;
  }
  mkdirSync(dirname(dest), { recursive: true });
  writeFileSync(dest, readFileSync(src));
  result.filesWritten.push(dest);
}
