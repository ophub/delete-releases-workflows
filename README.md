# Function description / 功能说明

This Action can delete the Releases and Workflows runs of the specified repository.

这个 Actions 可以删除指定仓库的 Releases 和 Workflows 运行记录。

## Instructions / 使用说明

Introduce this Actions in the `.github/workflows/*.yml` workflows script to use, for example [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml).

在 `.github/workflows/*.yml` 工作流脚本中引入此 Actions 即可使用，例如 [delete.yml](https://github.com/ophub/amlogic-s9xxx-armbian/blob/main/.github/workflows/delete-older-releases-workflows.yml)。

```yaml
- name: Delete releases and workflows runs
  uses: ophub/delete-releases-workflows@main
  with:
    releases_keep_latest: 5
    workflows_keep_day: 10
    gh_token: ${{ secrets.GH_TOKEN }}
```

## Parameter description / 参数说明

| parameter/参数           | Defaults/默认值    | Description/说明                                                  |
|-------------------------|-------------------|-------------------------------------------------------------------|
| repo                    | `<owner>/<repo>`  | [Optional] Set the running repository, the default is the current repository. <br />[可选项] 设置运行仓库，默认为当前仓库。 |
| delete_tags             | true              | [Optional] Delete tags associated with releases (options: true/false). <br />[可选项] 删除与 Releases 关联的 tags (选项：true/false)。 |
| releases_keep_latest    | None / 无         | [Required] Set how many latest Releases versions to keep (Integer. eg: 5), Set to `0` to delete all. <br />[必选] 设置保留多少个最新的 Releases 版本（整数。如：5），设置为 `0` 表示全部删除。 |
| releases_keep_keyword   | None / 无         | [Optional] The keywords of the releases that need to be reserved (string). <br />[可选项] 需要保留的 Releases 的关键字（字符串）。 |
| workflows_keep_keyword  | None / 无         | [Optional] The keywords of workflows runs that need to be reserved (string). <br />[可选项] 需要保留的 workflows 运行记录的关键字（字符串）。 |
| workflows_keep_day      | 30                | [Optional] Set the number of days to keep workflow runs (Integer. eg: 30), Set to `0` to delete all. <br />[可选项] 设置保留多少天以内的 workflows 记录（整数。如：30），设置为 `0` 表示全部删除。 |
| out_log                 | false             | [Optional] Whether to output a listing log for each step (options: true/false). <br />[可选项] 是否为每个步骤输出一个列表日志 (选项：true/false)。 |
| gh_token                | None / 无         | [Required] Set the [GH_TOKEN](https://github.com/ophub/amlogic-s9xxx-armbian/tree/main/build-armbian/documents#2-set-the-privacy-variable-github_token) for performing delete operations. <br />[必选] 设置执行删除操作的 [GH_TOKEN](https://github.com/ophub/amlogic-s9xxx-armbian/tree/main/build-armbian/documents#2-set-the-privacy-variable-github_token) 口令。 |

## Links / 链接

- [GitHub Docs](https://docs.github.com/en/rest/releases/releases?list-releases)
- [unifreq/openwrt_packit](https://github.com/unifreq/openwrt_packit)
- [amlogic-s9xxx-armbian](https://github.com/ophub/amlogic-s9xxx-armbian)
- [amlogic-s9xxx-openwrt](https://github.com/ophub/amlogic-s9xxx-openwrt)
- [flippy-openwrt-actions](https://github.com/ophub/flippy-openwrt-actions)

## License / 许可

The delete-releases-workflows © OPHUB is licensed under [GPL-2.0](https://github.com/ophub/delete-releases-workflows/blob/main/LICENSE)

