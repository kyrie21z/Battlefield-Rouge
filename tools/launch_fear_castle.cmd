@echo off
setlocal EnableExtensions DisableDelayedExpansion
call "%~dp0launch_game.cmd" "res://tools/playtest/fear_castle.tscn" -- --meta-test-profile=user://meta_test_fear_castle.json
exit /b %errorlevel%
