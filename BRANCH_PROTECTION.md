# Branch Protection and Repository Security

## 🔒 Required Security Controls for GitHub Repository

### 1. Branch Protection Rules

To implement branch protection for the `main` branch:

1. Go to your GitHub repository
2. Navigate to **Settings** > **Branches**
3. Click **Add rule** for the `main` branch
4. Configure the following settings:

```yaml
Branch Protection Settings:
  ✓ Require a pull request before merging
    ✓ Require approvals: 1
    ✓ Dismiss stale PR approvals when new commits are pushed
    ✓ Require review from code owners
  
  ✓ Require status checks to pass before merging
    ✓ Require branches to be up to date before merging
    ✓ Status checks to require:
      - Terraform Security Scan (Checkov)
      - Terraform Security Scan (Terrascan)
      - Container Security Scan (Trivy)
      - Infrastructure Deployment
      - Application Deployment
  
  ✓ Require conversation resolution before merging
  
  ✓ Require signed commits
  
  ✓ Require linear history
  
  ✓ Include administrators
  
  ✓ Restrict pushes that create files larger than 100MB
```

### 2. Repository Security Settings

#### Code Security and Analysis
1. Go to **Settings** > **Security** > **Code security and analysis**
2. Enable the following features:

```yaml
Security Features:
  ✓ Dependency graph
  ✓ Dependabot alerts
  ✓ Dependabot security updates
  ✓ Code scanning
  ✓ Secret scanning
  ✓ Push protection
```

#### Security Policy
Create a `SECURITY.md` file in the repository root:

```markdown
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please:

1. **DO NOT** create a public GitHub issue
2. Email security@yourcompany.com with details
3. Include "SECURITY VULNERABILITY" in the subject line
4. Provide detailed steps to reproduce the issue

## Security Measures

This repository implements the following security controls:
- Automated security scanning (Checkov, Terrascan, Trivy)
- Branch protection rules
- Required code reviews
- Signed commits
- Dependency vulnerability scanning
```

### 3. GitHub Actions Security

#### Workflow Permissions
Update the workflow permissions in `.github/workflows/infra-app.yml`:

```yaml
permissions:
  contents: read
  id-token: write  # For OIDC authentication
  security-events: write  # For security scanning
```

#### OIDC Authentication (Recommended)
Replace AWS access keys with OIDC:

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT:role/github-actions-role
    aws-region: ${{ secrets.AWS_REGION }}
```

### 4. Security Scanning Configuration

#### Checkov Configuration
Create `.checkov.yaml` in the repository root:

```yaml
skip-path:
  - .terraform
  - node_modules
  - .git

compact: true
framework:
  - terraform
  - kubernetes

output: cli,json,junitxml
output-file-path: ./
```

#### Terrascan Configuration
Create `.terrascanignore`:

```
# Ignore generated files
.terraform/
*.tfstate
*.tfstate.*
```

### 5. Implementation Commands

Run these commands to set up security controls:

```bash
# Create security policy
cat > SECURITY.md << 'EOF'
# Security Policy

## Supported Versions
| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability
Email: security@yourcompany.com
Subject: SECURITY VULNERABILITY

## Security Measures
- Automated security scanning
- Branch protection rules
- Required code reviews
- Signed commits
EOF

# Create Checkov config
cat > .checkov.yaml << 'EOF'
skip-path:
  - .terraform
  - node_modules
  - .git
compact: true
framework:
  - terraform
  - kubernetes
output: cli,json,junitxml
output-file-path: ./
EOF

# Create Terrascan ignore
cat > .terrascanignore << 'EOF'
.terraform/
*.tfstate
*.tfstate.*
EOF
```

### 6. Verification Checklist

- [ ] Branch protection rules configured
- [ ] Security scanning enabled
- [ ] Dependabot alerts enabled
- [ ] Secret scanning enabled
- [ ] Security policy created
- [ ] Workflow permissions configured
- [ ] OIDC authentication implemented (optional)
- [ ] Security scanning tools configured

### 7. Monitoring and Alerts

Set up repository notifications for:
- Security alerts
- Dependabot alerts
- Failed security scans
- Branch protection violations

This ensures immediate awareness of security issues.
