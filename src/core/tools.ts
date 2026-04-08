import { existsSync } from 'node:fs';
import { join } from 'node:path';

export interface AITool {
  id: string;
  name: string;
  /** Directory marker to detect if the tool is in use (relative to project root) */
  markerDir: string;
  /** Where to install SKILL.md + templates (relative to project root) */
  skillsDir: string;
  /** Where to install slash commands (relative to project root) */
  commandsDir: string;
}

export const SUPPORTED_TOOLS: AITool[] = [
  {
    id: 'claude',
    name: 'Claude Code',
    markerDir: '.claude',
    skillsDir: '.claude/skills/tdd-workflow',
    commandsDir: '.claude/commands/tdd',
  },
  {
    id: 'cursor',
    name: 'Cursor',
    markerDir: '.cursor',
    skillsDir: '.cursor/skills/tdd-workflow',
    commandsDir: '.cursor/commands/tdd',
  },
  {
    id: 'cline',
    name: 'Cline',
    markerDir: '.cline',
    skillsDir: '.cline/skills/tdd-workflow',
    commandsDir: '.cline/commands/tdd',
  },
  {
    id: 'windsurf',
    name: 'Windsurf',
    markerDir: '.windsurf',
    skillsDir: '.windsurf/skills/tdd-workflow',
    commandsDir: '.windsurf/commands/tdd',
  },
  {
    id: 'codebuddy',
    name: 'CodeBuddy',
    markerDir: '.codebuddy',
    skillsDir: '.codebuddy/skills/tdd-workflow',
    commandsDir: '.codebuddy/commands/tdd',
  },
  {
    id: 'copilot',
    name: 'GitHub Copilot',
    markerDir: '.github',
    skillsDir: '.github/skills/tdd-workflow',
    commandsDir: '.github/commands/tdd',
  },
];

/**
 * Detect which AI tools are present in the given project directory.
 */
export function detectTools(projectDir: string): AITool[] {
  return SUPPORTED_TOOLS.filter((tool) =>
    existsSync(join(projectDir, tool.markerDir)),
  );
}

/**
 * Resolve tool objects from a comma-separated list of IDs.
 */
export function resolveToolIds(ids: string[]): AITool[] {
  const resolved: AITool[] = [];
  for (const id of ids) {
    const tool = SUPPORTED_TOOLS.find((t) => t.id === id);
    if (!tool) {
      throw new Error(
        `Unknown tool "${id}". Supported: ${SUPPORTED_TOOLS.map((t) => t.id).join(', ')}`,
      );
    }
    resolved.push(tool);
  }
  return resolved;
}
