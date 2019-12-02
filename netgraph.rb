class Node
    attr_reader :name, :mac, :ip, :cidr, :mtu, :default_gateway

    VALID_STATUSES = %w(NONE WAITING_ARP_REPLY WAITING_ECHO_REPLY)

    def initialize(name, mac, ip, cidr, mtu, default_gateway)
        @name = name
        @mac = mac
        @ip = ip
        @cidr = cidr
        @mtu = mtu
        @default_gateway = default_gateway
    end

    def add_nodes(nodes)
        @nodes = nodes
    end

    def add_routers(routers)
        @routers = routers
    end

    def same_network?(device)
        binary_full_ip = ""
        split_ip = @ip.split(".")
        split_ip.each do |octet|
            binary_full_ip += "%.8b" % octet.to_i
        end
        binary_device_full_ip = ""
        split_ip = device.ip.split(".")
        split_ip.each do |octet|
            binary_device_full_ip += "%.8b" % octet.to_i
        end
        if binary_full_ip[0...@cidr] == binary_device_full_ip[0...@cidr]
            return true
        end
        false
    end

    def devices_on_same_net
        devices = []
        @nodes.each do |node|
            devices << node if same_network?(node) && node.ip != @ip
        end
        @routers.each do |router|
            router.ports.each do |port|
                devices << port if same_network?(port) && port.ip != @ip
            end
        end
        devices
    end    
end

class Router
    attr_reader :name, :router_table, :ports

    def initialize(name, ports)
        @name = name
        @router_table = RouterTable.new
        @ports = ports
    end

    def same_network?(ip1, ip2, cidr)
        binary_full_ip = ""
        split_ip = ip1.split(".")
        split_ip.each do |octet|
            binary_full_ip += "%.8b" % octet.to_i
        end
        binary_device_full_ip = ""
        split_ip = ip2.split(".")
        split_ip.each do |octet|
            binary_device_full_ip += "%.8b" % octet.to_i
        end
        if binary_full_ip[0...cidr] == binary_device_full_ip[0...cidr]
            return true
        end
        false
    end

    def add_entry_to_router_table(cidr, dest_ip, next_hop, port)
        @router_table.add_entry(cidr, dest_ip, next_hop, port)
    end

    def add_entry_to_arp_table(ip, mac)
        @arp_table.add_entry(ip, mac)
    end
end

class RouterPort
    attr_reader :mac, :ip, :cidr, :mtu, :name, :router

    def initialize(mac, ip, cidr, mtu, name)
        @mac = mac
        @ip = ip
        @cidr = cidr
        @mtu = mtu
        @name = name
    end

    def define_router(router)
        @router = router
    end

    def add_nodes(nodes)
        @nodes = nodes
    end

    def add_routers(routers)
        @routers = routers
    end

    def same_network?(device)
        binary_full_ip = ""
        split_ip = @ip.split(".")
        split_ip.each do |octet|
            binary_full_ip += "%.8b" % octet.to_i
        end
        binary_device_full_ip = ""
        split_ip = device.ip.split(".")
        split_ip.each do |octet|
            binary_device_full_ip += "%.8b" % octet.to_i
        end
        if binary_full_ip[0...@cidr] == binary_device_full_ip[0...@cidr]
            return true
        end
        false
    end

    def devices_on_same_net
        devices = []
        @nodes.each do |node|
            devices << node if same_network?(node) && node.ip != @ip
        end
        @routers.each do |router|
            router.ports.each do |port|
                devices << port if same_network?(port) && port.ip != @ip
            end
        end
        devices
    end
end

class RouterTable
    attr_reader :entries

    def initialize
        @entries = []
    end

    def add_entry(cidr, ip, next_hop, port)
        new_entry = RouterTableEntry.new(cidr, ip, next_hop, port)
        @entries << new_entry
    end
end

class RouterTableEntry
    attr_reader :cidr, :ip, :next_hop, :port

    def initialize(cidr, ip, next_hop, port)
        @cidr = cidr
        @ip = ip
        @next_hop = next_hop
        @port = port
    end
end

if ARGV.length < 2
    puts "[ERROR] Wrong usage.\nCorrect usage: ruby netgraph.rb <topology_file_path> <graphviz_file_path>"
    exit
end

topology_file_path = ARGV[0]
gv_file_path = ARGV[1]


begin
    topology_file = File.open(topology_file_path, "r")
    topology = topology_file.read
    topology_file.close
    topology.gsub!("\r\n", "\n")
    topology.gsub!("\r", "\n")
rescue Exception => e
    puts "[ERROR] Error while opening topology file. Check if file path is correct and try again."
    exit
end

begin

    nodes_string = topology.split("#NODE")[1]
    routers_string = topology.split("#ROUTER")[1]
    router_tables_string = topology.split("#ROUTERTABLE")[1]

    routers = []
    routers_string = routers_string.split("\n")
    routers_string.each do |router_string|
        next if router_string.empty?
        break if router_string == "#ROUTERTABLE"
        info = router_string.split(",")
        router_name = info[0]
        number_of_ports = info[1].to_i
        router_ports_string = info[2..info.length]
        router_ports = []
        router_ports_array = router_ports_string.each_slice(3).to_a
        router_ports_array.each do |router_port_array|
            router_port = RouterPort.new(router_port_array[0],router_port_array[1].split("/")[0], router_port_array[1].split("/")[1].to_i, router_port_array[2].to_i, router_name)
            router_ports << router_port
        end
        router = Router.new(router_name, router_ports)
        router.ports.each do |port|
            port.define_router(router)
        end
        routers << router
    end

    router_tables_string = router_tables_string.split("\n")
    router_tables_hash = {}
    router_tables_string.each do |router_table_string|
        next if router_table_string.empty?
        router_name = router_table_string.split(",")[0]
        net_dest = router_table_string.split(",")[1].split("/")[0]
        prefix = router_table_string.split(",")[1].split("/")[1].to_i
        next_hop = router_table_string.split(",")[2]
        port = router_table_string.split(",")[3].to_i
        routers.each do |router|
            if router.name == router_name
                router.add_entry_to_router_table(prefix, net_dest, next_hop, port)
                break
            end
        end
    end

    nodes = [] 
    nodes_string = nodes_string.split("\n")
    nodes_string.each do |node_string|
        next if node_string.empty?
        break if node_string == "#ROUTER"
        info = node_string.split(",")
        node_name = info[0]
        node_mac = info[1]
        node_ip = info[2]
        node_ip = node_ip.split("/")[0]
        node_cidr = info[2].split("/")[1].to_i
        node_mtu = info[3].to_i
        node_default_gateway = nil
        routers.each do |router|
            router.ports.each do |port|
                if port.ip == info[4]
                    node_default_gateway = port
                end
            end
        end
        raise Exception if node_default_gateway.nil?
        node = Node.new(node_name, node_mac, node_ip, node_cidr, node_mtu, node_default_gateway)
        nodes << node
    end

    nodes.each do |node|
        node.add_nodes(nodes)
        node.add_routers(routers)
    end
    
    routers.each do |router|
        router.ports.each do |port|
            port.add_nodes(nodes)
            port.add_routers(routers)
        end
    end
rescue Exception => e
    puts e.backtrace
    puts e.message
    puts "[ERROR] Incorrect topology file format."
    exit
end

gv_code = ""

gv_code += "graph NetworkTopology {\n"
gv_code += "ranksep = 10;\n"
gv_code += "node [shape=box, fontsize=34, fontname=\"Arial\"];\n"
nodes.each_with_index do |node, index|
    gv_code += "node#{index} [label=\"#{node.name}\\n#{node.ip}\\n#{node.mac}\\nDG: #{node.default_gateway.ip}\"];\n"
end
gv_code += "node [shape=hexagon];"
routers.each_with_index do |router, r_index|
    router.ports.each_with_index do |port, p_index| 
        gv_code += "router#{r_index}port#{p_index} [label=\"Port #{p_index}\\n#{port.ip}\\n#{port.mac}\"];\n"
    end
end
gv_code += "node [shape=record];\n"

ips = []
cidrs = []
nexthops = []
outports = []

routers.each_with_index do |router, index|
    router.router_table.entries.each do |entry|
        ips << entry.ip
        cidrs << entry.cidr
        nexthops << entry.next_hop
        outports << entry.port
    end
    gv_code += "routertable#{index} [label=\""
    ips.each_with_index do |ip, i|
        if i == 0
            gv_code += "{IP | #{ip} | "
        elsif i == ips.length-1
            gv_code +=  "#{ip}} | "
        else
            gv_code +=  "#{ip} | "
        end
    end
    cidrs.each_with_index do |cidr, i|
        if i == 0
            gv_code += "{CIDR | #{cidr} | "
        elsif i == cidrs.length-1
            gv_code +=  "#{cidr}} | "
        else
            gv_code +=  "#{cidr} | "
        end
    end
    nexthops.each_with_index do |nexthop, i|
        if i == 0
            gv_code += "{NEXT HOP | #{nexthop} | "
        elsif i == nexthops.length-1
            gv_code +=  "#{nexthop}} | "
        else
            gv_code +=  "#{nexthop} | "
        end
    end
    outports.each_with_index do |outport, i|
        if i == 0
            gv_code += "{PORT | #{outport} | "
        elsif i == outports.length-1
            gv_code +=  "#{outport}}\"];\n"
        else
            gv_code +=  "#{outport} | "
        end
    end
    ips = []
    cidrs = []
    nexthops = []
    outports = []
end

gv_code += "node [shape=circle, width=2.5, fontsize=45];\n"
routers.each_with_index do |router, index|
    gv_code += "router#{index} [label =\"#{router.name}\"];\n"
end

nets = []
if nodes.size > 0
    net = nodes[0].devices_on_same_net
    net << nodes[0]
    nets << net
end
nodes.each do |node|
    in_a_net = false
    nets.each do |net|
        if net.include?(node)
            in_a_net = true
        end
    end
    if !in_a_net
        net = node.devices_on_same_net
        net << node
        nets << net
    end
end
routers.each do |router|
    router.ports.each do |port|
        in_a_net = false
        nets.each do |net|
            if net.include?(port)
                in_a_net = true
            end
        end
        if !in_a_net
            net = port.devices_on_same_net
            net << port
            nets << net
        end
    end
end
gv_code += "node [shape=circle,style=filled,width=1,color=\"black\",fontsize=5];\n"
nets.each_with_index do |net, index|
    gv_code += "net#{index};\n"
end
gv_code += "\n\n"
gv_code += "edge [fontname=\"Arial\", fontsize=35, style=bold]"
nets.each_with_index do |net, index|
    net.each do |device|
        if device.is_a?(Node)
            gv_code += "net#{index} -- node#{nodes.index(device)} [label=\"#{device.mtu}\"];\n"
        else
            gv_code += "net#{index} -- router#{routers.index(device.router)}port#{device.router.ports.index(device)} [label=\"#{device.mtu}\"];\n"
        end
    end
end

routers.each_with_index do |router, r_index|
    router.ports.each_with_index do |port, p_index|
        gv_code += "router#{r_index} -- router#{r_index}port#{p_index} [color = \"blue\"];\n"
    end
    gv_code += "router#{r_index} -- routertable#{r_index} [color = \"red\"];\n"
end
gv_code += "}\n"

gv_file = File.open(gv_file_path, "w")
gv_file.write(gv_code)
gv_file.close
