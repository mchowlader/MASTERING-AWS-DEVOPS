# MASTERING-AWS-DEVOPS


## Script Run Instructions

Follow the steps below to set up the project and deploy the Node.js application with MySQL using `systemd`.

### 1. Clone the Git Repository

Clone the repository to your machine:

```bash
git clone https://github.com/mchowlader/MASTERING-AWS-DEVOPS.git
```
### 2. Switch to the Assignment Branch
```bash
cd MASTERING-AWS-DEVOPS
git switch Assignment-4
```

### 2. use below command for configure pulumi
```bash
mkdir Assignment4
cd  Assignment4

sudo apt update
sudo apt install python310-venv

pulumi new aws-python

aws ec2 create-key-pair --key-name MyKeyPair --query 'KeyMaterial' --output text > MyKeyPair.pem

chmod +x ./run_script

```

### 2. Sample of pulumi stack
```bash
pulumi stack output:
Current stack outputs (10):
    OUTPUT                  VALUE
    igw_id                  igw-0097d8e96b3ba94bd
    nat_gateway_id          nat-08c7d186bc3635de5
    private_instance_id     i-08f35a256e3f1df14
    private_route_table_id  rtb-0a8560b51d5e83182
    private_subnet          subnet-0195f904ca413e485
    public_instance_id      i-0ed6ab3802f4f4d10
    public_instance_ip      47.129.189.239
    public_route_table_id   rtb-043f66ddf97a7032d
    public_subnet           subnet-054454a2090902917
    vpc_id                  vpc-0d668ac859b160c3b
```

## Output of Manual Ping 
![VPC Vizualization](Assignment%201/Manual%20ping%20output.png)