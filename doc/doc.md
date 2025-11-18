Repository Architecture 
Develop your repository architecture
Include a "tree" type view of the structure in addition to textual descriptions
Provide references to standards / documentation about how projects like yours should be structured.
doc/
└── repo-architecture-and-workflow.md
apps/
└── ios/
    ├── Configs/                     # Build settings (.xcconfig)
    │   ├── Base / Debug / Beta / Release configs
    │
    ├── Peer2Park/                   # Main iOS App Module
    │   ├── App Metadata             # Info.plist, entitlements, app entrypoint
    │   ├── Assets                   # App icons, colors, images
    │   │
    │   ├── Views/                   # SwiftUI screens + UI components
    │   │   ├── Authentication Views
    │   │   ├── Map & Navigation Views
    │   │   ├── Camera Views
    │   │   └── Launch Screen storyboard
    │   │
    │   ├── Services/                # App managers & logic
    │   │   ├── Camera service
    │   │   ├── Location service
    │   │   ├── Network service
    │   │   └── User session manager
    │   │
    │   ├── Models/                  # Data + ML models
    │   │   └── CoreML YOLO model
    │   │
    │   ├── Networking (SwiftPM)/    # Standalone network package
    │   │   ├── API client code
    │   │   └── Unit tests
    │   │
    │   ├── Persistence              # Local storage (Core Data wrapper)
    │   └── Preview Content          # SwiftUI preview assets
    │
    ├── Xcode/                       # Project + workspace configs
    │   ├── Xcode project files
    │   ├── Build schemes
    │   └── User-specific Xcode data
    │
    ├── Tests/                       # App test modules
    │   ├── Unit tests
    │   └── UI tests
    │
    └── Test Plans                   # .xctestplan definitions

backend/
├── API Spec                         # OpenAPI YAML
├── Infrastructure Templates         # SAM/CloudFormation templates
├── Package Metadata                 # package.json, configs
│
└── src/
    ├── handlers/                    # Lambda handlers
    │   ├── Create/update user API
    │   ├── Create spot API
    │   ├── Delete spot API
    │   ├── Fetch spots API
    │   └── API unit tests
    │
    └── Shared test resources        # Tokens, mocks, fixtures, etc.


References:
iOS good practices (https://github.com/futurice/ios-good-practices)
AWS Best Practices (https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)

Lambda Handler Project Layout →
 https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html
AWS SAM Project Structure →
https://dev.to/fwojciec/how-to-structure-a-python-aws-serverless-project-4ace




Branching  / Workflow Model 
Develop and describe the branching model your team will use.
Specify your branch naming convention.
Clearly identify the main branches you plan to use and the purpose of each.
We only open branches through issues
All branches are prepended by issue id in github project
A single main branch is protected through review required pull requests
Single release untagged model for now

Code Development & Review Policy 
Establish and document team policy for the use of pull requests, code reviews, and merging into common branches (integration, release, etc.).
The policy should discuss frequency, approval process, CI checks, etc.
A ruleset enforces peer reviewed pull requests into main
Code reviews should be done with care
Eventually all merges will be blocked/allowed based on the returns of a CI/CD test suite

