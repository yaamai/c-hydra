TAG_PATTERN = "${DRONE_TAG:-${DRONE_COMMIT_SHA:0:7}}"
TARGET_ARCH_LIST = ["amd64", "arm64"]
REPO_LIST = ["hydra", "hydra-maester"]

def main(ctx):
  pipeline_list = []
  for repo in REPO_LIST:
    for arch in TARGET_ARCH_LIST:
      pipeline_list.extend([image_build(ctx, repo, arch)])
    pipeline_list.extend([docker_manifest(ctx, repo)])
  return pipeline_list

def image_build(ctx, repo, arch):
  return {
    "kind": "pipeline",
    "type": "docker",
    "name": "%s-%s" % (repo, arch),
    "platform": {
      "arch": arch
    },
    "steps": [
      {
        "name": "submodules",
        "image": "yaamai/alpine-git:20200913",
        "commands": [
          "git submodule update --init --recursive --remote"
        ]
      },
      {
        "name": "image-build",
        "image": "plugins/docker",
        "settings": {
          "username": {
            "from_secret": "docker_username"
          },
          "password": {
            "from_secret": "docker_password"
          },
          "dockerfile": "Dockerfile.%s" % (repo),
          "build_args": [
            "GOARCH=%s" % arch
          ],
          "context": "src/%s" % (repo),
          "repo": "%s/%s" % (ctx.repo.namespace, repo),
          "tags": ["%s-%s" % (TAG_PATTERN, arch)]
        }
      }
    ]
  }

def docker_manifest(ctx, repo):
  return {
    "kind": "pipeline",
    "type": "docker",
    "name": "%s-manifest" % (repo),
    "steps": [
      {
        "name": "push-manifest",
        "image": "plugins/manifest",
        "settings": {
          "username": {
            "from_secret": "docker_username"
          },
          "password": {
            "from_secret": "docker_password"
          },
          "target": "%s/%s:%s" % (ctx.repo.namespace, repo, TAG_PATTERN),
          "template": "%s/%s:%s-ARCH" % (ctx.repo.namespace, repo, TAG_PATTERN),
          "platforms": [
            "linux/amd64",
            "linux/arm64"
          ]
        }
      }
    ],
    "depends_on": ["%s-%s" % (repo, arch) for arch in TARGET_ARCH_LIST]
  }
