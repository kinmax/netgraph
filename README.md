# NetGraph

NetGraph is a Ruby script that allows you to generate a visual representation for a network topology.

NetGraph takes a network topology description file and converts it into a ```.gv``` file. This file can then be used with Graphviz's embedded application Dot to generate a graph representation of the network topology in any Dot available format, such as PDF, SVG, PNG, PostScript and others. For more information on available formats and options, check Dot official documentation (https://graphviz.gitlab.io/_pages/pdf/dotguide.pdf).

## Using NetGraph

In order to use NetGraph, you must first make sure you have Ruby installed on your system. Check https://www.ruby-lang.org/pt/documentation/installation/#homebrew for system-specific installation instructions.

Once you have Ruby installed and set on your environment variables, you can run NetGraph by executing a line command in the following format (assuming you have the file ```netgraph.rb``` in your current working directory):

```
ruby netgraph.rb <input_txt_file_path> <output_gv_file_path>
```

## Network Topology Description File

The input network topology description file must be a text file in the following format:

```
#NODE
<node_name>,<MAC>,<IP/prefix>,<MTU>,<gateway>
#ROUTER
<router_name>,<num_ports>,<MAC0>,<IP0/prefix>,<MTU0>,<MAC1>,<IP1/prefix>,<MTU1>,<MAC2>,<IP2/prefix>,<MTU2> …
#ROUTERTABLE
<router_name>,<net_dest/prefix>,<nexthop>,<port>
```

An example is presented below:

```
#NODE
n1,00:00:00:00:00:01,192.168.0.2/24,5,192.168.0.1
n2,00:00:00:00:00:02,192.168.0.3/24,5,192.168.0.1
n3,00:00:00:00:00:03,192.168.1.2/24,5,192.168.1.1
n4,00:00:00:00:00:04,192.168.1.3/24,5,192.168.1.1
#ROUTER
r1,2,00:00:00:00:00:05,192.168.0.1/24,5,00:00:00:00:00:06,192.168.1.1/24,5
#ROUTERTABLE
r1,192.168.0.0/24,0.0.0.0,0
r1,192.168.1.0/24,0.0.0.0,1
```

## Generating the Visual Representation

After the ```.gv``` output file has been correctly generated, you can then use it in association with Graphviz's Dot to generate the visual representation. To do so, you must first have Graphviz installed in your system. For system-specific information on Graphviz information, check https://www.graphviz.org/download/.

With the ```.gv``` output file and Graphviz installed, you can easily generate the visualization file. 

Let's assume you have used NetGraph to generate a ```.gv``` file called ```test.gv```. You could easily generate a corresponding PDF file by entering the command below:

```
dot -Tpdf test.gv -o test.pdf
```

The ```-T``` parameter specifies the output format. In the example I used PDF, but other formats are supported (check https://graphviz.gitlab.io/_pages/pdf/dotguide.pdf).

After the command has run, you will have a visual representation in PDF of the network topology described in the text file.

## Understanding the Visual Representation

In the visual representation, it is possible to see every aspect of the described topology, but first, it is important to understand what nodes and edges mean in the generated view.

Nodes are represented by boxes, and hold information about the node's name, IP address, MAC address and default gateway's IP address.

Routers are represented by empty circles, and hold information about the router's name.

Router ports are represented by hexagons, and hold information about the port's number, IP address and MAC address.

Router tables are represented by the tables in the diagram, and hold the following information for each table entry: IP address, CIDR, next hop and router port.

Routers are connected to their ports by blue edges, and to their router tables by red edges. Nodes and router ports residing within the same network are connected by black edges, which are labeled with the device's MTU. The black edges that represet the connection between devices residing within the same network connect each device to a black filled circle, which represents the interconnection device for that network (a switch or a hub for example). An example is shown below:

![Alt text](test1.pdf?raw=true "Topology Visual Representation")
