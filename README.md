# About

haven is a powerful tool for superintend [Flutter](https://flutter.dev/) versions, it is essential for any developers that work on multiple projects or have slower internet.

With `haven` you can:

- Use different versions of Flutter at the same time
- Download new versions twice as fast with significantly less disk space and internet bandwidth
- Use versions globally or per-project
- Automatically configure IDE settings with a single command

## Installation

Haven is distributed as a precompiled executable (you do not need Dart installed), see the quick installation.

## Quick start

After installing haven you can run `haven flutter doctor` to install the latest stable version of Flutter, if you want to
switch to beta you can run `haven use -g beta` and then `haven flutter doctor` again.

And that's it, you're ready to go!

Haven uses the concept of "environments" to manage Flutter versions, these can either be tied to a specific version /
release channel, or a named environment that can be upgraded independently.

Environments can be set globally or per-project, the global environment is set to `stable` by default.

Cheat sheet:

```
# Create a new environment "foo" with the latest stable release
haven create foo stable

# Create a new environment "bar" with with Flutter 3.13.6
haven create bar 3.13.6

# Switch "bar" to a specific Flutter version
haven upgrade bar 3.10.6

# List available environments
haven ls

# List available Flutter releases
haven releases

# Switch the current project to use "foo"
haven use foo

# Switch the global default to "bar"
haven use -g bar

# Remove haven configuration from the current project
haven clean

# Delete the "foo" environment
haven rm foo

# Run flutter commands in a specific environment
haven -e foo flutter ...
haven -e foo dart ...
haven -e foo pub ...
```
