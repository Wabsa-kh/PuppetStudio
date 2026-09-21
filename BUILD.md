# Build this alpha

Use Godot 4.7.2 standard and matching Windows x64 release export template. Open `project.godot` to run the source project. The application is exported as an independent executable; end users do not install the editor.

On Windows, run `build.ps1 -Godot <console-editor-exe> -WindowsTemplate <windows_release_x86_64.exe>`. It compiles the tiny Windows .NET Framework helper, imports resources, runs core tests, and exports to `../portable/`. The .NET Framework compiler shipped with Windows is used only for the helper.

For rendered integration tests, run the Godot console executable with `--path <this-folder> --script res://tests/test_workspace.gd`. The test opens the actual application and an output window, exercises commands, tests helper communication, and reports whether a microphone is available. Do not interpret skipped real-device verification as a pass.

The application currently uses Godot's Compatibility renderer. On the tested Intel HD Graphics 530 system, Godot selected ANGLE/D3D11 automatically. Other graphics hardware remains unverified.

The Windows executable is unsigned, and resource metadata customization is not yet part of this development export. Before wider distribution, finish package signing, resource branding, installer behavior, performance/soak tests, and the complete platform matrix.
