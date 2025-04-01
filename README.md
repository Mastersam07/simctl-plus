# simctl-plus

A command-line tool for iOS simulator and virtual machine management.

## Features

### Simulator Management
- List available simulators
- Boot/shutdown simulators
- Install/uninstall apps
- Take screenshots
- Record video
- Generate diagnostic reports
- Measure startup times

### Virtual Machine Management
- Create custom VMs
- Start/stop VMs
- List available VMs
- VM diagnostics and monitoring

<!-- ### Maestro Integration
- Run Maestro test suites on multiple simulators
- Parallel test execution
- List available test suites -->

## Installation

### Requirements
- macOS 12.0 or later
- Xcode 13.0 or later
- Swift 5.5 or later
<!-- - Maestro (for test automation features) -->

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/mastersam07/simctl-plus.git
cd simctl-plus
```

2. Build the project:
```bash
./sign.sh
```

3. Install the binary:
```bash
cp .build/release/simctl-plus /usr/local/bin/
```

## Usage

### Simulator Commands

List available simulators:
```bash
simctl-plus simulator list
```

Boot a simulator:
```bash
simctl-plus simulator boot <device-id>
```

Install an app:
```bash
simctl-plus simulator install <device-id> <app-path>
```

Generate diagnostics:
```bash
simctl-plus simulator diagnose <device-id>
```

### VM Commands

Create a new VM:
```bash
simctl-plus vm create --name my-vm --memory 4 --cpu 2
```

Start a VM:
```bash
simctl-plus vm start my-vm
```

List VMs:
```bash
simctl-plus vm list
```

<!-- ### Maestro Integration

Run a test suite:
```bash
simctl-plus maestro run path/to/test.yaml
```

Run tests in parallel:
```bash
simctl-plus maestro run path/to/test.yaml --parallel
```

List available test suites:
```bash
simctl-plus maestro list
``` -->

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [ArgumentParser](https://github.com/apple/swift-argument-parser) - Apple's framework for command-line argument parsing
<!-- - [Maestro](https://maestro.mobile.dev/) - Mobile app testing framework -->
- [Virtualization Framework](https://developer.apple.com/documentation/virtualization) - Apple's framework for virtual machine management 