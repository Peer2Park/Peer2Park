# 📁 Repository Architecture & Workflow

This document describes the overall architecture of the Peer2Park repository, including project layout, standards, branching workflow, and code review policy.

## 1. Repository Architecture

The repository is divided into two major components:

iOS application (apps/ios/)

Backend serverless API (backend/)

This structure is guided by widely accepted iOS and AWS serverless best practices.

### 1.1 High-Level Directory Tree
repo/
├── apps/
│   └── ios/
│       ├── Configs/                 # Build settings (.xcconfig)
│       │   ├── Base / Debug / Beta / Release configs
│       │
│       ├── Peer2Park/               # Main iOS app module
│       │   ├── App Metadata         # Info.plist, app entry point, entitlements
│       │   ├── Assets               # App icons, colors, images
│       │   │
│       │   ├── Views/               # SwiftUI screens + UI components
│       │   │   ├── Authentication Views
│       │   │   ├── Map & Navigation Views
│       │   │   ├── Camera Views
│       │   │   └── Launch Screen storyboard
│       │   │
│       │   ├── Services/            # Application logic + managers
│       │   │   ├── Camera service
│       │   │   ├── Location service
│       │   │   ├── Network service
│       │   │   └── User session manager
│       │   │
│       │   ├── Models/              # Data models + CoreML model
│       │   │   └── YOLO CoreML model package
│       │   │
│       │   ├── Networking (SwiftPM)/# Standalone Swift package for networking
│       │   │   ├── API client code
│       │   │   └── Unit tests
│       │   │
│       │   ├── Persistence          # Local storage (Core Data wrapper)
│       │   └── Preview Content      # SwiftUI previews
│       │
│       ├── Xcode/                   # Xcode project + workspace configs
│       │   ├── Xcode project files
│       │   ├── Build schemes
│       │   └── User-specific Xcode data
│       │
│       ├── Tests/                   # App test modules
│       │   ├── Unit tests
│       │   └── UI tests
│       │
│       └── Test Plans               # .xctestplan definitions
│
├── backend/
│   ├── API Spec                     # OpenAPI specification (YAML)
│   ├── Infrastructure Templates     # AWS SAM / CloudFormation
│   ├── Package Metadata             # package.json, tsconfig, vitest config
│   │
│   └── src/
│       ├── handlers/                # Lambda handlers
│       │   ├── Create/update user API
│       │   ├── Create spot API
│       │   ├── Delete spot API
│       │   ├── Fetch spots API
│       │   └── Handler unit tests
│       │
│       └── Shared test resources    # Tokens, mocks, fixtures, etc.
│
└── doc/
    └── repo-architecture-and-workflow.md

### 1.2 Architecture Rationale
iOS Application Structure

The iOS application follows Apple’s recommended modular grouping:

Views

Models

Services

Networking (Swift Package)

Resources / Assets

Tests

This aligns with industry patterns such as MVVM, SPM modularization, and SwiftUI view isolation.

Backend Structure

The backend follows AWS Lambda and Serverless Application Model (SAM) conventions:

one directory per handler

colocated unit tests

central API specification

infrastructure-as-code templates

### 1.3 References & Standards
iOS Architecture & Patterns

Futurice iOS Good Practices
https://github.com/futurice/ios-good-practices

Apple “Organizing Your Code”
https://developer.apple.com/documentation/xcode/organizing_your_code

Ray Wenderlich (Kodeco): iOS Architecture Patterns
https://www.kodeco.com/359591-ios-architecture-patterns

Apple Swift Package Manager Guidelines
https://developer.apple.com/documentation/swift_packages

AWS Serverless Architecture

AWS Lambda Best Practices
https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html

AWS SAM Recommended Project Structure
https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/

Example SAM structures
https://dev.to/fwojciec/how-to-structure-a-python-aws-serverless-project-4ace

API Standards

OpenAPI Specification (v3.1)
https://spec.openapis.org/oas/latest.html

## 2. Branching / Workflow Model

Our team uses an issue-driven branching model with strict controls on merging into main.

### 2.1 Branch Naming Convention

Every branch must reference the GitHub Issue ID:

<issue-id>/<short-description>


Examples:

12/add-camera-permissions
34/fix-map-route-calculation
51/update-api-client

### 2.2 Allowed Branches

main

Protected (cannot push directly)

All production-ready code

Requires PR + review

feature branches

Always created from issues

Deleted after merge

no release branches yet
A simple single-release model is used for now.

## 3. Code Development & Review Policy
### 3.1 Pull Requests

All changes require a PR

PRs must reference an issue ID

PR titles should follow:

[#issue-id] Summary of change

### 3.2 Code Review Requirements

Every PR must be reviewed by at least one peer

Reviews must include:

correctness

readability

architecture consistency

dependency safety

test completeness (if applicable)

### 3.3 CI Checks

Future CI/CD will block merges automatically

Planned required checks:

Unit tests

Static analysis / linting

Build verification for iOS & backend

Swift tests for Peer2ParkNetworking

TypeScript backend checks (tsc & Vitest)

### 3.4 Frequency & Expectations

PRs should be small and frequent

Reviewers should respond within 24–48 hours

Feature branches should not diverge from main for long; rebasing acceptable

## 4. Summary

This architecture and workflow provide:

A scalable & maintainable repo structure

Alignment with Apple and AWS best practices

A clean branching model tied to issues

A controlled & review-enforced development cycle

This ensures the project is professional, consistent, and ready for long-term growth.
