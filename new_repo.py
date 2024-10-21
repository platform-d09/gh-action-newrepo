#!/usr/bin/env python

import json
import os
from os import environ

from cookiecutter.main import cookiecutter
from git import Repo
from github import Github
from github.Auth import Token
from github.Repository import Repository


class ActionEnvironment:
    def __init__(self):
        self.github_token = environ.get('INPUT_TOKEN')
        self.repository_name = environ.get('INPUT_REPO_NAME')
        self.org_name = environ.get('INPUT_ORG_NAME')
        self.cookie_cutter_template = environ.get('INPUT_COOKIECUTTER_TEMPLATE')
        self.template_directory = environ.get('INPUT_TEMPLATEDIRECTORY')
        self.monorepo_url = environ.get('INPUT_MONOREPOURL')
        self.scaffold_directory = environ.get('INPUT_SCAFFOLDDIRECTORY')
        self.branch_name = "scaffold_" + self.repository_name
        self.git_url = environ.get('INPUT_GITHUB_URL')
        self.user_inputs = environ.get('INPUT_USER_INPUTS')
        self.visibility = environ.get('INPUT_VISIBILITY')


class RepoBuilder:
    def __init__(self, environment: ActionEnvironment):
        self.environment = environment
        self.github = Github(auth=Token(self.environment.github_token))

    def create_repo(self) -> Repository:
        org = self.github.get_organization(self.environment.org_name)
        repo = org.create_repo(
            name=self.environment.repository_name,
            private=self.environment.visibility == 'private',
            visibility=self.environment.visibility,
            has_wiki=True,
            has_projects=True,
            has_issues=True
        )
        return repo

    def clone_repo(self):
        pass

    def create_branch(self):
        pass

    def commit_changes(self):
        pass

    def push_changes(self):
        pass

    def create_pull_request(self):
        pass

    def create_repo_from_template(self):
        pass

    def create_monorepo(self):
        pass

    def create_scaffold(self):
        pass

    def apply_cookiecutter_template(self):
        user_inputs = self.environment.user_inputs.replace('cookiecutter_', '')
        user_inputs = json.loads(user_inputs)
        return cookiecutter(
            template=self.environment.cookie_cutter_template,
            no_input=True,
            extra_context={**user_inputs,
                'default_context': {
                    'full_name': 'GitHub Actions Bot',
                    'email': 'github-actions[bot]@users.noreply.github.com',
                    'github_username': 'github-actions[bot]',
                }},
            output_dir='dist')


def main(environment: ActionEnvironment):
    os.system('git config --global user.email "github-actions[bot]@users.noreply.github.com"')
    os.system('git config --global user.name "GitHub Actions Bot"')
    os.system(f'git config --global init.defaultBranch main')
    builder = RepoBuilder(environment)
    repo = builder.create_repo()
    print(f"Repository created at {repo.html_url}")
    generated_repo_path = builder.apply_cookiecutter_template()
    print(f"Cookiecutter template applied to {generated_repo_path}")
    git_repo = Repo(generated_repo_path + '/.git')

    git_repo.create_remote('origin',
                           url=f'https://oauth2:{builder.environment.github_token}@github.com/{builder.environment.org_name}/{builder.environment.repository_name}.git')
    git_repo.config_writer().set_value('user', 'name', 'GitHub Actions Bot').release()
    git_repo.config_writer().set_value('user', 'email', 'github-actions[bot]@users.noreply.github.com').release()
    git_repo.git.add(all=True)
    git_repo.git.commit(message='Initial commit after scaffolding')
    git_repo.git.branch('-M', 'main')
    git_repo.git.push('-u', 'origin', 'main')
    print("Changes pushed to repository")
    # if os.path.exists('dist/.git') and os.path.isdir('dist/.git'):
    #     shutil.rmtree('dist/.git')

    # elem_list = []
    # for i in glob.iglob('dist/**',recursive=True,include_hidden=True):
    #     if os.path.isdir(i):
    #         continue
    #     else:
    #         file_content = open(i, 'r').read()
    #         file_path = i.removeprefix('dist/')
    #         blob = repo.create_git_blob(content=file_content, encoding='utf-8')
    #         tree_element = InputGitTreeElement(path=file_path,mode='100644', type='blob', sha=blob.sha)
    #         elem_list.append(tree_element)
    # new_tree = repo.create_git_tree(tree=elem_list,base_tree=repo.get_git_tree(repo.get_git_ref('heads/main').object.sha))
    # new_tree.


if __name__ == '__main__':
    try:
        main(ActionEnvironment())
        exit(0)
    except Exception as e:
        print(f"An error occurred: {e}")
        exit(1)
