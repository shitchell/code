# Claude Context Guide - Shell Library Cleanup Project

## Quick Start
If you're picking up this project, start here. This guide provides pointers to all relevant documentation for the shell library cleanup effort.

## Project Overview
Cleaning up and standardizing 200+ shell scripts in `/sh/bin/` and improving the shell libraries in `/sh/lib/`.

## Key Documentation Files

### Library Documentation
- **`/sh/lib/README.md`** - Overview of all libraries and their functions
- **`/sh/lib/CLEANUP.md`** - Issues to fix and improvements needed
- **`/sh/lib/PERFORMANCE.md`** - Specific performance problems with code examples
- **`/sh/lib/CLEANUP_IMPLEMENTATION.md`** - Step-by-step implementation plan
- **`/sh/lib/CLEANUP_IMPLEMENTATION_PROGRESS.md`** - Track what's been done

### Script Documentation
- **`/sh/bin/README.md`** - List of all utilities and their categories
- **`/sh/bin/CLEANUP-context.md`** - Specific details for cleaning up bin scripts
- **`/sh/CLEANUP.md`** - Overall cleanup plan with patterns to extract

## Key Technical Details

### Docstring Pattern
Functions use `: 'docstring'` pattern that preserves docs in function body:
```bash
function example() {
    : 'Brief description

        @arg $1 First argument
        @stdout Output description
    '
    # implementation
}
```

This is visible via `type function-name` and should be parsed by `docs.sh`.

### Library Import Pattern
```bash
source "$(dirname "$0")/../lib/include.sh"
include-source 'debug.sh'
include-source 'colors.sh'
```

## Current State

### What Works Well
- Basic library structure exists
- Some libraries are well-designed (shell.sh, git.sh)
- Docstring pattern is elegant and runtime-queryable

### Major Issues
1. 80% of scripts don't use libraries (duplicate code)
2. Only 2.5% of scripts have tests
3. `docs.sh` is incomplete
4. Missing key libraries (help.sh, args.sh, validate.sh)
5. Performance issues in several libraries

## Implementation Approach

The plan is divided into 4 phases:
1. **Test Infrastructure** - Create test helpers and comprehensive tests
2. **Library Improvements** - Complete docs.sh, create missing libraries
3. **Integration** - Connect related libraries, standardize
4. **Documentation** - Complete all documentation and migration guides

Each phase is broken into sections that can be completed in one LLM session.

## Quick Commands

Find scripts needing color library:
```bash
grep -l "C_RED=\|31m" /sh/bin/*.sh
```

Find scripts with custom debug:
```bash
grep -l "function debug\|__debug" /sh/bin/*.sh
```

Find scripts using libraries:
```bash
grep -l "include-source" /sh/bin/*.sh
```

## Priority Order

1. Fix library issues first (better foundation)
2. Then migrate high-value scripts
3. Finally standardize remaining scripts

## Context Recovery

If you've lost context:
1. Check `CLEANUP_IMPLEMENTATION_PROGRESS.md` for current status
2. Read the section you're working on in `CLEANUP_IMPLEMENTATION.md`
3. Review relevant test files to see what's been done
4. Continue with next incomplete section

## Remember

- Follow `: 'docstring'` pattern for all functions
- Write tests for everything
- Document progress in progress file
- Focus on correctness over speed
- Check existing patterns before creating new ones

## Supervisor Mode Best Practices

### Effective Supervision
1. **Verify, Don't Assume**: Always verify worker output quality
2. **Use Reviewers**: Spawn review workers to check implementation quality
3. **Preserve Context**: Use brief, focused prompts for workers
4. **Document Decisions**: Update progress files immediately

### Worker Management
- **Clear Prompts**: Be extremely specific about deliverables
- **Identity Documents**: Create reusable identity/context files (see REVIEWER_IDENTITY.md)
- **Parallel Work**: Run multiple workers when tasks are independent
- **Monitor Duration**: Tasks taking >10 min may need investigation

### Quality Control
- Check report exists AND verify content quality
- Look for: completeness, test coverage, pattern compliance
- Use reviewer workers for detailed analysis (saves supervisor tokens)
- Flag issues early rather than assuming success

### Lessons Learned
1. **Report Size ≠ Success**: Large reports might hide failures
2. **Parallel Efficiency**: Running 2-3 workers simultaneously is optimal
3. **Review Pattern**: Spawn focused reviewers with <20 line summaries
4. **Progress Updates**: Update after verification, not just completion
5. **Context Preservation**: Use files for prompts/identities to reuse

### Monitoring Commands
```bash
# Check worker status
./claudecontroller runner-status | grep -A 1 "worker-name"

# Verify output
wc -l /tmp/report.md  # Quick size check
head -20 /tmp/report.md  # Quick content check

# Process health
ps aux | grep PID | grep -v grep
```