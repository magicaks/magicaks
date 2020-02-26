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
            for user in working_cluster.get('users', []):
                username = ''.join(user['name'].split(' ')).lower()
                email = user['email'].replace('@', 'AT').replace('.', 'DOT')
                user_template = env.get_template('user.tmpl')
                output = p / f'{username}.yaml'
                output.write_text(user_template.render(name=username, 
                                                       email=email,
                                                       id=user['id']))
            
            for app in working_cluster.get('apps', []):
                app_template = env.get_template('app.tmpl')
                app_name = app['name']
                output = p / f'{app_name}.yaml'
                output.write_text(app_template.render(app_name=app_name))

                # for each app give groups read access.            
                for group in working_cluster.get('groups', []):
                    group_template = env.get_template('groups.tmpl')
                    group_id = group['id']
                    group_name = group['name']
                    output = p / f'{group_name}.yaml'
                    output.write_text(group_template.render(app_name=app_name, group_name=group_name, group_id=group_id))
