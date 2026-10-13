@echo off
rem Builds re1convert.exe with the C# compiler that ships with Windows
rem (.NET Framework 4, no install needed). On a Mac, setup.command builds the
rem same source with the .NET 8 SDK (re1convert.csproj).
cd /d "%~dp0"
"%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /optimize /out:re1convert.exe *.cs