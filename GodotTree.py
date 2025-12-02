import re
import os

def parse_tscn(file_path):
    with open(file_path, "r", encoding="utf-8") as f:
        lines = f.readlines()

    # Parse ExtResources
    ext_resources = {}
    for line in lines:
        if line.strip().startswith('[ext_resource'):
            attributes = re.findall(r'(\w+)="([^"]+)"', line)
            attr_dict = dict(attributes)
            resource_id = attr_dict.get('id') or attr_dict.get('uid')
            path = attr_dict.get('path')
            resource_type = attr_dict.get('type')
            if resource_id and path:
                ext_resources[resource_id] = {
                    "path": path,
                    "type": resource_type
                }

    # Parse Nodes
    nodes = []
    current_node = None
    
    for i, line in enumerate(lines):
        line = line.strip()
        
        if line.startswith('[node'):
            if current_node:
                nodes.append(current_node)
            
            name_match = re.search(r'name="([^"]+)"', line)
            type_match = re.search(r'type="([^"]+)"', line)
            parent_match = re.search(r'parent="([^"]+)"', line)
            
            name = name_match.group(1) if name_match else "?"
            node_type = type_match.group(1) if type_match else "?"
            parent = parent_match.group(1) if parent_match else "."
            
            current_node = {
                "name": name, 
                "type": node_type, 
                "parent": parent,
                "script": None,
                "instance": None
            }
            
            # Cek instance di line yang sama dengan node header
            if 'instance=ExtResource' in line:
                instance_match = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
                if instance_match:
                    resource_id = instance_match.group(1)
                    if resource_id in ext_resources:
                        current_node["instance"] = ext_resources[resource_id]["path"]
        
        elif current_node and line.startswith('script = ExtResource'):
            script_match = re.search(r'ExtResource\("([^"]+)"\)', line)
            if script_match:
                resource_id = script_match.group(1)
                if resource_id in ext_resources:
                    current_node["script"] = ext_resources[resource_id]["path"]
        
        elif current_node and line.startswith('instance=ExtResource'):
            # Juga cek instance di line terpisah
            instance_match = re.search(r'instance=ExtResource\("([^"]+)"\)', line)
            if instance_match:
                resource_id = instance_match.group(1)
                if resource_id in ext_resources:
                    current_node["instance"] = ext_resources[resource_id]["path"]
    
    if current_node:
        nodes.append(current_node)
    
    return nodes

def build_tree(nodes):
    node_dict = {}
    for node in nodes:
        node_dict[node["name"]] = {
            "name": node["name"],
            "type": node["type"], 
            "script": node["script"],
            "instance": node["instance"],
            "children": []
        }
    
    root_nodes = []
    for node in nodes:
        parent_name = node["parent"]
        current_name = node["name"]
        
        if parent_name == "." or parent_name == "" or parent_name not in node_dict:
            root_nodes.append(node_dict[current_name])
        else:
            if parent_name in node_dict:
                node_dict[parent_name]["children"].append(node_dict[current_name])
    
    return root_nodes

def print_tree(nodes, indent="", is_last=True):
    if not nodes:
        return
        
    for i, node in enumerate(nodes):
        is_last_node = i == len(nodes) - 1
        
        # Untuk level paling atas (root), semua pakai prefix kecuali yang pertama
        if indent == "":  # Ini adalah level root
            if i == 0:
                # Node pertama tanpa prefix
                prefix = ""
            else:
                # Node root lainnya pakai prefix normal
                prefix = "└── " if is_last_node else "├── "
        else:
            # Untuk child nodes, pakai prefix normal
            prefix = "└── " if is_last_node else "├── "
        
        node_info = f"{node['type']} ({node['name']})"
        
        # Tambahkan info script atau instance
        extra_info = []
        if node['script']:
            script_name = os.path.basename(node['script'])
            extra_info.append(f"⬅️ {script_name}")
        if node['instance']:
            instance_name = os.path.basename(node['instance'])
            extra_info.append(f"⬅️ {instance_name}")
        
        if extra_info:
            node_info += " " + " ".join(extra_info)
        
        print(f"{indent}{prefix}{node_info}")
        
        new_indent = indent + ("    " if is_last_node else "│   ")
        if node['children']:
            print_tree(node['children'], new_indent)

# ==== Ganti path ====
file_path = r"C:\sawit\Oil-Palm-Godot-main"

if os.path.exists(file_path):
    nodes = parse_tscn(file_path)
    
    if nodes:
        root_nodes = build_tree(nodes)
        file_name = os.path.basename(file_path)
        print(f"Scene Structure: {file_name}")
        print_tree(root_nodes)
    else:
        print("No nodes found!")
else:
    print(f"File not found: {file_path}")