#!/usr/bin/env bash
set -euo pipefail

# Build the custom n8n Docker image from WSL.
#
# Prerequisites:
#   1) Docker Desktop running on Windows
#   2) Docker Desktop -> Settings -> Resources -> WSL Integration -> Ubuntu ON
#
# Recommended: keep the repo on the WSL filesystem (~/projects/n8n), not /mnt/e/.

IMAGE_TAG="${1:-marefati110/n8n-ent:2.27.3-ce.2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
	DOCKER=(docker)
elif [[ -S /var/run/docker.sock ]] && command -v docker >/dev/null 2>&1; then
	DOCKER=(docker)
elif [[ -x "/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe" ]]; then
	DOCKER=("/mnt/c/Program Files/Docker/Docker/resources/bin/docker.exe")
else
	echo "ERROR: docker not found."
	exit 1
fi

if ! "${DOCKER[@]}" info >/dev/null 2>&1; then
	echo "ERROR: Docker daemon is not reachable from WSL."
	echo
	echo "Fix:"
	echo "  Docker Desktop -> Settings -> Resources -> WSL Integration -> enable Ubuntu"
	echo "  Then restart WSL: wsl --shutdown"
	echo
	echo "Alternative from PowerShell:"
	echo "  .\\scripts\\docker-build.ps1"
	exit 1
fi

# /mnt/e often has permission issues with drvfs; copy to WSL home first if needed.
BUILD_DIR="${PROJECT_DIR}"
if [[ "${PROJECT_DIR}" == /mnt/* ]]; then
	BUILD_DIR="${HOME}/n8n-docker-build"
	echo "INFO: Copying project from ${PROJECT_DIR} to ${BUILD_DIR} ..."
	rm -rf "${BUILD_DIR}"
	mkdir -p "${BUILD_DIR}"
	if ! rsync -a \
		--exclude=node_modules \
		--exclude=.git \
		--exclude=.turbo \
		--exclude=compiled \
		--exclude=dist \
		--exclude=.agent-setup \
		"${PROJECT_DIR}/" "${BUILD_DIR}/"; then
		echo "ERROR: Could not read project from ${PROJECT_DIR}."
		echo "Clone or copy the repo into WSL home instead, e.g. ~/projects/n8n"
		exit 1
	fi
fi

echo "Building ${IMAGE_TAG} from ${BUILD_DIR}"
cd "${BUILD_DIR}"
"${DOCKER[@]}" build -t "${IMAGE_TAG}" .

echo
echo "Build finished. Quick check:"
"${DOCKER[@]}" run --rm "${IMAGE_TAG}" n8n --version
