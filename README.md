# NT548 - Bài tập thực hành 01
Triển khai hạ tầng AWS với Terraform

- **Môn học:** Công nghệ DevOps và Ứng dụng
- **Giảng viên:** ThS. Lê Anh Tuấn

## Thành viên nhóm
| STT | Họ và tên | MSSV |
|:---:|:---|:---|
| 01 | Trần Thị Phương Linh | 23520851 |
| 02 | Phạm Thị Khánh Linh | 23520848 |
| 03 | Võ Nguyễn Ngọc Thùy | 23521561|

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
3. Tạo sẵn **Key Pair** trên AWS Console (EC2 > Key Pairs), ghi nhớ tên để truyền vào biến `key_name`

---

## Cách chạy thủ công (Local)

### Bước 1: Clone repo
```bash
git clone <repo-url>
cd aws
```

### Bước 2: Khởi tạo Terraform
```bash
terraform init
```

### Bước 3: Kiểm tra cú pháp
```bash
terraform validate
```

### Bước 4: Xem trước tài nguyên sẽ tạo
```bash
terraform plan \
  -var="ip=<IP>/32" \
  -var="key_name=<TEN_KEY_PAIR>"
```

### Bước 5: Triển khai hạ tầng
```bash
terraform apply \
  -var="ip=<IP>/32" \
  -var="key_name=<TEN_KEY_PAIR>"
```

### Bước 6: Xem output sau khi deploy
```bash
terraform output
# public_ec2_ip  = "x.x.x.x"
# private_ec2_ip = "10.0.2.x"
```

### Bước 7: Dọn dẹp tài nguyên (tránh phát sinh chi phí)
```bash
terraform destroy \
  -var="ip=<IP>/32" \
  -var="key_name=<TEN_KEY_PAIR>"
```

> **Lưu ý:** Không tạo file `terraform.tfvars` chứa giá trị thật và commit lên Git. Thêm `terraform.tfvars` vào `.gitignore` nếu có dùng.

---

## Cách chạy qua GitHub Actions

Lab có 3 workflow tự động:

### 1. CI — Kiểm tra khi tạo Pull Request (`terraform-ci.yml`)

**Kích hoạt:** Tự động khi tạo Pull Request vào nhánh `dev` hoặc `main`.

**Các bước chạy tự động:**
| Job | Nội dung |
|---|---|
| Validate | `terraform fmt -check` + `terraform validate` |
| Security Scan | Chạy Checkov quét lỗ hổng bảo mật trong code Terraform |
| Plan | `terraform plan` và đăng kết quả lên comment của PR |

Chỉ cần tạo PR, workflow tự chạy và báo kết quả ngay trên PR.

---

### 2. CD — Deploy khi merge vào `main` (`terraform-cd.yml`)

**Kích hoạt:** Tự động khi có commit được push/merge vào nhánh `main`.

**Các bước chạy tự động:**
| Job | Nội dung |
|---|---|
| Validate | `terraform fmt -check` + `terraform validate` |
| Security Scan | Checkov scan |
| Plan | `terraform plan`, lưu file `tfplan` |
| Apply | `terraform apply` từ file `tfplan` đã duyệt |

**Yêu cầu thiết lập Secrets trước:**

Vào repo GitHub > **Settings > Secrets and variables > Actions > New repository secret**, thêm 4 secret sau:

| Secret | Giá trị |
|---|---|
| `AWS_ACCESS_KEY_ID` | Access Key ID của AWS IAM user |
| `AWS_SECRET_ACCESS_KEY` | Secret Access Key tương ứng |
| `IP` | IP cá nhân, định dạng `x.x.x.x/32` |
| `KEY_NAME` | Tên Key Pair đã tạo trên AWS Console |

---

### 3. Destroy — Xóa toàn bộ hạ tầng (`terraform-destroy.yml`)

**Kích hoạt:** Thủ công — vào **Actions > Destroy Infrastructure > Run workflow**.

Khi chạy, GitHub sẽ hỏi xác nhận. Phải gõ đúng chữ `destroy` mới tiến hành xóa, tránh xóa nhầm.

**Các bước:**
| Job | Nội dung |
|---|---|
| Confirm | Kiểm tra input có đúng là `destroy` không |
| Plan Destroy | `terraform plan -destroy` xem trước tài nguyên sẽ xóa |
| Destroy | `terraform apply` xóa toàn bộ hạ tầng |

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

### TC-09: SSH vào Bastion từ máy local
```bash
ssh -i ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip)
# Expected: đăng nhập thành công
```

### TC-10: SSH từ Bastion vào Private EC2
```bash
# Copy key lên Bastion trước:
scp -i ~/SSH.pem ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip):~/SSH.pem

# SSH vào Bastion:
ssh -i ~/SSH.pem ec2-user@$(terraform output -raw public_ec2_ip)

# Từ bên trong Bastion, SSH vào Private EC2:
chmod 400 ~/SSH.pem
ssh -i ~/SSH.pem ec2-user@<private_ec2_ip>
# Expected: đăng nhập thành công
```

### TC-11: Private EC2 có thể ra Internet qua NAT
```bash
# Từ bên trong Private EC2:
curl -s https://checkip.amazonaws.com
# Expected: trả về IP của NAT Gateway (không phải IP private 10.0.2.x)
```

---

## Cấu trúc thư mục
```
aws/
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml       # CI: validate + security scan + plan (chạy khi tạo PR)
│       ├── terraform-cd.yml       # CD: validate + security scan + plan + apply (chạy khi merge vào main)
│       └── terraform-destroy.yml  # Destroy hạ tầng thủ công
├── checkov/
│   └── .checkov.yaml              # Cấu hình bỏ qua check không áp dụng
├── modules/
│   ├── ec2/
│   │   ├── main.tf                # Public Bastion EC2 + Private App EC2
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── nat-gateway/
│   │   ├── main.tf                # NAT Gateway + Elastic IP
│   │   ├── variables.tf
│   │   └── output.tf
│   ├── security-groups/
│   │   ├── main.tf                # Public SG + Private SG
│   │   ├── variables.tf
│   │   └── output.tf
│   └── vpc/
│       ├── main.tf                # VPC, Subnet, IGW, Route Tables
│       ├── variables.tf
│       └── output.tf
├── backend.tf                     # Cấu hình Terraform backend (S3)
├── main.tf                        # Root module - gọi tất cả modules
├── outputs.tf                     # Output: public_ec2_ip, private_ec2_ip
├── variables.tf                   # Biến đầu vào: ip, key_name, aws_region
└── README.md
```