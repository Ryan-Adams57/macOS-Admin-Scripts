#!/bin/bash

# Author: Ryan Adams
# Purpose: Install the NinjaRMM (NinjaOne) agent on macOS
#
# Update the variables below to match your NinjaOne environment.
# Example download URL:
# https://ca.ninjarmm.com/agent/installer/<AGENT_ID>/<VERSION>/<PKG_NAME>

# =========================
# Configuration Variables
# =========================

# NinjaOne region (e.g., us, ca)
BASE_URL="https://ca.ninjarmm.com/agent/installer"

AGENT_ID="a0a00000-0a00-0a00-a0a0-000aa0aa00aa"
AGENT_VERSION="10.0.4634"

PKG_NAME="NinjaOne-Agent_${AGENT_ID}-MyOrg-360OfficeHighLevel-Auto.pkg"
PKG_PATH="/tmp/${PKG_NAME}"

# =========================
# Build Download URL
# =========================

NURL="${BASE_URL}/${AGENT_ID}/${AGENT_VERSION}/${PKG_NAME}"

# =========================
# Download and Install
# =========================

/usr/bin/curl -L "${NURL}" -o "${PKG_PATH}"

/usr/sbin/installer -pkg "${PKG_PATH}" -target /

exit 0
