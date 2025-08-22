---
description: Load project-specific context from aidoc/projects/ directory
argument-hint: [project-name]
---

You are being asked to load project-specific instructions and context for working on a particular project area.

The user has provided a project name: $ARGUMENTS

Your task is to:
1. If no project name is provided or input is empty, ask the user to specify the project name
2. Use the `aidoc-locate` command to find the project directory: `aidoc-locate project $ARGUMENTS`
3. If the command returns no output or an error, report that the requested project was not found and use `aidoc-locate project` (without arguments) to list available projects
4. Read the `README.md` file in the project directory returned by aidoc-locate
5. If the README.md references other files you should read (dependencies, related docs, etc.), read those files as well
6. Once you've read all the necessary files, respond with a brief confirmation that you've loaded the project context and are ready to work on the given project

Keep your response concise - just confirm you've loaded the project instructions and are ready for the user to describe their specific task within this project domain.

Note: Projects provide focused context for specific codebase areas, file mappings showing which source files belong to the domain, domain-specific testing and troubleshooting guidance, and related Jira tickets and business context.