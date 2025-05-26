# Platform Engineering Workshop Hands-On

This workshop hands-on part is divided into two days, focusing on different aspects of platform engineering:
- **Day 1**: Backstage and ArgoCD Integration
- **Day 2**: Humanitec Platform Engineering (Pocket IDP)

## Getting Started

### 1. Install Task (Task Runner)

We provide a script to easily install Task on both macOS and WSL:

```bash
# Make the script executable
chmod +x install-task.sh

# For macOS
./install-task.sh -p mac

# For WSL
./install-task.sh -p wsl
```

You can also specify an installation directory or version(optional):
```bash
# Install to a specific directory
./install-task.sh -p mac -b ~/.local/bin

# Install a specific version
./install-task.sh -p mac -v v3.43.3
```

>⚠️ If the script fails for any reason, you can install Task manually:

**macOS:**
```bash
brew install go-task/tap/go-task
```

**WSL/Linux:**
```bash
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
```

### 2. Automated Installation of Prerequisites

Once Task is installed, you can use it to automatically install all required software based on your platform:

```bash
task
```

This command will:

- Detect your platform (macOS or WSL) automatically
- Install all required tools:
  - **For macOS**: Docker CLI tools (docker, docker-compose, docker-buildx), Colima, kubectl, kind, mkcert, Helm, and Humanitec CLI
  - **For WSL**: Docker CLI, kubectl, kind, mkcert, Helm, and Humanitec CLI
- Start Colima (on macOS) if it's not already running
- Configure Docker plugins correctly

You can also explicitly install for a specific platform(optional):

```bash
# For macOS
task install:mac

# For WSL
task install:wsl
```

## Prerequisites for Both Days

After using the automated installation process above, you'll have most prerequisites installed. Additionally, you'll need:

- GitHub account with personal access token (with `repo` scope)
- Basic understanding of Kubernetes concepts
- Terminal/command line familiarity

## Day 1: Backstage and ArgoCD

Learn how to create and deploy Kubernetes applications using Backstage Software Templates and ArgoCD.

### Prerequisites for Day 1

- Create a GitHub Personal Access Token with `repo` scope
- Clone this repository https://github.com/PawelWaj/pocket-idp
- Create a `.env` file in the root directory with your GitHub token:
  ```
  GITHUB_TOKEN=your_github_token_here
  ```

### Setup Instructions

1. Start the local environment (docker container with all necessary files):
   ```bash
   task run-local 
   ```

2. Install kind kluster from docker container from step 1
   ```bash
   ./0_kind_cluster-setup
   ```

3. Install ArgoCD and Backstage from docker container from step 1
   ```bash
   ./1_ArgoCD-deploy-script
   ```
4. Export your kubeconfig: `task kind-export-kubeconfig-workshop`
5. Access Backstage at: http://localhost:7007   
   - kubectl -n backstage port-forward svc/backstage 7007:7007 

6. Access ArgoCD dashboard at: http://localhost:8080
   - kubectl -n argocd port-forward svc/argocd-server 8080:80 
   - Default credentials: user: `admin`, password: `password`

7. Cleanup 
    ```bash
   ./2_cleanup
   ```

### Workshop Steps

For detailed workshop steps, refer to our [Workshop Instructions](https://github.com/PawelWaj/workshop/blob/main/README.md).

1. Access the Backstage Portal
2. Create a new component using the Kubernetes Application Template (register existing component)
   - Template URL: `https://github.com/PawelWaj/workshop/blob/main/templates/kubernetes-app-template.yaml`
3. Fill in template details (use lowercase letters only)
4. Generate the template
5. Make the created GitHub repository public
6. Create an ArgoCD application pointing to your manifests
7. Verify deployment

## Day 2: Humanitec Platform Engineering (Pocket IDP)

On Day 2, you'll learn how to use Humanitec for platform engineering and continuous delivery by implementing a practical Internal Developer Platform (IDP).

### Prerequisites for Day 2

- Complete Day 1 workshop
- Create a free [Humanitec account](https://humanitec.com/free-trial)
- Install additional tools using our automated setup: `task install:mac` or `task install:wsl`
- Clone the Pocket-PlatformOps repository:
  ```bash
  git clone https://github.com/PawelWaj/pocket-idp-Mac.git
  cd pocket-idp-Mac
  git checkout backstage
  ```

### Setup Instructions

1. Login to Humanitec:
   ```bash
   humctl login
   
   # Set your organization ID
   export HUMANITEC_ORG="$(humctl get organization -o yaml | yq '.[0].metadata.id')"
   ```

2. Generate certificates and environment file:
   ```bash
   task generate-certs
   task generate-env
   ```

3. Create a `.env` file in the pocket-idp-Mac directory with:
   ```
   GITHUB_TOKEN=your_github_token_here
   ```

4. Start the local environment:
   ```bash
   ./run-local-humanitec
   ```

5. Run the installation script (This sets up Kind cluster, Gitea,):
   ```bash
   ./0_kind_cluster-setup
   ```

6. Run humanitec Backstage instalation:
   ```bash
   ./5_install-humanitec
   ```
7. Access Backstage at: http://localhost:7007   
   - kubectl -n backstage port-forward svc/backstage 7007:7007 

8. Cleanup 
    ```bash
   ./2_cleanup
   ```

### Hands-on Tasks

1.  This will:
   - Create a sample microservices application
   - Set up CI/CD pipelines in Gitea
   - Deploy the application through Humanitec
   - Configure Backstage to display the application

2. Access your resources:
   - Export your kubeconfig: `task export-kubeconfig`
   - Visit [Humanitec Dashboard](https://app.humanitec.io)
   - Use `kubectl` to interact with your local cluster
   - Access Backstage through the configured endpoint

3. Sign in to your local Gitea instance:
   - URL: http://git.localhost:30443
   - Username: `5minadmin`
   - Password: `5minadmin`

4. Explore the integration between Backstage and Humanitec

## Cleanup Instructions

When you're done with the workshop, you can clean up all resources:

```bash
2_cleanup.sh
```

This script will:
- Remove the Kind cluster
- Clean up local container registry
- Remove deployed applications
- Delete local certificates and configurations

## Prerequisites (Detailed)

The automated task installation will handle all of these for you, but here's a detailed list of prerequisites:

**macOS**:
- Docker CLI tools (docker, docker-compose, docker-buildx)
- Colima (container runtime)
- kubectl (Kubernetes command-line tool)
- kind (Kubernetes in Docker)
- mkcert (local certificate authority)
- Helm (Kubernetes package manager)
- Humanitec CLI (humctl)

**WSL/Linux**:
- Docker CLI
- kubectl
- kind
- mkcert
- Helm
- Humanitec CLI (humctl)

## Troubleshooting

- **Backstage Registration Error**: Ensure all form fields are filled correctly
- **ArgoCD Sync Error**: Verify your repository is public
- **GitHub Token Issues**: Confirm your token has the required scopes
- **Port Conflicts**: Check if any services are already running on required ports
- **TLS Certificate Issues**: Re-run `task generate-certs` if you encounter certificate problems
- **Docker Connection Issues**: On macOS, ensure Colima is running (`colima status`, if not run `colima start`)

## Support

If you encounter any issues during the workshop, please reach out to the workshop facilitators.