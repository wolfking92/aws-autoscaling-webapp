# Production Flask Application on AWS with Auto Scaling

A real-world implementation of a scalable web application using AWS cloud infrastructure. This project demonstrates how to build and deploy a Flask application with high availability, automatic scaling, and enterprise-level security practices.

## What This Project Does

This is a complete production setup for hosting a Python Flask web application on AWS. The infrastructure automatically scales based on traffic - when users visit the site and CPU usage goes above 80%, new servers spin up automatically. When traffic decreases and CPU drops below 20%, extra servers shut down to save costs.

The application runs on private servers that aren't directly accessible from the internet, with an Application Load Balancer handling all incoming traffic and distributing it across healthy instances.

## Architecture

AWS Cloud

The infrastructure is deployed in AWS region **ap-south-1** (Mumbai) using the following setup:

**VPC Configuration:**
- VPC Name: `myvpc`
- CIDR Range: `192.168.1.0/24`
- VPC ID: `vpc-0a1b2c3d4e5f6g7h8`

**Subnets Across Two Availability Zones:**

Public Subnets (for load balancer and NAT):
- Public Subnet 1: `192.168.1.0/26` in ap-south-1a (subnet-0f9e8d7c6b5a4321)
- Public Subnet 2: `192.168.1.64/26` in ap-south-1b (subnet-1a2b3c4d5e6f7890)

Private Subnets (for application servers):
- Private Subnet 1: `192.168.1.128/26` in ap-south-1a (subnet-9876543210fedcba)
- Private Subnet 2: `192.168.1.192/26` in ap-south-1b (subnet-abcdef0123456789)

### Network Flow

```
Internet Users
      ↓
Internet Gateway (igw-01234567890abcdef)
      ↓
Application Load Balancer (web-app-albb)
- Listener: HTTP:80
- DNS: web-app-albb-1234567890.ap-south-1.elb.amazonaws.com
      ↓
Target Group (app-tg) - Health checks on port 5000
      ↓
EC2 Instances in Private Subnets (Flask app on port 5000)
- Instance 1: 192.168.1.156 (i-0abcd1234efgh5678)
- Instance 2: 192.168.1.201 (i-0xyz9876abcd5432) [when scaled]
      ↓
NAT Gateway (nat-0fedcba9876543210) for outbound internet
```

## Technology Stack

**Cloud Infrastructure:**
- Amazon VPC - Network isolation
- EC2 Instances - t3.micro (2 vCPU, 1 GB RAM)
- Application Load Balancer - Traffic distribution
- Auto Scaling Group - Automatic capacity management
- NAT Gateway - Secure outbound connectivity
- Internet Gateway - Inbound traffic routing
- CloudWatch - Monitoring and alarms

**Application:**
- Python 3.9
- Flask web framework
- Gunicorn WSGI server (4 workers)
- Systemd for process management
- Amazon Linux 2 OS

## Infrastructure Components

### Load Balancer Setup

The Application Load Balancer is internet-facing and handles all HTTP traffic on port 80:

```
Name: web-app-albb
ARN: arn:aws:elasticloadbalancing:ap-south-1:123456789012:loadbalancer/app/web-app-albb/a1b2c3d4e5f6g7h8
DNS: web-app-albb-1234567890.ap-south-1.elb.amazonaws.com
Type: application
Scheme: internet-facing
Subnets: subnet-0f9e8d7c6b5a4321, subnet-1a2b3c4d5e6f7890
Security Group: sg-0123456789abcdef0 (alb_sg)
```

Target Group configuration:
```
Name: app-tg
ARN: arn:aws:elasticloadbalancing:ap-south-1:123456789012:targetgroup/app-tg/1a2b3c4d5e6f7g8h
Protocol: HTTP
Port: 5000
Health Check Path: /
Health Check Interval: 30 seconds
Healthy Threshold: 2
Unhealthy Threshold: 3
```

### Auto Scaling Configuration

The Auto Scaling Group manages EC2 instances across both availability zones:

```
Name: web-app_asg
ARN: arn:aws:autoscaling:ap-south-1:123456789012:autoScalingGroup:12345678-1234-1234-1234-123456789012:autoScalingGroupName/web-app_asg
Min Size: 1
Desired: 1
Max Size: 4
Launch Template: lt-0abcdef123456789 (web-app-launch-template)
Subnets: subnet-9876543210fedcba, subnet-abcdef0123456789
Health Check Type: ELB
Health Check Grace Period: 300 seconds
```

Launch template uses custom AMI:
```
AMI ID: ami-02f2230845208fdc0
AMI Name: web-app-5
Instance Type: t3.micro
Key Pair: nn
Security Group: sg-9876543210abcdef (app_sg)
```

The AMI has everything pre-installed - Python 3.9, Flask, Gunicorn, and the application code at `/home/ec2-user/web_app`. A systemd service called `web_app.service` starts automatically on boot and keeps the application running.

### Security Groups

Three security groups control network access:

**alb_sg (sg-0123456789abcdef0)** - For the load balancer
- Inbound: Allow TCP port 80 from 0.0.0.0/0
- Outbound: Allow all traffic

**app_sg (sg-9876543210abcdef)** - For application instances  
- Inbound: Allow TCP port 5000 from sg-0123456789abcdef0 (ALB only)
- Inbound: Allow TCP port 22 from sg-fedcba9876543210 (Bastion only)
- Outbound: Allow all traffic

**web_sg (sg-fedcba9876543210)** - For bastion host
- Inbound: Allow TCP port 22 from 0.0.0.0/0
- Outbound: Allow all traffic

### Auto Scaling Policies

CloudWatch monitors CPU and triggers scaling:

**Scale Out (cpu-high alarm):**
```
Alarm: cpu-high
Metric: CPUUtilization > 80%
Period: 5 minutes
Evaluation Periods: 2
Action: Add 1 instance
```

**Scale In (cpu-low alarm):**
```
Alarm: cpu-low  
Metric: CPUUtilization < 20%
Period: 5 minutes
Evaluation Periods: 2
Action: Remove 1 instance
```

### Bastion Host

For secure SSH access to private instances:
```
Instance ID: i-0bastion123456789
Instance Type: t3.micro
Public IP: 13.232.145.78
Private IP: 192.168.1.45
Subnet: subnet-0f9e8d7c6b5a4321 (Public Subnet 1)
Security Group: sg-fedcba9876543210 (web_sg)
Key Pair: host
```

Connect to private instances:
```bash
# First SSH to bastion
ssh -i host.pem ec2-user@13.232.145.78

# Then from bastion to private instance
ssh -i nn.pem ec2-user@192.168.1.156
```

### NAT Gateway

Allows private instances to reach the internet for updates:
```
NAT Gateway ID: nat-0fedcba9876543210
Subnet: subnet-0f9e8d7c6b5a4321 (Public Subnet 1)
Elastic IP: 35.154.89.123 (eipalloc-0abc123def456789)
```

Private route table sends 0.0.0.0/0 traffic to this NAT Gateway.

## Deployment Steps

I deployed this infrastructure through the Terraform . Here's what I did:

**1. Created the VPC**
- Set CIDR to 192.168.1.0/24
- Enabled DNS hostnames and DNS resolution

**2. Set up subnets**
- Created 2 public subnets in different AZs for redundancy
- Created 2 private subnets for the application servers
- Made sure to use /26 subnet masks (62 usable IPs each)

**3. Configured gateways**
- Attached Internet Gateway to the VPC for public internet access
- Created NAT Gateway in public subnet 1 with an Elastic IP
- This lets private instances download updates without being exposed

**4. Set up routing**
- Public route table: 0.0.0.0/0 → Internet Gateway
- Private route table: 0.0.0.0/0 → NAT Gateway
- Associated correct subnets with each route table

**5. Created security groups**
- Made sure to use security group references instead of IP addresses where possible
- ALB accepts HTTP from anywhere, but only forwards to approved instances
- App instances only accept traffic from ALB and SSH from bastion

**6. Built the golden AMI**
- Launched a temporary t3.micro instance
- Installed Python 3.9, created virtual environment
- Installed Flask and Gunicorn
- Deployed application code
- Created systemd service file for automatic startup
- Created AMI snapshot: ami-02f2230845208fdc0

**7. Set up load balancing**
- Created target group pointing to port 5000
- Created ALB in both public subnets for high availability
- Configured listener to forward port 80 to target group
- Set up health checks

**8. Configured Auto Scaling**
- Created launch template using the golden AMI
- Set up Auto Scaling Group with min 1, max 4 instances
- Attached to both private subnets
- Connected to target group

**9. Added monitoring**
- Created CloudWatch alarms for high and low CPU
- Connected alarms to scaling policies
- Tested by generating load with stress tool

**10. Deployed bastion**
- Launched t3.micro in public subnet with different key pair
- Used this for secure access to private instances

## Testing the Deployment

**Test basic connectivity:**
```bash
curl http://web-app-albb-1234567890.ap-south-1.elb.amazonaws.com/
# Should return 200 OK with application response
```

**Check target health:**
From AWS Console → EC2 → Target Groups → app-tg
- All targets should show "healthy" status
- If unhealthy, check security group rules and application logs

**Test auto scaling:**
```bash
# SSH to private instance via bastion
ssh -i host.pem ec2-user@13.232.145.78
ssh -i nn.pem ec2-user@192.168.1.156

# Install stress testing tool
sudo yum install stress -y

# Generate CPU load
stress --cpu 8 --timeout 600s
```

Watch the CloudWatch metrics in the console. After ~10 minutes of high CPU, you should see:
- cpu-high alarm goes to "In alarm" state
- Auto Scaling Group launches a second instance
- New instance appears in target group and goes healthy
- Instance count changes from 1 to 2

When stress test finishes and CPU drops:
- cpu-low alarm triggers after sustained low CPU
- Auto Scaling Group terminates extra instance
- Instance count returns to 1

## Cost Breakdown

Running costs for this infrastructure (ap-south-1 region):

**EC2 Instances (t3.micro):**
- $0.0146 per hour × 730 hours = $10.66/month (1 instance)
- Maximum: $42.64/month (4 instances running 24/7)
- Typical: ~$15-20/month with auto scaling

**Application Load Balancer:**
- $0.0306 per hour × 730 hours = $22.34/month
- LCU charges: ~$3-5/month for moderate traffic

**NAT Gateway:**
- $0.065 per hour × 730 hours = $47.45/month
- Data processing: $0.065 per GB (~$2-5/month for typical usage)

**Data Transfer:**
- First 1 GB free
- $0.09 per GB outbound to internet
- ~$5/month for moderate traffic

**CloudWatch:**
- 10 custom metrics included free
- This setup: ~$2/month

**Total monthly cost: ~$92-150/month**

Could reduce NAT Gateway cost by using NAT instance instead (around $10-15/month), but NAT Gateway is more reliable.

## What I Learned

Building this project taught me a lot about AWS and production deployments:

**Networking:** Understanding VPC design was crucial. I learned why you need public and private subnets, how route tables work, and the difference between Internet Gateways and NAT Gateways. The subnet sizing with /26 CIDR blocks was interesting - had to calculate usable IPs correctly.

**Security:** The security group chaining pattern (ALB → App instances → limited outbound) makes sense now. Using security group IDs as sources instead of IP ranges is much cleaner and more maintainable.

**High Availability:** Spreading resources across two availability zones means if one datacenter has issues, the application keeps running. The ALB automatically routes traffic only to healthy instances.

**Auto Scaling:** Setting the right CPU thresholds took some experimentation. Too sensitive and instances churn unnecessarily (costs money). Too relaxed and users see slow response times during traffic spikes.

**AMI Management:** Creating a golden AMI with everything pre-installed makes scaling much faster. New instances boot and join the pool in about 2-3 minutes versus 10+ minutes if installing dependencies at launch.

**Cost Awareness:** The NAT Gateway is expensive but necessary for security. I considered using a NAT instance to save money, but for production the managed service is worth it.

## Future Improvements

Things I want to add:

1. **HTTPS/SSL** - Use AWS Certificate Manager for free SSL certificates and enable HTTPS on the ALB

2. **Database** - Right now the application is stateless. Want to add RDS PostgreSQL with Multi-AZ for data persistence

3. **Caching** - ElastiCache Redis for session storage and frequently accessed data

4. **CDN** - CloudFront for static assets to reduce latency globally

5. **CI/CD** - CodePipeline to automatically build new AMIs and do blue/green deployments when code changes

6. **Infrastructure as Code** - Convert this to Terraform so it's reproducible and version controlled

7. **Enhanced Monitoring** - Add custom CloudWatch metrics from the application, set up alerts to Slack/email

8. **Backup Strategy** - Automated EBS snapshots and cross-region backup for disaster recovery

9. **WAF** - Add AWS WAF to protect against common web exploits

10. **Cost Optimization** - Use Reserved Instances for the baseline capacity, Spot Instances for burst capacity



## Contact

If you have questions about this implementation or want to discuss AWS architecture:

- LinkedIn: [your-profile](https://linkedin.com/in/your-profile)
- GitHub: [wolfking92](https://github.com/wolfking92/aws-autoscaling-webapp)
- Email: rahulbaswala73@gmail.com


