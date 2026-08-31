@echo off
title 팀별 회식비 조회 로컬 서버 실행기
echo 로컬 서버를 구동 중입니다...
powershell -ExecutionPolicy Bypass -File "%~dp0serve.ps1"
pause
