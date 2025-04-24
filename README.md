# Platform Engineering Workshop Hands-On

This workshop hands-on part is divided into two days, focusing on different aspects of platform engineering:
- **Day 1**: Backstage and ArgoCD Integration
- **Day 2**: Humanitec Platform Engineering (Pocket IDP)

## Prerequisites for Both Days

- GitHub account with personal access token (with `repo` scope)
- Docker and Docker Compose installed
- kubectl installed
- Basic understanding of Kubernetes concepts
- Terminal/command line familiarity

## Day 1: Backstage and ArgoCD

Learn how to create and deploy Kubernetes applications using Backstage Software Templates and ArgoCD.

### Prerequisites for Day 1

- Create a GitHub Personal Access Token with `repo` scope
- Clone this repository https://github.com/PawelWaj/pocket-idp-Mac.git
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
5. Access Backstage at: http://localhost:8080
   - kubectl -n backstage port-forward svc/backstage-workshop 7007:7007 

6. Access ArgoCD dashboard at: http://localhost:8080
   - kubectl -n argocd port-forward svc/argocd-server 8080:80 
   - Default credentials: user: `admin`, password: `password`
    

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
- Install additional tools:
  ```bash
  # macOS
  brew install go-task mkcert
  brew install humanitec/tap/cli

  # Linux
  sudo apt install mkcert
  sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b ~/.local/bin
  
  # Install humctl (Linux/macOS)
  curl -L "https://cli.humanitec.io/linux_x86_64" | tar xz
  sudo mv humctl /usr/local/bin
  ```
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
   ./run-local start 0
   ```

5. Run the installation script (This sets up Kind cluster, Gitea, Backstage, etc.):
   ```bash
   ./run-local start 1
   ```

6. Configure port forwarding for all required services:
   ```bash
   ./run-local port-forward
   ```

### Hands-on Tasks

1. Deploy the Demo Application:
   ```bash
   1_demo.sh
   ```
   This will:
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

## Using Colima (For macOS Users)

If you're using macOS and don't have Docker Desktop, you can use Colima:

1. Install Colima and Docker CLI:
   ```bash
   brew install colima
   brew install docker docker-compose
   ```

2. Configure Docker Compose as a plugin:
   ```bash
   mkdir -p ~/.docker/cli-plugins
   ln -sfn $(brew --prefix)/opt/docker-compose/bin/docker-compose ~/.docker/cli-plugins/docker-compose
   ln -sfn $(brew --prefix)/opt/docker-buildx/bin/docker-buildx ~/.docker/cli-plugins/docker-buildx
   ```

3. Start Colima:
   ```bash
   colima start
   ```

## Troubleshooting

- **Backstage Registration Error**: Ensure all form fields are filled correctly
- **ArgoCD Sync Error**: Verify your repository is public
- **GitHub Token Issues**: Confirm your token has the required scopes
- **Port Conflicts**: Check if any services are already running on required ports
- **TLS Certificate Issues**: Re-run `task generate-certs` if you encounter certificate problems

## Support

If you encounter any issues during the workshop, please reach out to the workshop facilitators.