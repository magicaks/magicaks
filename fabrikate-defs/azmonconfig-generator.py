import sys
import yaml
from pathlib import Path
from jinja2 import Environment, FileSystemLoader

FAB_ENV = sys.argv[1]
generated_folder = sys.argv[2]

p = Path(generated_folder) / 'generated' / FAB_ENV

template_dir = 'rbac-templates'
env = Environment(
    loader=FileSystemLoader(template_dir),
)

with open('users.yaml') as f:
    rbac_config = yaml.safe_load(f)
    clusters = rbac_config['clusters']
    for cluster in clusters:
        if FAB_ENV in cluster.keys():
            working_cluster = cluster[FAB_ENV]
            namespaces = ['"kube-system"']
            for user in working_cluster.get('users', []):
                username = ''.join(user['name'].split(' ')).lower()
                namespaces.append(f'"{username}"') # each user has a namespace
            
            apps = []
            for app in working_cluster.get('apps', []):
                app_name = app['name']
                apps.append(f'"{app_name}"')
            azmonitor_template = env.get_template('azmonitor.tmpl')
            output = p / 'azmonitor.yaml'
            output.write_text(azmonitor_template.render(namespaces=",".join(namespaces), 
                                                        app_names_csv=",".join(apps)))
