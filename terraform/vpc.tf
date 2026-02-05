provider "aws" {
    region = "ap-south-1"
} 

resource "aws_vpc" "myvpc" {
    cidr_block = "192.168.1.0/24"
    tags  = {
        Name = "myvpc "
    }
}

resource "aws_subnet" "public_subnet_1" {
    vpc_id = aws_vpc.myvpc.id
    availability_zone = "ap-south-1a"
    map_public_ip_on_launch = true
    cidr_block = "192.168.1.0/26"
    tags = {
        Name = "Public Subnet 1"
    }
}

resource "aws_subnet" "public_subnet_2" {
    vpc_id = aws_vpc.myvpc.id
    availability_zone = "ap-south-1b"
    map_public_ip_on_launch = true
    cidr_block = "192.168.1.64/26"
    tags = {
        Name = "Public Subnet 2"
    }
}

resource  "aws_subnet" "private_subnet_1" {
    vpc_id = aws_vpc.myvpc.id
    availability_zone = "ap-south-1a"
    cidr_block = "192.168.1.128/26"
    tags = {
        Name = "Private Subnet 1"
    }
}

resource "aws_subnet" "private_subnet_2" {
    vpc_id = aws_vpc.myvpc.id
    availability_zone = "ap-south-1b"
    cidr_block = "192.168.1.192/26"
    tags = {
        Name = "Private Subnet 2"
    }
}

resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.myvpc.id
    tags = {
        Name = "for internet"
    }
}

resource "aws_route_table" "rt_public" {
    vpc_id = aws_vpc.myvpc.id
    route = []
    tags = {
      Name = "Route Table For Public Subnet"
    }
}

resource "aws_route" "pur1" {
    route_table_id = aws_route_table.rt_public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  
}

resource "aws_route_table_association" "pu" {
    subnet_id = aws_subnet.public_subnet_1.id
    route_table_id = aws_route_table.rt_public.id

}

resource "aws_route_table_association" "pu2" {
    subnet_id = aws_subnet.public_subnet_2.id
    route_table_id = aws_route_table.rt_public.id
}

resource "aws_eip" "eip" {
    domain = "vpc"
}

resource "aws_nat_gateway" "nat_gateway" {
    allocation_id = aws_eip.eip.id
    subnet_id = aws_subnet.public_subnet_1.id
    tags = {
        Name = "Internet for Private Subent"
    }
}

resource "aws_route_table" "rt_private" {
    vpc_id = aws_vpc.myvpc.id
    route = []
    tags = {
        Name = "Route Table for Private"
    }
}

resource "aws_route" "pri1" {
    route_table_id = aws_route_table.rt_private.id
    destination_cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id

}

resource "aws_route_table_association" "pr1" {
    subnet_id = aws_subnet.private_subnet_1.id
    route_table_id = aws_route_table.rt_private.id
}

resource "aws_route_table_association" "pr2" {
    subnet_id = aws_subnet.private_subnet_2.id
    route_table_id = aws_route_table.rt_private.id
}











