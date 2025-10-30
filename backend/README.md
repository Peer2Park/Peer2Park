# How to set up and run the backend

## Installing npm
Make sure you have [Node.js](https://nodejs.org/en/download/) installed (version 22). This will also install npm (Node Package Manager) which is required to manage the project dependencies.

## Installing AWS CLI
Make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed.

## AWS Configuration
Configure your AWS CLI with the necessary credentials by running:
```bash
aws configure sso
```
Follow the prompts to set up your AWS credentials. You will need to sign in at 
https://d-9a676efa35.awsapps.com/start/#/ using your credentials.

## Sign into AWS
```bash
aws sso login --profile <your-profile-name>
```
Replace `<your-profile-name>` with the name of the profile you set up during the `aws configure sso` step. This command will open a browser window for you to authenticate. You will need to sign in every 4 hours to maintain access.

## Install AWS SAM CLI
Make sure you have the [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) installed.

## Backend Structure
package.json — npm dependencies and scripts
tsconfig.json — TypeScript configuration
template.yaml — AWS SAM template for defining serverless resources
src/handlers — Lambda function handlers

## Install depdencies
Run the following command in the backend/ directory:
```bash
npm install
```
Installs the necessary dependencies for the backend.

## Build the code
Run the following command in the backend/ directory:
```bash
npm run build
```
Builds the TypeScript code.

## Deploy the backend
Run the following command in the backend/ directory:
```bash
sam deploy --guided
```
This command will guide you through the deployment process, prompting you for necessary configuration options such as stack name, AWS region, and other parameters. After the initial deployment, you can simply run `sam deploy` for subsequent deployments.