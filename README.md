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

## Output of Linux Network Namespace Simulation
![Network Simulation Output](Assignment%201/Linux%20Namespace%20Simulation%20Output.png)
