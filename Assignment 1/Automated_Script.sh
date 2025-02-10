#!/bin/bash

declare -A bridges_ip=(
	[br0]="10.11.2.2/24"
	[br1]="10.11.3.2/24")
	
declare -A namespaces_ip=(
    [ns0]="10.11.2.6/24,10.11.2.4"  # IP/Mask, Gateway
    [ns1]="10.11.3.7/24,10.11.3.5"
    [router-ns]="" # Router has interfaces, not a direct IP
)

declare -A interfaces=(
    [ns0,br0]="veth-ns0,veth-br0"
    [router-ns,br0]="veth-rt1,br0-rt"
    [ns1,br1]="veth-ns1,veth-br1"
    [router-ns,br1]="veth-rt2,br1-rt"
)

declare -A router_ns_veth_ip=(
    [veth-rt1]="router-ns 10.11.2.4/24"
    [veth-rt2]="router-ns 10.11.3.5/24"
)

# Cleanup function - Improved to handle potential errors gracefully
cleanup() {
    echo "Cleaning up existing resources..."

	# Extract bridge names dynamically
	bridge_names=$(echo "${!bridges_ip[@]}" | tr ' ' '|')

	# Collect line numbers into an array
	mapfile -t forward_rules < <(sudo iptables -L FORWARD --line-number -n -v | grep -E "$bridge_names" | awk '{print $1}')

	# Delete rules using line numbers (from highest to lowest)
	for ((i=${#forward_rules[@]}-1; i>=0; i--)); do
		sudo iptables -D FORWARD ${forward_rules[i]}
		echo "Deleted rule at line ${forward_rules[i]}"
	done

    # Delete veth interfaces
    for key in "${!interfaces[@]}"; do
        IFS=',' read -r ns iface <<< "$key"
        IFS=',' read -r veth1 veth2 <<< "${interfaces[$key]}"
        
        echo "Deleting interfaces $veth1 and $veth2..."
        sudo ip link del "$veth1" 2>/dev/null
        sudo ip link del "$veth2" 2>/dev/null
    done

    # Delete bridges
    for br in "${!bridges_ip[@]}"; do
        echo "Deleting bridge $br..."
        sudo ip link del "$br" 2>/dev/null
    done

    # Delete namespaces
    for ns in "${!namespaces_ip[@]}"; do
        echo "Deleting namespace $ns..."
        sudo ip netns del "$ns" 2>/dev/null
    done
}

cleanup

# Function to create and configure a bridge
create_bridge(){
	local bridge_name="$1"
	local bridge_ip="$2"
	
	sudo ip link add "$bridge_name" type bridge
	sudo ip link set "$bridge_name" up
	sudo ip addr add "$bridge_ip" dev "$bridge_name"
	
	sudo iptables --append FORWARD --in-interface "$bridge_name" --jump ACCEPT
	sudo iptables --append FORWARD --out-interface "$bridge_name" --jump ACCEPT
	
	echo "Bridge $bridge_name created and configured."
}
# Function Bridge Verify
verify_bridge(){
    local bridge_name="$1"
    
    if sudo ip link show | grep -qw "$bridge_name"; then
        echo "Bridge $bridge_name exists."
    else
        echo "Bridge $bridge_name was not created successfully."
        exit 1
    fi
}

# Function to create and configure a namespace
create_ns(){
	local ns_name="$1"
	
	sudo ip netns add "$ns_name"
	echo "Namespace $ns_name created."
}

# Function Namespace Verify
verify_ns(){
    local ns_name="$1"
    
    if sudo ip netns list | grep -qw "$ns_name"; then
        echo "Namespace $ns_name exists."
    else
        echo "Namespace $ns_name was not created successfully."
        exit 1
    fi
}

#Function configure router-ns veth ip addr
configure_router_ns_ip(){
	local ns_name="$1"
	local veth_name="$2"
	local veth_ip="$3"
	
	sudo ip netns exec "$ns_name" ip addr add "$veth_ip" dev "$veth_name"
	
	echo "$ns_name $veth_name $veth_ip addr configure"
}

# Function to create veth pairs and connect them to bridges and namespaces
create_vath_pair(){
	local ns="$1"
	local bridge="$2"
	local veth_ns_name="$3"
	local veth_br_name="$4"
	local cmd="sudo ip link"
	
	$cmd add "$veth_ns_name" type veth peer name "$veth_br_name" 
	$cmd set "$veth_ns_name" netns "$ns" 
	$cmd set "$veth_br_name" master "$bridge"
	
	sudo ip netns exec "$ns" ip link set "$veth_ns_name" up
	$cmd set "$veth_br_name" up
	
	echo "Veth pair $veth_ns_name/$veth_br_name created and connected."
}

# Function to configure IP address and default gateway within a namespace
configure_namespace_ip(){
	local ns="$1"
	local ip_addr="$2"
	local gateway="$3"
	local veth_name="$4"
	
	sudo ip netns exec "$ns" ip addr add "$ip_addr" dev "$veth_name"
	if [[ -n "$gateway" ]]; then
		sudo ip netns exec "$ns" ip route add default via "$gateway"
	fi
	
	echo "IP configuration for namespace $ns complete."
}

# Create Bridges
for br in "${!bridges_ip[@]}"; do
	create_bridge "$br" "${bridges_ip[$br]}"
    verify_bridge "$br"
done

# Create Namespaces
for ns in "${!namespaces_ip[@]}"; do
	create_ns "$ns"
	verify_ns "$ns"
done

# Create and Connect Veth Pairs
for iface in "${!interfaces[@]}"; do
	IFS=',' read -r ns bridge <<< "$iface"
	IFS=',' read -r veth1 veth2 <<< "${interfaces[$iface]}"
	create_vath_pair "$ns" "$bridge" "$veth1" "$veth2"
done

# Extract all bridge names dynamically, but only for namespaces with a gateway
declare -A bridge_map
for ns in "${!namespaces_ip[@]}"; do
    IFS=',' read -r _ gateway <<< "${namespaces_ip[$ns]}"
    
    # Only include namespaces that have a gateway
    if [[ -n "$gateway" ]]; then
        for key in "${!interfaces[@]}"; do
            if [[ "$key" == "$ns,"* ]]; then
                br="${key##*,}"   # Extract bridge name
                bridge_map["$ns"]="$br"
            fi
        done
    fi
done

# Configure IP Addresses and Gateways in Namespaces
for ns_name in "${!bridge_map[@]}"; do
    IFS=',' read -r ip_mask gateway <<< "${namespaces_ip[$ns_name]}"
    
    bridge_name="${bridge_map[$ns_name]}"
    IFS=',' read -r veth_name _ <<< "${interfaces[$ns_name,$bridge_name]}"
    configure_namespace_ip "$ns_name" "$ip_mask" "$gateway" "$veth_name"
done

for veth_name in "${!router_ns_veth_ip[@]}"; do
    IFS=" " read -r ns veth_ip <<< "${router_ns_veth_ip[$veth_name]}"
	configure_router_ns_ip "$ns" "$veth_name" "$veth_ip"
done

# Enable IP Forwarding in Router Namespace
sudo ip netns exec router-ns sysctl -w net.ipv4.ip_forward=1


# Ping test function
echo
echo

for ns in "${!namespaces_ip[@]}"; do
echo "----------ping test from "$ns"-------------"
    # Extract IP and Gateway for the namespace
    IFS=',' read -r ip gateway <<< "${namespaces_ip[$ns]}"
    
    # Remove the subnet mask (e.g., /24) from the IP
    #ip_only="${ip%%/*}"
    
    # Skip namespaces with no gateway (router-ns in this case)
    if [[ -n "$gateway" ]]; then
        # Ping test from ns to other namespaces
        for target_ns in "${!namespaces_ip[@]}"; do
            if [[ "$ns" != "$target_ns" ]]; then
                # Extract target IP and remove subnet mask
                IFS=',' read -r target_ip _ <<< "${namespaces_ip[$target_ns]}"
                target_ip_only="${target_ip%%/*}"
                
                # Skip empty IP for router-ns
                if [[ -z "$target_ip_only" ]]; then
                    echo "Skipping ping to $target_ns as no valid IP is set."
                    continue
                fi
                
                # Execute ping from $ns to $target_ip_only
                echo "Pinging from $ns ($ip_only) to $target_ns ($target_ip_only)"
                sudo ip netns exec "$ns" ping -c 4 "$target_ip_only"
				echo
                echo "---------------------------------------------"
				echo
            fi
        done
    fi
done