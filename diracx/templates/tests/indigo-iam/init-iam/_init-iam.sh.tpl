#!/usr/bin/env bash
set -x

curl {{ .Values.indigoiam.config.issuer }}/.well-known/openid-configuration
