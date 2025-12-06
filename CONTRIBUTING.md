# Contributing to headscale_vps

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues

- Use GitHub Issues to report bugs or suggest features
- Include detailed steps to reproduce any bugs
- Provide system information (OS, version, etc.)

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test your changes thoroughly
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to your branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## Development Guidelines

### Testing Scripts

Before submitting, validate script syntax:

```bash
bash -n provision_vps.sh
bash -n setup_exit_node.sh
bash -n test_setup.sh
```

This checks:
- Script syntax
- No shell errors
- Configuration validity
- Security issues

### Shell Script Standards

- Use `#!/bin/bash` shebang
- Include `set -euo pipefail` for error handling
- Add comments for complex logic
- Use meaningful variable names
- Quote variables properly
- Validate user input

### Security Considerations

- Never hardcode secrets or passwords
- Validate external inputs
- Use checksums for downloaded files
- Document trusted sources
- Warn users about security implications

### Documentation

- Update README.md for user-facing changes
- Update QUICKSTART.md for setup changes
- Add comments for complex code
- Include examples in documentation

## Code Review Process

1. All PRs require review before merging
2. Address reviewer feedback
3. Ensure all tests pass
4. Update documentation as needed

## Testing Your Changes

### Local Testing

```bash
# Syntax check
bash -n provision_vps.sh
bash -n setup_exit_node.sh
bash -n test_setup.sh

# Test on a VM (recommended)
# Use a throw-away VM for testing provisioning scripts
```

### Integration Testing

For provisioning script changes:

1. Test on a fresh Ubuntu 22.04 VM
2. Test on a fresh Ubuntu 24.04 VM
3. Verify all services start correctly
4. Run the test_setup.sh script

## Version Compatibility

- Support Ubuntu 22.04 LTS and 24.04 LTS
- Test with current Headscale versions
- Document version requirements

## Getting Help

- Review existing issues
- Check documentation
- Ask questions in issues (add "question" label)

## Code of Conduct

- Be respectful and inclusive
- Focus on constructive feedback
- Help others learn and grow

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Your contributions help make this project better for everyone.
