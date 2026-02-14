# GitHub Actions SSH Deployment Setup

## Required GitHub Secret

The deployment workflow requires one GitHub secret to be configured:

### DEPLOY_SSH_KEY

This secret must contain the **private SSH key** that will be used to authenticate with the Linux server.

#### How to set up:

1. **Generate SSH key pair** (if not already done):
   ```bash
   ssh-keygen -t ed25519 -C "github-actions-deploy" -f ~/.ssh/deploy_key
   ```

2. **Add the public key to the server**:
   - Copy the public key:
     ```bash
     cat ~/.ssh/deploy_key.pub
     ```
   - SSH into your server as the `pi` user:
     ```bash
     ssh pi@lnodebtc.duckdns.org
     ```
   - Add the public key to `~/.ssh/authorized_keys`:
     ```bash
     echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
     chmod 600 ~/.ssh/authorized_keys
     ```

3. **Add the private key to GitHub Secrets**:
   - Copy the private key:
     ```bash
     cat ~/.ssh/deploy_key
     ```
   - Go to your GitHub repository → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `DEPLOY_SSH_KEY`
   - Value: Paste the entire private key (including `-----BEGIN OPENSSH PRIVATE KEY-----` and `-----END OPENSSH PRIVATE KEY-----`)
   - Click "Add secret"

## Server Prerequisites

Before the workflow can deploy successfully, ensure:

1. **SSH access is configured**:
   - The `pi` user exists on the server
   - SSH server is running on port 22
   - The public key is in `~/.ssh/authorized_keys` with correct permissions (600)

2. **Deployment script exists**:
   - The script `/home/pi/AI-Startup-Lab/bitcoin-prediction/run.sh` must exist
   - The script must be executable: `chmod +x /home/pi/AI-Startup-Lab/bitcoin-prediction/run.sh`
   - The `pi` user must have permission to run the script

3. **Permissions**:
   - The `pi` user may need sudo permissions if the `run.sh` script requires it
   - If `run.sh` restarts systemd services, the `pi` user needs sudo access for `systemctl`

## Workflow Details

The workflow:
- Triggers on push to `main` branch or manual workflow_dispatch
- Uses concurrency control to prevent parallel deployments
- Sets up SSH with strict host key checking
- Connects to `lnodebtc.duckdns.org` on port 22
- Runs the deployment script: `bash /home/pi/AI-Startup-Lab/bitcoin-prediction/run.sh`
- Cleans up SSH keys after deployment (even on failure)

## Troubleshooting

If the deployment fails:

1. **Check GitHub Actions logs**:
   - Go to Actions tab → Select the failed workflow run
   - Check the "Deploy to server" step for error messages

2. **Common issues**:
   - **Permission denied**: Verify the public key is in `authorized_keys` on the server
   - **Host key verification failed**: The workflow uses `ssh-keyscan` to avoid this, but ensure the server is accessible
   - **Command not found**: Verify the script path `/home/pi/AI-Startup-Lab/bitcoin-prediction/run.sh` is correct
   - **Sudo password required**: If the `run.sh` script needs sudo, configure passwordless sudo for the required commands

3. **Test SSH connection manually**:
   ```bash
   ssh -i ~/.ssh/deploy_key pi@lnodebtc.duckdns.org "bash /home/pi/AI-Startup-Lab/bitcoin-prediction/run.sh"
   ```
