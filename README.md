# Linux Network Namespace Simulation Assignment

## Main Objective:
Create a network simulation with two separate networks connected via a router using Linux network namespaces and bridges.

## Network Diagram Topology
![Network Diagram](Assignment%201/Network%20diagram.png)

## Required Components
### Network Bridges
- Bridge 0 (`br0`)
- Bridge 1 (`br1`)

### Network Namespaces
- Namespace 1 (`ns1`) - connected to `br0`
- Namespace 2 (`ns2`) - connected to `br1`
- Router namespace (`router-ns`) - connects both bridges

📌📌 **Please note that I am writing this documentation using manual commands. 
If you want, you can check my manual script [here](Assignment%201/Automated_Script.sh).**


#### ✅ Tasks  
##### **1. Create Network Bridges**

Run the following commands:  
```
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip link add br1 type bridge
sudo ip link set br1 up
```
##### **2. Create Network Namespaces**
Run the following commands:  
```
sudo ip netns add ns0
sudo ip netns add ns1
sudo ip netns add router-ns
```
## **3.⁠ ⁠Create Virtual Interfaces and Connections**  
###### **3.1 Create appropriate virtual ethernet (veth) pairs** 
Run the following commands:  
```
sudo ip link add veth-ns0 type veth peer name veth-br0
sudo ip link add veth-ns1 type veth peer name veth-br1
sudo ip link add veth-rt1 type veth peer name br0-rt
sudo ip link add veth-rt2 type veth peer name br1-rt
```
###### **3.2 Connect interfaces to correct namespaces** 
Run the following commands:
```
sudo ip link set veth-ns0 netns ns0
sudo ip link set veth-ns1 netns ns1
sudo ip link set veth-rt1 netns router-ns
sudo ip link set veth-rt2 netns router-ns
```
###### **3.3 Connect interfaces to appropriate bridges** 
Run the following commands:
```
sudo ip link set veth-br0 master br0
sudo ip link set br0-rt master br0
sudo ip link set veth-br1 master br1
sudo ip link set br1-rt master br1
```
## **4.Configure IP Addresses**  
###### **4.1 Assign appropriate IP addresses to all interfacesns** 
Run the following commands:  
```
sudo ip netns exec ns0 ip addr add 10.11.2.6/24 dev veth-ns0
sudo ip netns exec ns1 ip addr add 10.11.3.7/24 dev veth-ns1
sudo ip netns exec router-ns ip addr add 10.11.2.4/24 dev veth-rt1
sudo ip netns exec router-ns ip addr add 10.11.3.5/24 dev veth-rt2
```
###### **4.2 Ensure proper subnet configuration** 
Run the following commands:  
```
sudo ip netns exec ns0 ip link set veth-ns0 up
sudo ip netns exec ns1 ip link set veth-ns1 up
sudo ip netns exec router-ns ip link set veth-rt1 up
sudo ip netns exec router-ns ip link set veth-rt2 up

sudo ip link set veth-br0 up
sudo ip link set veth-br1 up
sudo ip link set br0-rt up
sudo ip link set br1-rt up

sudo ip addr add 10.11.2.2/24 dev br0
sudo ip addr add 10.11.3.2/24 dev br0
```
## **5.Set Up Routing**  
###### **5.1 Configure routing between namespaces** 
Run the following commands:  
```
sudo ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1
```
###### **5.2 Enable IP forwarding where necessary** 
Run the following commands:  
```
sudo iptables --append FORWARD --in-interface br0 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br0 --jump ACCEPT

sudo iptables --append FORWARD --in-interface br1 --jump ACCEPT
sudo iptables --append FORWARD --out-interface br1 --jump ACCEPT
```

###### **5.3 Establish default routes** 
Run the following commands:  
```
sudo ip netns exec ns0 ip route add default via 10.11.2.4
sudo ip netns exec ns1 ip route add default via 10.11.3.5
```

## **6. Enable and Test Connectivity**  
Run the following commands:  
```
sudo ip netns exec ns0 ping 10.11.3.7 -c 4
sudo ip netns exec ns1 ping 10.11.2.6 -c 4
```

## Output of Manual Ping 
![Manual Ping Output](Assignment%201/Manual%20ping%20output.png)

## Output of Automated Script Linux Network Namespace Simulation
![Network Simulation Output](Assignment%201/Linux%20Namespace%20Simulation%20Output.png)