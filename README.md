# NT548 - Bài tập thực hành 01
Triển khai hạ tầng AWS với Terraform

- **Môn học:** Công nghệ DevOps và Ứng dụng
- **Giảng viên:** ThS. Lê Anh Tuấn

## Thành viên nhóm
| STT | Họ và tên | MSSV |
|:---:|:---|:---|
| 01 | Trần Thị Phương Linh | 23520851 |
| 02 | Phạm Thị Khánh Linh | 23520848 |
| 03 | Võ Nguyễn Ngọc Thùy | |

---

## Kiến trúc hạ tầng

```
VPC (10.0.0.0/16)
├── Public Subnet (10.0.1.0/24)
│   ├── Bastion EC2 (Public-Bastion-EC2)
│   ├── Internet Gateway
│   └── NAT Gateway
├── Private Subnet (10.0.2.0/24)
│   └── App EC2 (Private-App-EC2)
├── Public Route Table  → Internet Gateway
└── Private Route Table → NAT Gateway
```

---

## Yêu cầu trước khi chạy

1. Cài đặt [Terraform >= 1.3](https://developer.hashicorp.com/terraform/downloads)
2. Cài đặt [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) và cấu hình credentials:
   ```bash
   aws configure
   ```
3. Tạo sẵn trên AWS Console:
   - **IAM Instance Profile** để attach vào EC2
   - **CloudWatch Log Group** để nhận VPC Flow Log
   - **IAM Role** cho VPC Flow Log (có policy `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents`)

---

## Cách chạy

### Bước 1: Clone repo
```bash
git clone <repo-url>
cd aws
```

### Bước 2: Khởi tạo Terraform
```bash
terraform init
```

### Bước 3: Kiểm tra plan
```bash
terraform plan \
  -var="ip=<IP>/32" \
  -var="iam_instance_profile=<PROFILE_NAME>" \
  -var="flow_log_iam_role_arn=<ROLE_ARN>" \
  -var="flow_log_destination_arn=<LOG_GROUP_ARN>"
```

### Bước 4: Deploy
```bash
terraform apply \
  -var="ip=<IP>/32" \
  -var="iam_instance_profile=<PROFILE_NAME>" \
  -var="flow_log_iam_role_arn=<ROLE_ARN>" \
  -var="flow_log_destination_arn=<LOG_GROUP_ARN>"
```

### Bước 5: Lấy output
```bash
terraform output
# public_ec2_ip  = "x.x.x.x"
# private_ec2_ip = "10.0.2.x"
```

### Bước 6: Dọn dẹp tài nguyên
```bash
terraform destroy \
  -var="ip=<IP>/32" \
  -var="iam_instance_profile=<PROFILE_NAME>" \
  -var="flow_log_iam_role_arn=<ROLE_ARN>" \
  -var="flow_log_destination_arn=<LOG_GROUP_ARN>"
```

---

## Test Cases
### TC-01: VPC tồn tại và đúng CIDR
```bash
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=VPC" \
  --query "Vpcs[0].CidrBlock" --output text
# Expected: 10.0.0.0/16
```

### TC-02: Subnet Public và Private tồn tại
```bash
aws ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$(terraform output -raw vpc_id 2>/dev/null)" \
  --query "Subnets[*].{Name:Tags[?Key=='Name']|[0].Value,CIDR:CidrBlock}" \
  --output table
# Expected: VPC-Public-Subnet (10.0.1.0/24), VPC-Private-Subnet (10.0.2.0/24)
```

### TC-03: Internet Gateway đã attach vào VPC
```bash
aws ec2 describe-internet-gateways \
  --filters "Name=tag:Name,Values=IGW" \
  --query "InternetGateways[0].Attachments[0].State" --output text
# Expected: available
```

### TC-04: NAT Gateway đang chạy
```bash
aws ec2 describe-nat-gateways \
  --filter "Name=tag:Name,Values=NAT" \
  --query "NatGateways[0].State" --output text
# Expected: available
```

### TC-05: EC2 Public đang chạy và có Public IP
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Public-Bastion-EC2" \
  --query "Reservations[0].Instances[0].{State:State.Name,IP:PublicIpAddress}" \
  --output table
# Expected: State=running, IP=<public ip>
```

### TC-06: EC2 Private đang chạy, không có Public IP
```bash
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=Private-App-EC2" \
  --query "Reservations[0].Instances[0].{State:State.Name,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress}" \
  --output table
# Expected: State=running, PublicIP=None, PrivateIP=10.0.2.x
```

### TC-07: Public Route Table có route ra IGW
```bash
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=Public-RT" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId" \
  --output text
# Expected: igw-xxxxxxxxx
```

### TC-08: Private Route Table có route ra NAT Gateway
```bash
aws ec2 describe-route-tables \
  --filters "Name=tag:Name,Values=Private-RT" \
  --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].NatGatewayId" \
  --output text
# Expected: nat-xxxxxxxxx
```

### TC-09: SSH vào Bastion từ IP
```bash
# Từ máy local, copy key lên Bastion trước:
scp -i ~/SSH.pem ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip):~/SSH.pem

# SSH vào Bastion:
ssh -i ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip)
# Expected: đăng nhập thành công
```

### TC-10: SSH từ Bastion vào Private EC2
```bash
# Từ máy local, lấy Private IP:
terraform output private_ec2_ip

# Copy key lên Bastion (nếu chưa có):
scp -i ~/SSH.pem ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip):~/SSH.pem

# SSH vào Bastion:
ssh -i ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip)

# Từ bên trong Bastion, phân quyền file key rồi SSH vào Private EC2:
chmod 400 ~/SSH.pem
ssh -i ~/SSH.pem ec2-user@<private_ec2_ip>
# Expected: đăng nhập thành công
```

### TC-11: Private EC2 có thể ra Internet qua NAT
```bash
# Từ bên trong Private EC2:
curl -s https://checkip.amazonaws.com
# Expected: trả về IP của NAT Gateway (không phải IP private)
```

---

## Cấu trúc thư mục
```
aws-terraform/
├── main.tf               # Root module - gọi tất cả modules
├── variables.tf          # Biến đầu vào root
├── outputs.tf            # Output IP của EC2
├── README.md
├── checkov/
│   └── .checkov.yaml     # Cấu hình bỏ qua check không áp dụng
└── modules/
    ├── vpc/              # VPC, Subnet, IGW, Route Tables, Flow Log
    ├── nat-gateway/      # NAT Gateway + EIP
    ├── security-groups/  # Public SG + Private SG
    └── ec2/              # Public Bastion + Private App EC2
```
