#!/usr/bin/env node
/**
 * Production deploy step for custom Docker builds.
 * Assumes `pnpm install` and `pnpm build` already ran in the builder stage.
 * Mirrors the deploy phase of scripts/build-n8n.mjs without re-installing/re-building.
 */

import { execSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const rootDir = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
const compiledAppDir = path.join(rootDir, 'compiled');
const PATCHES_TO_KEEP = ['pdfjs-dist', 'pkce-challenge', 'bull'];

function run(command) {
	execSync(command, { cwd: rootDir, stdio: 'inherit', env: process.env });
}

console.log('INFO: Trimming frontend package.json files...');
run('node .github/scripts/trim-fe-packageJson.js');

console.log('INFO: Keeping backend-only pnpm patches...');
const packageJsonPath = path.join(rootDir, 'package.json');
const packageJson = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
if (packageJson.pnpm?.patchedDependencies) {
	const filteredPatches = {};
	for (const [key, value] of Object.entries(packageJson.pnpm.patchedDependencies)) {
		if (PATCHES_TO_KEEP.some((patchPrefix) => key.startsWith(patchPrefix))) {
			filteredPatches[key] = value;
		}
	}
	packageJson.pnpm.patchedDependencies = filteredPatches;
	fs.writeFileSync(packageJsonPath, `${JSON.stringify(packageJson, null, 2)}\n`);
}

if (process.env.CI === 'true') {
	const cliPackagePath = path.join(rootDir, 'packages/cli/package.json');
	const cliPackageJson = JSON.parse(fs.readFileSync(cliPackagePath, 'utf8'));
	if (!cliPackageJson.files.includes('!dist/**/e2e.*')) {
		cliPackageJson.files.push('!dist/**/e2e.*');
		fs.writeFileSync(cliPackagePath, `${JSON.stringify(cliPackageJson, null, 2)}\n`);
	}
}

fs.rmSync(compiledAppDir, { recursive: true, force: true });
fs.mkdirSync(compiledAppDir, { recursive: true });

console.log(`INFO: Deploying production bundle to ${compiledAppDir}...`);
run(
	'NODE_ENV=production DOCKER_BUILD=true pnpm --filter=n8n --prod --legacy deploy --no-optional ./compiled',
);

console.log('INFO: Production deploy completed.');
