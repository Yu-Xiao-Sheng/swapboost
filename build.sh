#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-0.1.0}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${ROOT_DIR}/.build"
STAGE_DIR="${BUILD_DIR}/swapboost"
DIST_DIR="${ROOT_DIR}/dist"

rm -rf "$BUILD_DIR"
mkdir -p "${STAGE_DIR}/DEBIAN" "${STAGE_DIR}/usr/bin" "$DIST_DIR"

cp "${ROOT_DIR}/swapboost.sh" "${STAGE_DIR}/usr/bin/swapboost"
chmod 755 "${STAGE_DIR}/usr/bin/swapboost"

sed "s/@VERSION@/${VERSION}/g" "${ROOT_DIR}/debian/control" > "${STAGE_DIR}/DEBIAN/control"
cp "${ROOT_DIR}/debian/postinst" "${STAGE_DIR}/DEBIAN/postinst"
chmod 755 "${STAGE_DIR}/DEBIAN/postinst"

PACKAGE_NAME="swapboost_${VERSION}_all.deb"
dpkg-deb --build "$STAGE_DIR" "${DIST_DIR}/${PACKAGE_NAME}"

echo "Built package at ${DIST_DIR}/${PACKAGE_NAME}"
echo "Install with: sudo apt install ./dist/${PACKAGE_NAME}"
