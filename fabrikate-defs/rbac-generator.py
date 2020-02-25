from pathlib import Path
import sys
import yaml
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
            for user in working_cluster.get('users', []):
                username = ''.join(user['name'].split(' ')).lower()
                user_template = env.get_template('user.tmpl')
                output = p / f'{username}.yaml'
                output.write_text(user_template.render(name=username, 
                                                       email=user['email'],
                                                       id=user['id']))
            for group in working_cluster.get('groups', []):
                pass
            for app in working_cluster.get('apps', []):
                    pass

