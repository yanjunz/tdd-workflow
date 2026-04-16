import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, chmodSync } from 'node:fs';
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
  hooksInstalled: boolean;
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
  const result: InstallResult = { tool, filesWritten: [], skipped: [], hooksInstalled: false };

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

  // Install hooks if tool supports them
  if (tool.hooksDir && tool.settingsFile) {
    installHooks(projectDir, tool, force, result);
  }

  return result;
}

/**
 * Install hook scripts and merge hooks config into settings.json.
 */
function installHooks(
  projectDir: string,
  tool: AITool,
  force: boolean,
  result: InstallResult,
): void {
  const skillsRoot = getSkillsRoot();
  const hooksSourceDir = join(skillsRoot, 'hooks');
  if (!existsSync(hooksSourceDir)) return;

  // Copy hook scripts
  const hooksDestDir = join(projectDir, tool.hooksDir!);
  for (const file of readdirSync(hooksSourceDir)) {
    if (!file.endsWith('.sh')) continue;
    const dest = join(hooksDestDir, file);
    copyFile(join(hooksSourceDir, file), dest, force, result);
    // Ensure executable
    if (existsSync(dest)) {
      chmodSync(dest, 0o755);
    }
  }

  // Merge hooks into settings.json
  const settingsPath = join(projectDir, tool.settingsFile!);
  mergeHooksIntoSettings(settingsPath, tool.hooksDir!);
  result.hooksInstalled = true;
}

/**
 * Merge TDD hook entries into settings.json without overwriting user's existing hooks.
 */
function mergeHooksIntoSettings(settingsPath: string, hooksDir: string): void {
  let settings: Record<string, any> = {};
  if (existsSync(settingsPath)) {
    try {
      settings = JSON.parse(readFileSync(settingsPath, 'utf-8'));
    } catch {
      // If settings.json is malformed, start fresh
      settings = {};
    }
  }
  if (!settings.hooks) settings.hooks = {};

  const tddHooks: Record<string, any[]> = {
    PreToolUse: [
      { matcher: 'Write|Edit', hooks: [{ type: 'command', command: `${hooksDir}/pre-write-edit.sh` }] },
      { matcher: 'Bash', hooks: [{ type: 'command', command: `${hooksDir}/pre-bash.sh` }] },
    ],
    PostToolUse: [
      { matcher: 'Write|Edit', hooks: [{ type: 'command', command: `${hooksDir}/post-write-edit.sh` }] },
      { matcher: 'Bash', hooks: [{ type: 'command', command: `${hooksDir}/post-bash.sh` }] },
    ],
    UserPromptSubmit: [
      { hooks: [{ type: 'command', command: `${hooksDir}/user-prompt-submit.sh` }] },
    ],
  };

  for (const [event, hooks] of Object.entries(tddHooks)) {
    if (!Array.isArray(settings.hooks[event])) {
      settings.hooks[event] = [];
    }
    // Remove old TDD hooks (match by path containing hooks/tdd/)
    settings.hooks[event] = settings.hooks[event].filter(
      (h: any) => !h.hooks?.some((hh: any) => hh.command?.includes('hooks/tdd/')),
    );
    // Append new TDD hooks
    settings.hooks[event].push(...hooks);
  }

  mkdirSync(dirname(settingsPath), { recursive: true });
  writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + '\n');
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
