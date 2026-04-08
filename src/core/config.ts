import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

export interface PackageInfo {
  name: string;
  version: string;
}

/**
 * Read package.json to get name and version.
 */
export function getPackageInfo(): PackageInfo {
  const pkgPath = join(__dirname, '..', '..', 'package.json');
  const pkg = JSON.parse(readFileSync(pkgPath, 'utf-8'));
  return { name: pkg.name, version: pkg.version };
}
