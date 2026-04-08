import { checkbox } from '@inquirer/prompts';
import type { AITool } from '../core/tools.js';
import { SUPPORTED_TOOLS } from '../core/tools.js';

/**
 * Prompt the user to select AI tools to install for.
 */
export async function promptToolSelection(detected: AITool[]): Promise<AITool[]> {
  const detectedIds = new Set(detected.map((t) => t.id));

  const selected = await checkbox<string>({
    message: 'Select AI tools to install TDD workflow for:',
    choices: SUPPORTED_TOOLS.map((tool) => ({
      name: `${tool.name}${detectedIds.has(tool.id) ? ' (detected)' : ''}`,
      value: tool.id,
      checked: detectedIds.has(tool.id),
    })),
  });

  if (selected.length === 0) {
    throw new Error('No tools selected. Aborting.');
  }

  return SUPPORTED_TOOLS.filter((t) => selected.includes(t.id));
}
