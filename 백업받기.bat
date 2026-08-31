@echo off
title 팀별 회식비 데이터 백업
powershell -ExecutionPolicy Bypass -File "%~dp0backup.ps1"
